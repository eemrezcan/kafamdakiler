using System.Globalization;

namespace Kafamdakiler.Yakalamalar;

// Text for the web pages (Turkish display).
public static class YakalamaGorunum
{
    private static readonly CultureInfo Tr = new("tr-TR");
    private static readonly TimeZoneInfo Istanbul = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");

    public static string DurumAdi(YakalamaDurumu durum) => durum switch
    {
        YakalamaDurumu.Bekliyor => "Bekliyor",
        YakalamaDurumu.BeyneGitti => "Beyne gitti",
        YakalamaDurumu.Islendi => "İşlendi",
        _ => "",
    };

    // Stored as UTC (K-0014), shown in Istanbul time.
    public static string Zaman(DateTimeOffset an) =>
        TimeZoneInfo.ConvertTime(an, Istanbul).ToString("d MMM yyyy HH:mm", Tr);

    public static string Saat(DateTimeOffset an) => TimeZoneInfo.ConvertTime(an, Istanbul).ToString("HH:mm", Tr);

    // The Istanbul calendar day of a moment; the list is grouped by it.
    public static DateOnly Gun(DateTimeOffset an) => DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(an, Istanbul).DateTime);

    public static DateOnly Bugun() => Gun(DateTimeOffset.UtcNow);

    // "Bugün", "Dün", "3 Kasım Pazartesi"; the year is added only when it is not this year.
    public static string GunBasligi(DateOnly gun, DateOnly bugun)
    {
        if (gun == bugun)
            return "Bugün";
        if (gun == bugun.AddDays(-1))
            return "Dün";
        return gun.ToString(gun.Year == bugun.Year ? "d MMMM dddd" : "d MMMM yyyy dddd", Tr);
    }

    // "projects/kitap-kulubu" is shown as "kitap-kulubu".
    public static string HedefAdi(string hedef) =>
        hedef.StartsWith("projects/", StringComparison.Ordinal) ? hedef["projects/".Length..] : hedef;
}
