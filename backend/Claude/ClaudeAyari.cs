namespace Kafamdakiler.Claude;

// The "Claude" settings. With Komut empty the layer is off and the rest of the app works.
public class ClaudeAyari
{
    // The claude executable: a full path, or a bare name found on PATH. Empty means "Claude bağlı değil".
    public string Komut { get; init; } = "";

    // Passed as --model: an alias (sonnet, opus) or a full model name.
    public string Model { get; init; } = "sonnet";

    public TimeSpan ZamanAsimi { get; init; } = TimeSpan.FromSeconds(120);

    // How many claude processes may run at once.
    public int EsZamanliEnCok { get; init; } = 1;

    // A cap on the calls started per day (Europe/Istanbul), so a loop or a flood cannot drain the subscription.
    public int GunlukEnCokCagri { get; init; } = 50;

    public bool Acik => !string.IsNullOrWhiteSpace(Komut);

    // A relative path with a directory part is resolved against the app folder, like Beyin:Komut.
    // A bare name ("claude") is left alone: the operating system looks it up on PATH.
    public static ClaudeAyari Oku(IConfiguration config, string icerikKoku)
    {
        var bolum = config.GetSection("Claude");
        var komut = bolum["Komut"];
        if (!string.IsNullOrWhiteSpace(komut) && komut.IndexOfAny(['/', '\\']) >= 0)
            komut = Path.GetFullPath(komut, icerikKoku);

        return new ClaudeAyari
        {
            Komut = string.IsNullOrWhiteSpace(komut) ? "" : komut,
            Model = bolum["Model"] is { Length: > 0 } model ? model : "sonnet",
            ZamanAsimi = TimeSpan.FromSeconds(bolum.GetValue("ZamanAsimiSaniye", 120.0)),
            EsZamanliEnCok = Math.Max(1, bolum.GetValue("EsZamanliEnCok", 1)),
            GunlukEnCokCagri = Math.Max(0, bolum.GetValue("GunlukEnCokCagri", 50)),
        };
    }
}
