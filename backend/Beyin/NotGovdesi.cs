using System.Text.RegularExpressions;
using Markdig;
using Markdig.Renderers.Html;
using Markdig.Syntax;
using Markdig.Syntax.Inlines;
using Microsoft.AspNetCore.Html;

namespace Kafamdakiler.Beyin;

// A note's body (Markdown from the brain) as HTML for the web page. This is the one place in the app where text from
// the vault becomes markup, so it is closed on purpose:
//  - raw HTML in the note (blocks, inline tags, comments) is switched off: it comes out as escaped text, never as a tag;
//  - an image is never loaded: it shows as its alt text (the mobile screen does the same);
//  - a link stays a link only for http, https and mailto; any other address (javascript:, data:, a vault path) is shown as
//    plain text, and a kept link opens in a new tab without handing over the opener.
// Everything else Markdig writes (paragraphs, lists, tables, code) is markup the library generates itself with its
// text escaped. The page prints the result as an IHtmlContent, so no `Html.Raw` is needed anywhere.
public static partial class NotGovdesi
{
    private static readonly MarkdownPipeline Boru = new MarkdownPipelineBuilder()
        .DisableHtml()
        .UsePipeTables()
        .UseTaskLists()
        .UseEmphasisExtras()
        .Build();

    // The allow-list is on the raw address: nothing but http(s):// or mailto: at the start, and no whitespace or control
    // character anywhere (a browser drops tabs and line breaks inside a scheme: "java&#9;script:").
    [GeneratedRegex(@"^(?:https?://|mailto:)[^\s\p{C}]*\z", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex IzinliAdres();

    public static IHtmlContent Html(string? markdown)
    {
        if (string.IsNullOrWhiteSpace(markdown))
            return HtmlString.Empty;

        var belge = Markdown.Parse(markdown, Boru);
        foreach (var baglanti in belge.Descendants<LinkInline>().ToList())
            Kapat(baglanti);
        // <https://...> and <a@b.c> are a type of their own, not a LinkInline: <javascript:alert(1)> is one too.
        foreach (var baglanti in belge.Descendants<AutolinkInline>().ToList())
            Kapat(baglanti);

        return new HtmlString(Markdown.ToHtml(belge, Boru));
    }

    private static void Kapat(AutolinkInline baglanti)
    {
        // An e-mail address has no scheme in the note; the renderer adds mailto: itself.
        if (baglanti.IsEmail || IzinliAdres().IsMatch(baglanti.Url))
        {
            Ac(baglanti.GetAttributes());
            return;
        }

        baglanti.ReplaceBy(new LiteralInline(baglanti.Url), copyChildren: false);
    }

    private static void Ac(HtmlAttributes ozellikler)
    {
        ozellikler.AddProperty("target", "_blank");
        ozellikler.AddProperty("rel", "noopener noreferrer nofollow");
    }

    private static void Kapat(LinkInline baglanti)
    {
        if (baglanti.IsImage)
        {
            // Not loaded, not linked: the alt text in place of the picture.
            var alt = string.Concat(baglanti.Descendants<LiteralInline>().Select(l => l.Content.ToString())).Trim();
            baglanti.ReplaceBy(new LiteralInline(alt.Length > 0 ? $"[Görsel: {alt}]" : "[Görsel]"), copyChildren: false);
            return;
        }

        if (baglanti.Url is { } adres && IzinliAdres().IsMatch(adres))
        {
            Ac(baglanti.GetAttributes());
            return;
        }

        // An address we do not open: keep the words, drop the link.
        baglanti.ReplaceBy(new ContainerInline(), copyChildren: true);
    }
}
