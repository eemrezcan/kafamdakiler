using System.Text.Json;

namespace Kafamdakiler.Eylemler;

// Display texts of the approval queue pages, in one place.
public static class EylemGorunum
{
    // Below this a suggestion is marked "not sure".
    public const double GuvenEsigi = 0.7;

    public static string KipAdi(EylemKipi kip) => kip switch
    {
        EylemKipi.Sor => "Sor",
        EylemKipi.KendinYap => "Kendin yap",
        _ => "Yasak",
    };

    public static string KipAciklamasi(EylemKipi kip) => kip switch
    {
        EylemKipi.Sor => "Önce onayını bekler.",
        EylemKipi.KendinYap => "Hemen uygular, geri alınabilir. Dış kaynaklı öneriler yine onay bekler.",
        _ => "Bu türde öneri hiç kaydedilmez.",
    };

    public static string DurumAdi(EylemDurumu durum) => durum switch
    {
        EylemDurumu.Bekliyor => "Bekliyor",
        EylemDurumu.Uygulandi => "Uygulandı",
        EylemDurumu.Reddedildi => "Reddedildi",
        EylemDurumu.GeriAlindi => "Geri alındı",
        _ => "Hatalı",
    };

    public static string KaynakAdi(string kaynak) => kaynak switch
    {
        "kullanici" => "Sen",
        "ses" => "Ses",
        "gelen" => "Gelen kutusu",
        "brifing" => "Brifing",
        "mail" => "Mail",
        _ => kaynak,
    };

    public static bool EminDegil(Eylem e) => e.Guven is { } g && g < GuvenEsigi;

    public static string GuvenMetni(double guven) => $"%{Math.Round(guven * 100):0}";

    // The payload as a person edits it: indented JSON.
    public static string YukMetni(string yuk)
    {
        using var belge = JsonDocument.Parse(yuk);
        return JsonSerializer.Serialize(belge.RootElement, new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
    }
}
