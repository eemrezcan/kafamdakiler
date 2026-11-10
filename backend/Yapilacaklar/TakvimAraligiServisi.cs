using Kafamdakiler.Ayarlar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Takvim;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Yapilacaklar;

// The calendar's range view (K-0024, §3): a count per day for the month grid, and what is coming. Reminders and events come from the
// database, tasks from one `gorev liste`, and the plan only for the days around today (a day file is read per day, so further out it is 0).
public class TakvimAraligiServisi(
    AppDbContext db, BeyinIstemcisi beyin, GunAyari gunAyari, HatirlaticiAyari hatirlaticiAyari, TimeProvider saat, ILogger<TakvimAraligiServisi> log)
{
    public const int EnCokGun = 42;

    // The plan is read for yesterday .. a week from today.
    public const int PlanGeriGun = 1;
    public const int PlanIleriGun = 7;

    public const int YaklasanGun = 30;
    public const int YaklasanEnCok = 20;

    public async Task<TakvimAraligiDto> GetirAsync(DateOnly baslangic, DateOnly bitis, CancellationToken ct)
    {
        var bugun = GunSiniri.Bugun(saat.GetUtcNow());
        var gunler = Enumerable.Range(0, bitis.DayNumber - baslangic.DayNumber + 1).Select(baslangic.AddDays).ToList();
        var ayar = await GunKapasitesi.AyarAsync(db, gunAyari, ct);
        int Kapasite(DateOnly gun) => GunKapasitesi.HaftaSonu(gun) ? ayar.HaftaSonuDk : ayar.HaftaIciDk;

        // Reminders (open and closed ones; an archived one is out) and what was done.
        var (ilkBas, _) = TakvimZamani.GunAraligi(gunler[0]);
        var (_, sonSon) = TakvimZamani.GunAraligi(gunler[^1]);
        var yaklasanSonu = bugun.AddDays(YaklasanGun);
        var pencereSonu = new[] { sonSon, TakvimZamani.GunAraligi(yaklasanSonu).Son }.Max();
        var ilkGun = gunler[0];
        var sonGun = gunler[^1];
        // A repeating reminder is always read (its turns are worked out); a one-off only when its moment is in the window.
        var hatirlaticilar = await db.Hatirlaticilar.AsNoTracking()
            .Where(h => h.Durum != HatirlaticiDurumu.Arsiv
                && (h.Tekrar != Tekrar.Yok
                    || (h.SonrakiAn >= ilkBas && h.SonrakiAn < pencereSonu)
                    || (h.ErteleAn != null && h.ErteleAn >= ilkBas && h.ErteleAn < pencereSonu)))
            .ToListAsync(ct);
        var yapilanlar = (await db.HatirlaticiOlaylari.AsNoTracking()
            .Where(o => o.Tur == HatirlaticiOlayTuru.Yapildi && o.HedefAn >= ilkBas && o.HedefAn < sonSon)
            .Select(o => new { o.HatirlaticiId, o.HedefAn }).ToListAsync(ct)).ToLookup(o => o.HatirlaticiId, o => o.HedefAn);

        // A reminder tied to an item shows with that item (§1), so it is not counted a second time as a reminder of its own day.
        var bagsizlar = hatirlaticilar.Where(h => h.MaddeId is null && h.GorevKimligi is null).ToList();

        var etkinlikler = await db.TakvimEtkinlikleri.AsNoTracking()
            .Where(e => (e.TumGun && e.BaslangicGunu <= sonGun && e.BitisGunu > ilkGun) || (!e.TumGun && e.Baslangic >= ilkBas && e.Baslangic < sonSon))
            .ToListAsync(ct);

        // Tasks with a due date, all from one call. A brain that is not set up or cannot be read leaves the task counts at 0.
        var gorevler = new List<AcikGorevDto>();
        var planlar = new Dictionary<DateOnly, BeyinGunDto>();
        if (beyin.Bagli)
        {
            var liste = await BeyinOkuma.AcikGorevlerAl(beyin, log, ct);
            if (liste.Basarili)
                gorevler = liste.Veri!.Where(g => g.Bitis is not null).ToList();
            else
                log.LogWarning("The calendar could not read the tasks ({Durum})", liste.Durum);

            foreach (var gun in gunler.Where(g => g >= bugun.AddDays(-PlanGeriGun) && g <= bugun.AddDays(PlanIleriGun)))
            {
                var yanit = await BeyinOkuma.GunAl($"{gun:yyyy-MM-dd}", beyin, log, ct, gunAyari, Kapasite(gun));
                if (yanit.Basarili)
                    planlar[gun] = yanit.Veri!;
            }
        }

        var sonuc = new List<TakvimGunuDto>(gunler.Count);
        foreach (var gun in gunler)
        {
            var etkinlikGunu = etkinlikler.Where(e => EtkinlikGundeMi(e, gun)).ToList();
            var etkinlikDk = etkinlikGunu.Where(e => !e.TumGun).Sum(e => Math.Max(0, (int)Math.Round((e.Bitis - e.Baslangic).TotalMinutes)));
            var hatirlaticiSayisi = bagsizlar.Count(h => YapilacakYardimcisi.Anlar(h, gun, hatirlaticiAyari.VarsayilanSaat, yapilanlar).Count > 0);

            var planSayisi = 0;
            var planAcikDk = 0;
            if (planlar.TryGetValue(gun, out var plan))
            {
                // A task due that day shows in the plan as a made-up item `g:<task>`: it is counted with the tasks, not twice.
                var maddeler = plan.Bolumler.SelectMany(b => b.Maddeler).ToList();
                planSayisi = maddeler.Count(m => !m.Id.StartsWith("g:", StringComparison.Ordinal));
                planAcikDk = maddeler.Where(m => m.Durum == "acik").Sum(m => m.TahminDk ?? 0);
            }

            sonuc.Add(new TakvimGunuDto(
                gun, new TakvimSayilariDto(planSayisi, gorevler.Count(g => g.Bitis == gun), hatirlaticiSayisi, etkinlikGunu.Count),
                planAcikDk + etkinlikDk > Kapasite(gun)));
        }

        return new TakvimAraligiDto(sonuc, await YaklasanAsync(bugun, yaklasanSonu, hatirlaticilar, gorevler, ct));
    }

    // What is coming in the next 30 days (after today): reminders, tasks with a due date and all-day events, soonest first, at most 20.
    private async Task<List<YapilacakDto>> YaklasanAsync(
        DateOnly bugun, DateOnly son, List<Hatirlatici> hatirlaticilar, List<AcikGorevDto> gorevler, CancellationToken ct)
    {
        var ilk = bugun.AddDays(1);
        var (bas, _) = TakvimZamani.GunAraligi(ilk);
        var satirlar = new List<(DateOnly Gun, string Saat, YapilacakDto Oge)>();

        // A reminder tied to a task shown here joins that task.
        var gorevKimlikleri = gorevler.Where(g => g.Bitis > bugun && g.Bitis <= son).Select(g => g.Kimlik).ToHashSet();
        var hatirlaticiBagi = hatirlaticilar
            .Where(h => h.Durum == HatirlaticiDurumu.Acik && h.GorevKimligi is not null && gorevKimlikleri.Contains(h.GorevKimligi))
            .GroupBy(h => h.GorevKimligi!).ToDictionary(g => g.Key, g => g.OrderBy(h => h.EtkinAn).First());

        foreach (var g in gorevler.Where(g => g.Bitis > bugun && g.Bitis <= son))
        {
            hatirlaticiBagi.TryGetValue(g.Kimlik, out var bagli);
            var (baslik, bolunmus) = YapilacakYardimcisi.BaslikAyir(g.Baslik);
            satirlar.Add((g.Bitis!.Value, bagli is null ? "" : YapilacakYardimcisi.HatirlaticiSaati(bagli) ?? "", new YapilacakDto(
                $"g:{g.Kimlik}", YapilacakTuru.Gorev, baslik, bagli is null ? null : YapilacakYardimcisi.HatirlaticiSaati(bagli), null, false, null, null,
                YapilacakDurumu.Acik, g.Proje, null, null, bolunmus, bagli is null ? null : YapilacakYardimcisi.Ozet(bagli), null, g.Kimlik, null, null, null)));
        }

        // Open reminders: the next moment of each from tomorrow on (a repeating one shows its next turn, the rest of its turns are the grid's).
        // A one-off whose moment has passed is not "coming".
        foreach (var h in hatirlaticilar.Where(h => h.Durum == HatirlaticiDurumu.Acik && !(h.GorevKimligi is { } k && hatirlaticiBagi.TryGetValue(k, out var secili) && secili.Id == h.Id)))
        {
            var an = h.EtkinAn;
            if (an < bas)
            {
                if (h.Tekrar == Tekrar.Yok)
                    continue;

                an = HatirlaticiHesap.Sonraki(h.Tekrar, h.Gun, h.Saat ?? hatirlaticiAyari.VarsayilanSaat, bas.AddTicks(-1), h.Gunler);
            }

            var gun = GunSiniri.Bugun(an);
            if (gun > son)
                continue;

            var saatli = h.Saat is not null || (h.ErteleAn is not null && an == h.ErteleAn);
            satirlar.Add((gun, saatli ? TakvimZamani.SaatMetni(an) : "", new YapilacakDto(
                $"h:{h.Id}", YapilacakTuru.Hatirlatici, h.Baslik, saatli ? TakvimZamani.SaatMetni(an) : null, null, false, null, null,
                YapilacakDurumu.Acik, null, null, null, null, YapilacakYardimcisi.Ozet(h), h.MaddeId, h.GorevKimligi, h.Id, null, null)));
        }

        var tumGunler = await db.TakvimEtkinlikleri.AsNoTracking()
            .Where(e => e.TumGun && e.BaslangicGunu <= son && e.BitisGunu > ilk).OrderBy(e => e.BaslangicGunu).ThenBy(e => e.Baslik).ToListAsync(ct);
        foreach (var e in tumGunler)
        {
            // A multi-day event shows once, on the first day of the window it covers.
            var gun = e.BaslangicGunu > ilk ? e.BaslangicGunu : ilk;
            satirlar.Add((gun, "", new YapilacakDto(
                $"e:{e.Id}", YapilacakTuru.Etkinlik, e.Baslik, null, null, true, null, null, YapilacakDurumu.Acik, null, null, null, null, null,
                null, null, null, e.Id, string.IsNullOrWhiteSpace(e.Yer) ? null : e.Yer)));
        }

        return satirlar.OrderBy(s => s.Gun).ThenBy(s => s.Saat, StringComparer.Ordinal).ThenBy(s => s.Oge.Kimlik, StringComparer.Ordinal)
            .Take(YaklasanEnCok).Select(s => s.Oge).ToList();
    }

    // The same test the day view uses: an all-day event covers the dates from its first day up to (not including) its end day; a timed one
    // belongs to the brain's day it starts in.
    internal static bool EtkinlikGundeMi(TakvimEtkinligi e, DateOnly gun)
    {
        if (e.TumGun)
            return e.BaslangicGunu <= gun && e.BitisGunu > gun;

        var (bas, son) = TakvimZamani.GunAraligi(gun);
        return e.Baslangic >= bas && e.Baslangic < son;
    }
}
