using System.Globalization;
using System.Security.Claims;
using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Isler;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Asistan;

// The assistant's one feed (K-0024, §7.3): what was said and done, the questions and the actions waiting for approval, the open work cards, the
// briefing of today and the captures of the last week, newest first, in one list. Each source is shown only to a person who may read it (the
// Asistan role sees the feed with the permissions it holds). What is waiting for the person has one rule, here: an unanswered question, an action
// in the queue, an open card with a question open. The badge (`sayi`) and the filter `bekleyen` both use it.
public class AsistanAkisi(
    AppDbContext db, BeyinIstemcisi beyin, BrifingHazirlayici brifing, EylemServisi eylemler, IAuthorizationService yetki, TimeProvider saat,
    ILogger<AsistanAkisi> gunluk)
{
    public const int VarsayilanSatir = 40;
    public const int EnCokSatir = 100;

    // Captures this old (days) are still on the feed.
    public const int YakalamaGunu = 7;

    public static readonly string[] Suzgecler = ["hepsi", "bekleyen", "isler", "notlar"];

    // One rule of "waiting" (the three places it is counted use these).
    private IQueryable<AsistanMesaji> CevapsizSorular(Guid kullaniciId) =>
        db.AsistanMesajlari.Where(m => m.KullaniciId == kullaniciId && m.Tur == AsistanMesajTuru.Soru && m.CevaplandiAni == null);

    private IQueryable<Eylem> BekleyenEylemler() => db.Eylemler.Where(e => e.Durum == EylemDurumu.Bekliyor);

    private static bool BekleyenKart(IsKartiDto k) => k.Acik && k.BekleyenSoru > 0;

    private sealed record Okuma(bool Eylem, bool Is, bool Yakalama, bool Brifing);

    private async Task<Okuma> OkumaAsync(ClaimsPrincipal kullanici) => new(
        await Izinli(kullanici, EylemPolicies.Oku), await Izinli(kullanici, IsPolicies.Oku),
        await Izinli(kullanici, YakalamaPolicies.Oku), await Izinli(kullanici, BrifingPolicies.Oku));

    private async Task<bool> Izinli(ClaimsPrincipal kullanici, string politika) =>
        (await yetki.AuthorizeAsync(kullanici, null, politika)).Succeeded;

    // The open cards of the brain; none when it is not set up or cannot be read (the feed does not fail for it).
    private async Task<List<IsKartiDto>> AcikKartlarAsync(CancellationToken ct)
    {
        if (!beyin.Bagli)
            return [];

        var yanit = await IsKartlari.ListeAl(null, null, false, beyin, gunluk, saat, ct);
        if (!yanit.Basarili)
        {
            gunluk.LogWarning("The assistant feed could not read the work cards ({Durum})", yanit.Durum);
            return [];
        }

        return yanit.Veri!;
    }

    // The badge: how many things wait for the person.
    public async Task<int> BekleyenSayisiAsync(ClaimsPrincipal kullanici, Guid kullaniciId, CancellationToken ct)
    {
        var okuma = await OkumaAsync(kullanici);
        var sayi = await CevapsizSorular(kullaniciId).CountAsync(ct);
        if (okuma.Eylem)
            sayi += await BekleyenEylemler().CountAsync(ct);
        if (okuma.Is)
            sayi += (await AcikKartlarAsync(ct)).Count(BekleyenKart);
        return sayi;
    }

    public async Task<List<AkisOgesiDto>> AkisAsync(
        ClaimsPrincipal kullanici, Guid kullaniciId, DateTimeOffset? once, int limit, string suzgec, CancellationToken ct)
    {
        var okuma = await OkumaAsync(kullanici);
        var simdi = saat.GetUtcNow();
        bool Hepsi() => suzgec == "hepsi";
        var ogeler = new List<(AkisOgesiDto Oge, int Sira)>();

        // What was said, done and asked.
        if (Hepsi() || suzgec == "bekleyen")
        {
            var sorgu = db.AsistanMesajlari.AsNoTracking().Where(m => m.KullaniciId == kullaniciId);
            if (once is { } sinir)
                sorgu = sorgu.Where(m => m.Zaman < sinir);
            if (suzgec == "bekleyen")
                sorgu = sorgu.Where(m => m.Tur == AsistanMesajTuru.Soru && m.CevaplandiAni == null);
            var satirlar = await sorgu.OrderByDescending(m => m.Zaman).ThenByDescending(m => m.Id).Take(limit).ToListAsync(ct);
            await MesajlariEkleAsync(satirlar, ogeler, ct);
        }

        // Actions waiting for approval.
        if (okuma.Eylem && (Hepsi() || suzgec == "bekleyen"))
        {
            var sorgu = BekleyenEylemler().AsNoTracking();
            if (once is { } sinir)
                sorgu = sorgu.Where(e => e.CreatedAt < sinir);
            foreach (var e in await sorgu.OrderByDescending(e => e.CreatedAt).ThenByDescending(e => e.Id).Take(limit).ToListAsync(ct))
                ogeler.Add((new AkisOgesiDto($"onay:{e.Id}", e.CreatedAt, AkisTuru.Onay, null, null, null, null, eylemler.DtoYap(e), null, null, null), 3));
        }

        // Open work cards: all of them, or the ones with a question open.
        if (okuma.Is && (Hepsi() || suzgec is "bekleyen" or "isler"))
        {
            foreach (var k in await AcikKartlarAsync(ct))
            {
                if (suzgec == "bekleyen" && !BekleyenKart(k))
                    continue;

                var zaman = KartZamani(k);
                if (once is { } sinir && zaman >= sinir)
                    continue;
                ogeler.Add((new AkisOgesiDto($"is:{k.Kimlik}", zaman, AkisTuru.Is, null, null, null, null, null, k, null, null), 2));
            }
        }

        // Today's briefing.
        if (okuma.Brifing && Hepsi() && await brifing.GetirAsync(GunSiniri.Bugun(simdi), ct) is { } bugunku && (once is not { } s || bugunku.UretimAni < s))
        {
            var dto = await brifing.DtoYapAsync(bugunku, ct);
            ogeler.Add((new AkisOgesiDto($"brifing:{bugunku.Gun:yyyy-MM-dd}", bugunku.UretimAni, AkisTuru.Brifing, dto.Kartlar.FirstOrDefault()?.Metin, null, null, null, null, null, dto, null), 1));
        }

        // The captures of the last week (the ones the assistant made are already told by its results).
        if (okuma.Yakalama && (Hepsi() || suzgec == "notlar"))
        {
            var alt = simdi.AddDays(-YakalamaGunu);
            var sorgu = db.Yakalamalar.AsNoTracking().Where(y => y.YakalandiAt >= alt);
            if (once is { } sinir)
                sorgu = sorgu.Where(y => y.YakalandiAt < sinir);
            var asistanNotlari = await AsistanNotlariAsync(alt, ct);
            foreach (var y in await sorgu.OrderByDescending(y => y.YakalandiAt).ThenByDescending(y => y.Id).Take(limit + asistanNotlari.Count).ToListAsync(ct))
            {
                if (asistanNotlari.Contains(y.Id))
                    continue;
                ogeler.Add((new AkisOgesiDto($"not:{y.Id}", y.YakalandiAt, AkisTuru.Not, y.Metin, OgeEndpoints.FotografUrl(y.FotografId), null, null, null, null, null, YakalamaEndpoints.DtoYap(y)), 0));
            }
        }

        return ogeler.OrderByDescending(o => o.Oge.Zaman).ThenByDescending(o => o.Sira).ThenByDescending(o => o.Oge.Id, StringComparer.Ordinal)
            .Take(limit).Select(o => o.Oge).ToList();
    }

    // The messages as feed items. A result's flags are read from what the things are now: an action undone, or a note taken back or already sent
    // to the brain, can no longer be undone from the feed.
    private async Task MesajlariEkleAsync(List<AsistanMesaji> satirlar, List<(AkisOgesiDto, int)> ogeler, CancellationToken ct)
    {
        // The empty result row that closes a round with a question has nothing to show.
        satirlar = satirlar.Where(m => !(m.Tur == AsistanMesajTuru.Sonuc && m.SonuclarJson is null or "[]")).ToList();
        var sonuclar = satirlar.Where(m => m.Tur == AsistanMesajTuru.Sonuc)
            .ToDictionary(m => m.Id, m => JsonSerializer.Deserialize<List<AsistanSonucuDto>>(m.SonuclarJson ?? "[]", AsistanServisi.Json)!);
        var eylemIdleri = sonuclar.Values.SelectMany(l => l).Select(r => r.EylemId).OfType<Guid>().Distinct().ToList();
        var uygulanan = eylemIdleri.Count == 0
            ? new HashSet<Guid>()
            : (await db.Eylemler.AsNoTracking().Where(e => eylemIdleri.Contains(e.Id) && e.Durum == EylemDurumu.Uygulandi).Select(e => e.Id).ToListAsync(ct)).ToHashSet();
        var notIdleri = sonuclar.Values.SelectMany(l => l).Where(r => r.Tur == AsistanSiniflandirici.Not && r.Hedef.Kimlik is not null)
            .Select(r => Guid.TryParse(r.Hedef.Kimlik, out var g) ? g : (Guid?)null).OfType<Guid>().Distinct().ToList();
        var simdi = saat.GetUtcNow();
        var bekleyenNotlar = notIdleri.Count == 0
            ? new HashSet<Guid>()
            : (await db.Yakalamalar.AsNoTracking().Where(y => notIdleri.Contains(y.Id) && y.Durum == YakalamaDurumu.Bekliyor).ToListAsync(ct))
                .Where(y => !YakalamaGonderimi.Gonderiliyor(y, simdi)).Select(y => y.Id).ToHashSet();

        var fotograflar = satirlar.Select(m => m.FotografId).OfType<Guid>().Distinct().ToList();
        var fotoVar = fotograflar.Count == 0
            ? new HashSet<Guid>()
            : (await db.Dosyalar.AsNoTracking().Where(d => fotograflar.Contains(d.Id)).Select(d => d.Id).ToListAsync(ct)).ToHashSet();

        foreach (var m in satirlar)
        {
            switch (m.Tur)
            {
                case AsistanMesajTuru.Kullanici:
                    ogeler.Add((new AkisOgesiDto($"kullanici:{m.Id}", m.Zaman, AkisTuru.Kullanici, m.Metin,
                        m.FotografId is { } f && fotoVar.Contains(f) ? OgeEndpoints.FotografUrl(f) : null, null, null, null, null, null, null), 0));
                    break;

                case AsistanMesajTuru.Sonuc:
                    var guncel = sonuclar[m.Id].Select(r => r with
                    {
                        GeriAlinabilir = r.GeriAlinabilir && (r.EylemId is { } e
                            ? uygulanan.Contains(e)
                            : r.Tur == AsistanSiniflandirici.Not && Guid.TryParse(r.Hedef.Kimlik, out var y) && bekleyenNotlar.Contains(y)),
                    }).ToList();
                    ogeler.Add((new AkisOgesiDto($"sonuc:{m.Id}", m.Zaman, AkisTuru.Sonuc, null, null, guncel, null, null, null, null, null), 1));
                    break;

                default:
                    var kayit = JsonSerializer.Deserialize<AsistanServisi.SoruKaydi>(m.SoruJson!, AsistanServisi.Json)!;
                    var soru = m.CevaplandiAni is null ? new AsistanSorusuDto(kayit.Id, kayit.Metin, kayit.Secenekler) : null;
                    ogeler.Add((new AkisOgesiDto($"soru:{m.Id}", m.Zaman, AkisTuru.Soru, m.Metin, null, null, soru, null, null, null, null), 2));
                    break;
            }
        }
    }

    // The captures the assistant made in the window: their ids are in its results.
    private async Task<HashSet<Guid>> AsistanNotlariAsync(DateTimeOffset alt, CancellationToken ct)
    {
        var json = await db.AsistanMesajlari.AsNoTracking().Where(m => m.Tur == AsistanMesajTuru.Sonuc && m.Zaman >= alt.AddDays(-1))
            .Select(m => m.SonuclarJson).ToListAsync(ct);
        return json.SelectMany(j => JsonSerializer.Deserialize<List<AsistanSonucuDto>>(j ?? "[]", AsistanServisi.Json)!)
            .Where(r => r.Tur == AsistanSiniflandirici.Not && Guid.TryParse(r.Hedef.Kimlik, out _))
            .Select(r => Guid.Parse(r.Hedef.Kimlik!)).ToHashSet();
    }

    // The brain writes a card's time as "2026-11-10T14:30" (Istanbul, no zone).
    private static DateTimeOffset KartZamani(IsKartiDto k) =>
        k.Guncelleme is { Length: >= 16 } z
        && DateOnly.TryParseExact(z[..10], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun)
        && TimeOnly.TryParseExact(z[11..16], "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var saatDegeri)
            ? HatirlaticiHesap.An(gun, saatDegeri)
            : DateTimeOffset.MinValue;
}
