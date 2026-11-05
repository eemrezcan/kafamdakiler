namespace Kafamdakiler.Beyin;

// The "Beyin" settings (K-0023). With Komut or Vault empty the brain features are off and the rest of the app works.
public class BeyinAyari
{
    // Path of beyin.py; run with `Python`.
    public string Komut { get; init; } = "";

    // The vault folder given to every command as --vault. In Kat 1 this is always the copy of ornek-beyin/.
    public string Vault { get; init; } = "";

    // Where the Development startup copies the vault from when Vault does not exist yet.
    public string Sablon { get; init; } = "";

    public string Python { get; init; } = "python3";

    public TimeSpan ZamanAsimi { get; init; } = TimeSpan.FromSeconds(30);

    // A capture stays editable this long after its last edit, then goes to the brain.
    public TimeSpan GonderimGecikmesi { get; init; } = TimeSpan.FromMinutes(10);

    // How often the sender looks for captures that are due.
    public TimeSpan GonderimAraligi { get; init; } = TimeSpan.FromSeconds(30);

    public bool Acik => !string.IsNullOrWhiteSpace(Komut) && !string.IsNullOrWhiteSpace(Vault);

    // Relative paths are resolved against the app folder, like Dosyalar:Klasor.
    public static BeyinAyari Oku(IConfiguration config, string icerikKoku)
    {
        var bolum = config.GetSection("Beyin");
        string Yol(string anahtar) =>
            string.IsNullOrWhiteSpace(bolum[anahtar]) ? "" : Path.GetFullPath(bolum[anahtar]!, icerikKoku);

        return new BeyinAyari
        {
            Komut = Yol("Komut"),
            Vault = Yol("Vault"),
            Sablon = Yol("Sablon"),
            Python = bolum["Python"] is { Length: > 0 } python ? python : "python3",
            ZamanAsimi = TimeSpan.FromSeconds(bolum.GetValue("ZamanAsimiSaniye", 30.0)),
            GonderimGecikmesi = TimeSpan.FromMinutes(bolum.GetValue("GonderimGecikmesiDakika", 10.0)),
            GonderimAraligi = TimeSpan.FromSeconds(bolum.GetValue("GonderimAraligiSaniye", 30.0)),
        };
    }
}
