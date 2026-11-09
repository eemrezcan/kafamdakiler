namespace Kafamdakiler.Bildirimler;

// The "Firebase" settings. AnahtarDosyasi is the path of the service account key (a secret, K-0012; it is mounted, never in the
// repository). Empty, or no such file (compose always sets the path, the file may not be there yet): push is off, the rest of
// the app works and Yönetim says "kapalı". Only the existence of the file is checked here, never its content.
public class PushAyari
{
    public string AnahtarDosyasi { get; init; } = "";

    public bool Acik => !string.IsNullOrWhiteSpace(AnahtarDosyasi) && File.Exists(AnahtarDosyasi);

    public static PushAyari Oku(IConfiguration config) =>
        new() { AnahtarDosyasi = config["Firebase:AnahtarDosyasi"]?.Trim() ?? "" };
}
