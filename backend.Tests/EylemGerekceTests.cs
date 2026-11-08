using Kafamdakiler.Eylemler;

namespace Kafamdakiler.Tests;

// The "Mailde aç" link of a Gmail suggestion: only the last line, only a Gmail address of the exact shape GmailTarayici writes.
public class EylemGerekceTests
{
    [Fact]
    public void AGmailReason_SplitsIntoTheQuoteAndTheLink()
    {
        var (metin, baglanti) = EylemGorunum.GerekceAyir("Gmail'den: «Sınav 17 Kasım 09:00»\nhttps://mail.google.com/mail/u/0/#inbox/18c2f0a9b7d4e1f3");

        Assert.Equal("Gmail'den: «Sınav 17 Kasım 09:00»", metin);
        Assert.Equal("https://mail.google.com/mail/u/0/#inbox/18c2f0a9b7d4e1f3", baglanti);
    }

    [Theory]
    [InlineData("Sadece bir gerekçe")]
    [InlineData("Gmail'den: «x»\nhttps://kotu.example/mail/u/0/#inbox/abc")]
    [InlineData("Gmail'den: «x»\nhttps://mail.google.com/mail/u/0/#inbox/abc\" onclick=\"x")]
    [InlineData("https://mail.google.com/mail/u/0/#inbox/abc\nson satır başka")]
    public void AnythingElse_StaysPlainText(string gerekce)
    {
        var (metin, baglanti) = EylemGorunum.GerekceAyir(gerekce);

        Assert.Null(baglanti);
        Assert.Equal(gerekce, metin);
    }
}
