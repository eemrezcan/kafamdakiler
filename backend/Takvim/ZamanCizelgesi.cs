using Kafamdakiler.Ayarlar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Takvim;

// One item of the timeline. `Tur`: etkinlik, hatirlatici or plan. Timed items have Baslangic and Saat (HH:mm, Istanbul); an event also
// has Bitis, BitisSaati, SureDk and Yer; a plan item has Durum, Bolum and TahminDk. `Kimlik` is what the item links to
// (the event's id here, the reminder's id, the plan item's id in the brain).
public record ZamanCizelgesiOgesi(
    string Tur, string Kimlik, string Baslik, bool TumGun, DateTimeOffset? Baslangic, string? Saat, DateTimeOffset? Bitis, string? BitisSaati,
    int? SureDk, string? Yer, string? Durum, string? Bolum, int? TahminDk);

// "Bugün sığmıyor", counting the events too: the plan's open estimates plus the minutes of the day's timed events are more than a day holds.
public record ZamanCizelgesiKapasitesi(int PlanDk, int EtkinlikDk, int ToplamDk, int KapasiteDk, int AsimDk);

// `Google`: kapali, bagliDegil, bagli or yenidenBaglan. `Plan`: yok (no brain here), tamam or okunamadi (the brain is set up but could not be read:
// the plan part is then empty and the capacity warning may be short by the plan's share).
public record ZamanCizelgesiDto(
    DateOnly Gun, string Google, string Plan, List<ZamanCizelgesiOgesi> Saatli, List<ZamanCizelgesiOgesi> Saatsiz,
    ZamanCizelgesiKapasitesi? Kapasite, DateTimeOffset? SonEsitleme);

public static class TakvimSorgulari
{
    // The events of the brain's day `gun` (05:00 to 05:00): timed ones that start in it, and the all-day ones that cover its date.
    // All-day ones first, then by the clock.
    public static IQueryable<TakvimEtkinligi> GununEtkinlikleri(this IQueryable<TakvimEtkinligi> kaynak, DateOnly gun)
    {
        var (bas, son) = TakvimZamani.GunAraligi(gun);
        return kaynak
            .Where(e => (e.TumGun && e.BaslangicGunu <= gun && e.BitisGunu > gun) || (!e.TumGun && e.Baslangic >= bas && e.Baslangic < son))
            .OrderByDescending(e => e.TumGun).ThenBy(e => e.Baslangic).ThenBy(e => e.Baslik).ThenBy(e => e.Id);
    }
}

// The one timeline of a day (K2.3c): what has a time, in the order of the clock, and what has none, apart. All of it comes from
// the database and the brain; nothing here calls Google.
public class ZamanCizelgesiServisi(
    AppDbContext db, BeyinIstemcisi beyin, GunAyari gunAyari, TakvimAyari ayar, ILogger<ZamanCizelgesiServisi> gunluk)
{
    // `hazirPlan` is the day's plan when the caller has read it already (the day page): the brain is then not asked a second time.
    public async Task<ZamanCizelgesiDto> GetirAsync(DateOnly gun, CancellationToken ct, BeyinGunDto? hazirPlan = null)
    {
        var (bas, son) = TakvimZamani.GunAraligi(gun);

        var etkinlikler = await db.TakvimEtkinlikleri.AsNoTracking().GununEtkinlikleri(gun).ToListAsync(ct);
        var hatirlaticilar = await db.Hatirlaticilar.AsNoTracking()
            .Where(h => h.Durum == HatirlaticiDurumu.Acik && (h.ErteleAn ?? h.SonrakiAn) >= bas && (h.ErteleAn ?? h.SonrakiAn) < son)
            .OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id).ToListAsync(ct);

        var saatli = new List<ZamanCizelgesiOgesi>();
        var saatsiz = new List<ZamanCizelgesiOgesi>();

        // Plan items have no hour; they come first among the unhoured, then the all-day events, then the reminders without an hour.
        var (planDurumu, planOgeleri, planAcikDk) = await PlanAlAsync(gun, hazirPlan, ct);
        saatsiz.AddRange(planOgeleri);

        var etkinlikDk = 0;
        foreach (var e in etkinlikler)
        {
            if (e.TumGun)
            {
                saatsiz.Add(new ZamanCizelgesiOgesi("etkinlik", e.Id.ToString(), e.Baslik, true, null, null, null, null, null, e.Yer, null, null, null));
                continue;
            }

            var sure = Math.Max(0, (int)Math.Round((e.Bitis - e.Baslangic).TotalMinutes));
            etkinlikDk += sure;
            saatli.Add(new ZamanCizelgesiOgesi(
                "etkinlik", e.Id.ToString(), e.Baslik, false, e.Baslangic, TakvimZamani.SaatMetni(e.Baslangic), e.Bitis, TakvimZamani.SaatMetni(e.Bitis),
                sure, e.Yer, null, null, null));
        }

        foreach (var h in hatirlaticilar)
        {
            var an = h.EtkinAn;
            // A snooze is an hour of its own, whatever the reminder's rule says.
            var saatliMi = h.Saat is not null || h.ErteleAn is not null;
            var oge = new ZamanCizelgesiOgesi(
                "hatirlatici", h.Id.ToString(), h.Baslik, false, saatliMi ? an : null, saatliMi ? TakvimZamani.SaatMetni(an) : null, null, null, null, null, null, null, null);
            (saatliMi ? saatli : saatsiz).Add(oge);
        }

        // By the clock; at the same moment an event comes before a reminder, then by title.
        saatli = saatli.OrderBy(o => o.Baslangic).ThenBy(o => o.Tur == "etkinlik" ? 0 : 1).ThenBy(o => o.Baslik, StringComparer.Ordinal).ThenBy(o => o.Kimlik, StringComparer.Ordinal).ToList();

        var toplam = planAcikDk + etkinlikDk;
        var kapasiteDk = await GunKapasitesi.DkAsync(db, gunAyari, gun, ct);
        var kapasite = toplam > kapasiteDk ? new ZamanCizelgesiKapasitesi(planAcikDk, etkinlikDk, toplam, kapasiteDk, toplam - kapasiteDk) : null;

        return new ZamanCizelgesiDto(gun, await GoogleDurumuAsync(ct), planDurumu, saatli, saatsiz, kapasite,
            await db.TakvimEsitlemeleri.AsNoTracking().MaxAsync(e => e.SonEsitleme, ct));
    }

    // The day's plan from the brain. A brain that is not set up gives no plan (and no warning); one that is set up but cannot be read
    // gives no plan and says so, so a day is never shown as empty because the read failed.
    private async Task<(string Durum, List<ZamanCizelgesiOgesi> Ogeler, int AcikDk)> PlanAlAsync(DateOnly gun, BeyinGunDto? hazirPlan, CancellationToken ct)
    {
        if (!beyin.Bagli)
            return ("yok", [], 0);

        var plan = hazirPlan;
        if (plan is null)
        {
            var yanit = await BeyinOkuma.GunAl($"{gun:yyyy-MM-dd}", beyin, gunluk, ct, gunAyari, await GunKapasitesi.DkAsync(db, gunAyari, gun, ct));
            if (!yanit.Basarili)
                return ("okunamadi", [], 0);
            plan = yanit.Veri!;
        }

        var maddeler = plan.Bolumler.SelectMany(b => b.Maddeler.Select(m => (Bolum: b.Ad, Madde: m))).ToList();
        var ogeler = maddeler.Select(m => new ZamanCizelgesiOgesi(
            "plan", m.Madde.Id, m.Madde.Baslik, false, null, null, null, null, null, null, m.Madde.Durum, m.Bolum, m.Madde.TahminDk)).ToList();
        // Only open items count towards the day's weight; one without an estimate counts as zero (as the plan's own warning does).
        var acikDk = maddeler.Where(m => m.Madde.Durum == "acik").Sum(m => m.Madde.TahminDk ?? 0);
        return ("tamam", ogeler, acikDk);
    }

    // kapali, bagliDegil, bagli or yenidenBaglan. The day view shows the same word.
    public async Task<string> GoogleDurumuAsync(CancellationToken ct)
    {
        if (!ayar.Acik)
            return "kapali";

        var baglanti = await db.GoogleBaglantilari.AsNoTracking().FirstOrDefaultAsync(ct);
        return baglanti is null ? "bagliDegil" : baglanti.Durum == GoogleBaglantiDurumu.Bagli ? "bagli" : "yenidenBaglan";
    }
}
