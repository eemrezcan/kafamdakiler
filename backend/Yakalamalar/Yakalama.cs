namespace Kafamdakiler.Yakalamalar;

// Bekliyor -> BeyneGitti -> Islendi. Stored as text; only Bekliyor is produced for now.
public enum YakalamaDurumu { Bekliyor, BeyneGitti, Islendi }

// A quick capture: a thought or a photo that the brain sorts out later.
public class Yakalama
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public string? Metin { get; set; }
    public Guid? FotografId { get; set; }
    // Optional hint for the brain, e.g. "projects/kitap-kulubu".
    public string? Hedef { get; set; }
    public YakalamaDurumu Durum { get; set; } = YakalamaDurumu.Bekliyor;
    // The client's clock (when the thought came), not the server's.
    public DateTimeOffset YakalandiAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    // Last edit by the user; the sender waits the configured delay after it (K-0023, Kat 1 karar 1).
    public DateTimeOffset GuncellendiAt { get; set; } = DateTimeOffset.UtcNow;

    // Sending to the brain (YakalamaGonderimi).
    // Set when a sender takes the capture; cleared only after a failure that is known to have written nothing.
    // A capture that stays claimed after a crash or a timeout may already be a card, so it is not sent again by itself.
    public DateTimeOffset? GonderimBasladiAt { get; set; }
    public int DenemeSayisi { get; set; }
    public DateTimeOffset? SonDenemeAt { get; set; }
    public string? SonHata { get; set; }

    public Dosyalar.Dosya? Fotograf { get; set; }
}
