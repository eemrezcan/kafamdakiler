using System.Globalization;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace Kafamdakiler.Gmail;

// Turns a mail body into the plain text that goes to Claude. The text is only ever read by Claude (never shown as HTML), so this is not
// a sanitiser: it drops what is not words (scripts, styles, tags, invisible characters) and keeps the lines.
public static partial class GmailMetni
{
    // HTML past this is cut before it is parsed: a mail can be megabytes of markup around a few lines.
    private const int HtmlEnCok = 400_000;

    private const int Zamanasimi = 1000;

    [GeneratedRegex(@"<(script|style|head)\b.*?</\1\s*>|<!--.*?-->", RegexOptions.Singleline | RegexOptions.IgnoreCase, Zamanasimi)]
    private static partial Regex Gizlenenler();

    [GeneratedRegex(@"<\s*br\s*/?\s*>|</\s*(p|div|tr|li|ul|ol|table|h[1-6]|blockquote|section|article)\s*>", RegexOptions.IgnoreCase, Zamanasimi)]
    private static partial Regex SatirSonlari();

    [GeneratedRegex(@"</\s*(td|th)\s*>", RegexOptions.IgnoreCase, Zamanasimi)]
    private static partial Regex HucreSonlari();

    [GeneratedRegex(@"<[^>]{0,2000}>", RegexOptions.None, Zamanasimi)]
    private static partial Regex Etiketler();

    [GeneratedRegex(@"[ \t]+", RegexOptions.None, Zamanasimi)]
    private static partial Regex Bosluklar();

    [GeneratedRegex(@"\n{3,}", RegexOptions.None, Zamanasimi)]
    private static partial Regex BosSatirlar();

    // The plain part when it has words, else the HTML part converted. Both come out cleaned.
    public static string Govde(string? duzMetin, string? html)
    {
        var duz = Temizle(duzMetin ?? "");
        return duz.Length > 0 ? duz : Temizle(Htmlden(html ?? ""));
    }

    public static string Htmlden(string html)
    {
        if (html.Length > HtmlEnCok)
            html = html[..HtmlEnCok];

        try
        {
            html = Gizlenenler().Replace(html, " ");
            html = SatirSonlari().Replace(html, "\n");
            html = HucreSonlari().Replace(html, " ");
            html = Etiketler().Replace(html, "");
        }
        catch (RegexMatchTimeoutException)
        {
            // Markup built to make the patterns crawl: nothing from it is worth sending.
            return "";
        }

        return WebUtility.HtmlDecode(html);
    }

    // One line: control characters, line breaks and invisible characters become single spaces, then it is cut to `enUzun`.
    // For the subject and the sender, which are headers and must not carry a line of their own into the prompt.
    public static string Satir(string? metin, int enUzun)
    {
        if (string.IsNullOrWhiteSpace(metin))
            return "";

        var sb = new StringBuilder(Math.Min(metin.Length, enUzun + 2));
        foreach (var rune in metin.EnumerateRunes())
        {
            if (Gorunmez(rune) || rune.Value is '\n' or '\r' or '\t')
                sb.Append(' ');
            else
                sb.Append(rune.ToString());
        }

        return Kisalt(Bosluklar().Replace(sb.ToString(), " ").Trim(), enUzun);
    }

    // Cuts to `enUzun` characters without splitting a surrogate pair.
    public static string Kisalt(string metin, int enUzun)
    {
        if (metin.Length <= enUzun)
            return metin;

        var kesilen = metin[..enUzun];
        if (char.IsHighSurrogate(kesilen[^1]))
            kesilen = kesilen[..^1];
        return kesilen.TrimEnd();
    }

    // Line breaks stay; every other control, format (zero-width, direction marks, the Unicode "tag" block that can hide text),
    // private-use and unassigned character goes; runs of spaces and of blank lines shrink.
    private static string Temizle(string metin)
    {
        var sb = new StringBuilder(metin.Length);
        foreach (var rune in metin.Replace("\r\n", "\n").EnumerateRunes())
        {
            if (rune.Value == '\n' || rune.Value == '\r')
                sb.Append('\n');
            else if (rune.Value == '\t' || rune.Value == 0xA0)
                sb.Append(' ');
            else if (!Gorunmez(rune))
                sb.Append(rune.ToString());
        }

        var satirlar = sb.ToString().Split('\n').Select(s => Bosluklar().Replace(s, " ").Trim());
        return BosSatirlar().Replace(string.Join('\n', satirlar), "\n\n").Trim();
    }

    private static bool Gorunmez(Rune rune) => Rune.GetUnicodeCategory(rune) is
        UnicodeCategory.Control or UnicodeCategory.Format or UnicodeCategory.PrivateUse or UnicodeCategory.OtherNotAssigned
        or UnicodeCategory.Surrogate or UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator;
}
