namespace Kafamdakiler.Mobil;

// The "Mobil" settings. EnAzSurumKodu is the lowest app build number (the `+N` in mobile/pubspec.yaml) that still works
// with this API; older apps show a blocking "update needed" screen. Raise it only for a breaking API change.
public class MobilAyari
{
    public int EnAzSurumKodu { get; init; } = 1;

    public static MobilAyari Oku(IConfiguration config) =>
        new() { EnAzSurumKodu = config.GetValue("Mobil:EnAzSurumKodu", 1) };
}
