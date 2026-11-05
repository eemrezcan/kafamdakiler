using System.Text.RegularExpressions;

namespace Kafamdakiler.Beyin;

// Search snippets (`alinti`) come from beyin.py as a piece of a note with the line breaks flattened into spaces:
// "# Başlık ## 2026-11-03 · Madde - [x] 20 sayfa ^c4d957". It can start or end in the middle of a sentence, so a
// Markdown parser has nothing whole to read; these few patterns take the marks out of such a fragment instead.
public static partial class DuzMetin
{
    public static string? Temizle(string? alinti)
    {
        if (string.IsNullOrWhiteSpace(alinti))
            return alinti;

        var m = Gorsel().Replace(alinti, "$1");
        m = Vikibaglanti().Replace(m, "$2");
        m = Baglanti().Replace(m, "$1");
        m = HtmlEtiketi().Replace(m, " ");
        m = BlokKimligi().Replace(m, "");
        m = SatirBasi().Replace(m, "$1");
        m = KalinItalik().Replace(m, "");
        m = Bosluk().Replace(m, " ");
        return m.Trim();
    }

    // ![alt](url)
    [GeneratedRegex(@"!\[([^\]]*)\]\([^)]*\)", RegexOptions.CultureInvariant)]
    private static partial Regex Gorsel();

    // [[not]] and [[not|görünen ad]]: the shown name when there is one
    [GeneratedRegex(@"\[\[([^\]|]*\|)?([^\]]*)\]\]", RegexOptions.CultureInvariant)]
    private static partial Regex Vikibaglanti();

    // [metin](url)
    [GeneratedRegex(@"\[([^\]]*)\]\([^)]*\)", RegexOptions.CultureInvariant)]
    private static partial Regex Baglanti();

    [GeneratedRegex(@"</?[A-Za-z][^>]*>", RegexOptions.CultureInvariant)]
    private static partial Regex HtmlEtiketi();

    // Obsidian block ids: " ^c4d957"
    [GeneratedRegex(@"\s\^[A-Za-z0-9-]+(?=\s|$)", RegexOptions.CultureInvariant)]
    private static partial Regex BlokKimligi();

    // Heading hashes, quote marks, list bullets and task boxes. Flattened text has them in the middle of the line too,
    // so they are matched after a space (or at the start), and only when a space follows: "C# dili" and "a-b" stay.
    [GeneratedRegex(@"(^|\s)(?:#{1,6}|>|[-*+]|\d+\.|\[[ xX]\]|\|)(?=\s|$)(?:\s*\[[ xX]\](?=\s|$))?", RegexOptions.CultureInvariant)]
    private static partial Regex SatirBasi();

    // **bold**, __bold__, *italic*, _italic_, ~~strike~~, `code`: the marks go, the words stay.
    // An underscore inside a word (snake_case) is not a mark.
    [GeneratedRegex(@"\*{1,3}|~~|`+|(?<![\p{L}\p{N}])_{1,3}|_{1,3}(?![\p{L}\p{N}])", RegexOptions.CultureInvariant)]
    private static partial Regex KalinItalik();

    [GeneratedRegex(@"\s+", RegexOptions.CultureInvariant)]
    private static partial Regex Bosluk();
}
