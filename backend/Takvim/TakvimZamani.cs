using System.Globalization;
using Kafamdakiler.Beyin;
using Kafamdakiler.Hatirlaticilar;

namespace Kafamdakiler.Takvim;

// Days and hours of the calendar are Europe/Istanbul, like everything else in the app. The helpers the calendar parts share.
public static class TakvimZamani
{
    private static readonly TimeZoneInfo Istanbul = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");

    // A moment at the local day and hour, with Istanbul's own offset (the form Google and a person read: 2026-11-09T14:00:00+03:00).
    public static DateTimeOffset YerelAn(DateOnly gun, TimeOnly saat)
    {
        var yerel = gun.ToDateTime(saat);
        return new DateTimeOffset(yerel, Istanbul.GetUtcOffset(yerel));
    }

    public static DateTimeOffset YerelAn(DateTimeOffset an) => TimeZoneInfo.ConvertTime(an, Istanbul);

    public static string SaatMetni(DateTimeOffset an) => $"{HatirlaticiHesap.IstanbulSaati(an):HH:mm}";

    // The brain's day starts at 05:00: the instants [start, end) of the day `gun`.
    public static (DateTimeOffset Bas, DateTimeOffset Son) GunAraligi(DateOnly gun)
    {
        var donus = new TimeOnly(GunSiniri.DonusSaati, 0);
        return (HatirlaticiHesap.An(gun, donus), HatirlaticiHesap.An(gun.AddDays(1), donus));
    }

    // A title or place that came from outside: one line, no control characters, cut to length.
    public static string Duzelt(string? metin, int enUzun)
    {
        if (string.IsNullOrWhiteSpace(metin))
            return "";

        var temiz = new string(metin.Select(c => char.IsControl(c) ? ' ' : c).ToArray());
        var tek = string.Join(' ', temiz.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
        return tek.Length <= enUzun ? tek : tek[..enUzun].TrimEnd();
    }

    // The form actions carry a moment in: ISO 8601 with an explicit offset, so it can mean only one instant.
    private static readonly string[] AnBicimleri =
    [
        "yyyy-MM-dd'T'HH:mm:ssK", "yyyy-MM-dd'T'HH:mmK", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK",
    ];

    // The "K" in the formats also accepts no offset at all (then the server's own zone would decide the instant), so the offset is
    // required by hand: "Z" or "+hh:mm" / "-hh:mm" at the end.
    public static bool AnCoz(string? metin, out DateTimeOffset an)
    {
        an = default;
        var temiz = metin?.Trim();
        if (string.IsNullOrEmpty(temiz) || !(temiz.EndsWith('Z') || (temiz.Length > 6 && temiz[^6] is '+' or '-' && temiz[^3] == ':')))
            return false;

        return DateTimeOffset.TryParseExact(temiz, AnBicimleri, CultureInfo.InvariantCulture, DateTimeStyles.None, out an);
    }

    public static bool GunCoz(string? metin, out DateOnly gun) =>
        DateOnly.TryParseExact(metin?.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out gun);
}
