using System.Globalization;
using System.Text.RegularExpressions;

namespace Kafamdakiler.Gelen;

// One card of `gelen liste`. `Kimlik` is the file name without ".md"; the brain takes it as it is.
public record BeyinKarti(string Kimlik, string Baslik, string? Yakalandi, string? Hedef, bool GorselVar);

// The rules about what leaves the server: which cards may go to Claude, which suggestions count as coming from outside.
public static partial class GelenKurallari
{
    // The most card text sent in one call.
    public const int EnUzunMetin = 8000;

    private static readonly string[] KapaliKlasorler = ["finans", "kisisel"];

    // A card goes to Claude only when it is not hidden, and the brain's list already leaves hidden ones out. This is the
    // second lock, on the server's side: a card aimed at a hidden or missing project, or at a closed folder (finans/,
    // kisisel/), is kept back too. `gorunurProjeler` are the ids of the projects that exist and are not hidden; with
    // null (the list could not be read) no card goes.
    public static bool ClaudeaGidebilir(BeyinKarti kart, IReadOnlySet<string>? gorunurProjeler, out string neden)
    {
        neden = "";
        if (gorunurProjeler is null)
        {
            neden = "Proje listesi okunamadı.";
            return false;
        }

        if (string.IsNullOrWhiteSpace(kart.Hedef))
            return true;

        var parcalar = kart.Hedef.Trim().Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (parcalar.Length == 0)
            return true;

        if (KapaliKlasorler.Contains(parcalar[0], StringComparer.OrdinalIgnoreCase))
        {
            neden = "Kartın hedefi kapalı bir klasör.";
            return false;
        }

        if (parcalar[0].Equals("projects", StringComparison.OrdinalIgnoreCase) && parcalar.Length > 1 && !gorunurProjeler.Contains(parcalar[1]))
        {
            neden = "Kartın hedefi gizli ya da olmayan bir proje.";
            return false;
        }

        return true;
    }

    // A control character or a line or paragraph separator: it would split a line in two where the brain writes one.
    public static bool DenetimKarakteriVar(string metin) =>
        metin.Any(c => char.IsControl(c) || char.GetUnicodeCategory(c) is UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator);

    // The card text without the image links the brain writes into it (`![](ekler/x.jpg)`). Empty when the card is only an image:
    // images are not sent to Claude, such a card is placed by hand.
    public static string Metin(string govde) =>
        string.Join('\n', govde.Split('\n').Where(s => !s.TrimStart().StartsWith("![", StringComparison.Ordinal))).Trim();

    // True when the card came from a web page or mentions an address. Captures keep no record of where they came from
    // (the share menu hands over text), so an address in the text is what shows it: the suggestion is then never applied by itself.
    public static bool DisKaynakMi(string metin) => Adres().IsMatch(metin);

    [GeneratedRegex(
        @"(?:\b[a-z][a-z0-9+.-]*://|\bwww\.|\bmailto:|\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:com|org|net|io|co|edu|gov|app|dev|me|info|ai|tv|ly|tr|de|uk|ru|fr|nl|xyz|site|online|blog)\b)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Adres();
}
