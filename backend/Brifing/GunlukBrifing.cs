namespace Kafamdakiler.Brifing;

// How a day's briefing was made. Stored as text; the API shows "claude" or "hesap".
public enum BrifingYontemi
{
    // Claude picked and worded the cards; the server checked every one.
    Claude,
    // Fixed rules made the cards (Claude is off, its daily cap is reached, it failed or its answer was no good).
    Hesap,
}

// One day's briefing (K2.7). The day is the app's day (05:00 turn, GunSiniri), so there is at most one row per day.
public class GunlukBrifing
{
    // The brain's day, not the calendar date: at 02:00 the day is still yesterday's.
    public DateOnly Gun { get; set; }

    // The cards as a JSON array (jsonb), in the order they are shown.
    public string Kartlar { get; set; } = "[]";

    public DateTimeOffset UretimAni { get; set; }

    public BrifingYontemi Yontem { get; set; }

    // How many times the Sahip asked for a new one today; the limit is BrifingHazirlayici.GundeEnCokYenileme.
    public int YenilemeSayisi { get; set; }
}

// A thumb on one card. Kept apart from the cards so a vote is a single small write; the card kind is copied in, so the
// last days' votes can be summed per kind without opening every briefing.
public class BrifingOyu
{
    public DateOnly Gun { get; set; }

    // The card's position in the briefing, from 0.
    public int Sira { get; set; }

    public string Tur { get; set; } = "";

    // 1 for a thumb up, -1 for a thumb down. Taking the vote back deletes the row.
    public int Oy { get; set; }

    public DateTimeOffset Zaman { get; set; }
}
