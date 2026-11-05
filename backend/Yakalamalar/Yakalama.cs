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

    public Dosyalar.Dosya? Fotograf { get; set; }
}
