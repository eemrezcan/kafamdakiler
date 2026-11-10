using Kafamdakiler.Aliskanliklar;

namespace Kafamdakiler.Hatirlaticilar;

// Pure reminder calculations: no database, no clock. Callers pass "now" in. All days and hours are Europe/Istanbul;
// results are UTC moments.
public static class HatirlaticiHesap
{
    private static readonly TimeZoneInfo Istanbul = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");

    // The moment (UTC) of a local Istanbul day and hour.
    public static DateTimeOffset An(DateOnly gun, TimeOnly saat)
    {
        var yerel = gun.ToDateTime(saat);
        return new DateTimeOffset(yerel, Istanbul.GetUtcOffset(yerel)).ToUniversalTime();
    }

    public static DateOnly IstanbulGunu(DateTimeOffset an) =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(an, Istanbul).DateTime);

    public static TimeOnly IstanbulSaati(DateTimeOffset an) =>
        TimeOnly.FromDateTime(TimeZoneInfo.ConvertTime(an, Istanbul).DateTime);

    // The n-th day of the rule, counted from the start day. Months and years count from the start day each time, so a
    // rule starting on the 31st gives 31 Jan, 28 Feb, 31 Mar (not 28 Feb, 28 Mar). 29 Feb gives 28 Feb in common years.
    public static DateOnly Olusum(Tekrar tekrar, DateOnly baslangic, int n) => tekrar switch
    {
        Tekrar.Gunluk => baslangic.AddDays(n),
        Tekrar.Haftalik => baslangic.AddDays(7 * n),
        Tekrar.Aylik => baslangic.AddMonths(n),
        Tekrar.Yillik => baslangic.AddYears(n),
        _ => baslangic,
    };

    // The flag of a day of the week, Monday = 1 ... Sunday = 64 (the habits' `Gunler`).
    public static Gunler HaftaGunu(DateOnly gun) => (Gunler)(1 << (((int)gun.DayOfWeek + 6) % 7));

    // A weekly rule that names several days. Only Haftalik reads `gunler`; anywhere else (or with none chosen) the rule is the plain one.
    public static bool CokGunlu(Tekrar tekrar, Gunler gunler) => tekrar == Tekrar.Haftalik && gunler != Gunler.Yok;

    // The n-th day (from 0) of a weekly rule with several days: the days from `baslangic` on (the start day included) whose weekday is
    // chosen, in order. With no day chosen it is the plain weekly rule (every 7 days from the start day).
    public static DateOnly Olusum(Tekrar tekrar, DateOnly baslangic, int n, Gunler gunler)
    {
        if (!CokGunlu(tekrar, gunler))
            return Olusum(tekrar, baslangic, n);

        var secili = Enumerable.Range(0, 7).Count(i => gunler.HasFlag(HaftaGunu(baslangic.AddDays(i))));
        if (secili == 0)
            return Olusum(tekrar, baslangic, n);

        // Whole weeks first, then the n-th chosen day inside the week that is left.
        var gun = baslangic.AddDays(7 * (n / secili));
        for (var kalan = n % secili; ; gun = gun.AddDays(1))
        {
            if (!gunler.HasFlag(HaftaGunu(gun)))
                continue;
            if (kalan-- == 0)
                return gun;
        }
    }

    // The first firing moment strictly after `sonra`. A one-off (Yok) has only its own moment, even when it is past.
    public static DateTimeOffset Sonraki(Tekrar tekrar, DateOnly baslangic, TimeOnly saat, DateTimeOffset sonra, Gunler gunler = Gunler.Yok)
    {
        if (tekrar == Tekrar.Yok)
            return An(baslangic, saat);

        if (CokGunlu(tekrar, gunler))
        {
            // From the later of the start day and today, at most a week ahead holds the answer.
            var gun = DateOnly.FromDayNumber(Math.Max(baslangic.DayNumber, IstanbulGunu(sonra).DayNumber));
            for (var i = 0; i < 8; i++, gun = gun.AddDays(1))
            {
                if (gunler.HasFlag(HaftaGunu(gun)) && An(gun, saat) > sonra)
                    return An(gun, saat);
            }
        }

        // Start a little below the answer (never above it), then step forward.
        var gunFark = IstanbulGunu(sonra).DayNumber - baslangic.DayNumber;
        var tahmin = tekrar switch
        {
            Tekrar.Gunluk => gunFark,
            Tekrar.Haftalik => gunFark / 7,
            Tekrar.Aylik => gunFark / 31,
            _ => gunFark / 366,
        };

        var n = Math.Max(0, tahmin - 1);
        while (An(Olusum(tekrar, baslangic, n), saat) <= sonra)
            n++;

        return An(Olusum(tekrar, baslangic, n), saat);
    }

    // The heads-up moment: `onceGun` days before the firing day, at the same hour. Null when there is none.
    public static DateTimeOffset? OnceAni(DateTimeOffset asilAn, int onceGun) =>
        onceGun <= 0 ? null : An(IstanbulGunu(asilAn).AddDays(-onceGun), IstanbulSaati(asilAn));

    // Days from today (Istanbul) to the moment's day; negative when it is past.
    public static int KalanGun(DateTimeOffset an, DateTimeOffset simdi) =>
        IstanbulGunu(an).DayNumber - IstanbulGunu(simdi).DayNumber;

    // Snooze target: "1s" is one hour from now, "yarin" is tomorrow at the reminder's hour. Null for any other value.
    public static DateTimeOffset? ErteleAni(string? sure, DateTimeOffset simdi, TimeOnly saat) => sure switch
    {
        "1s" => simdi.AddHours(1),
        "yarin" => An(IstanbulGunu(simdi).AddDays(1), saat),
        _ => null,
    };
}
