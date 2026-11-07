using System.Globalization;

namespace Kafamdakiler.Beyin;

// Display texts for the Beyin pages, the same words the mobile screens use. Pure functions, so they are unit tested.
public static class BeyinGorunum
{
    private static readonly CultureInfo Tr = new("tr-TR");

    // "45 dk", "2 sa", "1 sa 30 dk".
    public static string Dakika(int dakika)
    {
        if (dakika < 60)
            return $"{dakika} dk";

        var saat = dakika / 60;
        var kalan = dakika % 60;
        return kalan == 0 ? $"{saat} sa" : $"{saat} sa {kalan} dk";
    }

    // "10 Kas" for a due date.
    public static string KisaTarih(DateOnly tarih) => tarih.ToString("d MMM", Tr);

    // "3 Kasım 2026 Salı"
    public static string GunBasligi(DateOnly tarih) => tarih.ToString("d MMMM yyyy dddd", Tr);

    // What the brain writes for a task's state, in words (anything unknown is shown as it is).
    public static string GorevDurumu(string? durum) => durum switch
    {
        "aktif" => "Aktif",
        "bekliyor" => "Bekliyor",
        "bitti" => "Bitti",
        null => "",
        var d => d,
    };

    public static string Oncelik(string? oncelik) => oncelik switch
    {
        "yuksek" => "Yüksek öncelik",
        "orta" => "Orta öncelik",
        "dusuk" => "Düşük öncelik",
        null => "",
        var o => o,
    };

    // The brain writes "yapildi" for a done plan line; anything else counts as open.
    public static bool Yapildi(string? durum) => durum == "yapildi";

    // "kitap-kulubu · projects" under a search hit: the project, else the area.
    public static string Konum(string? proje, string? alan) =>
        string.Join(" · ", new[] { proje, proje is null ? alan : null }.Where(s => !string.IsNullOrEmpty(s)));
}
