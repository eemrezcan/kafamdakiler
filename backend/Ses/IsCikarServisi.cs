using System.Globalization;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Nodes;
using Kafamdakiler.Beyin;
using Kafamdakiler.Claude;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Authorization;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Ses;

// Either the answer or the HTTP refusal that goes out instead of it.
public record SesSonucu<T>(T? Veri = default, IResult? Hata = null);

// Work out of text (K2.4): Claude reads what the person said and suggests reminders, plan items and tasks; nothing is saved
// until the person picks some of them in the preview and sends them back. The text is the only untrusted thing in the call. It
// goes as data; Claude has no tools; every suggestion is checked here as if a stranger had typed it, and then the person sees it
// before anything is written. The ones the person chooses become actions in the approval queue (source "ses") that are
// applied at once (EylemServisi.OnayliUygulaAsync).
public class IsCikarServisi(
    BeyinIstemcisi beyin, ClaudeIstemcisi claude, EylemTurleri turler, EylemServisi eylemler, IAuthorizationService yetki,
    TimeProvider saat, ILogger<IsCikarServisi> gunluk)
{
    // About one long paragraph of speech.
    public const int EnUzunMetin = 4000;

    // Past this many suggestions in one answer the rest is cut (and reported); past this many chosen in one request it is refused.
    public const int EnCokOneri = 10;
    public const int EnCokSecilen = 20;

    // A date further than this from today is more likely a slip of the year than a plan.
    public const int EnCokGunIleri = 730;

    public const string Kaynak = "ses";

    // The text came from the box in the morning briefing (K2.7).
    public const string BrifingKaynagi = "brifing";

    private const int KaynakParcaEnUzun = 300;
    private const int GorunenGunSayisi = 14;
    private const int YeniMetinEnUzun = 2 * EnUzunMetin;

    public static readonly string[] GunAdlari =["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];

    // The permission each kind needs: the same that the kind's own page or endpoint asks for.
    private static readonly Dictionary<string, string> TurIzinleri = new()
    {
        [HatirlaticiKurTuru.Anahtar] = HatirlaticiPolicies.Yaz,
        [PlanEkleTuru.Anahtar] = BeyinPolicies.PlanYaz,
        [GorevEkleTuru.Anahtar] = BeyinPolicies.GorevYaz,
        [TakvimEkleTuru.Anahtar] = TakvimPolicies.Yaz,
    };

    // The permission a queue kind needs (null for anything that is not one of the four): the assistant's own entry asks it too.
    public static string? TurIzni(string? tur) => tur is not null && TurIzinleri.TryGetValue(tur, out var izin) ? izin : null;

    public static IEnumerable<string> KuyrukTurleri => TurIzinleri.Keys;

    private static readonly string[] Tekrarlar = Enum.GetNames<Tekrar>().Select(CamelCase).ToArray();

    // "9:00" is as good as "09:00": the person may have corrected it by hand.
    private static readonly string[] SaatBicimleri = ["H:mm", "H:mm:ss"];

    // A suggestion after the checks: what the preview shows (normalised), and what the queue gets.
    public sealed record Cevrilmis(IsOnerisi Oneri, JsonElement Yuk, string Ozet, string? Gerekce);

    // Preview

    public async Task<SesSonucu<IsCikarYaniti>> CikarAsync(IsCikarGirdi girdi, CancellationToken ct)
    {
        if (MetinDenetle(girdi.Metin, out var metin) is { } metinHatasi)
            return new(Hata: metinHatasi);

        var sunucuBugun = GunSiniri.Bugun(saat.GetUtcNow());
        var bugun = sunucuBugun;
        if (!string.IsNullOrWhiteSpace(girdi.Bugun))
        {
            if (!DateOnly.TryParseExact(girdi.Bugun.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out bugun))
                return new(Hata: Sorun("bugun", "Tarih yyyy-MM-dd biçiminde olmalı."));
            if (Math.Abs(bugun.DayNumber - sunucuBugun.DayNumber) > 1)
                return new(Hata: Sorun("bugun", "Bugünün tarihi sunucunun gününden en çok bir gün farklı olabilir."));
        }

        if (!claude.Bagli)
            return new(Hata: ClaudeHatasi(ClaudeDurumu.BagliDegil));

        // Only projects that exist and are not hidden may be named: they go into the schema as the allowed values.
        var projeler = await BeyinOkuma.ProjelerAl(beyin, gunluk, ct);
        if (!projeler.Basarili)
            return new(Hata: projeler.Sonuc());

        var yanit = await claude.SorAsync<ClaudeIsCikarCevabi>(
            new ClaudeIstegi("ses-is-cikar", Talimat(bugun, projeler.Veri!), metin!, Sema(projeler.Veri!)), ct);
        if (!yanit.Basarili)
            return new(Hata: ClaudeHatasi(yanit.Durum));

        var projeKimlikleri = projeler.Veri!.Select(p => p.Kimlik).ToHashSet(StringComparer.Ordinal);
        var oneriler = new List<IsOnerisi>();
        var atlananlar = new List<AtlananOneri>();
        foreach (var (o, sira) in (yanit.Veri!.Oneriler ?? []).Select((o, i) => (o, i)))
        {
            if (sira >= EnCokOneri)
            {
                atlananlar.Add(new AtlananOneri(o?.Tur, o?.Baslik, o?.KaynakParca, $"Çok fazla öneri: ilk {EnCokOneri} gösterildi."));
                continue;
            }

            // The days are counted by the server's own rule, whatever "today" the instruction was given.
            var (cevrilmis, neden) = Cevir(o, sunucuBugun, projeKimlikleri);
            if (cevrilmis is null)
                atlananlar.Add(new AtlananOneri(o?.Tur, o?.Baslik, o?.KaynakParca, neden!));
            else
                oneriler.Add(cevrilmis.Oneri);
        }

        return new(new IsCikarYaniti($"{bugun:yyyy-MM-dd}", GunAdlari[(int)bugun.DayOfWeek], oneriler, atlananlar));
    }

    // Apply

    public async Task<SesSonucu<IsCikarUygulaYaniti>> UygulaAsync(IsCikarUygulaGirdi girdi, ClaimsPrincipal kullanici, CancellationToken ct)
    {
        if (girdi.Secilenler is not { Count: > 0 })
            return new(Hata: Sorun("secilenler", "En az bir öneri seçilmeli."));
        if (girdi.Secilenler.Count > EnCokSecilen)
            return new(Hata: Sorun("secilenler", $"En çok {EnCokSecilen} öneri seçilebilir."));

        var kaynak = girdi.Kaynak?.Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(kaynak))
            kaynak = Kaynak;
        else if (kaynak is not (Kaynak or BrifingKaynagi))
            return new(Hata: Sorun("kaynak", $"Kaynak {Kaynak} ya da {BrifingKaynagi} olmalı."));
        var gerekceOnEki = kaynak == BrifingKaynagi ? "Brifingten" : "Sesten";

        var bugun = GunSiniri.Bugun(saat.GetUtcNow());

        // The project list is read once, and only when a task names a project.
        var projeKimlikleri = new HashSet<string>(StringComparer.Ordinal);
        if (girdi.Secilenler.Any(o => o is { Tur: GorevEkleTuru.Anahtar, Proje: not null }))
        {
            var projeler = await BeyinOkuma.ProjelerAl(beyin, gunluk, ct);
            if (!projeler.Basarili)
                return new(Hata: projeler.Sonuc());
            projeKimlikleri = projeler.Veri!.Select(p => p.Kimlik).ToHashSet(StringComparer.Ordinal);
        }

        var kullaniciId = EylemEndpoints.KullaniciId(kullanici);
        var sonuclar = new List<IsUygulaSonucu>();
        for (var sira = 0; sira < girdi.Secilenler.Count; sira++)
        {
            var o = girdi.Secilenler[sira];
            var (cevrilmis, neden) = Cevir(o, bugun, projeKimlikleri, gerekceOnEki);
            if (cevrilmis is null)
            {
                sonuclar.Add(new IsUygulaSonucu(sira, "gecersiz", null, null, neden));
                continue;
            }

            if (!await IzinliMi(kullanici, cevrilmis.Oneri.Tur))
            {
                sonuclar.Add(new IsUygulaSonucu(sira, "izinYok", null, null, "Bu işlem için izniniz yok."));
                continue;
            }

            var oneri = new EylemOnerisi(cevrilmis.Oneri.Tur, cevrilmis.Yuk, cevrilmis.Ozet, kaynak, DisKaynak: false, cevrilmis.Gerekce, cevrilmis.Oneri.Guven);
            var sonuc = await eylemler.OnayliUygulaAsync(oneri, kullaniciId, ct);
            sonuclar.Add(sonuc.Tur switch
            {
                EylemSonucuTuru.Tamam => new IsUygulaSonucu(sira, "uygulandi", eylemler.DtoYap(sonuc.Eylem!), null, null),
                EylemSonucuTuru.Gecersiz => new IsUygulaSonucu(sira, "gecersiz", null, sonuc.Alan, sonuc.Mesaj),
                _ => new IsUygulaSonucu(sira, "hata", sonuc.Eylem is null ? null : eylemler.DtoYap(sonuc.Eylem), null, sonuc.Mesaj ?? "Eylem uygulanamadı."),
            });
        }

        var uygulanan = sonuclar.Count(s => s.Durum == "uygulandi");
        return new(new IsCikarUygulaYaniti(uygulanan, sonuclar.Count - uygulanan, sonuclar));
    }

    private async Task<bool> IzinliMi(ClaimsPrincipal kullanici, string tur) =>
        TurIzinleri.TryGetValue(tur, out var politika) && (await yetki.AuthorizeAsync(kullanici, null, politika)).Succeeded;

    // Rewrite

    public async Task<SesSonucu<YenidenYazYaniti>> YenidenYazAsync(YenidenYazGirdi girdi, CancellationToken ct)
    {
        if (MetinDenetle(girdi.Metin, out var metin) is { } metinHatasi)
            return new(Hata: metinHatasi);

        var kip = girdi.Kip?.Trim().ToLowerInvariant();
        if (kip is not ("ozet" or "madde"))
            return new(Hata: Sorun("kip", "Kip ozet ya da madde olmalı."));

        if (!claude.Bagli)
            return new(Hata: ClaudeHatasi(ClaudeDurumu.BagliDegil));

        var yanit = await claude.SorAsync<ClaudeYenidenYazCevabi>(new ClaudeIstegi($"ses-yeniden-yaz-{kip}", YenidenYazTalimati(kip), metin!), ct);
        if (!yanit.Basarili)
            return new(Hata: ClaudeHatasi(yanit.Durum));

        var yeni = yanit.Veri!.Metin?.Trim();
        if (string.IsNullOrEmpty(yeni) || yeni.Length > YeniMetinEnUzun)
        {
            gunluk.LogWarning("The rewrite answer was empty or too long ({Uzunluk} characters).", yeni?.Length ?? 0);
            return new(Hata: ClaudeHatasi(ClaudeDurumu.BozukCikti));
        }

        return new(new YenidenYazYaniti(yeni));
    }

    // The checks

    private static IResult? MetinDenetle(string? girdi, out string? metin)
    {
        metin = girdi?.Trim();
        if (string.IsNullOrEmpty(metin))
            return Sorun("metin", "Metin boş olamaz.");
        if (metin.Length > EnUzunMetin)
            return Sorun("metin", $"Metin en çok {EnUzunMetin} karakter olabilir.");
        return null;
    }

    // The same rules for what Claude suggested and what a person sent back: the kind, the dates, the project, then the kind's own
    // shape check. Returns the suggestion in the queue's terms, or the reason it is refused. Nothing is written here. The Gmail
    // scan uses it too, so a mail's suggestion passes the very same rules as a spoken one.
    public (Cevrilmis? Sonuc, string? Neden) Cevir(IsOnerisi? o, DateOnly bugun, IReadOnlySet<string> projeler, string gerekceOnEki = "Sesten")
    {
        if (o is null)
            return (null, "Boş öneri.");
        if (o.Tur is null || !TurIzinleri.ContainsKey(o.Tur) || turler.Bul(o.Tur) is not { } tur)
            return (null, "Bilinmeyen öneri türü.");

        var baslik = o.Baslik?.Trim() ?? "";
        if (baslik.Length == 0)
            return (null, "Başlık boş.");
        if (o.Guven is { } g && (double.IsNaN(g) || g is < 0 or > 1))
            return (null, "Güven 0 ile 1 arasında olmalı.");

        if (Tarih(o.Gun, "Tarih", bugun, out var gun) is { } gunHatasi)
            return (null, gunHatasi);

        var yuk = new JsonObject();
        string ozet;
        var yeni = o with { Baslik = baslik, Gun = null, Saat = null, Tekrar = null, Bolum = null, TahminDk = null, Proje = null, Alan = null, Bitis = null, BitisSaati = null, Yer = null,
            Israrli = null, Acil = null, OnceGun = null };
        switch (o.Tur)
        {
            case HatirlaticiKurTuru.Anahtar:
            {
                if (gun is null)
                    return (null, "Tarih belirtilmemiş.");

                TimeOnly? saatDegeri = null;
                if (!string.IsNullOrWhiteSpace(o.Saat))
                {
                    if (!TimeOnly.TryParseExact(o.Saat.Trim(), SaatBicimleri, CultureInfo.InvariantCulture, DateTimeStyles.None, out var s))
                        return (null, "Saat HH:mm biçiminde olmalı.");
                    saatDegeri = s;
                }

                var tekrar = string.IsNullOrWhiteSpace(o.Tekrar) ? "yok" : Tekrarlar.FirstOrDefault(t => t.Equals(o.Tekrar.Trim(), StringComparison.OrdinalIgnoreCase));
                if (tekrar is null)
                    return (null, "Tekrar yok, gunluk, haftalik, aylik ya da yillik olmalı.");

                // Persistent, urgent and "warn me N days before" (H4): left out unless asked, so a spoken reminder is as it was.
                var israrli = o.Israrli == true;
                var acil = o.Acil == true;
                var onceGun = o.OnceGun ?? 0;
                if (onceGun is < 0 or > 60)
                    return (null, "Kaç gün önce uyarılacağı 0 ile 60 arasında olmalı.");

                yuk["baslik"] = baslik;
                yuk["gun"] = $"{gun:yyyy-MM-dd}";
                if (saatDegeri is { } sv)
                    yuk["saat"] = $"{sv:HH:mm:ss}";
                yuk["tekrar"] = tekrar;
                if (israrli)
                    yuk["israrli"] = true;
                if (acil)
                    yuk["acil"] = true;
                if (onceGun > 0)
                    yuk["onceGun"] = onceGun;
                var ekler = new List<string>();
                if (israrli)
                    ekler.Add("ısrarlı");
                if (acil)
                    ekler.Add("acil");
                if (onceGun > 0)
                    ekler.Add($"{onceGun} gün önce haber");
                ozet = $"Hatırlatıcı: {baslik} ({gun:yyyy-MM-dd}{(saatDegeri is { } sh ? $" {sh:HH:mm}" : "")}{string.Concat(ekler.Select(e => $", {e}"))})";
                yeni = yeni with
                {
                    Gun = $"{gun:yyyy-MM-dd}", Saat = saatDegeri is { } sa ? $"{sa:HH:mm}" : null, Tekrar = tekrar,
                    Israrli = israrli ? true : null, Acil = acil ? true : null, OnceGun = onceGun > 0 ? onceGun : null,
                };
                break;
            }

            case PlanEkleTuru.Anahtar:
            {
                if (gun is null)
                    return (null, "Tarih belirtilmemiş.");

                var bolum = string.IsNullOrWhiteSpace(o.Bolum) ? null : o.Bolum.Trim();
                yuk["gun"] = $"{gun:yyyy-MM-dd}";
                yuk["metin"] = baslik;
                if (bolum is not null)
                    yuk["bolum"] = bolum;
                if (o.TahminDk is { } dk)
                    yuk["tahminDk"] = dk;
                ozet = $"Plan ({gun:yyyy-MM-dd}): {baslik}";
                yeni = yeni with { Gun = $"{gun:yyyy-MM-dd}", Bolum = bolum, TahminDk = o.TahminDk };
                break;
            }

            case TakvimEkleTuru.Anahtar:
            {
                if (gun is null)
                    return (null, "Tarih belirtilmemiş.");

                TimeOnly? baslangicSaati = null, bitisSaati = null;
                if (!string.IsNullOrWhiteSpace(o.Saat))
                {
                    if (!TimeOnly.TryParseExact(o.Saat.Trim(), SaatBicimleri, CultureInfo.InvariantCulture, DateTimeStyles.None, out var s))
                        return (null, "Saat HH:mm biçiminde olmalı.");
                    baslangicSaati = s;
                }

                if (!string.IsNullOrWhiteSpace(o.BitisSaati))
                {
                    if (baslangicSaati is null)
                        return (null, "Bitiş saati için başlangıç saati de verilmeli.");
                    if (!TimeOnly.TryParseExact(o.BitisSaati.Trim(), SaatBicimleri, CultureInfo.InvariantCulture, DateTimeStyles.None, out var s))
                        return (null, "Bitiş saati HH:mm biçiminde olmalı.");
                    bitisSaati = s;
                }

                var yer = string.IsNullOrWhiteSpace(o.Yer) ? null : o.Yer.Trim();
                yuk["baslik"] = baslik;
                if (baslangicSaati is not { } bas)
                {
                    // No hour: an all-day event.
                    yuk["tumGun"] = true;
                    yuk["gun"] = $"{gun:yyyy-MM-dd}";
                    ozet = $"Takvim: {baslik} ({gun:yyyy-MM-dd}, tüm gün)";
                }
                else
                {
                    var baslangic = TakvimZamani.YerelAn(gun.Value, bas);
                    var bitis = bitisSaati is { } bit ? TakvimZamani.YerelAn(gun.Value, bit) : baslangic.AddHours(1);
                    if (bitis <= baslangic)
                        return (null, "Bitiş saati başlangıç saatinden sonra olmalı.");

                    yuk["baslangic"] = baslangic.ToString("yyyy-MM-dd'T'HH:mm:sszzz", CultureInfo.InvariantCulture);
                    yuk["bitis"] = bitis.ToString("yyyy-MM-dd'T'HH:mm:sszzz", CultureInfo.InvariantCulture);
                    ozet = $"Takvim: {baslik} ({gun:yyyy-MM-dd} {bas:HH:mm})";
                }

                if (yer is not null)
                    yuk["yer"] = yer;
                yeni = yeni with
                {
                    Gun = $"{gun:yyyy-MM-dd}",
                    Saat = baslangicSaati is { } sa2 ? $"{sa2:HH:mm}" : null,
                    BitisSaati = bitisSaati is { } bs ? $"{bs:HH:mm}" : null,
                    Yer = yer,
                };
                break;
            }

            default:
            {
                var proje = string.IsNullOrWhiteSpace(o.Proje) ? null : o.Proje.Trim();
                var alan = string.IsNullOrWhiteSpace(o.Alan) ? null : o.Alan.Trim();
                if ((proje is null) == (alan is null))
                    return (null, "Proje ya da alandan tam biri verilmeli.");
                if (proje is not null && !projeler.Contains(proje))
                    return (null, $"Böyle bir proje yok: {proje}.");
                if (alan is not null && !GelenYolu.AcikKokler.Contains(alan, StringComparer.Ordinal))
                    return (null, $"Alan {string.Join(", ", GelenYolu.AcikKokler)} arasından biri olmalı.");
                if (Tarih(o.Bitis, "Bitiş tarihi", bugun, out var bitis) is { } bitisHatasi)
                    return (null, bitisHatasi);

                yuk["baslik"] = baslik;
                if (proje is not null)
                    yuk["proje"] = proje;
                if (alan is not null)
                    yuk["alan"] = alan;
                if (bitis is not null)
                    yuk["bitis"] = $"{bitis:yyyy-MM-dd}";
                ozet = $"Görev: {baslik}";
                yeni = yeni with { Proje = proje, Alan = alan, Bitis = bitis is null ? null : $"{bitis:yyyy-MM-dd}" };
                break;
            }
        }

        // The kind's own check, the one the queue runs again before it applies.
        var yukElement = JsonSerializer.SerializeToElement(yuk);
        var sekil = tur.Dogrula(yukElement);
        if (!sekil.Basarili)
            return (null, sekil.Mesaj);

        var kaynakParca = string.IsNullOrWhiteSpace(o.KaynakParca) ? null : Kisalt(o.KaynakParca.Trim(), KaynakParcaEnUzun);
        yeni = yeni with { KaynakParca = kaynakParca };
        return (new Cevrilmis(yeni, yukElement, Kisalt(ozet, 200), kaynakParca is null ? null : $"{gerekceOnEki}: «{kaynakParca}»"), null);
    }

    // Null when the date is fine or not given. A date before today is a slip (a year, a weekday) far more often than a wish.
    private static string? Tarih(string? deger, string ad, DateOnly bugun, out DateOnly? tarih)
    {
        tarih = null;
        if (string.IsNullOrWhiteSpace(deger))
            return null;
        if (!DateOnly.TryParseExact(deger.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d))
            return $"{ad} yyyy-MM-dd biçiminde olmalı.";
        if (d < bugun)
            return $"{ad} geçmişte ({d:yyyy-MM-dd}); bugün {bugun:yyyy-MM-dd}.";
        if (d > bugun.AddDays(EnCokGunIleri))
            return $"{ad} çok uzakta ({d:yyyy-MM-dd}).";

        tarih = d;
        return null;
    }

    // The call

    // The fixed part of the call. The person's text is not in it: that goes as data.
    public static string Talimat(DateOnly bugun, IEnumerable<ProjeOzetDto> projeler)
    {
        var projeSatirlari = projeler.Select(p => $"    - {Satir(p.Kimlik, 80)}: {Satir(p.Baslik, 80)}").ToList();

        return
            "Sen kişisel bir asistanın \"sesten iş çıkarma\" yardımcısısın. Kullanıcı bir şey söyledi ve telefon bunu yazıya çevirdi " +
            "(yazıda dikte hataları olabilir). Metinden yapılacak işleri çıkar. Hiçbir şey kaydedilmez: önerilerin kullanıcıya gösterilir, o seçer ve onaylar.\n\n" +
            TarihKurallari(bugun) +
            "Öneri türleri (tur):\n" +
            "- hatirlatici-kur: belirli bir güne (ve istenirse saate) bağlı hatırlatma (\"hatırlat\", \"unutma\", \"ara\", \"öde\"). gun zorunlu; saat ve tekrar " +
            "(yok, gunluk, haftalik, aylik, yillik) isteğe bağlı. baslik: kısa hatırlatma metni.\n" +
            "- plan-ekle: belirli bir günün planına girecek iş. gun zorunlu (söylenmediyse bugünün tarihi); bolum ve tahminDk (dakika) isteğe bağlı, söylenmediyse boş bırak. baslik: işin kısa adı.\n" +
            "- gorev-ekle: günü belli olmayan ya da uzun süren, kalıcı görev. Bir projeye aitse proje, yalnız şu listeden:\n" +
            (projeSatirlari.Count > 0 ? string.Join('\n', projeSatirlari) : "    (hiç proje yok; proje alanını kullanma)") + "\n" +
            $"  değilse alan ({string.Join(", ", GelenYolu.AcikKokler)}). proje ve alandan tam biri verilir. bitis isteğe bağlı (yyyy-MM-dd).\n" +
            "- takvim-ekle: belirli bir gün ve saatte olacak bir toplantı, randevu ya da etkinlik (takvime yazılır). gun zorunlu; saat (başlangıç) söylendiyse yaz, " +
            "söylenmediyse boş bırak (tüm gün etkinlik olur); bitisSaati ve yer isteğe bağlı, söylenmediyse boş bırak. baslik: etkinliğin kısa adı. " +
            "Başkasıyla ya da bir yerde buluşma olmayan, yalnız unutulmaması istenen şeyler hatirlatici-kur'dur.\n\n" +
            "Bir cümlede birden çok iş varsa ayrı öneriler yaz. Metinde olmayan iş uydurma; iş yoksa oneriler boş dizi olsun. " + $"En çok {EnCokOneri} öneri.\n" +
            "kaynakParca: önerinin dayandığı cümle ya da cümle parçası, metinden olduğu gibi. guven: 0 ile 1 arasında bir sayı; tür ya da tarih konusunda emin değilsen düşük ver.";
    }

    // Today, the next days and how a spoken or written date becomes yyyy-MM-dd. Shared by every call that turns text into dates
    // (the voice here, the Gmail scan); ends with a blank line.
    public static string TarihKurallari(DateOnly bugun)
    {
        var gunler = Enumerable.Range(0, GorunenGunSayisi).Select(i =>
        {
            var gun = bugun.AddDays(i);
            var not = i switch { 0 => " (bugün)", 1 => " (yarın)", 2 => " (öbür gün)", _ => "" };
            return $"  {gun:yyyy-MM-dd} {GunAdlari[(int)gun.DayOfWeek]}{not}";
        });

        return
            $"Bugün: {bugun:yyyy-MM-dd} {GunAdlari[(int)bugun.DayOfWeek]}. Günün sınırı saat 05:00'tir: gece yarısından sonra 05:00'e kadar hâlâ önceki günün sayılır. " +
            "Tarihleri yalnız buna göre çevir. Önümüzdeki günler:\n" + string.Join('\n', gunler) + "\n\n" +
            "Tarih kuralları: \"bugün\" bugünün tarihi, \"yarın\" ertesi gün, \"öbür gün\" iki gün sonrası. \"Haftaya cuma\" bir sonraki haftanın cumasıdır. " +
            "Yalnız gün adı (\"cuma\") bugünden sonraki ilk o gündür (bugün o günse bir hafta sonrası). \"Ayın 15'i\" bugünden sonraki ilk 15'tir. " +
            "Tarihleri hep yyyy-MM-dd yaz, geçmişte bir tarih verme. Metin bir tarih söylemiyorsa gun alanını boş bırak, uydurma. " +
            "Saat 24 saatlik HH:mm yazılır (\"akşam 8\" 20:00, \"öğlen\" 12:00); söylenmediyse saat alanını boş bırak.\n\n";
    }

    public static string YenidenYazTalimati(string kip) => kip == "madde"
        ? "Kullanıcı bir şeyi sesle söyledi ve telefon bunu yazıya çevirdi. Metni kısa maddeler hâlinde yeniden yaz: her madde ayrı satırda ve \"- \" ile başlar, " +
          "metindeki sıra korunur, aynı dilde yazılır. Metinde olmayan bilgi ekleme, yorum yapma. Yanıtın metin alanında yalnız maddeler olsun."
        : "Kullanıcı bir şeyi sesle söyledi ve telefon bunu yazıya çevirdi. Metnin anlamını koruyarak kısa bir özetini yaz: en çok birkaç cümle, aynı dilde, " +
          "kullanıcının kendi ağzından (kişi eki değişmez). Metinde olmayan bilgi ekleme, yorum yapma. Yanıtın metin alanında yalnız özet olsun.";

    // The answer shape. The project is an enum of the projects that exist (left out when there are none: an empty enum is no schema).
    // The optional fields are left out of `required`; the ranges and dates are checked after the answer, not here.
    // `turler` narrows the kinds that may be named (all of them when null); `israrAlanlari` adds the reminder's persistent, urgent and
    // days-before fields, which the voice call leaves out.
    public static string Sema(IEnumerable<ProjeOzetDto> projeler, IEnumerable<string>? turler = null, bool israrAlanlari = false)
    {
        static JsonObject Metin(string aciklama) => new() { ["type"] = "string", ["description"] = aciklama };
        static JsonArray Dizi(IEnumerable<string> degerler) => new(degerler.Select(d => (JsonNode)JsonValue.Create(d)!).ToArray());

        var ozellikler = new JsonObject
        {
            ["tur"] = new JsonObject { ["type"] = "string", ["enum"] = Dizi(turler ?? TurIzinleri.Keys) },
            ["baslik"] = Metin("Hatırlatıcının başlığı, plan maddesinin metni ya da görevin başlığı"),
            ["gun"] = Metin("yyyy-MM-dd; hatırlatıcı, plan maddesi ve takvim etkinliği için"),
            ["saat"] = Metin("HH:mm; hatırlatıcı ve takvim etkinliğinin başlangıcı için"),
            ["tekrar"] = new JsonObject { ["type"] = "string", ["enum"] = Dizi(Tekrarlar) },
            ["bolum"] = Metin("Plan maddesinin bölümü"),
            ["tahminDk"] = new JsonObject { ["type"] = "integer", ["description"] = "Plan maddesinin süre tahmini, dakika" },
        };
        var proje = projeler.Select(p => p.Kimlik).ToList();
        if (proje.Count > 0)
            ozellikler["proje"] = new JsonObject { ["type"] = "string", ["enum"] = Dizi(proje) };
        ozellikler["alan"] = new JsonObject { ["type"] = "string", ["enum"] = Dizi(GelenYolu.AcikKokler) };
        ozellikler["bitis"] = Metin("yyyy-MM-dd; görev için");
        ozellikler["bitisSaati"] = Metin("HH:mm; takvim etkinliği için");
        ozellikler["yer"] = Metin("Takvim etkinliğinin yeri");
        if (israrAlanlari)
        {
            ozellikler["israrli"] = new JsonObject { ["type"] = "boolean", ["description"] = "Hatırlatıcı: telefon cevap verilene kadar tekrar tekrar haber versin" };
            ozellikler["acil"] = new JsonObject { ["type"] = "boolean", ["description"] = "Hatırlatıcı: telefon sessiz kipte bile haber versin" };
            ozellikler["onceGun"] = new JsonObject { ["type"] = "integer", ["description"] = "Hatırlatıcı: kaç gün önceden de haber verilsin (0 ile 60)" };
        }

        ozellikler["kaynakParca"] = Metin("Önerinin dayandığı cümle, metinden olduğu gibi");
        ozellikler["guven"] = new JsonObject { ["type"] = "number" };

        var oneri = new JsonObject
        {
            ["type"] = "object",
            ["properties"] = ozellikler,
            ["required"] = new JsonArray("tur", "baslik", "kaynakParca", "guven"),
            ["additionalProperties"] = false,
        };
        var sema = new JsonObject
        {
            ["type"] = "object",
            ["properties"] = new JsonObject { ["oneriler"] = new JsonObject { ["type"] = "array", ["items"] = oneri } },
            ["required"] = new JsonArray("oneriler"),
            ["additionalProperties"] = false,
        };
        return sema.ToJsonString();
    }

    // Claude's own message can hold anything the text said: the API says a fixed sentence.
    private static IResult ClaudeHatasi(ClaudeDurumu durum) => durum switch
    {
        ClaudeDurumu.BagliDegil => Results.Problem(title: "Asistan şu an kullanılamıyor", detail: "Bu makinede Claude ayarlı değil ya da başlatılamadı.", statusCode: StatusCodes.Status503ServiceUnavailable),
        ClaudeDurumu.SinirDoldu => Results.Problem(title: "Claude için bugünlük sınır doldu", detail: "Yarın tekrar dene.", statusCode: StatusCodes.Status429TooManyRequests),
        ClaudeDurumu.ZamanAsimi => Results.Problem(title: "Asistan zamanında cevap vermedi", detail: "Biraz sonra tekrar dene.", statusCode: StatusCodes.Status504GatewayTimeout),
        _ => Results.Problem(title: "Asistan cevap veremedi", detail: "Claude cevap vermedi ya da cevabı anlaşılamadı. Hiçbir şey kaydedilmedi.", statusCode: StatusCodes.Status502BadGateway),
    };

    private static string CamelCase(string ad) => char.ToLowerInvariant(ad[0]) + ad[1..];

    private static string Satir(string metin, int enUzun) =>
        Kisalt(new string(metin.Select(c => char.IsControl(c) ? ' ' : c).ToArray()).Trim(), enUzun);

    private static string Kisalt(string metin, int enUzun) => metin.Length <= enUzun ? metin : metin[..enUzun].TrimEnd();
}
