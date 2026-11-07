namespace Kafamdakiler.Beyin;

public enum BeyinIslemiDurumu
{
    // Claimed; the write is running (or the server died while it ran).
    Calisiyor,
    // Applied: `Cevap` is the answer to send again.
    Tamam,
    // The brain did not answer in time or answered badly: the write may or may not have happened. Never applied twice by itself.
    Belirsiz,
}

// A write that carried an `Idempotency-Key` (the phone's offline queue may send one request twice). The row is the claim on the
// key: the first request inserts it, a second one finds it and gets the first answer instead of writing again.
// A write the brain refused is not kept (nothing was written, the same key may be tried again).
public class BeyinIslemi
{
    public Guid KullaniciId { get; set; }

    public string Anahtar { get; set; } = "";

    // SHA-256 of the operation and its input: the same key on a different request is a mistake, not a repeat.
    public string Parmakizi { get; set; } = "";

    public BeyinIslemiDurumu Durum { get; set; } = BeyinIslemiDurumu.Calisiyor;

    public int DurumKodu { get; set; }

    public string? Cevap { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
