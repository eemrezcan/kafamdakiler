namespace Kafamdakiler.Takvim;

public static class TakvimPolicies
{
    // The `izin` claim values double as policy names (K-0009): reading the timeline, and writing to the calendar through the approval queue.
    public const string Oku = "takvim.oku";
    public const string Yaz = "takvim.yaz";
}

// The "Google" settings (K2.3c). The module is off until the client id, the client secret and the return address are all set:
// then there is no connect button that works, no sync, and the calendar action kinds refuse their payloads ("Google bağlı değil").
public class TakvimAyari
{
    // Google's own name for the account's main calendar.
    public const string BirincilTakvim = "primary";

    // The sync window: the last 7 days and the next 60.
    public const int GecmisGun = 7;
    public const int GelecekGun = 60;

    // The narrowest scopes that do the calendar's job: events (read and write) and the calendar list (read). A connection
    // made without them is refused.
    public static readonly IReadOnlyList<string> TakvimKapsamlari =
    [
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/calendar.readonly",
    ];

    // Gmail, read only. A reply draft would need gmail.compose, which is asked for when that feature is written. A connection
    // made without this scope (or before it was asked for) still works for the calendar and leaves Gmail in "izinYok".
    public const string GmailKapsami = "https://www.googleapis.com/auth/gmail.readonly";

    // Everything the consent screen asks for.
    public static readonly IReadOnlyList<string> Kapsamlar = [.. TakvimKapsamlari, GmailKapsami];

    private const int EnCokTakvim = 10;
    private const int TakvimKimligiEnUzun = 200;

    public string ClientId { get; init; } = "";

    public string ClientSecret { get; init; } = "";

    // Where Google sends the person back: a full address ending in /google/donus. Never taken from the request, whose host a client can choose.
    public string DonusAdresi { get; init; } = "";

    // The calendars that are synced and that actions may write to.
    public IReadOnlyList<string> Takvimler { get; init; } = [BirincilTakvim];

    public TimeSpan EsitlemeAraligi { get; init; } = TimeSpan.FromMinutes(5);

    // Set when a setting was half there or unusable: logged once at start-up.
    public string? Uyari { get; init; }

    public bool Acik => ClientId.Length > 0 && ClientSecret.Length > 0 && DonusAdresi.Length > 0;

    public string VarsayilanTakvim => Takvimler[0];

    public static TakvimAyari Oku(IConfiguration config)
    {
        var bolum = config.GetSection("Google");
        var clientId = bolum["ClientId"]?.Trim() ?? "";
        var clientSecret = bolum["ClientSecret"]?.Trim() ?? "";
        var donus = bolum["DonusAdresi"]?.Trim() ?? "";
        var aralik = TimeSpan.FromMinutes(Math.Max(0.05, bolum.GetValue("EsitlemeDakika", 5.0)));
        var takvimler = TakvimlerOku(bolum);

        string? uyari = null;
        if (donus.Length > 0 && !(Uri.TryCreate(donus, UriKind.Absolute, out var adres) && adres.Scheme is "http" or "https"))
        {
            uyari = "Google:DonusAdresi tam bir adres (https://...) değil; Google Takvim kapalı.";
            donus = "";
        }
        else if ((clientId.Length > 0 || clientSecret.Length > 0 || donus.Length > 0) && (clientId.Length == 0 || clientSecret.Length == 0 || donus.Length == 0))
        {
            uyari = "Google:ClientId, Google:ClientSecret ve Google:DonusAdresi birlikte verilmeli; Google Takvim kapalı.";
        }

        return new TakvimAyari
        {
            ClientId = clientId,
            ClientSecret = clientSecret,
            DonusAdresi = donus,
            Takvimler = takvimler,
            EsitlemeAraligi = aralik,
            Uyari = uyari,
        };
    }

    // `Google:Takvimler` as an array (appsettings) or as one comma-separated text (an environment variable). A missing or empty
    // value is the main calendar; a calendar id with a control character or an absurd length is dropped.
    private static IReadOnlyList<string> TakvimlerOku(IConfigurationSection bolum)
    {
        var ham = bolum.GetSection("Takvimler").Get<string[]>() ?? [];
        if (ham.Length == 0 && bolum["Takvimler"] is { Length: > 0 } tek)
            ham = tek.Split(',');

        var liste = ham.Select(t => t.Trim())
            .Where(t => t.Length is > 0 and <= TakvimKimligiEnUzun && !t.Any(char.IsControl))
            .Distinct(StringComparer.Ordinal).Take(EnCokTakvim).ToList();
        return liste.Count > 0 ? liste : [BirincilTakvim];
    }
}
