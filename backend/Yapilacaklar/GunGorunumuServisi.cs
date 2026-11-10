using System.Text.RegularExpressions;
using Kafamdakiler.Ayarlar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Takvim;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Yapilacaklar;

// How the pieces of a day become the one list of K-0024 (API sözleşmesi §1): plan items, tasks, reminders and calendar events as
// `YapilacakDto`. Pure helpers, so the rules are unit tested without a database or a brain.
public static partial class YapilacakYardimcisi
{
    // The brain's own estimate marker (`~30dk`, `~1s30dk`): it stays in the plan line, but the title shown to a person is without it
    // (the estimate has a field of its own).
    [GeneratedRegex(@"\s*(?:~(?:\d+(?:[.,]\d+)?)(?:saat|sa|s)(?:\s*\d+\s*(?:dk|d))?|~\d+\s*(?:dk|d))(?![\wçğıöşüÇĞİÖŞÜ])", RegexOptions.CultureInvariant)]
    private static partial Regex TahminIsareti();

    // "(2/3)": what splitting a task over days writes into each day's item.
    [GeneratedRegex(@"\s*\((\d{1,2})/(\d{1,2})\)\s*$", RegexOptions.CultureInvariant)]
    private static partial Regex BolmeIsareti();

    public static string BaslikTemizle(string baslik) => TahminIsareti().Replace(baslik, "").Trim();

    // The title without the estimate and without the "(2/3)" count, and the count when the title had one that makes sense.
    public static (string Baslik, BolunmusDto? Bolunmus) BaslikAyir(string baslik)
    {
        var temiz = BaslikTemizle(baslik);
        var eslesme = BolmeIsareti().Match(temiz);
        if (!eslesme.Success)
            return (temiz, null);

        var sira = int.Parse(eslesme.Groups[1].Value);
        var toplam = int.Parse(eslesme.Groups[2].Value);
        if (sira < 1 || toplam < 2 || sira > toplam)
            return (temiz, null);

        var sade = temiz[..eslesme.Index].TrimEnd();
        return (sade.Length > 0 ? sade : temiz, new BolunmusDto(sira, toplam));
    }

    // The hour a reminder shows on a row: a snooze is an hour of its own, else the reminder's own hour; none when it has neither.
    public static string? HatirlaticiSaati(Hatirlatici h) =>
        h is { Durum: HatirlaticiDurumu.Acik, ErteleAn: { } erte } ? TakvimZamani.SaatMetni(erte)
        : h.Saat is { } saat ? $"{saat:HH:mm}"
        : null;

    public static HatirlaticiOzetDto Ozet(Hatirlatici h) => new(
        h.Id, h.Saat is { } saat ? $"{saat:HH:mm}" : null, h.Tekrar,
        HatirlaticiHesap.CokGunlu(h.Tekrar, h.Gunler) ? HatirlaticiIslemleri.GunListesi(h) : null,
        h.Acil, h.Israrli, h.OnceGun);

    public static (YapilacakTuru Tur, string Kimlik, string? MaddeId, string? GorevKimligi) Kimlikle(string madde, string? gorev) =>
        madde.StartsWith("g:", StringComparison.Ordinal)
            ? (YapilacakTuru.Gorev, madde, null, madde[2..])
            : (YapilacakTuru.Plan, $"m:{madde}", madde, gorev);

    // Whether `gun` is one of the days of the reminder's rule (not counting snoozes or progress).
    public static bool KuralGunu(Hatirlatici h, DateOnly gun)
    {
        if (gun < h.Gun)
            return false;

        return h.Tekrar switch
        {
            Tekrar.Yok => gun == h.Gun,
            Tekrar.Gunluk => true,
            Tekrar.Haftalik => HatirlaticiHesap.CokGunlu(h.Tekrar, h.Gunler)
                ? h.Gunler.HasFlag(HatirlaticiHesap.HaftaGunu(gun))
                : (gun.DayNumber - h.Gun.DayNumber) % 7 == 0,
            Tekrar.Aylik => HatirlaticiHesap.Olusum(Tekrar.Aylik, h.Gun, (gun.Year - h.Gun.Year) * 12 + gun.Month - h.Gun.Month) == gun,
            Tekrar.Yillik => HatirlaticiHesap.Olusum(Tekrar.Yillik, h.Gun, gun.Year - h.Gun.Year) == gun,
            _ => false,
        };
    }

    // The moments of a reminder in the brain's day `gun` (05:00 to 05:00), and whether each was done:
    // - open: its pending moment (a snooze included) when it falls in the day, and the later turns of a repeating rule that fall in it;
    // - done: the turns that were marked done (the weekly summary's events), and a closed one-off at its own moment.
    public static List<(DateTimeOffset An, bool Yapildi)> Anlar(
        Hatirlatici h, DateOnly gun, TimeOnly varsayilanSaat, ILookup<Guid, DateTimeOffset> yapilanlar)
    {
        var (bas, son) = TakvimZamani.GunAraligi(gun);
        bool Icinde(DateTimeOffset an) => an >= bas && an < son;

        var anlar = new List<(DateTimeOffset, bool)>();
        var yapilan = yapilanlar[h.Id].Where(Icinde).ToList();
        if (h.Durum == HatirlaticiDurumu.Acik)
        {
            if (Icinde(h.EtkinAn))
                anlar.Add((h.EtkinAn, false));

            if (h.Tekrar != Tekrar.Yok)
            {
                // 00:00-05:00 of the next calendar day still belongs to this brain day.
                foreach (var aday in new[] { gun, gun.AddDays(1) })
                {
                    if (!KuralGunu(h, aday))
                        continue;

                    var an = HatirlaticiHesap.An(aday, h.Saat ?? varsayilanSaat);
                    if (Icinde(an) && an > h.SonrakiAn)
                        anlar.Add((an, false));
                }
            }
        }

        anlar.AddRange(yapilan.Select(an => (an, true)));
        if (h.Durum == HatirlaticiDurumu.Tamam && h.Tekrar == Tekrar.Yok && yapilan.Count == 0 && Icinde(h.SonrakiAn))
            anlar.Add((h.SonrakiAn, true));

        return anlar;
    }

    // The day's weight (§1 `yuk`): open plan and task items count with their estimate, an item without one counts as zero and is counted apart.
    public static GunYukuDto Yuk(IEnumerable<YapilacakDto> ogeler, int etkinlikDk, int kapasiteDk)
    {
        var acik = ogeler.Where(o => o is { Durum: YapilacakDurumu.Acik, Tur: YapilacakTuru.Plan or YapilacakTuru.Gorev }).ToList();
        var tahmin = acik.Sum(o => o.TahminDk ?? 0);
        var toplam = tahmin + etkinlikDk;
        return new GunYukuDto(tahmin, etkinlikDk, kapasiteDk, Math.Max(0, toplam - kapasiteDk), Math.Max(0, kapasiteDk - toplam), acik.Count(o => o.TahminDk is null));
    }
}

// The one view of a day (K-0024, §1): what the Bugün screen and the calendar's day show. Built on what exists: the brain's day plan and
// tasks (BeyinOkuma), the database's reminders and synced events, the stored briefing. It writes nothing.
public class GunGorunumuServisi(
    AppDbContext db, BeyinIstemcisi beyin, GunAyari gunAyari, HatirlaticiAyari hatirlaticiAyari, ZamanCizelgesiServisi cizelge,
    BrifingHazirlayici brifing, TimeProvider saat, ILogger<GunGorunumuServisi> log)
{
    public const int OzetEnUzun = 300;

    public async Task<GunGorunumuDto> GetirAsync(DateOnly tarih, Guid? kullaniciId, CancellationToken ct)
    {
        var simdi = saat.GetUtcNow();
        var bugunGunu = GunSiniri.Bugun(simdi);
        var bugun = tarih == bugunGunu;
        var (bas, son) = TakvimZamani.GunAraligi(tarih);
        var kapasiteDk = await GunKapasitesi.DkAsync(db, gunAyari, tarih, ct);

        // The plan. A brain that is not set up gives none; one that is set up but cannot be read says so, so a day is never shown empty
        // only because the read failed.
        var planDurumu = "yok";
        BeyinGunDto? plan = null;
        if (beyin.Bagli)
        {
            var yanit = await BeyinOkuma.GunAl($"{tarih:yyyy-MM-dd}", beyin, log, ct, gunAyari, kapasiteDk);
            planDurumu = yanit.Basarili ? "tamam" : "okunamadi";
            plan = yanit.Veri;
        }

        var ogeler = new List<YapilacakDto>();
        if (plan is not null)
        {
            foreach (var bolum in plan.Bolumler)
            {
                foreach (var m in bolum.Maddeler)
                {
                    var (tur, kimlik, maddeId, gorev) = YapilacakYardimcisi.Kimlikle(m.Id, m.Gorev);
                    var (baslik, bolunmus) = YapilacakYardimcisi.BaslikAyir(m.Baslik);
                    ogeler.Add(new YapilacakDto(
                        kimlik, tur, baslik, null, null, false, m.TahminDk, m.SureDk is > 0 ? m.SureDk : null,
                        BeyinGorunum.Yapildi(m.Durum) ? YapilacakDurumu.Yapildi : YapilacakDurumu.Acik, m.Proje, bolum.Ad, null, bolunmus,
                        null, maddeId, gorev, null, null, null, tarih));
                }
            }

            // Overdue tasks are today's business. A task that already has an item (a plan item linked to it) shows its lateness on that item.
            if (bugun)
            {
                foreach (var g in plan.Geciken)
                {
                    var mevcut = ogeler.FindIndex(o => o.GorevKimligi == g.Kimlik);
                    if (mevcut >= 0)
                    {
                        ogeler[mevcut] = ogeler[mevcut] with { GecikmeGun = g.Gun };
                        continue;
                    }

                    var (baslik, bolunmus) = YapilacakYardimcisi.BaslikAyir(g.Baslik);
                    ogeler.Add(new YapilacakDto(
                        $"g:{g.Kimlik}", YapilacakTuru.Gorev, baslik, null, null, false, null, null, YapilacakDurumu.Acik, g.Proje, null, g.Gun,
                        bolunmus, null, null, g.Kimlik, null, null, null, g.Bitis ?? tarih));
                }
            }
        }

        // Calendar events (database): all-day first in the list, timed ones with their hours.
        var etkinlikler = await db.TakvimEtkinlikleri.AsNoTracking().GununEtkinlikleri(tarih).ToListAsync(ct);
        var etkinlikDk = 0;
        var etkinlikSatirlari = new List<YapilacakDto>();
        foreach (var e in etkinlikler)
        {
            var sure = e.TumGun ? (int?)null : Math.Max(0, (int)Math.Round((e.Bitis - e.Baslangic).TotalMinutes));
            etkinlikDk += sure ?? 0;
            etkinlikSatirlari.Add(new YapilacakDto(
                $"e:{e.Id}", YapilacakTuru.Etkinlik, e.Baslik, e.TumGun ? null : TakvimZamani.SaatMetni(e.Baslangic),
                e.TumGun ? null : TakvimZamani.SaatMetni(e.Bitis), e.TumGun, null, sure, YapilacakDurumu.Acik, null, null, null, null, null,
                null, null, null, e.Id, string.IsNullOrWhiteSpace(e.Yer) ? null : e.Yer, tarih));
        }

        // Reminders: the ones tied to an item of this list join it; the rest are rows of their own when one of their moments is in the day
        // (open overdue ones too, on today: the reminders tab is gone, so a late reminder must show here).
        var adaylar = await db.Hatirlaticilar.AsNoTracking()
            .Where(h => h.Durum != HatirlaticiDurumu.Arsiv
                && (h.Tekrar != Tekrar.Yok
                    || (h.SonrakiAn >= bas && h.SonrakiAn < son)
                    || (h.ErteleAn != null && h.ErteleAn >= bas && h.ErteleAn < son)
                    || h.MaddeTarihi == tarih
                    || (h.Durum == HatirlaticiDurumu.Acik && (h.GorevKimligi != null || (bugun && (h.ErteleAn ?? h.SonrakiAn) < bas)))))
            .OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id).ToListAsync(ct);
        var yapilanlar = (await db.HatirlaticiOlaylari.AsNoTracking()
            .Where(o => o.Tur == HatirlaticiOlayTuru.Yapildi && o.HedefAn >= bas && o.HedefAn < son)
            .Select(o => new { o.HatirlaticiId, o.HedefAn }).ToListAsync(ct)).ToLookup(o => o.HatirlaticiId, o => o.HedefAn);

        var kullanilan = new HashSet<Guid>();
        for (var i = 0; i < ogeler.Count; i++)
        {
            var oge = ogeler[i];
            var h = adaylar
                .Where(a => !kullanilan.Contains(a.Id)
                    && ((oge.MaddeId is not null && a.MaddeId == oge.MaddeId && a.MaddeTarihi == tarih)
                        || (oge.GorevKimligi is not null && a.GorevKimligi == oge.GorevKimligi)))
                // The one that matches the item itself first, then an open one before a closed one, then the earlier moment.
                .OrderBy(a => oge.MaddeId is not null && a.MaddeId == oge.MaddeId ? 0 : 1)
                .ThenBy(a => a.Durum == HatirlaticiDurumu.Acik ? 0 : 1).ThenBy(a => a.EtkinAn).FirstOrDefault();
            if (h is null)
                continue;

            kullanilan.Add(h.Id);
            // An item without an hour takes the reminder's.
            ogeler[i] = oge with { Saat = oge.Saat ?? YapilacakYardimcisi.HatirlaticiSaati(h), Hatirlatici = YapilacakYardimcisi.Ozet(h) };
        }

        foreach (var h in adaylar.Where(a => !kullanilan.Contains(a.Id)))
        {
            var anlar = YapilacakYardimcisi.Anlar(h, tarih, hatirlaticiAyari.VarsayilanSaat, yapilanlar);
            var gecikmeGun = (int?)null;
            if (bugun && anlar.Count == 0 && h.Durum == HatirlaticiDurumu.Acik && h.EtkinAn < bas)
            {
                anlar.Add((h.EtkinAn, false));
                gecikmeGun = Math.Max(1, tarih.DayNumber - GunSiniri.Bugun(h.EtkinAn).DayNumber);
            }

            // One row per reminder and day: the open moment is the one that matters.
            if (anlar.Count == 0)
                continue;

            var (an, yapildi) = anlar.OrderBy(a => a.Yapildi).ThenBy(a => a.An).First();
            // A late one shows how late it is, not its old hour.
            var saatli = (h.Saat is not null || h.ErteleAn is not null) && gecikmeGun is null;
            ogeler.Add(new YapilacakDto(
                $"h:{h.Id}", YapilacakTuru.Hatirlatici, h.Baslik, saatli ? TakvimZamani.SaatMetni(an) : null, null, false, null, null,
                yapildi ? YapilacakDurumu.Yapildi : YapilacakDurumu.Acik, null, null, gecikmeGun, null, YapilacakYardimcisi.Ozet(h),
                h.MaddeId, h.GorevKimligi, h.Id, null, null, GunSiniri.Bugun(an)));
        }

        ogeler.AddRange(etkinlikSatirlari);

        // Order: what has an hour by the clock (an event before a reminder at the same minute), then what has none: late items first (the
        // later, the earlier in the list), all-day events, the plan in the brain's order, and the reminders without an hour last.
        var sirali = ogeler
            .Select((o, i) => (Oge: o, Sira: i))
            .OrderBy(x => SiraGrubu(x.Oge))
            .ThenBy(x => SiraGrubu(x.Oge) == 0 ? x.Oge.Saat : "", StringComparer.Ordinal)
            .ThenBy(x => x.Oge.Tur == YapilacakTuru.Etkinlik ? 0 : 1)
            .ThenByDescending(x => x.Oge.GecikmeGun ?? 0)
            .ThenBy(x => x.Sira)
            .Select(x => x.Oge).ToList();

        var yuk = YapilacakYardimcisi.Yuk(sirali, etkinlikDk, kapasiteDk);

        var dundenKalanlar = new List<DundenKalanDto>();
        if (bugun && beyin.Bagli)
            dundenKalanlar = await DundenKalanlarAsync(tarih, kullaniciId, sirali, ct);

        return new GunGorunumuDto(
            tarih, bugun, plan?.Kapandi ?? false, bugun ? await OzetAsync(tarih, plan, sirali, yuk, ct) : null, yuk, dundenKalanlar, sirali,
            new GunKaynaklariDto(planDurumu, await cizelge.GoogleDurumuAsync(ct), await db.TakvimEsitlemeleri.AsNoTracking().MaxAsync(e => e.SonEsitleme, ct)));
    }

    private static int SiraGrubu(YapilacakDto o) =>
        o.Saat is not null && !o.TumGun ? 0
        : o.GecikmeGun is not null ? 1
        : o.TumGun ? 2
        : o.Tur == YapilacakTuru.Hatirlatici ? 4
        : 3;

    // What yesterday's plan left open, without what the person dropped (BirakilanMadde) and without a task that already shows up late.
    private async Task<List<DundenKalanDto>> DundenKalanlarAsync(DateOnly bugun, Guid? kullaniciId, List<YapilacakDto> ogeler, CancellationToken ct)
    {
        var sabah = await BeyinOkuma.SabahAl(beyin, log, saat, ct);
        if (!sabah.Basarili)
            return [];

        var birakilan = kullaniciId is { } id
            ? (await db.BirakilanMaddeler.AsNoTracking().Where(b => b.Tarih == bugun && b.KullaniciId == id).Select(b => b.MaddeId).ToListAsync(ct)).ToHashSet()
            : [];
        var gecikenler = ogeler.Where(o => o.GorevKimligi is not null).Select(o => o.GorevKimligi!).ToHashSet();

        return sabah.Veri!.Maddeler
            .Where(m => !birakilan.Contains(m.Id) && !(m.Id.StartsWith("g:", StringComparison.Ordinal) && gecikenler.Contains(m.Id[2..])))
            .Select(m => new DundenKalanDto(m.Id, YapilacakYardimcisi.BaslikTemizle(m.Baslik), m.TahminDk, m.Proje)).ToList();
    }

    // Today's one or two sentences: the first card of the stored briefing, else a line from the numbers. Null when there is nothing to say.
    // A briefing is never made here (that may call Claude): only a stored one is read.
    private async Task<string?> OzetAsync(DateOnly tarih, BeyinGunDto? plan, List<YapilacakDto> ogeler, GunYukuDto yuk, CancellationToken ct)
    {
        var kayit = await brifing.GetirAsync(tarih, ct);
        if (kayit is not null && BrifingHazirlayici.KartlariOku(kayit).FirstOrDefault() is { } kart && !string.IsNullOrWhiteSpace(kart.Metin))
            return kart.Metin.Length <= OzetEnUzun ? kart.Metin : kart.Metin[..OzetEnUzun].TrimEnd();

        if (plan is null)
            return null;

        var acik = ogeler.Count(o => o is { Durum: YapilacakDurumu.Acik, Tur: YapilacakTuru.Plan or YapilacakTuru.Gorev });
        if (acik == 0)
            return null;

        var cumle = $"Bugün {acik} açık iş var" + (yuk.AcikTahminDk > 0 ? $", tahmini {BeyinGorunum.Dakika(yuk.AcikTahminDk)}." : ".");
        return yuk.AsimDk > 0 ? $"{cumle} Gün {BeyinGorunum.Dakika(yuk.AsimDk)} taşıyor." : cumle;
    }
}
