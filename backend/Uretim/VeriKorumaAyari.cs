namespace Kafamdakiler.Uretim;

// The "VeriKoruma" settings. Klasor is where the Data Protection keys (login cookies, antiforgery tokens) are kept.
// Empty: the framework default stays (keys live in the user profile, or in memory inside a container,
// so they are lost on restart). On a server give a folder on a volume so the keys survive restarts.
public class VeriKorumaAyari
{
    public string Klasor { get; init; } = "";

    public bool Acik => !string.IsNullOrWhiteSpace(Klasor);

    // A relative folder is resolved against the app folder, like Dosyalar:Klasor.
    public static VeriKorumaAyari Oku(IConfiguration config, string icerikKoku)
    {
        var klasor = config["VeriKoruma:Klasor"];
        return new VeriKorumaAyari
        {
            Klasor = string.IsNullOrWhiteSpace(klasor) ? "" : Path.GetFullPath(klasor, icerikKoku),
        };
    }

    public DirectoryInfo KlasoruHazirla()
    {
        // Created here so a bad path fails at startup, not on the first sign-in.
        return Directory.CreateDirectory(Klasor);
    }
}
