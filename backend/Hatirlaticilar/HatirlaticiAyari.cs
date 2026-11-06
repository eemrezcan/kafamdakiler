namespace Kafamdakiler.Hatirlaticilar;

// The "Hatirlatici" settings. VarsayilanSaat is the hour (Istanbul) used when a reminder has no hour of its own.
public class HatirlaticiAyari
{
    public TimeOnly VarsayilanSaat { get; init; } = new(9, 0);

    public static HatirlaticiAyari Oku(IConfiguration config) =>
        TimeOnly.TryParse(config["Hatirlatici:VarsayilanSaat"], System.Globalization.CultureInfo.InvariantCulture, out var saat)
            ? new HatirlaticiAyari { VarsayilanSaat = saat }
            : new HatirlaticiAyari();
}
