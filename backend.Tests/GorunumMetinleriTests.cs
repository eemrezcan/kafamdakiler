using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Yakalamalar;

namespace Kafamdakiler.Tests;

// The words the web shows for what the brain writes in its own shorthand (simplification: no raw dates, paths or ids).
public class GorunumMetinleriTests
{
    private static readonly DateOnly Bugun = new(2026, 11, 8);

    [Theory]
    [InlineData("2026-11-03 09:15", "3 Kas 09:15")]
    [InlineData("2026-11-03T18:40:00", "3 Kas 18:40")]
    [InlineData("2026-11-03", "3 Kas")]
    [InlineData("2025-12-31 23:00", "31 Ara 2025 23:00")]
    [InlineData("dün akşam", "dün akşam")]
    public void BrainTimes_ReadAsWords(string ham, string beklenen) => Assert.Equal(beklenen, BeyinGorunum.Zaman(ham, Bugun));

    [Theory]
    [InlineData("engelli", "Engelli")]
    [InlineData("askida", "Askida")]
    [InlineData(null, "")]
    public void TaskStates_ReadAsWords(string? durum, string beklenen) => Assert.Equal(beklenen, BeyinGorunum.GorevDurumu(durum));

    [Theory]
    [InlineData("projects/kitap-kulubu", "Kitap kulubu")]
    [InlineData("projects/kitap-kulubu/notlar", "Kitap kulubu")]
    [InlineData("kisisel", "Kisisel")]
    public void ATarget_ReadsAsWords(string hedef, string beklenen) => Assert.Equal(beklenen, YakalamaGorunum.HedefAdi(hedef));

    [Fact]
    public void APercentage_PutsTheSignFirst_AsTurkishDoes() => Assert.Equal("%14", Gorunum.Yuzde(0.14));
}
