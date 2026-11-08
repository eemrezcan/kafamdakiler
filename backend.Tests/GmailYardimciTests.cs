using System.Text;
using Google.Apis.Gmail.v1.Data;
using Kafamdakiler.Claude;
using Kafamdakiler.Gmail;
using Microsoft.Extensions.Configuration;

namespace Kafamdakiler.Tests;

// The parts of the Gmail scan that need no database or process: turning a mail into text, reading the Gmail part of a message, the
// settings, and the model per kind of Claude call.
public class GmailYardimciTests
{
    private static IConfiguration Ayarlar(params (string, string?)[] degerler) =>
        new ConfigurationBuilder().AddInMemoryCollection(degerler.Select(d => new KeyValuePair<string, string?>(d.Item1, d.Item2))).Build();

    private static string B64(string metin, Encoding? kodlama = null) =>
        Convert.ToBase64String((kodlama ?? Encoding.UTF8).GetBytes(metin)).Replace('+', '-').Replace('/', '_').TrimEnd('=');

    // The text of a mail

    [Fact]
    public void AnHtmlMail_BecomesPlainText_WithoutScriptsStylesTagsOrEntities_KeepingTheLines()
    {
        var html = """
            <html><head><title>x</title><style>p { color: red }</style></head>
            <body><script>alert(1)</script><!-- gizli yorum -->
            <p>Merhaba&nbsp;Ay&#351;e,</p><p>Final s&#305;nav&#305; <b>20 Kas&#305;m</b> saat 10:00.</p>
            <table><tr><td>Salon</td><td>B-204</td></tr></table><br>Ba&#351;ar&#305;lar &amp; sevgiler</body></html>
            """;

        var metin = GmailMetni.Htmlden(html);
        var temiz = GmailMetni.Govde(null, html);

        Assert.DoesNotContain("<", temiz);
        Assert.DoesNotContain("alert", temiz);
        Assert.DoesNotContain("gizli yorum", temiz);
        Assert.DoesNotContain("color: red", temiz);
        Assert.Equal("Merhaba Ayşe,\n\nFinal sınavı 20 Kasım saat 10:00.\n\nSalon B-204\n\nBaşarılar & sevgiler".Replace("\n\n", "\n"), temiz.Replace("\n\n", "\n"));
        Assert.Contains("Ayşe", metin);
    }

    [Fact]
    public void ThePlainPart_IsPreferredToTheHtml_AndTheHtmlIsUsedOnlyWhenThePlainHasNoWords()
    {
        Assert.Equal("düz metin", GmailMetni.Govde("düz metin", "<p>html metin</p>"));
        Assert.Equal("html metin", GmailMetni.Govde("  \n ", "<p>html metin</p>"));
        Assert.Equal("", GmailMetni.Govde(null, null));
    }

    [Fact]
    public void InvisibleAndControlCharacters_AreRemoved_IncludingTheUnicodeTagBlockThatCanHideText()
    {
        // U+200B zero width space, U+202E right-to-left override, U+E0049 a "tag" letter, U+0007 bell, a soft hyphen.
        var gizli = "Mer​haba‮ \U000E0049 \u0007sınav­ı";

        var temiz = GmailMetni.Govde(gizli, null);

        Assert.Equal("Merhaba sınavı", temiz);
    }

    [Fact]
    public void LinesAndBlankLines_AreTidied()
    {
        Assert.Equal("bir\n\niki üç", GmailMetni.Govde("  bir  \r\n\r\n\r\n\r\n\r\niki \t üç \n\n", null));
    }

    [Fact]
    public void AHeaderLine_HasNoLineBreakOrControlCharacter_AndIsCutWithoutSplittingACharacter()
    {
        Assert.Equal("Konu Sistem: yap", GmailMetni.Satir("Konu\r\nSistem:\u0000 yap", 100));
        Assert.Equal("", GmailMetni.Satir(null, 10));
        // The cut falls inside the emoji's surrogate pair: the half is dropped.
        Assert.Equal("ab", GmailMetni.Satir("ab😀cd", 3));
        Assert.Equal("ab😀", GmailMetni.Satir("ab😀cd", 4));
    }

    [Fact]
    public void ABodyOfMegabytesOfMarkup_IsCutBeforeItIsParsed()
    {
        var buyuk = "<p>" + new string('x', 450_000) + "</p>";

        var metin = GmailMetni.Htmlden(buyuk);

        Assert.True(metin.Length <= 400_000);
    }

    [Fact]
    public void MarkupBuiltToMakeThePatternsCrawl_IsAnsweredQuicklyWithNoText()
    {
        // Fifty thousand scripts that never close: each opener would scan to the end. The patterns' time limit ends it.
        var kotu = string.Concat(Enumerable.Repeat("<script>", 50_000));
        var saatSayaci = System.Diagnostics.Stopwatch.StartNew();

        var metin = GmailMetni.Govde(null, kotu);

        Assert.True(saatSayaci.Elapsed < TimeSpan.FromSeconds(10), $"took {saatSayaci.Elapsed}");
        Assert.Equal("", metin);
    }

    [Fact]
    public void AnUnclosedTag_IsLeftAsText_AndNeverHangsTheParser()
    {
        var saatSayaci = System.Diagnostics.Stopwatch.StartNew();

        var metin = GmailMetni.Govde(null, "<p>başı</p><div " + new string('a', 200_000));

        Assert.True(saatSayaci.Elapsed < TimeSpan.FromSeconds(10));
        Assert.StartsWith("başı", metin);
    }

    // The Gmail message

    [Fact]
    public void AMessageWithPlainAndHtmlParts_GivesThePlainText_TheHeaders_TheLabels_AndTheMomentGmailReceivedIt()
    {
        var mesaj = new Message
        {
            Id = "abc123",
            LabelIds = ["INBOX", "CATEGORY_PERSONAL"],
            InternalDate = new DateTimeOffset(2026, 11, 6, 11, 30, 0, TimeSpan.Zero).ToUnixTimeMilliseconds(),
            Payload = new MessagePart
            {
                MimeType = "multipart/alternative",
                Headers =
                [
                    new MessagePartHeader { Name = "Subject", Value = "Final sınav tarihi" },
                    new MessagePartHeader { Name = "from", Value = "\"Dr. Hoca\" <hoca@okul.edu.tr>" },
                ],
                Parts =
                [
                    new MessagePart { MimeType = "text/plain", Body = new MessagePartBody { Data = B64("Sınav 20 Kasım'da.") } },
                    new MessagePart { MimeType = "text/html", Body = new MessagePartBody { Data = B64("<p>Sınav <b>başka</b></p>") } },
                ],
            },
        };

        var posta = GmailIstemcisi.Cevir(mesaj);

        Assert.Equal(("abc123", "Final sınav tarihi", "Dr. Hoca", "hoca@okul.edu.tr"), (posta.Kimlik, posta.Konu, posta.GonderenAd, posta.GonderenAdres));
        Assert.Equal("Sınav 20 Kasım'da.", posta.Govde);
        Assert.Equal(["INBOX", "CATEGORY_PERSONAL"], posta.Etiketler);
        Assert.Equal(new DateTimeOffset(2026, 11, 6, 11, 30, 0, TimeSpan.Zero), posta.Tarih);
    }

    [Fact]
    public void AnHtmlOnlyMail_IsConverted_AnAttachmentIsNeverRead_AndTheCharsetOfThePartIsHonoured()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
        var turkce = Encoding.GetEncoding("iso-8859-9");
        var mesaj = new Message
        {
            Id = "x1",
            Payload = new MessagePart
            {
                MimeType = "multipart/mixed",
                Parts =
                [
                    new MessagePart
                    {
                        MimeType = "text/html",
                        Headers = [new MessagePartHeader { Name = "Content-Type", Value = "text/html; charset=\"ISO-8859-9\"" }],
                        Body = new MessagePartBody { Data = B64("<p>Öğrenci işleri: sınav ışığı</p>", turkce) },
                    },
                    new MessagePart
                    {
                        MimeType = "text/plain", Filename = "notlar.txt",
                        Body = new MessagePartBody { Data = B64("EKTEKİ GİZLİ METİN") },
                    },
                ],
            },
        };

        var posta = GmailIstemcisi.Cevir(mesaj);

        Assert.Equal("Öğrenci işleri: sınav ışığı", posta.Govde);
        Assert.DoesNotContain("EKTEKİ", posta.Govde);
        Assert.Null(posta.Konu);
        Assert.Null(posta.GonderenAdres);
    }

    // The settings

    [Fact]
    public void TheSettings_AreOffByDefault_AndTakeTheValuesOfTheConfiguration()
    {
        var varsayilan = GmailAyari.Oku(Ayarlar());
        Assert.False(varsayilan.Acik);
        Assert.Equal((TimeSpan.FromMinutes(10), 3, 4000), (varsayilan.Aralik, varsayilan.IlkBakisGunu, varsayilan.EnUzunGovde));

        var ayar = GmailAyari.Oku(Ayarlar(("Gmail:Acik", "true"), ("Gmail:AralikDakika", "30"), ("Gmail:IlkBakisGunu", "7"), ("Gmail:EnUzunGovde", "2000")));
        Assert.True(ayar.Acik);
        Assert.Equal((TimeSpan.FromMinutes(30), 7, 2000), (ayar.Aralik, ayar.IlkBakisGunu, ayar.EnUzunGovde));
    }

    [Fact]
    public void TheSettings_KeepTheirValuesInSaneBounds()
    {
        var ayar = GmailAyari.Oku(Ayarlar(("Gmail:AralikDakika", "0"), ("Gmail:IlkBakisGunu", "9999"), ("Gmail:EnUzunGovde", "999999999")));

        Assert.True(ayar.Aralik > TimeSpan.Zero);
        Assert.Equal(30, ayar.IlkBakisGunu);
        Assert.Equal(20000, ayar.EnUzunGovde);
    }

    [Theory]
    [InlineData("kisi@ornek.com", "kisi@ornek.com", true)]
    [InlineData("KISI@Ornek.com", "kisi@ornek.com", true)]
    [InlineData("baska@ornek.com", "kisi@ornek.com", false)]
    [InlineData("kisi@ornek.com", "ornek.com", true)]
    [InlineData("kisi@ornek.com", "@ornek.com", true)]
    [InlineData("kisi@alt.ornek.com", "ornek.com", false)]
    [InlineData("kisi@baska.com", "ornek.com", false)]
    [InlineData("kisi@notornek.com", "ornek.com", false)]
    [InlineData(null, "ornek.com", false)]
    public void ABlockedSender_IsMatchedByAddressOrByWholeDomain(string? gonderen, string kural, bool engelli)
    {
        var ayar = GmailAyari.Oku(Ayarlar(("Gmail:EngellenenGonderenler", kural)));

        Assert.Equal(engelli, ayar.Engelli(gonderen));
    }

    [Fact]
    public void TheBlockedList_CanBeAnArrayOrOneCommaSeparatedText_AndBadEntriesAreDropped()
    {
        var dizi = GmailAyari.Oku(Ayarlar(("Gmail:EngellenenGonderenler:0", "a@b.com"), ("Gmail:EngellenenGonderenler:1", "c.com")));
        var metin = GmailAyari.Oku(Ayarlar(("Gmail:EngellenenGonderenler", " a@b.com , c.com ,, bozuk girdi , ")));

        Assert.Equal(["a@b.com", "c.com"], dizi.EngellenenGonderenler);
        Assert.Equal(["a@b.com", "c.com"], metin.EngellenenGonderenler);
    }

    // The model per kind of call

    [Fact]
    public void TheModelOfACall_IsItsOwnEntry_ElseTheNearestShorterName_ElseTheGeneralModel()
    {
        var ayar = ClaudeAyari.Oku(Ayarlar(
            ("Claude:Model", "opus"),
            ("Claude:Modeller:gmail-cikar", "haiku"),
            ("Claude:Modeller:ses-yeniden-yaz", "haiku"),
            ("Claude:Modeller:ses-yeniden-yaz-madde", "sonnet"),
            ("Claude:Modeller:brifing", "  ")), "/");

        Assert.Equal("haiku", ayar.ModelSec("gmail-cikar"));
        Assert.Equal("haiku", ayar.ModelSec("GMAIL-CIKAR"));
        Assert.Equal("haiku", ayar.ModelSec("ses-yeniden-yaz-ozet"));
        Assert.Equal("sonnet", ayar.ModelSec("ses-yeniden-yaz-madde"));
        // No entry, an empty one, and a name nobody set: the general model.
        Assert.Equal("opus", ayar.ModelSec("gelen-yerlestir"));
        Assert.Equal("opus", ayar.ModelSec("brifing"));
        Assert.Equal("opus", ayar.ModelSec("ses"));
    }

    [Fact]
    public void WithNoModelEntries_EveryCallTakesTheGeneralModel()
    {
        var ayar = new ClaudeAyari { Model = "sonnet" };

        Assert.Equal("sonnet", ayar.ModelSec("gmail-cikar"));
        Assert.Equal("sonnet", ayar.ModelSec("x"));
    }
}
