namespace Kafamdakiler.Dosyalar;

public class Dosya
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public string DiskAdi { get; set; } = "";
    public string IcerikTuru { get; set; } = "";
    public long Boyut { get; set; }
    public DateTimeOffset YuklenmeAni { get; set; } = DateTimeOffset.UtcNow;
}
