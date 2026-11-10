namespace Kafamdakiler.Asistan;

public enum AsistanMesajTuru { Kullanici, Sonuc, Soru }

// One line of the assistant's conversation (K-0024, §7). A person's input is one `Kullanici` row, which also claims its client id
// (`GirdiId`): the same id again never runs twice. What the assistant did is a `Sonuc` row (the results as JSON), a question it asked a
// `Soru` row (the question as JSON, `CevaplandiAni` once answered). Everything one input led to shares its `GirdiId`; the rows of the
// answer to a question have `Kaynak = "cevap"`, so the first round and the second are told apart.
public class AsistanMesaji
{
    public const string CevapKaynagi = "cevap";

    public Guid Id { get; set; } = Guid.CreateVersion7();

    public Guid KullaniciId { get; set; }

    public DateTimeOffset Zaman { get; set; }

    public AsistanMesajTuru Tur { get; set; }

    // The person's words (Kullanici), the question (Soru). Null for a Sonuc row.
    public string? Metin { get; set; }

    // The photo of the input. Not a foreign key: the photo goes with the capture when the person takes the note back.
    public Guid? FotografId { get; set; }

    // yazi, ses, paylas or widget (where the input came from); "cevap" on the rows of an answer.
    public string Kaynak { get; set; } = "";

    public Guid GirdiId { get; set; }

    // jsonb: the list of AsistanSonucuDto (Sonuc).
    public string? SonuclarJson { get; set; }

    // jsonb: the question (Soru).
    public string? SoruJson { get; set; }

    public DateTimeOffset? CevaplandiAni { get; set; }
}
