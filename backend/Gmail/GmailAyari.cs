namespace Kafamdakiler.Gmail;

// The "Gmail" settings. The module is off until `Acik` is set: mail text goes to Claude, so it is the person's explicit choice,
// and it also needs the Google connection (with the gmail.readonly scope) and Claude. Anything missing leaves the scan idle.
public class GmailAyari
{
    private const int EngelliGonderenEnCok = 200;
    private const int GonderenEnUzun = 200;

    public bool Acik { get; init; }

    // How often the background scan runs.
    public TimeSpan Aralik { get; init; } = TimeSpan.FromMinutes(10);

    // How far back the scan looks (`newer_than:Nd`). Mail older than this is never read, not even on the first run.
    public int IlkBakisGunu { get; init; } = 3;

    // The most characters of a mail's body that go to Claude.
    public int EnUzunGovde { get; init; } = 4000;

    // Mail from these is never read by Claude: a full address ("kisi@ornek.com") or a whole domain ("ornek.com" or "@ornek.com").
    public IReadOnlyList<string> EngellenenGonderenler { get; init; } = [];

    public static GmailAyari Oku(IConfiguration config)
    {
        var bolum = config.GetSection("Gmail");
        return new GmailAyari
        {
            Acik = bolum.GetValue("Acik", false),
            Aralik = TimeSpan.FromMinutes(Math.Max(0.05, bolum.GetValue("AralikDakika", 10.0))),
            IlkBakisGunu = Math.Clamp(bolum.GetValue("IlkBakisGunu", 3), 1, 30),
            EnUzunGovde = Math.Clamp(bolum.GetValue("EnUzunGovde", 4000), 200, 20000),
            EngellenenGonderenler = GonderenleriOku(bolum),
        };
    }

    // True when the sender's address is on the blocked list.
    public bool Engelli(string? adres)
    {
        if (string.IsNullOrWhiteSpace(adres))
            return false;

        var gonderen = adres.Trim().ToLowerInvariant();
        var alanAdi = gonderen[(gonderen.LastIndexOf('@') + 1)..];
        return EngellenenGonderenler.Any(e => e.Contains('@') && !e.StartsWith('@') ? e == gonderen : e.TrimStart('@') == alanAdi);
    }

    // `Gmail:EngellenenGonderenler` as an array (appsettings) or as one comma-separated text (an environment variable).
    private static IReadOnlyList<string> GonderenleriOku(IConfigurationSection bolum)
    {
        var ham = bolum.GetSection("EngellenenGonderenler").Get<string[]>() ?? [];
        if (ham.Length == 0 && bolum["EngellenenGonderenler"] is { Length: > 0 } tek)
            ham = tek.Split(',');

        return ham.Select(g => g.Trim().ToLowerInvariant())
            .Where(g => g.Length is > 0 and <= GonderenEnUzun && !g.Any(c => char.IsControl(c) || char.IsWhiteSpace(c)))
            .Distinct(StringComparer.Ordinal).Take(EngelliGonderenEnCok).ToList();
    }
}
