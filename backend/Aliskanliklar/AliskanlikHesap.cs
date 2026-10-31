namespace Kafamdakiler.Aliskanliklar;

// Pure habit calculations: no database, no clock. Callers pass the dates in.
public static class AliskanlikHesap
{
    // Turkey has no daylight saving time since 2016, so the offset is a fixed +03:00.
    private static readonly TimeZoneInfo Istanbul = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");

    private const int GunDonumuSaati = 5;

    // The habit day starts at 05:00 Istanbul time: 03:30 still belongs to the previous day.
    public static DateOnly AliskanlikGunu(DateTimeOffset an)
    {
        var yerel = TimeZoneInfo.ConvertTime(an, Istanbul);
        return DateOnly.FromDateTime(yerel.DateTime.AddHours(-GunDonumuSaati));
    }

    // Value of one day between 0 and 1.
    public static double GununDegeri(Olcu olcu, HedefYonu yon, decimal? gunlukHedef, decimal miktar)
    {
        // Yes/no habits have no target: EnAz needs one tick, EnCok allows none.
        var hedef = olcu == Olcu.EvetHayir ? (yon == HedefYonu.EnAz ? 1m : 0m) : gunlukHedef ?? 0m;

        if (yon == HedefYonu.EnCok)
            return miktar <= hedef ? 1 : 0;

        if (hedef <= 0)
            return miktar > 0 ? 1 : 0;

        return Math.Min(1, (double)(miktar / hedef));
    }

    public static double GununDegeri(Aliskanlik a, decimal miktar) =>
        GununDegeri(a.Olcu, a.HedefYonu, a.GunlukHedef, miktar);

    // Is the habit expected on this day? Only BelirliGunler skips days.
    public static bool Planli(Aliskanlik a, DateOnly gun)
    {
        if (a.Siklik != Siklik.BelirliGunler)
            return true;

        var bayrak = (Gunler)(1 << (((int)gun.DayOfWeek + 6) % 7)); // Monday = 1 ... Sunday = 64
        return a.Gunler is { } secili && secili.HasFlag(bayrak);
    }

    // Habit strength (exponential smoothing, as in Loop Habit Tracker), one point per day from baslangic to bitis.
    // Each counted day pulls the score toward its value by (1 - m); m is the memory: the closer to 1,
    // the slower the score reacts. m comes from the frequency: rarer habits forget more slowly.
    // BelirliGunler ignores unplanned days; HaftadaN values a day by its trailing 7-day quota.
    // A day after bugun is not counted, and neither is bugun itself when nothing was entered yet for a EnAz habit.
    public static IReadOnlyList<(DateOnly Gun, double Guc)> GucSerisi(
        Aliskanlik a, IReadOnlyDictionary<DateOnly, decimal> miktarlar, DateOnly baslangic, DateOnly bitis, DateOnly bugun)
    {
        if (miktarlar.Count > 0)
            baslangic = DateOnly.FromDayNumber(Math.Min(baslangic.DayNumber, miktarlar.Keys.Min(k => k.DayNumber)));

        var haftadaN = a.Siklik == Siklik.HaftadaN && a.HaftalikSayi is > 0;
        var sikligi = haftadaN ? a.HaftalikSayi!.Value / 7.0 : 1.0;
        var m = Math.Pow(0.5, Math.Sqrt(sikligi) / 13.0);

        var seri = new List<(DateOnly, double)>();
        var guc = 0.0;
        for (var gun = baslangic; gun <= bitis; gun = gun.AddDays(1))
        {
            var sayilir = gun <= bugun
                && Planli(a, gun)
                && !(gun == bugun && a.HedefYonu == HedefYonu.EnAz && !miktarlar.ContainsKey(gun));

            if (sayilir)
            {
                var deger = haftadaN
                    ? Math.Min(1, Enumerable.Range(0, 7).Sum(i => GununDegeri(a, miktarlar.GetValueOrDefault(gun.AddDays(-i)))) / a.HaftalikSayi!.Value)
                    : GununDegeri(a, miktarlar.GetValueOrDefault(gun));
                guc = guc * m + deger * (1 - m);
            }

            seri.Add((gun, guc));
        }

        return seri;
    }

    public static double Guc(Aliskanlik a, IReadOnlyDictionary<DateOnly, decimal> miktarlar, DateOnly baslangic, DateOnly bugun)
    {
        var seri = GucSerisi(a, miktarlar, baslangic, bugun, bugun);
        return seri.Count == 0 ? 0 : seri[^1].Guc;
    }

    // Streak units, oldest first: days (HerGun, BelirliGunler) or Monday-based weeks (HaftadaN).
    // The unit that is still open (today, this week) is left out until it succeeds, so it never breaks a streak.
    private static List<bool> SeriBirimleri(
        Aliskanlik a, IReadOnlyDictionary<DateOnly, decimal> miktarlar, DateOnly baslangic, DateOnly bugun)
    {
        if (miktarlar.Count > 0)
            baslangic = DateOnly.FromDayNumber(Math.Min(baslangic.DayNumber, miktarlar.Keys.Min(k => k.DayNumber)));

        bool Basarili(DateOnly gun) => GununDegeri(a, miktarlar.GetValueOrDefault(gun)) >= 1;

        var birimler = new List<bool>();

        if (a.Siklik == Siklik.HaftadaN && a.HaftalikSayi is > 0)
        {
            var hafta = HaftaBasi(baslangic);
            for (; hafta <= bugun; hafta = hafta.AddDays(7))
            {
                var basarili = Enumerable.Range(0, 7).Count(i => Basarili(hafta.AddDays(i))) >= a.HaftalikSayi.Value;
                var acik = hafta.AddDays(6) >= bugun;
                if (!acik || basarili)
                    birimler.Add(basarili);
            }

            return birimler;
        }

        for (var gun = baslangic; gun <= bugun; gun = gun.AddDays(1))
        {
            if (!Planli(a, gun))
                continue;

            var basarili = Basarili(gun);
            var acik = gun == bugun && !miktarlar.ContainsKey(gun);
            if (!acik || basarili)
                birimler.Add(basarili);
        }

        return birimler;
    }

    private static DateOnly HaftaBasi(DateOnly gun) => gun.AddDays(-(((int)gun.DayOfWeek + 6) % 7));

    public static int Seri(Aliskanlik a, IReadOnlyDictionary<DateOnly, decimal> miktarlar, DateOnly baslangic, DateOnly bugun)
    {
        var birimler = SeriBirimleri(a, miktarlar, baslangic, bugun);
        var seri = 0;
        for (var i = birimler.Count - 1; i >= 0 && birimler[i]; i--)
            seri++;

        return seri;
    }

    public static int EnUzunSeri(Aliskanlik a, IReadOnlyDictionary<DateOnly, decimal> miktarlar, DateOnly baslangic, DateOnly bugun)
    {
        int enUzun = 0, simdiki = 0;
        foreach (var basarili in SeriBirimleri(a, miktarlar, baslangic, bugun))
        {
            simdiki = basarili ? simdiki + 1 : 0;
            enUzun = Math.Max(enUzun, simdiki);
        }

        return enUzun;
    }
}
