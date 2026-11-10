using System.Diagnostics;
using System.Globalization;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.Isler;
using Kafamdakiler.Ses;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Asistan;

// The assistant's single entry (K-0024, §7.1 and §7.2). A person's own words or photo go in; what they are is worked out (AsistanSiniflandirici)
// and applied at once, because it is the person's own input: no approval step. That is the rule of this entry only. What stays outside it:
// the kind's mode `Yasak` and the person's own permission for what each kind does are asked every time; text from anywhere else (a mail) keeps
// to the approval queue (DisKaynak), as does anything the assistant is not sure of: it asks one question and applies nothing until it is answered.
//
// Nothing the person typed is lost. If Claude cannot be used, or finds no work in the text, or none of what it found can be applied, the text
// (and the photo) is saved as a note in the capture line and the result says so. A repeated client id is the same answer, never a second run.
public class AsistanServisi(
    AppDbContext db, AsistanSiniflandirici siniflandirici, EylemServisi eylemler, IAuthorizationService yetki, BildirimServisi bildirimler,
    BeyinIstemcisi beyin, TimeProvider saat, ILogger<AsistanServisi> gunluk)
{
    // How long a repeated request waits for the first one that is still running (the Claude call), before it says "still running".
    public static TimeSpan BeklemeSuresi { get; set; } = TimeSpan.FromSeconds(30);

    // A claim with no answer this long after it was made belongs to a run that died with the server.
    public static readonly TimeSpan TakilmaSuresi = TimeSpan.FromMinutes(10);

    public const string Kaynak = "asistan";

    // The source of an input from the share menu (E7).
    public const string PaylasKaynagi = "paylas";

    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    // What is kept of a question: the asked words and the day the first round counted as today.
    internal record SoruKaydi(Guid Id, string Metin, List<string> Secenekler, string Bugun);

    private record IsSonucu(List<AsistanSonucuDto> Sonuclar, AsistanSorusuDto? Soru);

    // Entry

    public async Task<SesSonucu<AsistanYanitiDto>> GirdiAsync(AsistanGirdisiDto girdi, ClaimsPrincipal kullanici, CancellationToken ct)
    {
        var metin = string.IsNullOrWhiteSpace(girdi.Metin) ? null : girdi.Metin.Trim();
        if (metin is null && girdi.FotografId is null)
            return new(Hata: Sorun("metin", "Metin ya da fotoğraftan en az biri dolu olmalı."));
        if (EylemEndpoints.KullaniciId(kullanici) is not { } kullaniciId)
            return new(Hata: Results.Unauthorized());

        var simdi = saat.GetUtcNow();
        var sunucuBugun = GunSiniri.Bugun(simdi);
        var bugun = girdi.Bugun ?? sunucuBugun;
        if (Math.Abs(bugun.DayNumber - sunucuBugun.DayNumber) > 1)
            return new(Hata: Sorun("bugun", "Bugünün tarihi sunucunun gününden en çok bir gün farklı olabilir."));

        var girdiId = girdi.Id!.Value;
        var kaynak = KaynakAdi(girdi.Kaynak!.Value);

        // A repeat of an input that is already known is answered before anything is checked again.
        if (await YanitiOkuAsync(kullaniciId, girdiId, cevap: false, ct) is { } bilinen)
            return new(bilinen);

        if (await FotografKurali.HataAsync(db, girdi.FotografId, null, null, ct) is { } fotografHatasi)
            return new(Hata: Sorun(fotografHatasi.Alan ?? "fotografId", fotografHatasi.Mesaj!));

        var satir = new AsistanMesaji
        {
            KullaniciId = kullaniciId, Zaman = simdi, Tur = AsistanMesajTuru.Kullanici, Metin = metin, FotografId = girdi.FotografId, Kaynak = kaynak, GirdiId = girdiId,
        };
        db.AsistanMesajlari.Add(satir);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Another request with this id claimed it between our read and our insert: it is the same input.
            db.Entry(satir).State = EntityState.Detached;
            return await TekrarAsync(kullaniciId, girdiId, cevap: false, istenenCevap: null, ct);
        }

        // From the claim on, the work is not tied to the request: a phone that drops the connection must not leave an input half known.
        var sonuc = await IsleAsync(
            kullanici, kullaniciId, girdiId, satir.Id, metin, girdi.FotografId, kaynak, bugun, claudeMetni: null, ikinciTur: false, simdi, CancellationToken.None);
        return new(new AsistanYanitiDto(girdiId, satir.Id, sonuc.Sonuclar, sonuc.Soru));
    }

    // The answer to a question (§7.2): the first round's text and the question and the answer go to Claude together, once more. It may not
    // ask again: if it is still unsure it applies the most likely reading.
    public async Task<SesSonucu<AsistanYanitiDto>> CevapAsync(Guid soruId, string cevap, ClaimsPrincipal kullanici, CancellationToken ct)
    {
        if (EylemEndpoints.KullaniciId(kullanici) is not { } kullaniciId)
            return new(Hata: Results.Unauthorized());

        var metin = cevap.Trim();
        var soruSatiri = await db.AsistanMesajlari.AsNoTracking()
            .FirstOrDefaultAsync(m => m.Id == soruId && m.KullaniciId == kullaniciId && m.Tur == AsistanMesajTuru.Soru, ct);
        if (soruSatiri is null)
            return new(Hata: Results.NotFound());

        // The first answer claims the question; the same answer again gets the first one's result back.
        var simdi = saat.GetUtcNow();
        var alinan = await db.AsistanMesajlari.Where(m => m.Id == soruId && m.CevaplandiAni == null)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.CevaplandiAni, simdi), ct);
        if (alinan == 0)
            return await TekrarAsync(kullaniciId, soruSatiri.GirdiId, cevap: true, istenenCevap: metin, ct);

        var kayit = JsonSerializer.Deserialize<SoruKaydi>(soruSatiri.SoruJson!, Json)!;
        var ilk = await db.AsistanMesajlari.AsNoTracking().FirstAsync(
            m => m.KullaniciId == kullaniciId && m.GirdiId == soruSatiri.GirdiId && m.Tur == AsistanMesajTuru.Kullanici && m.Kaynak != AsistanMesaji.CevapKaynagi, ct);

        var cevapSatiri = new AsistanMesaji
        {
            KullaniciId = kullaniciId, Zaman = Sonra(soruSatiri.Zaman, 3), Tur = AsistanMesajTuru.Kullanici, Metin = metin, Kaynak = AsistanMesaji.CevapKaynagi, GirdiId = soruSatiri.GirdiId,
        };
        db.AsistanMesajlari.Add(cevapSatiri);
        await db.SaveChangesAsync(CancellationToken.None);

        var bugun = DateOnly.TryParseExact(kayit.Bugun, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var b) ? b : GunSiniri.Bugun(simdi);
        var claudeMetni =
            $"İLK MESAJ (kullanıcının yazdığı):\n{ilk.Metin}\n\n" +
            $"SİSTEMİN SORUSU:\n{kayit.Metin}\nSeçenekler: {string.Join(" | ", kayit.Secenekler)}\n\n" +
            $"KULLANICININ CEVABI:\n{metin}";
        var sonuc = await IsleAsync(
            kullanici, kullaniciId, soruSatiri.GirdiId, cevapSatiri.Id, ilk.Metin, ilk.FotografId, AsistanMesaji.CevapKaynagi, bugun, claudeMetni, ikinciTur: true, cevapSatiri.Zaman, CancellationToken.None,
            ilkKaynak: ilk.Kaynak);
        return new(new AsistanYanitiDto(soruSatiri.GirdiId, cevapSatiri.Id, sonuc.Sonuclar, sonuc.Soru));
    }

    // The work

    private async Task<IsSonucu> IsleAsync(
        ClaimsPrincipal kullanici, Guid kullaniciId, Guid girdiId, Guid mesajId, string? metin, Guid? fotografId, string kaynak, DateOnly bugun,
        string? claudeMetni, bool ikinciTur, DateTimeOffset simdi, CancellationToken ct, string? ilkKaynak = null)
    {
        // Words that came through the share menu may be another app's: only a note is made of them at once, the rest waits for approval (E7).
        var disKaynak = (ilkKaynak ?? kaynak) == PaylasKaynagi;
        var sonuclar = new List<AsistanSonucuDto>();
        var anahtarOnEki = ikinciTur ? "c" : "";
        try
        {
            string? yedekMesaji = null;
            List<HazirOneri> oneriler;
            var atlananlar = new List<AtlananOneri>();

            if (metin is null)
            {
                // A photo alone is a note: nothing to classify, and the photo never goes to Claude.
                oneriler = [TumuNot(null)];
            }
            else
            {
                var s = await siniflandirici.SiniflandirAsync(metin, claudeMetni ?? metin, bugun, soruSorabilir: !ikinciTur, baglamli: ikinciTur, disKaynak ? "Paylaşım" : "Asistan", ct);
                if (s.Durum == SiniflandirmaDurumu.Kullanilamiyor)
                {
                    gunluk.LogWarning("The assistant could not use Claude for input {GirdiId}: {Neden}", girdiId, s.Neden);
                    oneriler = [TumuNot(metin)];
                    yedekMesaji = $"{s.Neden} Mesajın not olarak kaydedildi.";
                }
                else if (s.Soru is { } soru)
                {
                    return await SoruSorAsync(kullaniciId, girdiId, mesajId, kaynak, bugun, soru, simdi);
                }
                else if (!ikinciTur && s.Oneriler.FirstOrDefault(o => o.Guven is { } g && g < AsistanSiniflandirici.GuvenEsigi) is { } belirsiz)
                {
                    // Not sure enough to apply on its own: one question, nothing applied yet.
                    return await SoruSorAsync(kullaniciId, girdiId, mesajId, kaynak, bugun, KararsizSoru(belirsiz), simdi);
                }
                else
                {
                    oneriler = s.Oneriler;
                    atlananlar = s.Atlananlar;
                    if (oneriler.Count == 0 && atlananlar.Count == 0)
                    {
                        oneriler = [TumuNot(metin)];
                        yedekMesaji = "Yapılacak bir iş bulunamadı; mesajın not olarak kaydedildi.";
                    }
                }
            }

            var fotografKullanildi = false;
            var sira = 0;
            foreach (var o in oneriler)
            {
                var sonuc = o.Tur switch
                {
                    AsistanSiniflandirici.Not => await NotUygulaAsync(o, metin, fotografKullanildi ? null : fotografId, yedekMesaji, kullanici, kullaniciId, bugun, simdi, ct),
                    _ when disKaynak => await KuyrugaOnerAsync(o, kullanici, bugun, ct),
                    AsistanSiniflandirici.Is => await IsKartiAcAsync(o, kullanici, bugun, ct),
                    _ => await KuyrukUygulaAsync(o, kullanici, kullaniciId, bugun, ct),
                };
                if (o.Tur == AsistanSiniflandirici.Not && sonuc.Durum == AsistanDurumu.Uygulandi && fotografId is not null)
                    fotografKullanildi = true;

                sonuclar.Add(sonuc);
                await BildirimYazAsync(kullaniciId, girdiId, $"{anahtarOnEki}{sira++}", o, sonuc);
            }

            // What could not be applied is told, one by one: a missing suggestion is never silent.
            sonuclar.AddRange(atlananlar.Select(a => new AsistanSonucuDto(
                a.Tur ?? "bilinmiyor", string.IsNullOrWhiteSpace(a.Baslik) ? "Öneri" : AsistanSiniflandirici.Temizle(a.Baslik, 200), "", AsistanDurumu.Gecersiz, null,
                new AsistanHedefiDto(null, null), false, a.Neden)));

            // The photo of an input whose text was something else: it goes into a note of its own, so it is not lost.
            if (fotografId is not null && !fotografKullanildi)
            {
                var foto = await NotUygulaAsync(TumuNot(null), null, fotografId, null, kullanici, kullaniciId, bugun, simdi, ct);
                sonuclar.Add(foto);
                await BildirimYazAsync(kullaniciId, girdiId, $"{anahtarOnEki}{sira++}", TumuNot(null), foto);
            }

            // The person's words must not end up nowhere: when nothing came of the suggestions (a rule broken, a failure), the text is kept as a note.
            // A refusal of permission is the person's own setting and is respected as it is.
            if (metin is not null && !sonuclar.Any(s => s.Durum is AsistanDurumu.Uygulandi or AsistanDurumu.IzinYok or AsistanDurumu.Onayda) && !oneriler.Any(o => o.Tur == AsistanSiniflandirici.Not))
            {
                var yedek = await NotUygulaAsync(TumuNot(metin), metin, null, "Önerilerin hiçbiri uygulanamadı; mesajın not olarak kaydedildi.", kullanici, kullaniciId, bugun, simdi, ct);
                sonuclar.Add(yedek);
                await BildirimYazAsync(kullaniciId, girdiId, $"{anahtarOnEki}{sira++}", TumuNot(metin), yedek);
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            // Something broke around the work: what was done before it stays in the list, and the failure is one more line of it.
            gunluk.LogError(e, "The assistant failed while working on input {GirdiId}", girdiId);
            db.ChangeTracker.Clear();
            sonuclar.Add(new AsistanSonucuDto("bilinmiyor", "Beklenmeyen hata", "", AsistanDurumu.Hata, null, new AsistanHedefiDto(null, null), false,
                "Girdi işlenirken beklenmeyen bir hata oldu; yapılmış olanlar listede. Gerekirse tekrar dene."));
        }

        db.AsistanMesajlari.Add(new AsistanMesaji
        {
            KullaniciId = kullaniciId, Zaman = Sonra(simdi), Tur = AsistanMesajTuru.Sonuc, Kaynak = kaynak, GirdiId = girdiId, SonuclarJson = JsonSerializer.Serialize(sonuclar, Json),
        });
        await db.SaveChangesAsync(CancellationToken.None);
        return new IsSonucu(sonuclar, null);
    }

    // One question; nothing was applied. The rows: the question, and an empty result that says the round is over (a repeat reads it).
    private async Task<IsSonucu> SoruSorAsync(
        Guid kullaniciId, Guid girdiId, Guid mesajId, string kaynak, DateOnly bugun, AsistanSorusuOnerisi soru, DateTimeOffset simdi)
    {
        var satir = new AsistanMesaji
        {
            KullaniciId = kullaniciId, Zaman = Sonra(simdi), Tur = AsistanMesajTuru.Soru, Metin = soru.Metin, Kaynak = kaynak, GirdiId = girdiId,
        };
        var kayit = new SoruKaydi(satir.Id, soru.Metin, soru.Secenekler, $"{bugun:yyyy-MM-dd}");
        satir.SoruJson = JsonSerializer.Serialize(kayit, Json);
        db.AsistanMesajlari.Add(satir);
        db.AsistanMesajlari.Add(new AsistanMesaji
        {
            KullaniciId = kullaniciId, Zaman = Sonra(simdi, 2), Tur = AsistanMesajTuru.Sonuc, Kaynak = kaynak, GirdiId = girdiId, SonuclarJson = "[]",
        });
        await db.SaveChangesAsync(CancellationToken.None);
        return new IsSonucu([], new AsistanSorusuDto(kayit.Id, kayit.Metin, kayit.Secenekler));
    }

    // The question the server asks itself when Claude gave a suggestion with too little confidence and no question of its own.
    private static AsistanSorusuOnerisi KararsizSoru(HazirOneri o)
    {
        var secenekler = new List<string> { TurEtiketi(o.Tur) };
        if (o.Tur != AsistanSiniflandirici.Not)
            secenekler.Add("Not olarak kaydet");
        return new AsistanSorusuOnerisi($"“{AsistanSiniflandirici.Temizle(o.Baslik, 80)}” için ne yapayım?", secenekler);
    }

    // The kinds

    private async Task<AsistanSonucuDto> KuyrukUygulaAsync(HazirOneri o, ClaimsPrincipal kullanici, Guid kullaniciId, DateOnly bugun, CancellationToken ct)
    {
        var c = o.Kuyruk!;
        var ozet = OzetMetni(o, bugun);
        var hedefRota = c.Oneri.Gun is { } gun ? $"/gun/{gun}" : null;
        AsistanSonucuDto Sonuc(AsistanDurumu durum, string? mesaj, Guid? eylemId = null, string? kimlik = null, bool geriAlinabilir = false) =>
            new(o.Tur, o.Baslik, ozet, durum, eylemId, new AsistanHedefiDto(kimlik, hedefRota), geriAlinabilir, mesaj);

        // The permission of what the kind does, then the kind's mode: `Yasak` is the person's own "never", and holds here too.
        if (!await IzinliMi(kullanici, IsCikarServisi.TurIzni(o.Tur)!))
            return Sonuc(AsistanDurumu.IzinYok, "Bu işlem için izniniz yok.");
        var izin = await db.EylemIzinleri.AsNoTracking().FirstOrDefaultAsync(i => i.Tur == o.Tur, ct);
        if (izin?.Kip == EylemKipi.Yasak)
            return Sonuc(AsistanDurumu.IzinYok, "Bu tür asistan için yasak olarak ayarlı.");

        var oneri = new EylemOnerisi(o.Tur, c.Yuk, c.Ozet, Kaynak, DisKaynak: false, c.Gerekce, c.Oneri.Guven);
        var sonuc = await eylemler.OnayliUygulaAsync(oneri, kullaniciId, ct);
        switch (sonuc.Tur)
        {
            case EylemSonucuTuru.Tamam:
                var eylem = sonuc.Eylem!;
                return Sonuc(AsistanDurumu.Uygulandi, null, eylem.Id, HedefKimligi(o.Tur, eylem), eylemler.DtoYap(eylem).GeriAlinabilir && eylem.Durum == EylemDurumu.Uygulandi);
            case EylemSonucuTuru.Gecersiz:
                return Sonuc(AsistanDurumu.Gecersiz, sonuc.Mesaj);
            default:
                return Sonuc(AsistanDurumu.Hata, sonuc.Mesaj ?? "Eylem uygulanamadı.", sonuc.Eylem?.Id);
        }
    }

    // Text from the share menu (E7): everything but a note waits in the approval queue as an action from an outside source (`DisKaynak`), which no mode
    // ever applies by itself. The person's own permission for the kind and the kind's `Yasak` mode are still asked, so nothing is queued that could
    // not be done. The result is `onayda` with the action's id; it is approved or rejected in the queue (the feed shows it as an approval card).
    private async Task<AsistanSonucuDto> KuyrugaOnerAsync(HazirOneri o, ClaimsPrincipal kullanici, DateOnly bugun, CancellationToken ct)
    {
        var ozet = OzetMetni(o, bugun);
        var isKarti = o.Tur == AsistanSiniflandirici.Is;
        AsistanSonucuDto Sonuc(AsistanDurumu durum, string? mesaj, Guid? eylemId = null) =>
            new(o.Tur, o.Baslik, ozet, durum, eylemId, new AsistanHedefiDto(null, "/asistan"), false, mesaj);

        var izin = isKarti ? IsPolicies.Yaz : IsCikarServisi.TurIzni(o.Tur)!;
        if (!await IzinliMi(kullanici, izin))
            return Sonuc(AsistanDurumu.IzinYok, "Bu işlem için izniniz yok.");

        var turAdi = isKarti ? IsAcTuru.Anahtar : o.Tur;
        if ((await db.EylemIzinleri.AsNoTracking().FirstOrDefaultAsync(i => i.Tur == turAdi, ct))?.Kip == EylemKipi.Yasak)
            return Sonuc(AsistanDurumu.IzinYok, "Bu tür asistan için yasak olarak ayarlı.");

        EylemOnerisi oneri;
        if (isKarti)
        {
            var g = o.IsGirdisi!;
            var yuk = JsonSerializer.SerializeToElement(new IsAcYuku(g.Baslik!, g.Talep, g.Proje, g.Alan, g.Tip), JsonSerializerOptions.Web);
            oneri = new EylemOnerisi(IsAcTuru.Anahtar, yuk, $"İş kartı: {o.Baslik}"[..Math.Min(200, $"İş kartı: {o.Baslik}".Length)], PaylasKaynagi, DisKaynak: true, "Paylaşımdan", o.Guven);
        }
        else
        {
            oneri = new EylemOnerisi(o.Tur, o.Kuyruk!.Yuk, o.Kuyruk.Ozet, PaylasKaynagi, DisKaynak: true, o.Kuyruk.Gerekce, o.Kuyruk.Oneri.Guven);
        }

        var sonuc = await eylemler.OnerAsync(oneri, ct);
        return sonuc.Tur switch
        {
            EylemSonucuTuru.Tamam => Sonuc(AsistanDurumu.Onayda, "Paylaşımdan geldiği için onayını bekliyor.", sonuc.Eylem!.Id),
            EylemSonucuTuru.Atlandi => Sonuc(AsistanDurumu.IzinYok, "Bu tür asistan için yasak olarak ayarlı."),
            EylemSonucuTuru.Gecersiz => Sonuc(AsistanDurumu.Gecersiz, sonuc.Mesaj),
            _ => Sonuc(AsistanDurumu.Hata, sonuc.Mesaj ?? "Öneri kuyruğa alınamadı."),
        };
    }

    // The note: the person's own words (the whole text, or the part Claude quoted exactly) and the photo go into the capture line.
    private async Task<AsistanSonucuDto> NotUygulaAsync(
        HazirOneri o, string? metin, Guid? fotografId, string? mesaj, ClaimsPrincipal kullanici, Guid kullaniciId, DateOnly bugun, DateTimeOffset simdi, CancellationToken ct)
    {
        var fotoluk = metin is null && fotografId is not null;
        var baslik = fotoluk ? "Fotoğraf" : o.Baslik;
        var ozet = fotoluk ? "Fotoğraf yakalamaya eklendi" : "Yakalamaya eklendi";
        AsistanSonucuDto Sonuc(AsistanDurumu durum, string? m, string? kimlik = null, bool geriAlinabilir = false) =>
            new(AsistanSiniflandirici.Not, baslik, ozet, durum, null, new AsistanHedefiDto(kimlik, "/asistan"), geriAlinabilir, m);

        if (!await IzinliMi(kullanici, YakalamaPolicies.Yaz))
            return Sonuc(AsistanDurumu.IzinYok, "Not kaydetmek için izniniz yok.");

        var (sonuc, yakalama) = await YakalamaIslemleri.OlusturAsync(
            db, new YakalamaYazDto { Metin = o.Parca ?? metin, FotografId = fotografId, YakalandiAt = simdi }, ct);
        return sonuc.Basarili
            ? Sonuc(AsistanDurumu.Uygulandi, mesaj, yakalama!.Id.ToString(), geriAlinabilir: true)
            : Sonuc(AsistanDurumu.Gecersiz, sonuc.Mesaj);
    }

    // The work card: the person's request goes to the brain as the card's request. A card cannot be undone from here (it is cancelled with a reason).
    private async Task<AsistanSonucuDto> IsKartiAcAsync(HazirOneri o, ClaimsPrincipal kullanici, DateOnly bugun, CancellationToken ct)
    {
        var ozet = OzetMetni(o, bugun);
        AsistanSonucuDto Sonuc(AsistanDurumu durum, string? mesaj, string? kimlik = null) =>
            new(AsistanSiniflandirici.Is, o.Baslik, ozet, durum, null, new AsistanHedefiDto(kimlik, kimlik is null ? null : $"/isler/{kimlik}"), false, mesaj);

        if (!await IzinliMi(kullanici, IsPolicies.Yaz))
            return Sonuc(AsistanDurumu.IzinYok, "İş kartı açmak için izniniz yok.");

        var yanit = await IsKartlari.Ac(o.IsGirdisi!, beyin, gunluk, ct);
        if (yanit.Basarili)
            return Sonuc(AsistanDurumu.Uygulandi, null, ((IsKartiDto)yanit.Veri!).Kimlik);

        return yanit.Tur switch
        {
            YazmaTuru.Belirsiz => Sonuc(AsistanDurumu.Hata, "Beyin zamanında cevap vermedi; kart açılmış olabilir, iş kartlarına bak."),
            _ when yanit.Durum == StatusCodes.Status400BadRequest => Sonuc(AsistanDurumu.Gecersiz, yanit.Ayrinti ?? "Beyin isteği kabul etmedi."),
            _ => Sonuc(AsistanDurumu.Hata, yanit.Baslik ?? "İş kartı açılamadı."),
        };
    }

    // Each thing done leaves a row for the notification center, without a push (the person is the one who asked).
    private async Task BildirimYazAsync(Guid kullaniciId, Guid girdiId, string anahtarSonu, HazirOneri o, AsistanSonucuDto sonuc)
    {
        if (sonuc.Durum != AsistanDurumu.Uygulandi)
            return;

        try
        {
            var baslik = $"{TurFiili(o.Tur)}: {sonuc.Baslik}";
            await bildirimler.OlusturAsync(
                kullaniciId, baslik.Length <= 200 ? baslik : baslik[..200].TrimEnd(), sonuc.Ozet, Kaynak, sonuc.Hedef.Rota, sonuc.Hedef.Kimlik,
                CancellationToken.None, anahtar: $"{Kaynak}:{girdiId}:{anahtarSonu}");
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            // The notification is a record of what was done, not part of doing it.
            gunluk.LogWarning(e, "The notification row of an assistant result could not be written");
            db.ChangeTracker.Clear();
        }
    }

    private async Task<bool> IzinliMi(ClaimsPrincipal kullanici, string politika) =>
        (await yetki.AuthorizeAsync(kullanici, null, politika)).Succeeded;

    // Repeats

    // The answer of an input that is already known, or null. The rows are the record: no separate store.
    private async Task<AsistanYanitiDto?> YanitiOkuAsync(Guid kullaniciId, Guid girdiId, bool cevap, CancellationToken ct)
    {
        var satirlar = await db.AsistanMesajlari.AsNoTracking().Where(m => m.KullaniciId == kullaniciId && m.GirdiId == girdiId).ToListAsync(ct);
        return YanitKur(satirlar, girdiId, cevap);
    }

    internal static AsistanYanitiDto? YanitKur(List<AsistanMesaji> satirlar, Guid girdiId, bool cevap)
    {
        bool Turu(AsistanMesaji m) => (m.Kaynak == AsistanMesaji.CevapKaynagi) == cevap;
        var kullanici = satirlar.FirstOrDefault(m => m.Tur == AsistanMesajTuru.Kullanici && Turu(m));
        var sonuc = satirlar.FirstOrDefault(m => m.Tur == AsistanMesajTuru.Sonuc && Turu(m));
        if (kullanici is null || sonuc is null)
            return null;

        AsistanSorusuDto? soru = null;
        if (!cevap && satirlar.FirstOrDefault(m => m.Tur == AsistanMesajTuru.Soru) is { SoruJson: not null } soruSatiri)
        {
            var kayit = JsonSerializer.Deserialize<SoruKaydi>(soruSatiri.SoruJson, Json)!;
            soru = new AsistanSorusuDto(kayit.Id, kayit.Metin, kayit.Secenekler);
        }

        return new AsistanYanitiDto(girdiId, kullanici.Id, JsonSerializer.Deserialize<List<AsistanSonucuDto>>(sonuc.SonuclarJson ?? "[]", Json)!, soru);
    }

    // A request that met a claim: wait for the first one to finish (the Claude call takes a while) and give its answer. A claim that never
    // finishes is a run that died: the person is told, and tries again with a new id.
    private async Task<SesSonucu<AsistanYanitiDto>> TekrarAsync(Guid kullaniciId, Guid girdiId, bool cevap, string? istenenCevap, CancellationToken ct)
    {
        var bekleme = Stopwatch.StartNew();
        while (true)
        {
            var satirlar = await db.AsistanMesajlari.AsNoTracking().Where(m => m.KullaniciId == kullaniciId && m.GirdiId == girdiId).ToListAsync(ct);
            if (cevap && istenenCevap is not null
                && satirlar.FirstOrDefault(m => m.Tur == AsistanMesajTuru.Kullanici && m.Kaynak == AsistanMesaji.CevapKaynagi) is { } onceki
                && onceki.Metin != istenenCevap)
            {
                return new(Hata: Results.Problem(title: "Soru zaten cevaplanmış", detail: "Bu soruya başka bir cevap verilmiş; cevap değiştirilmez.", statusCode: StatusCodes.Status409Conflict));
            }

            if (YanitKur(satirlar, girdiId, cevap) is { } yanit)
                return new(yanit);

            var baslangic = satirlar.FirstOrDefault(m => m.Tur == AsistanMesajTuru.Kullanici && (m.Kaynak == AsistanMesaji.CevapKaynagi) == cevap)?.Zaman;
            if (baslangic is { } an && saat.GetUtcNow() - an > TakilmaSuresi)
                return new(Hata: Results.Problem(title: "Girdi işlenemedi", detail: "İlk istek tamamlanmadı; yeni bir id ile tekrar dene.", statusCode: StatusCodes.Status409Conflict));
            if (bekleme.Elapsed > BeklemeSuresi)
                return new(Hata: Results.Problem(title: "Girdi işleniyor", detail: "Aynı id ile gelen ilk istek hâlâ sürüyor; biraz sonra tekrar dene.", statusCode: StatusCodes.Status409Conflict));

            await Task.Delay(100, ct);
        }
    }

    // The rows of one input are told apart by time (the feed pages by it): a result is a microsecond after the words it answers, even when the
    // clock has not moved (a test's, or two writes in one tick).
    private DateTimeOffset Sonra(DateTimeOffset an, int adim = 1)
    {
        var enAz = an.AddTicks(10 * adim);
        var simdi = saat.GetUtcNow();
        return simdi > enAz ? simdi : enAz;
    }

    // Words

    private static HazirOneri TumuNot(string? metin) =>
        new(AsistanSiniflandirici.Not, metin is null ? "Fotoğraf" : AsistanSiniflandirici.Temizle(metin, 60), null, "Not olarak kaydedilecek");

    private static string KaynakAdi(AsistanKaynagi k) => k switch
    {
        AsistanKaynagi.Ses => "ses",
        AsistanKaynagi.Paylas => "paylas",
        AsistanKaynagi.Widget => "widget",
        _ => "yazi",
    };

    public static string TurEtiketi(string tur) => tur switch
    {
        "hatirlatici-kur" => "Hatırlatıcı",
        "plan-ekle" => "Plana ekle",
        "gorev-ekle" => "Görev",
        "takvim-ekle" => "Takvim etkinliği",
        AsistanSiniflandirici.Is => "İş kartı",
        _ => "Not",
    };

    private static string TurFiili(string tur) => tur switch
    {
        "hatirlatici-kur" => "Hatırlatıcı kuruldu",
        "plan-ekle" => "Plana eklendi",
        "gorev-ekle" => "Görev eklendi",
        "takvim-ekle" => "Takvime eklendi",
        AsistanSiniflandirici.Is => "İş kartı açıldı",
        _ => "Not alındı",
    };

    // "yarın 09:00 · 🔔": what was set up, in a few words, in the person's terms.
    internal static string OzetMetni(HazirOneri o, DateOnly bugun)
    {
        var teklif = o.Kuyruk?.Oneri;
        string Gun(string? g) => g is not null && DateOnly.TryParseExact(g, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
            ? (d == bugun ? "bugün" : d == bugun.AddDays(1) ? "yarın" : BeyinGorunum.KisaTarih(d))
            : "";

        switch (o.Tur)
        {
            case "hatirlatici-kur":
                var tekrar = teklif!.Tekrar is { } t && t != "yok" ? $" · {t}" : "";
                return $"{Gun(teklif.Gun)}{(teklif.Saat is { } s ? $" {s}" : "")} · 🔔{tekrar}";
            case "plan-ekle":
                return $"{Gun(teklif!.Gun)} · plana eklendi{(teklif.TahminDk is { } dk ? $" · ~{dk} dk" : "")}";
            case "gorev-ekle":
                var yer = teklif!.Proje ?? teklif.Alan;
                return $"görev{(yer is null ? "" : $" · {yer}")}{(teklif.Bitis is { } b ? $" · {Gun(b)}" : "")}";
            case "takvim-ekle":
                return $"{Gun(teklif!.Gun)} {(teklif.Saat is { } sa ? sa : "tüm gün")} · 📅";
            case AsistanSiniflandirici.Is:
                return o.Ozet;
            default:
                return "Yakalamaya eklendi";
        }
    }

    // What a tap on the result of a queue kind goes to, read from what the kind put in the undo information.
    private static string? HedefKimligi(string tur, Eylem eylem)
    {
        if (eylem.GeriAlmaBilgisi is null)
            return null;

        using var bilgi = JsonDocument.Parse(eylem.GeriAlmaBilgisi);
        string? Oku(string ad) => bilgi.RootElement.ValueKind == JsonValueKind.Object && bilgi.RootElement.TryGetProperty(ad, out var d) && d.ValueKind == JsonValueKind.String ? d.GetString() : null;
        return tur switch
        {
            "hatirlatici-kur" => Oku("hatirlaticiId") is { } id ? $"h:{id}" : null,
            "plan-ekle" => Oku("madde") is { } madde ? $"m:{madde}" : null,
            "gorev-ekle" => Oku("kimlik") is { } kimlik ? $"g:{kimlik}" : null,
            _ => null,
        };
    }
}
