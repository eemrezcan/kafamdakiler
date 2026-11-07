using System.Globalization;

namespace Kafamdakiler.Beyin;

// The brain's day turns at 05:00, not at midnight (gun.py GUN_DONUS_SAATI): working at 02:00 is still the same day's plan.
// The app counts "today" the same way, in one place, and every write to the plan carries the date explicitly, so the
// server, the phone and the brain cannot disagree about which day a tick belongs to.
public static class GunSiniri
{
    public const int DonusSaati = 5;

    private static readonly TimeZoneInfo Istanbul = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");

    public static DateOnly Bugun(DateTimeOffset an) =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(an, Istanbul).DateTime.AddHours(-DonusSaati));

    public static DateOnly Dun(DateTimeOffset an) => Bugun(an).AddDays(-1);
}

// The "Gun" settings: how much planned work fits in a day.
public class GunAyari
{
    public const double VarsayilanKapasiteSaat = 6;

    public double KapasiteSaat { get; init; } = VarsayilanKapasiteSaat;

    public int KapasiteDk => (int)Math.Round(KapasiteSaat * 60);

    // A missing, zero, negative or absurd value falls back to the default: a typo in the settings must not turn the warning off.
    public static GunAyari Oku(IConfiguration config)
    {
        var saat = double.TryParse(config["Gun:KapasiteSaat"], NumberStyles.Float, CultureInfo.InvariantCulture, out var okunan) ? okunan : 0;
        return new GunAyari { KapasiteSaat = saat is > 0 and <= 24 ? saat : VarsayilanKapasiteSaat };
    }
}
