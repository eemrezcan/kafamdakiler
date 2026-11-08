using System.Globalization;

namespace Kafamdakiler.Beyin;

// Display texts for the Beyin pages, the same words the mobile screens use. Pure functions, so they are unit tested.
public static partial class BeyinGorunum
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

    // A time the brain writes as text ("2026-11-03 09:15", "2026-11-03T09:15", "2026-11-03") in words: "3 Kas 09:15", with
    // the year only when it is not this year (Istanbul's). Anything it cannot read is shown as it is.
    public static string Zaman(string ham, DateOnly? bugun = null)
    {
        var eslesme = ZamanKalibi().Match(ham.Trim());
        if (!eslesme.Success || !DateOnly.TryParseExact(eslesme.Groups[1].Value, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun))
            return ham;

        var buYil = (bugun ?? DateOnly.FromDateTime(DateTime.UtcNow)).Year;
        var metin = gun.ToString(gun.Year == buYil ? "d MMM" : "d MMM yyyy", Tr);
        return eslesme.Groups[2].Success ? $"{metin} {eslesme.Groups[2].Value}" : metin;
    }

    [System.Text.RegularExpressions.GeneratedRegex(@"^(\d{4}-\d{2}-\d{2})(?:[ T](\d{2}:\d{2}))?")]
    private static partial System.Text.RegularExpressions.Regex ZamanKalibi();

    // What the brain writes for a task's state, in words (anything unknown starts with a capital).
    public static string GorevDurumu(string? durum) => durum switch
    {
        "aktif" => "Aktif",
        "bekliyor" => "Bekliyor",
        "engelli" => "Engelli",
        "bitti" => "Bitti",
        null or "" => "",
        var d => char.ToUpper(d[0], Tr) + d[1..],
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
