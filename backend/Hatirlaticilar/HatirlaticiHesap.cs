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

    // The first firing moment strictly after `sonra`. A one-off (Yok) has only its own moment, even when it is past.
    public static DateTimeOffset Sonraki(Tekrar tekrar, DateOnly baslangic, TimeOnly saat, DateTimeOffset sonra)
    {
        if (tekrar == Tekrar.Yok)
            return An(baslangic, saat);

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
