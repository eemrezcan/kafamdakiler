namespace Kafamdakiler.Gmail;

public enum GmailSonucu
{
    // Claude read the mail. `OneriSayisi` suggestions were queued (0: nothing to do, which is the usual case).
    Islendi,
    // Not sent to Claude: sent by the person, from a blocked sender, or empty.
    Atlandi,
    // Claude failed or its answer broke a rule. The scan tries again until `GmailTarayici.EnCokDeneme`.
    Hata,
}

// A mail the scan has dealt with, so it is read once. Only the Gmail id, the outcome and a short subject are kept: the body and
// the sender never reach the database.
public class GmailMesaji
{
    public Guid Id { get; set; } = Guid.CreateVersion7();

    // Gmail's own message id; unique.
    public string GmailKimligi { get; set; } = "";

    public DateTimeOffset IslenmeAni { get; set; }

    public GmailSonucu Sonuc { get; set; }

    // How many suggestions went to the approval queue.
    public int OneriSayisi { get; set; }

    // Tries so far (more than one only after failures).
    public int Deneme { get; set; }

    // Why it was skipped or failed, in a few fixed words.
    public string? Neden { get; set; }

    // The subject, cut short.
    public string? Konu { get; set; }
}
