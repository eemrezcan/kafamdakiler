using System.Text.Encodings.Web;
using System.Text.RegularExpressions;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Tests;

// The note body on the web page (NotGovdesi): raw HTML or script must never reach the page, whatever a note contains.
// The check does not look for bad words (an escaped "&lt;script&gt;" is fine and a code sample may show one); it reads
// the markup that came out and allows only the tags, attributes and addresses a plain note can produce.
public partial class NotGovdesiTests
{
    private static string Uret(string markdown)
    {
        using var yazici = new StringWriter();
        NotGovdesi.Html(markdown).WriteTo(yazici, HtmlEncoder.Default);
        return yazici.ToString();
    }

    private static readonly HashSet<string> IzinliEtiketler =
    [
        "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "a", "strong", "em", "del", "code", "pre", "blockquote",
        "br", "hr", "table", "thead", "tbody", "tr", "th", "td", "input",
    ];

    private static readonly HashSet<string> IzinliOzellikler = ["href", "target", "rel", "title", "class", "type", "disabled", "checked", "style", "start"];

    [GeneratedRegex(@"<(/?)([a-zA-Z][a-zA-Z0-9]*)((?:[^>""']|""[^""]*""|'[^']*')*)>")]
    private static partial Regex Etiket();

    [GeneratedRegex(@"\s([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+))?")]
    private static partial Regex Ozellik();

    // Every `<` in the output opens a tag from the allow-list with allowed attributes only, every link goes to http(s) or
    // mailto, and no picture is loaded. Text is escaped, so a `<` that is only text never matches Etiket().
    internal static void KapaliMi(string html)
    {
        Assert.DoesNotContain("<img", html, StringComparison.OrdinalIgnoreCase);

        // A `<` that is not the start of a tag from the list must be gone from the output (it has to be &lt;).
        var etiketler = Etiket().Matches(html);
        Assert.Equal(html.Count(c => c == '<'), etiketler.Count);

        foreach (Match e in etiketler)
        {
            Assert.Contains(e.Groups[2].Value.ToLowerInvariant(), IzinliEtiketler);
            foreach (Match o in Ozellik().Matches(e.Groups[3].Value))
            {
                var ad = o.Groups[1].Value.ToLowerInvariant();
                Assert.Contains(ad, IzinliOzellikler);
                if (ad == "href")
                    Assert.Matches(@"^""(https?://|mailto:)[^\s""]*""$", o.Groups[2].Value);
            }
        }
    }

    public static TheoryData<string> Saldirilar() =>
    [
        "<script>alert(1)</script>",
        "<ScRiPt>alert(1)</sCrIpT>",
        "<<script>script>alert(1)//<</script>/script>",
        "<img src=x onerror=alert(1)>",
        "<svg onload=alert(1)>",
        "<iframe src=//evil.example></iframe>",
        "<a href=\"javascript:alert(1)\">x</a>",
        "<details open ontoggle=alert(1)>",
        "<style>@import 'https://evil.example/x.css'</style>",
        "<!-- <script>alert(1)</script> -->",
        "<div onmouseover=\"alert(1)\">üstüne gel</div>",
        "[x](javascript:alert(1))",
        "[x](JaVaScRiPt:alert(1))",
        "[x](   javascript:alert(1)   )",
        "[x](java&#9;script:alert(1))",
        "[x](java&#10;script:alert(1))",
        "[x](&#106;avascript:alert(1))",
        "[x](vbscript:msgbox(1))",
        "[x](data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==)",
        "[x](//evil.example/yol)",
        "[x](../kisisel/gizli-not.md)",
        "<javascript:alert(1)>",
        "[x][r]\n\n[r]: javascript:alert(1)",
        "![x](http://evil.example/izle.png)",
        "![x](javascript:alert(1))",
        "![<script>alert(1)</script>](http://evil.example/a.png)",
        "[x](http://ok.example \"baslik\\\" onmouseover=\\\"alert(1)\")",
        "[x](http://ok.example/\"onmouseover=\"alert(1))",
        "[<script>alert(1)</script>](http://ok.example)",
        "# <img src=x onerror=alert(1)>",
        "| a | b |\n|---|---|\n| <script>alert(1)</script> | [x](javascript:alert(1)) |",
        "- [ ] <script>alert(1)</script>\n- [x] [x](javascript:alert(1))",
        "```html\n<script>alert(1)</script>\n```",
        "`<img src=x onerror=alert(1)>`",
        "> <script>alert(1)</script>",
        "**<script>alert(1)</script>**",
    ];

    [Theory]
    [MemberData(nameof(Saldirilar))]
    public void HostileNotes_NeverReachThePageAsMarkup(string markdown) => KapaliMi(Uret(markdown));

    [Fact]
    public void RawHtml_IsShownAsText_NotDropped()
    {
        var html = Uret("<script>alert(1)</script>");

        Assert.Contains("&lt;script&gt;alert(1)&lt;/script&gt;", html);
        Assert.DoesNotContain("<script", html, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Images_ShowTheirAltText_AndLoadNothing()
    {
        var html = Uret("Önce ![kitap kapağı](http://evil.example/kapak.png) sonra");

        Assert.Contains("[Görsel: kitap kapağı]", html);
        Assert.DoesNotContain("evil.example", html);
        Assert.DoesNotContain("<img", html);
        Assert.Contains("[Görsel]", Uret("![](a.png)"));
    }

    [Theory]
    [InlineData("[sayfa](https://ornek.example/yol?a=1&b=2)", "https://ornek.example/yol?a=1&amp;b=2")]
    [InlineData("[sayfa](http://ornek.example)", "http://ornek.example")]
    [InlineData("[yaz](mailto:ben@ornek.example)", "mailto:ben@ornek.example")]
    [InlineData("<https://ornek.example/otomatik>", "https://ornek.example/otomatik")]
    [InlineData("<ben@ornek.example>", "mailto:ben@ornek.example")]
    public void OrdinaryLinks_Stay_AndOpenSafely(string markdown, string adres)
    {
        var html = Uret(markdown);

        Assert.Contains($"href=\"{adres}\"", html);
        Assert.Contains("target=\"_blank\"", html);
        Assert.Contains("rel=\"noopener noreferrer nofollow\"", html);
        KapaliMi(html);
    }

    [Theory]
    [InlineData("[kitap notu](projects/kitap-kulubu/notlar/takvim.md)", "kitap notu")]
    [InlineData("[tehlikeli](javascript:alert(1))", "tehlikeli")]
    [InlineData("[göreli](../yukari.md)", "göreli")]
    public void OtherAddresses_BecomePlainText_WithTheirWords(string markdown, string kelimeler)
    {
        var html = Uret(markdown);

        Assert.Contains(kelimeler, html);
        Assert.DoesNotContain("<a", html);
        Assert.DoesNotContain("href", html);
    }

    [Fact]
    public void OrdinaryMarkdown_BecomesOrdinaryHtml()
    {
        var html = Uret("# Başlık\n\nBir **kalın**, bir *eğik* ve ~~çizili~~ söz.\n\n- bir\n- iki\n\n1. sıra\n\n> alıntı\n\n`kod` ve\n\n```\nblok\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] bitti\n- [ ] sürüyor");

        Assert.Contains("<h1>Başlık</h1>", html);
        Assert.Contains("<strong>kalın</strong>", html);
        Assert.Contains("<em>eğik</em>", html);
        Assert.Contains("<del>çizili</del>", html);
        Assert.Contains("<li>bir</li>", html);
        Assert.Contains("<blockquote>", html);
        Assert.Contains("<code>kod</code>", html);
        Assert.Contains("<table>", html);
        Assert.Contains("type=\"checkbox\"", html);
        KapaliMi(html);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   \n ")]
    public void EmptyBody_IsEmptyOutput(string? markdown) => Assert.Equal("", Uret(markdown!));
}
