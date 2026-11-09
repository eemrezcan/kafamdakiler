using System.Text.Json;
using System.Text.Json.Nodes;
using Kafamdakiler.Beyin;
using Kafamdakiler.Claude;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Gelen;

// What Claude is asked for: where a card goes, under what title and with which tags. Only ever a suggestion.
// `Etiketler` are main names of the dictionary only; a tag the dictionary lacks goes in `YeniEtiket` (never in `Etiketler`), and
// the server adds it to the tags when it queues the suggestion.
public record YerlestirmeOnerisi(string Yol, string Baslik, List<string> Etiketler, string Gerekce, double Guven, YeniEtiket? YeniEtiket);

public enum OneriDurumu
{
    // The suggestion is in the approval queue (or was applied at once, if the kind's mode allowed it).
    Olustu,
    // The kind is Yasak: the suggestion was dropped.
    Atlandi,
    // No such card in the visible list (a hidden card looks the same).
    KartYok,
    // The card is not sent to Claude (aimed at a hidden project or a closed folder, or unreadable).
    Gonderilemez,
    // The card is only an image: placed by hand.
    MetinYok,
    // A suggestion for this card is already waiting.
    BekleyenVar,
    BagliDegil,
    SinirDoldu,
    // Claude failed, answered badly, or the answer broke a rule. The card stays; the try is counted.
    Basarisiz,
}

public record OneriSonucu(OneriDurumu Durum, string? Mesaj = null, Eylem? Eylem = null);

// Asks Claude where each new inbox card goes and puts the answer in the approval queue as a "yerlestir" action.
// The card text is the only untrusted thing in the call: it goes as data between the client's delimiters, while the
// projects and the tag dictionary are part of the fixed instruction. Claude has no tools, so the worst a card can do is
// a bad suggestion, and every suggestion is checked again here before it is queued.
public class GelenOnerici(
    AppDbContext db, BeyinIstemcisi beyin, ClaudeIstemcisi claude, EylemServisi eylemler, GelenAyari ayar, TimeProvider saat, ILogger<GelenOnerici> gunluk)
{
    // One suggestion at a time: the background round and a manual "suggest again" must not both queue one for the same card.
    private static readonly SemaphoreSlim Kilit = new(1, 1);

    private const int GerekceEnUzun = 500;

    public record TurOzeti(int Onerilen, int Basarisiz, int Atlanan);

    private sealed record Baglam(List<BeyinKarti> Kartlar, List<ProjeOzetDto> ProjeListesi, EtiketSozlugu Sozluk)
    {
        // The ids of the projects that exist and are not hidden.
        public HashSet<string> Projeler { get; } = ProjeListesi.Select(p => p.Kimlik).ToHashSet(StringComparer.Ordinal);
    }

    // The manual "suggest again" of one card.
    public async Task<OneriSonucu> OnerAsync(string kimlik, CancellationToken ct)
    {
        if (!claude.Bagli || !beyin.Bagli)
            return new OneriSonucu(OneriDurumu.BagliDegil, claude.Bagli ? "Beyin bağlı değil." : "Claude bağlı değil.");

        var (baglam, hata) = await YukleAsync(ct);
        if (baglam is null)
            return hata!;
        if (baglam.Kartlar.FirstOrDefault(k => k.Kimlik == kimlik) is not { } kart)
            return new OneriSonucu(OneriDurumu.KartYok, "Böyle bir gelen kartı yok.");

        return await KartIcinAsync(kart, baglam, ct);
    }

    // The background round: new cards that have no suggestion yet and are not marked for the laptop.
    public async Task<TurOzeti> TurAsync(CancellationToken ct)
    {
        if (!claude.Bagli || !beyin.Bagli)
            return new TurOzeti(0, 0, 0);

        var (baglam, _) = await YukleAsync(ct);
        if (baglam is null)
            return new TurOzeti(0, 0, 0);

        // Rows of cards that are gone (placed, deleted) are dropped.
        var mevcut = baglam.Kartlar.Select(k => k.Kimlik).ToHashSet(StringComparer.Ordinal);
        var eskiler = await db.GelenKartlari.Where(r => !mevcut.Contains(r.Kart)).ToListAsync(ct);
        if (eskiler.Count > 0)
        {
            db.GelenKartlari.RemoveRange(eskiler);
            await db.SaveChangesAsync(ct);
        }

        var satirlar = await db.GelenKartlari.AsNoTracking().ToDictionaryAsync(r => r.Kart, ct);
        var simdi = saat.GetUtcNow();
        int onerilen = 0, basarisiz = 0, atlanan = 0, denenen = 0;
        foreach (var kart in baglam.Kartlar)
        {
            if (denenen >= ayar.TurBasinaEnCok)
                break;
            if (!Aday(satirlar.GetValueOrDefault(kart.Kimlik), simdi))
                continue;

            var sonuc = await KartIcinAsync(kart, baglam, ct);
            switch (sonuc.Durum)
            {
                case OneriDurumu.BagliDegil or OneriDurumu.SinirDoldu:
                    return new TurOzeti(onerilen, basarisiz, atlanan);
                case OneriDurumu.Olustu:
                    onerilen++;
                    denenen++;
                    break;
                case OneriDurumu.Basarisiz:
                    basarisiz++;
                    denenen++;
                    break;
                case OneriDurumu.Atlandi:
                    atlanan++;
                    denenen++;
                    break;
            }
        }

        return new TurOzeti(onerilen, basarisiz, atlanan);
    }

    // A card the round may try: new, or failed before and its waiting time is over. A card with a suggestion, one marked for
    // the laptop and one that failed too often are left alone (the manual "suggest again" still works on them).
    private bool Aday(GelenKartDurumu? satir, DateTimeOffset simdi) =>
        satir is null
        || (satir.OneriAni is null && !satir.LaptoptaIslenecek && satir.DenemeSayisi < ayar.EnCokDeneme
            && (satir.SonDenemeAt is not { } son || simdi - son >= ayar.DenemeBekleme * satir.DenemeSayisi));

    private async Task<(Baglam?, OneriSonucu?)> YukleAsync(CancellationToken ct)
    {
        var kartlar = await GelenBeyin.KartlariAlAsync(beyin, gunluk, ct);
        if (!kartlar.Basarili)
            return (null, YuklemeHatasi(kartlar.Durum));

        var projeler = await BeyinOkuma.ProjelerAl(beyin, gunluk, ct);
        if (!projeler.Basarili)
            return (null, YuklemeHatasi(projeler.Durum));

        var sozluk = await GelenBeyin.SozluguAlAsync(beyin, gunluk, ct);
        if (!sozluk.Basarili)
            return (null, YuklemeHatasi(sozluk.Durum));

        // An empty dictionary has nothing to offer Claude as a tag: no call, the cards wait.
        if (sozluk.Veri!.Bos)
            return (null, new OneriSonucu(OneriDurumu.Basarisiz, "Etiket sözlüğü boş ya da okunamadı."));

        return (new Baglam(kartlar.Veri!, projeler.Veri!, sozluk.Veri), null);
    }

    private static OneriSonucu YuklemeHatasi(int durum) => new(
        durum == StatusCodes.Status503ServiceUnavailable ? OneriDurumu.BagliDegil : OneriDurumu.Basarisiz,
        "Beyin okunamadı: kartlar, projeler ya da etiket sözlüğü alınamadı.");

    private async Task<OneriSonucu> KartIcinAsync(BeyinKarti kart, Baglam baglam, CancellationToken ct)
    {
        await Kilit.WaitAsync(ct);
        try
        {
            if ((await GelenIslemleri.BekleyenOnerilerAsync(db, ct)).ContainsKey(kart.Kimlik))
                return new OneriSonucu(OneriDurumu.BekleyenVar, "Bu kart için bekleyen bir öneri var; önce onu uygula ya da reddet.");

            // Nothing below this line may run for a card that is not allowed to go to Claude.
            if (!GelenKurallari.ClaudeaGidebilir(kart, baglam.Projeler, out var neden))
                return new OneriSonucu(OneriDurumu.Gonderilemez, neden);

            var okuma = await GelenBeyin.KartMetniAlAsync(kart.Kimlik, beyin, gunluk, ct);
            if (!okuma.Basarili)
            {
                // 404 is what a hidden or vanished card looks like: not sent, not tried again by the round.
                if (okuma.Durum == StatusCodes.Status404NotFound)
                {
                    await KaydetAsync(kart.Kimlik, s => { s.DenemeSayisi = ayar.EnCokDeneme; s.SonDenemeAt = saat.GetUtcNow(); s.SonHata = "Kart okunamadı ya da gizli."; }, ct);
                    return new OneriSonucu(OneriDurumu.Gonderilemez, "Kart okunamadı ya da gizli.");
                }

                return await BasarisizAsync(kart.Kimlik, "Kart okunamadı.", ct);
            }

            var metin = GelenKurallari.Metin(okuma.Veri!.Govde);
            if (metin.Length == 0)
            {
                await KaydetAsync(kart.Kimlik, s => { s.DenemeSayisi = ayar.EnCokDeneme; s.SonDenemeAt = saat.GetUtcNow(); s.SonHata = "Kartta metin yok."; }, ct);
                return new OneriSonucu(OneriDurumu.MetinYok, "Kart yalnız görsel; elle yerleştirilir.");
            }

            var istek = new ClaudeIstegi("gelen-yerlestir", Talimat(baglam), Veri(kart, metin), Sema(baglam.Sozluk));
            var yanit = await claude.SorAsync<YerlestirmeOnerisi>(istek, ct);
            switch (yanit.Durum)
            {
                case ClaudeDurumu.Tamam:
                    break;
                case ClaudeDurumu.BagliDegil:
                    return new OneriSonucu(OneriDurumu.BagliDegil, yanit.Mesaj);
                case ClaudeDurumu.SinirDoldu:
                    return new OneriSonucu(OneriDurumu.SinirDoldu, yanit.Mesaj);
                default:
                    return await BasarisizAsync(kart.Kimlik, yanit.Mesaj ?? "Claude cevap vermedi.", ct);
            }

            var oneri = yanit.Veri!;
            if (Denetle(oneri, baglam.Sozluk, baglam.Projeler, out var etiketler, out var yeniEtiket) is { } sorun)
                return await BasarisizAsync(kart.Kimlik, $"Claude'un önerisi kurala uymuyor: {sorun}", ct);

            var gerekce = Kisalt(oneri.Gerekce.Trim(), GerekceEnUzun);
            var simdi = saat.GetUtcNow();
            var yuk = JsonSerializer.SerializeToElement(new YerlestirYuku(kart.Kimlik, oneri.Yol, oneri.Baslik.Trim(), etiketler, YeniEtiket: yeniEtiket), JsonSerializerOptions.Web);
            var oner = new EylemOnerisi(
                YerlestirTuru.Anahtar, yuk, Kisalt($"{kart.Baslik} → {oneri.Yol}" + (yeniEtiket is null ? "" : $" (yeni etiket: {yeniEtiket.Ad})"), 200), "gelen", GelenKurallari.DisKaynakMi(metin), gerekce.Length > 0 ? gerekce : null, oneri.Guven);
            var sonuc = await eylemler.OnerAsync(oner, ct);

            switch (sonuc.Tur)
            {
                case EylemSonucuTuru.Tamam or EylemSonucuTuru.Hata when sonuc.Eylem is not null:
                    await KaydetAsync(kart.Kimlik, s =>
                    {
                        s.LaptoptaIslenecek = false;
                        s.LaptopNotu = null;
                        s.OneriAni = simdi;
                        s.DenemeSayisi = 0;
                        s.SonHata = null;
                    }, ct);
                    return new OneriSonucu(OneriDurumu.Olustu, Eylem: sonuc.Eylem);
                case EylemSonucuTuru.Atlandi:
                    await KaydetAsync(kart.Kimlik, s => { s.OneriAni = simdi; s.SonHata = null; }, ct);
                    return new OneriSonucu(OneriDurumu.Atlandi, sonuc.Mesaj);
                default:
                    return await BasarisizAsync(kart.Kimlik, sonuc.Mesaj ?? "Öneri kuyruğa alınamadı.", ct);
            }
        }
        finally
        {
            Kilit.Release();
        }
    }

    private async Task<OneriSonucu> BasarisizAsync(string kimlik, string mesaj, CancellationToken ct)
    {
        // The text can hold what the command printed; it stays in the log, the API says a fixed sentence.
        gunluk.LogWarning("Suggestion for an inbox card did not work out: {Mesaj}", mesaj);
        var simdi = saat.GetUtcNow();
        await KaydetAsync(kimlik, s =>
        {
            s.DenemeSayisi++;
            s.SonDenemeAt = simdi;
            s.SonHata = Kisalt(mesaj, 500);
        }, ct);
        return new OneriSonucu(OneriDurumu.Basarisiz, mesaj);
    }

    // The row is read at the moment it is changed: the queue may have cleared the change tracker since.
    private async Task KaydetAsync(string kimlik, Action<GelenKartDurumu> degistir, CancellationToken ct)
    {
        var satir = await db.GelenKartlari.FindAsync([kimlik], ct);
        if (satir is null)
        {
            satir = new GelenKartDurumu { Kart = kimlik };
            db.GelenKartlari.Add(satir);
        }

        degistir(satir);
        await db.SaveChangesAsync(ct);
    }

    // The answer is checked as if a stranger had typed it: the schema asked for these shapes, nothing here trusts it.
    // Null when it is fine. `etiketler` are the tags as the brain would store them, the new tag (if any) last; `yeniEtiket` is
    // that new tag with its section as the dictionary writes it.
    public static string? Denetle(YerlestirmeOnerisi o, EtiketSozlugu sozluk, IReadOnlySet<string> projeler, out List<string> etiketler) =>
        Denetle(o, sozluk, projeler, out etiketler, out _);

    public static string? Denetle(
        YerlestirmeOnerisi o, EtiketSozlugu sozluk, IReadOnlySet<string> projeler, out List<string> etiketler, out YeniEtiket? yeniEtiket)
    {
        etiketler = [];
        yeniEtiket = null;
        if (o.Gerekce is null || o.Baslik is null || o.Yol is null || o.Etiketler is null)
            return "eksik alan";
        if (double.IsNaN(o.Guven) || o.Guven is < 0 or > 1)
            return "güven 0 ile 1 arasında olmalı";

        if (GelenYolu.Denetle(o.Yol, projeler) is { } yolHatasi)
            return $"yol: {yolHatasi}";

        var baslik = o.Baslik.Trim();
        if (baslik.Length is 0 or > YerlestirTuru.EnUzunBaslik || GelenKurallari.DenetimKarakteriVar(baslik))
            return "başlık boş, çok uzun ya da satır sonu içeriyor";

        // A new tag must be new: not a main name and not a synonym, and its section must exist in the dictionary.
        if (o.YeniEtiket is not null)
        {
            if (YerlestirTuru.YeniEtiketHatasi(o.YeniEtiket) is { } yeniHatasi)
                return $"yeni etiket: {yeniHatasi}";
            if (sozluk.Coz(o.YeniEtiket.Ad) is not null || o.YeniEtiket.Esler.Any(e => sozluk.Coz(e) is not null))
                return "yeni etiket ya da eş sözcüğü sözlükte zaten var";
            if (sozluk.BolumAdi(o.YeniEtiket.Bolum) is not { } bolum)
                return "yeni etiketin bölümü sözlükte yok";
            yeniEtiket = new YeniEtiket(o.YeniEtiket.Ad, [.. o.YeniEtiket.Esler], bolum);
        }

        // Main names of the dictionary only, whatever the schema said: an invented tag passes only as the marked new one.
        if (o.Etiketler.Any(e => !sozluk.AnaAdMi(e)))
            return "etiket sözlükte yok";
        etiketler = o.Etiketler.Select(e => sozluk.Coz(e)!).Distinct(StringComparer.Ordinal).ToList();
        if (yeniEtiket is not null)
            etiketler.Add(yeniEtiket.Ad);
        // The instruction asks for 3 to 6, but one is enough for the brain (it wants at least one); a short answer is not thrown away.
        if (etiketler.Count is < 1 or > 6)
            return "etiket sayısı 1 ile 6 arasında olmalı";

        return null;
    }

    // The fixed part of the call. Projects and tags come from the brain; they are flattened to one line each.
    public static string Talimat(EtiketSozlugu sozluk, IEnumerable<(string Kimlik, string Baslik)> projeler)
    {
        var liste = projeler.Select(p => $"  - {Satir(p.Kimlik, 80)}: {Satir(p.Baslik, 80)}").ToList();
        return
            "Sen kişisel bir bilgi deposunun (ikinci beyin) gelen kutusu yardımcısısın. Kullanıcı bir düşünce, not ya da bağlantı yakaladı; " +
            "bu kartın depoda nereye kaydedileceğini, başlığını ve etiketlerini öner.\n\n" +
            "Yol kuralları (yol, depo köküne göreli tek bir dosya yolu; küçük harfli, boşluksuz, ASCII, sözcükler tireyle, .md ile biter):\n" +
            "- Bir projeye aitse: projects/<proje>/notlar/<dosya-adi>.md. Proje yalnız şunlardan biri olabilir:\n" +
            (liste.Count > 0 ? string.Join('\n', liste) : "  (hiç proje yok; bu yolu kullanma)") + "\n" +
            "- Öğrenme, ders, okul, staj, kaynak: ogrenme/<dosya-adi>.md\n" +
            "- Spor ve antrenman: spor/<dosya-adi>.md\n" +
            "- Alışkanlıklar: aliskanliklar/<dosya-adi>.md\n" +
            "- Alt klasör, başka bir klasör, finans/, kisisel/ ya da listede olmayan bir proje kullanma.\n\n" +
            "baslik: kartı anlatan kısa başlık, en çok 80 karakter, kartın dilinde.\n" +
            $"etiketler: yalnız şu listeden, 3 ile 6 tane: {string.Join(", ", sozluk.AnaAdlar.Select(a => Satir(a, 40)))}\n" +
            "Listedeki etiketler karta yetmiyorsa ve gerçekten yeni bir etiket gerekiyorsa yeniEtiket alanını doldur, yoksa null bırak. " +
            "Var olan bir etiket işi görüyorsa yeni etiket önerme. Yeni etiket etiketler listesine yazılmaz, sunucu ekler (toplam en çok 6 etiket).\n" +
            "yeniEtiket.ad: küçük harf, boşluksuz, çok sözcük tireyle, en çok 40 karakter; yeniEtiket.esler: eş sözcükler, adla aynı kurallarla (küçük harf, boşluksuz, çok sözcük tireyle; en çok 6, listede olmayanlar, boş olabilir); " +
            $"yeniEtiket.bolum: yalnız şu bölümlerden biri: {string.Join(", ", sozluk.Bolumler.Select(b => Satir(b, 60)))}\n" +
            "gerekce: seçimini anlatan tek kısa Türkçe cümle. guven: 0 ile 1 arasında bir sayı; emin değilsen düşük ver.";
    }

    private static string Talimat(Baglam b) => Talimat(b.Sozluk, b.ProjeListesi.Select(p => (p.Kimlik, p.Baslik)));

    // The untrusted part: the card text and the hint the card carries. The client puts it between random delimiters.
    public static string Veri(BeyinKarti kart, string metin) =>
        $"Hedef ipucu: {(string.IsNullOrWhiteSpace(kart.Hedef) ? "yok" : Satir(kart.Hedef, 200))}\n" +
        $"Yakalanma: {kart.Yakalandi ?? "bilinmiyor"}\n\n" +
        Kisalt(metin, GelenKurallari.EnUzunMetin);

    // The answer shape. The tags are an enum of the dictionary's main names; the ranges are checked after the answer, not
    // here (the checked-answer mode of the CLI does not promise every keyword).
    public static string Sema(EtiketSozlugu sozluk)
    {
        var etiketler = new JsonArray(sozluk.AnaAdlar.Select(a => (JsonNode)JsonValue.Create(a)!).ToArray());
        var sema = new JsonObject
        {
            ["type"] = "object",
            ["properties"] = new JsonObject
            {
                ["yol"] = new JsonObject { ["type"] = "string" },
                ["baslik"] = new JsonObject { ["type"] = "string" },
                ["etiketler"] = new JsonObject
                {
                    ["type"] = "array",
                    ["items"] = new JsonObject { ["type"] = "string", ["enum"] = etiketler },
                },
                ["gerekce"] = new JsonObject { ["type"] = "string" },
                ["guven"] = new JsonObject { ["type"] = "number" },
                ["yeniEtiket"] = YeniEtiketSemasi(sozluk),
            },
            ["required"] = new JsonArray("yol", "baslik", "etiketler", "gerekce", "guven", "yeniEtiket"),
            ["additionalProperties"] = false,
        };
        return sema.ToJsonString();
    }

    // Null, or a tag the dictionary lacks. The section is an enum of the dictionary's own headings.
    private static JsonObject YeniEtiketSemasi(EtiketSozlugu sozluk)
    {
        var bolum = new JsonObject { ["type"] = "string" };
        if (sozluk.Bolumler.Count > 0)
            bolum["enum"] = new JsonArray(sozluk.Bolumler.Select(b => (JsonNode)JsonValue.Create(b)!).ToArray());

        return new JsonObject
        {
            ["type"] = new JsonArray("object", "null"),
            ["properties"] = new JsonObject
            {
                ["ad"] = new JsonObject { ["type"] = "string" },
                ["esler"] = new JsonObject { ["type"] = "array", ["items"] = new JsonObject { ["type"] = "string" } },
                ["bolum"] = bolum,
            },
            ["required"] = new JsonArray("ad", "esler", "bolum"),
            ["additionalProperties"] = false,
        };
    }

    private static string Satir(string metin, int enUzun) =>
        Kisalt(new string(metin.Select(c => GelenKurallari.DenetimKarakteriVar(c.ToString()) ? ' ' : c).ToArray()).Trim(), enUzun);

    private static string Kisalt(string metin, int enUzun) => metin.Length <= enUzun ? metin : metin[..enUzun].TrimEnd();
}
