namespace Kafamdakiler.Isler;

// Display texts for work cards, the same words the mobile screens use. Pure functions.
public static class IsGorunum
{
    public static string Asama(string asama) => asama switch
    {
        "talep" => "Talep",
        "plan" => "Plan",
        "karar" => "Karar",
        "kod-onayi" => "Kod onayı",
        "yapim" => "Yapım",
        "push-onayi" => "Push onayı",
        "deploy-onayi" => "Deploy onayı",
        "bitti" => "Bitti",
        "iptal" => "İptal",
        var diger => diger,
    };

    // Who the card waits on.
    public static string Sahip(string sahip) => sahip switch
    {
        "kullanici" => "Sende",
        "vps" => "VPS'te",
        "laptop" => "Laptop'ta",
        var diger => diger,
    };

    // The project or the area the card lives in.
    public static string Yer(string? proje, string? alan) => proje ?? alan ?? "";

    public static string Yer(IsKartiDto k) => Yer(k.Proje, k.Alan);
}
