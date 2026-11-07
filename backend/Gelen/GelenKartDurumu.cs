namespace Kafamdakiler.Gelen;

// What the server remembers about one inbox card. The card itself lives in the brain; this row only keeps the "marked for
// the laptop" flag and the count of tries, so a card is not sent to Claude again and again. A card without a row is new.
public class GelenKartDurumu
{
    // The card's name in the brain without ".md" (e.g. "2026-11-03-1840-kitap-onerisi").
    public string Kart { get; set; } = "";

    // Claude found no fitting tag: a new tag is first added to the dictionary on the laptop (K-0023), then the card is placed.
    public bool LaptoptaIslenecek { get; set; }

    // Why, in Claude's words (shown under the card).
    public string? LaptopNotu { get; set; }

    // Failed tries in a row; reset when a suggestion is made.
    public int DenemeSayisi { get; set; }

    public DateTimeOffset? SonDenemeAt { get; set; }

    public string? SonHata { get; set; }

    // When a suggestion was made (queued or marked for the laptop). A card with this set is not suggested again by itself.
    public DateTimeOffset? OneriAni { get; set; }
}
