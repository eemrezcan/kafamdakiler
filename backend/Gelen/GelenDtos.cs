using Kafamdakiler.Eylemler;

namespace Kafamdakiler.Gelen;

// One inbox card as the screens get it. `Ozet` is the card's own title (its first line); the full text is not sent.
// `Yakalandi` is the brain's local time ("2026-11-03T18:40"), as written in the card.
public record GelenKartDto(
    string Kimlik, string Ozet, bool GorselVar, string? Hedef, string? Yakalandi,
    bool LaptoptaIslenecek, string? LaptopNotu, GelenOneriDto? Oneri);

// The suggestion waiting in the approval queue for a card (an Eylem of kind "yerlestir").
public record GelenOneriDto(Guid EylemId, string Yol, string Baslik, List<string> Etiketler, string? Gerekce, double? Guven, bool DisKaynak);

// A placement a person makes by hand. The same checks as for a suggestion.
public record GelenIsleGirdi(string? Yol, string? Baslik, List<string>? Etiketler, string? Tur = null);

// A main tag of the dictionary and its synonyms (the brain accepts either).
public record GelenEtiketDto(string Ad, List<string> Esler);

// A place a card may be put by hand: `Tur` is "proje" (projects/<proje>/notlar/) or "kok" (ogrenme/, spor/, aliskanliklar/).
// `Yol` is the folder; the person adds a file name to it.
public record GelenKlasorDto(string Yol, string Ad, string Tur, string? Proje);

public record GelenIslendiDto(string Yol, string Kart);

public record GelenSilindiDto(string Kart);

// The answer of "suggest again": "olustu" (in the queue, `Eylem` is set), "laptoptaIslenecek" or "atlandi".
public record GelenOneriYaniti(string Durum, string? Mesaj, EylemDto? Eylem);
