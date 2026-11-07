using System.Text.Json.Nodes;

namespace Kafamdakiler.Brifing;

// The kinds of card a briefing holds.
public static class BrifingTurleri
{
    // Today's plan: the open items.
    public const string Plan = "plan";

    // What yesterday's plan left open.
    public const string Kalan = "kalan";

    // Reminders of the next days.
    public const string Hatirlatici = "hatirlatici";

    // Actions waiting in the approval queue.
    public const string Onay = "onay";

    // Today's calendar events (K2.3c).
    public const string Takvim = "takvim";

    // The open items do not fit in the day.
    public const string Kapasite = "kapasite";

    // Nothing to report: an empty day.
    public const string Bos = "bos";

    public static readonly IReadOnlyList<string> Tumu = [Plan, Kalan, Hatirlatici, Onay, Takvim, Kapasite, Bos];
}

// One card as it is stored and shown. `BagliKimlikler` are the ids of what the card is about (plan items, reminders,
// actions); only ids that were in the input are ever kept.
public record BrifingKarti(string Tur, string Baslik, string Metin, List<string> BagliKimlikler);

// What Claude is asked for. The same shape as BrifingKarti, but nothing here is trusted until BrifingKartlari.Denetle has run.
public record ClaudeBrifingKarti(string Tur, string Baslik, string Metin, List<string> BagliKimlikler);

public record ClaudeBrifingCevabi(List<ClaudeBrifingKarti> Kartlar);

// The checks on Claude's answer. It is checked as if a stranger had typed it: the schema asked for these shapes, nothing here
// trusts it. Ids that are not in the input are thrown away, because a card about a reminder that does not exist is worse than
// no card.
public static class BrifingKartlari
{
    // The instruction asks for 5 to 7 cards. Fewer is fine when the day has little in it; more is cut at the top.
    public const int EnAzKart = 5;
    public const int EnCokKart = 7;

    public const int BaslikEnUzun = 80;
    public const int MetinEnUzun = 300;
    public const int KartBasinaEnCokKimlik = 10;

    public record Denetim(List<BrifingKarti> Kartlar, int AtilanKart, int AtilanKimlik);

    public static Denetim Denetle(ClaudeBrifingCevabi cevap, BrifingGirdisi girdi)
    {
        var kartlar = new List<BrifingKarti>();
        int atilanKart = 0, atilanKimlik = 0;
        var destek = girdi.DesteklenenTurler();
        var gorulen = new HashSet<(string, string)>();

        foreach (var k in cevap.Kartlar ?? [])
        {
            if (kartlar.Count >= EnCokKart)
            {
                atilanKart++;
                continue;
            }

            if (k is null || k.Tur is null || k.Baslik is null || k.Metin is null || k.BagliKimlikler is null || !destek.Contains(k.Tur))
            {
                atilanKart++;
                continue;
            }

            var baslik = Duzelt(k.Baslik);
            var metin = Duzelt(k.Metin);
            if (baslik.Length is 0 or > BaslikEnUzun || metin.Length is 0 or > MetinEnUzun || !gorulen.Add((k.Tur, baslik)))
            {
                atilanKart++;
                continue;
            }

            // Each kind may link only to its own pool of ids.
            var havuz = girdi.Havuz(k.Tur);
            var kimlikler = new List<string>();
            foreach (var kimlik in k.BagliKimlikler)
            {
                if (kimlik is not null && havuz.Contains(kimlik) && !kimlikler.Contains(kimlik) && kimlikler.Count < KartBasinaEnCokKimlik)
                    kimlikler.Add(kimlik);
                else
                    atilanKimlik++;
            }

            // A card about reminders, plan items... that links to none that exist is made up.
            if (BrifingGirdisi.KimlikGerekir(k.Tur) && kimlikler.Count == 0)
            {
                atilanKart++;
                continue;
            }

            kartlar.Add(new BrifingKarti(k.Tur, baslik, metin, kimlikler));
        }

        return new Denetim(kartlar, atilanKart, atilanKimlik);
    }

    // One line: control characters (a line break from a model or from a title) become spaces and runs of spaces become one.
    public static string Duzelt(string metin)
    {
        var temiz = new string(metin.Select(c => char.IsControl(c) ? ' ' : c).ToArray());
        return string.Join(' ', temiz.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    // The answer shape. `tur` is an enum of the kinds the input supports; the ids are an enum of the ids the input holds (left out
    // when there are none: an empty enum is no schema). The lengths and the pools are checked after the answer, not here.
    public static string Sema(BrifingGirdisi girdi)
    {
        static JsonArray Dizi(IEnumerable<string> degerler) => new(degerler.Select(d => (JsonNode)JsonValue.Create(d)!).ToArray());

        var kimlik = new JsonObject { ["type"] = "string" };
        var tumKimlikler = girdi.TumKimlikler().ToList();
        if (tumKimlikler.Count > 0)
            kimlik["enum"] = Dizi(tumKimlikler);

        var kart = new JsonObject
        {
            ["type"] = "object",
            ["properties"] = new JsonObject
            {
                ["tur"] = new JsonObject { ["type"] = "string", ["enum"] = Dizi(girdi.DesteklenenTurler()) },
                ["baslik"] = new JsonObject { ["type"] = "string", ["description"] = $"En çok {BaslikEnUzun} karakter" },
                ["metin"] = new JsonObject { ["type"] = "string", ["description"] = $"Tek cümle, en çok {MetinEnUzun} karakter" },
                ["bagliKimlikler"] = new JsonObject { ["type"] = "array", ["items"] = kimlik },
            },
            ["required"] = new JsonArray("tur", "baslik", "metin", "bagliKimlikler"),
            ["additionalProperties"] = false,
        };
        var sema = new JsonObject
        {
            ["type"] = "object",
            ["properties"] = new JsonObject { ["kartlar"] = new JsonObject { ["type"] = "array", ["items"] = kart } },
            ["required"] = new JsonArray("kartlar"),
            ["additionalProperties"] = false,
        };
        return sema.ToJsonString();
    }
}
