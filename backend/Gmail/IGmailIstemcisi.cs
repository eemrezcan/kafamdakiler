namespace Kafamdakiler.Gmail;

// What the app needs from Gmail, and nothing more: two reads. Everything that touches the network sits behind this interface, so the
// tests run the whole scan on a fake and never call Google. The real one is GmailIstemcisi. The access token comes from
// GoogleErisimi; a 401 from Gmail is a GoogleYetkiGecersizException (the Takvim exception: the Sahip has to connect again).

// One mail, as the scan needs it. `Govde` is plain text already (an HTML-only mail is converted by the client). `Etiketler` are
// Gmail's label ids (INBOX, SENT, ...). Attachments are not part of it.
public record GmailPosta(
    string Kimlik, string? Konu, string? GonderenAd, string? GonderenAdres, DateTimeOffset? Tarih, string Govde, IReadOnlyList<string> Etiketler);

public interface IGmailIstemcisi
{
    // The ids of the messages that match a Gmail search query, newest first, at most `enCok`.
    Task<IReadOnlyList<string>> KimlikleriListeleAsync(string sorgu, int enCok, string erisimToken, CancellationToken ct);

    // Null when the message is gone (404).
    Task<GmailPosta?> PostaGetirAsync(string kimlik, string erisimToken, CancellationToken ct);
}
