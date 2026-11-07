namespace Kafamdakiler.Brifing;

// What the briefing endpoints return and take (K2.7).

// `Sira` counts from 0 and is what the vote endpoint takes. `Oy` is this person's vote on the card: 1, -1, or 0 for none.
// `BagliKimlikler` are ids of plan items, reminders or actions, as the other endpoints know them.
public record BrifingKartDto(int Sira, string Tur, string Baslik, string Metin, List<string> BagliKimlikler, int Oy);

// `Yontem` is "claude" or "hesap" (made by fixed rules). `KalanYenileme` is how many times the Sahip may still ask for a new one today.
public record BrifingDto(DateOnly Gun, DateTimeOffset UretimAni, BrifingYontemi Yontem, List<BrifingKartDto> Kartlar, int KalanYenileme);

// 1 for a thumb up, -1 for a thumb down, 0 to take the vote back.
public record BrifingOyGirdisi(int? Oy);
