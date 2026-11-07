using System.Globalization;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Brifing;

// The "Brifing" settings: at what hour (Istanbul) the day's briefing is made, and how often the server looks whether it is time.
public class BrifingAyari
{
    public static readonly TimeOnly VarsayilanSaat = new(6, 30);

    // Used when the setting is unusable.
    public static readonly TimeOnly YedekSaat = new(6, 0);

    public TimeOnly Saat { get; init; } = VarsayilanSaat;

    public TimeSpan KontrolAraligi { get; init; } = TimeSpan.FromMinutes(5);

    // Set when the setting was unusable and the backup hour is in use: logged once at start-up.
    public string? Uyari { get; init; }

    private static readonly string[] SaatBicimleri = ["H:mm", "H:mm:ss"];

    // A missing value is the default hour. A value that is not an hour, or an hour before the day turns (05:00), is not
    // trusted: before 05:00 the day is still yesterday's, so a briefing "of today" made then would be yesterday's.
    public static BrifingAyari Oku(IConfiguration config)
    {
        var bolum = config.GetSection("Brifing");
        var kontrol = TimeSpan.FromMinutes(Math.Max(0.05, bolum.GetValue("KontrolDakika", 5.0)));
        var ham = bolum["Saat"];
        if (string.IsNullOrWhiteSpace(ham))
            return new BrifingAyari { KontrolAraligi = kontrol };

        if (!TimeOnly.TryParseExact(ham.Trim(), SaatBicimleri, CultureInfo.InvariantCulture, DateTimeStyles.None, out var saat))
            return new BrifingAyari { Saat = YedekSaat, KontrolAraligi = kontrol, Uyari = $"Brifing:Saat '{ham}' bir saat değil; {YedekSaat:HH:mm} kullanılıyor." };
        if (saat.Hour < GunSiniri.DonusSaati)
            return new BrifingAyari { Saat = YedekSaat, KontrolAraligi = kontrol, Uyari = $"Brifing:Saat {saat:HH:mm}, günün dönüş saatinden (0{GunSiniri.DonusSaati}:00) önce; {YedekSaat:HH:mm} kullanılıyor." };

        return new BrifingAyari { Saat = saat, KontrolAraligi = kontrol };
    }
}
