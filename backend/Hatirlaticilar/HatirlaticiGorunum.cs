using System.Globalization;

namespace Kafamdakiler.Hatirlaticilar;

// Text for the web pages (Turkish display). Pure functions, so they are unit tested.
public static class HatirlaticiGorunum
{
    private static readonly CultureInfo Tr = new("tr-TR");

    // Turkish possessive-locative suffix of a day number: "31'inde", "2'sinde", "3'ünde" (by how the number is read).
    private static readonly string[] AyGunuEki =
    [
        "", "'inde", "'sinde", "'ünde", "'ünde", "'inde", "'sında", "'sinde", "'inde", "'unda", "'unda",
        "'inde", "'sinde", "'ünde", "'ünde", "'inde", "'sında", "'sinde", "'inde", "'unda", "'sinde",
        "'inde", "'sinde", "'ünde", "'ünde", "'inde", "'sında", "'sinde", "'inde", "'unda", "'unda", "'inde",
    ];

    public static string TurAdi(HatirlaticiTuru tur) => tur switch
    {
        HatirlaticiTuru.Gorev => "Görev",
        HatirlaticiTuru.Soz => "Söz",
        HatirlaticiTuru.OzelTarih => "Özel tarih",
        _ => "",
    };

    // Hue class of the type badge.
    public static string TurRengi(HatirlaticiTuru tur) => tur switch
    {
        HatirlaticiTuru.Gorev => "kd-c-blue",
        HatirlaticiTuru.Soz => "kd-c-pink",
        _ => "kd-c-teal",
    };

    public static string DurumAdi(HatirlaticiDurumu durum) => durum switch
    {
        HatirlaticiDurumu.Acik => "Açık",
        HatirlaticiDurumu.Tamam => "Tamam",
        HatirlaticiDurumu.Arsiv => "Arşiv",
        _ => "",
    };

    public static string TekrarAdi(Tekrar tekrar) => tekrar switch
    {
        Tekrar.Yok => "Tekrarlanmaz",
        Tekrar.Gunluk => "Her gün",
        Tekrar.Haftalik => "Her hafta",
        Tekrar.Aylik => "Her ay",
        Tekrar.Yillik => "Her yıl",
        _ => "",
    };

    // "bugün", "yarın", "3 gün sonra", "2 gün gecikti".
    public static string KalanGunMetni(int kalanGun) => kalanGun switch
    {
        0 => "bugün",
        1 => "yarın",
        > 1 => $"{kalanGun} gün sonra",
        _ => $"{-kalanGun} gün gecikti",
    };

    // "her gün", "her hafta Pazartesi", "her ayın 31'inde", "her yıl 29 Şubat"; null for a one-off.
    public static string? TekrarOzeti(Tekrar tekrar, DateOnly gun) => tekrar switch
    {
        Tekrar.Gunluk => "her gün",
        Tekrar.Haftalik => "her hafta " + gun.ToString("dddd", Tr),
        Tekrar.Aylik => $"her ay {gun.Day}{AyGunuEki[gun.Day]}",
        Tekrar.Yillik => "her yıl " + gun.ToString("d MMMM", Tr),
        _ => null,
    };

    // "3 gün önce de haber verilir"; null when there is no heads-up.
    public static string? OnceNotu(int onceGun) => onceGun switch
    {
        <= 0 => null,
        1 => "1 gün önce de haber verilir",
        _ => $"{onceGun} gün önce de haber verilir",
    };
}
