using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Yakalamalar;

namespace Kafamdakiler.Tests;

public class YakalamaDogrulamaTests
{
    private static readonly DateTimeOffset An = new(2026, 11, 4, 12, 0, 0, TimeSpan.Zero);

    // Runs the attributes and IValidatableObject, like the endpoint validation does.
    private static List<ValidationResult> Dogrula(YakalamaYazDto dto)
    {
        var sonuclar = new List<ValidationResult>();
        Validator.TryValidateObject(dto, new ValidationContext(dto), sonuclar, validateAllProperties: true);
        return sonuclar;
    }

    private static bool AlanHatasiVar(List<ValidationResult> sonuclar, string alan) =>
        sonuclar.Any(s => s.MemberNames.Contains(alan, StringComparer.OrdinalIgnoreCase));

    [Fact]
    public void TextOnly_IsValid()
    {
        Assert.Empty(Dogrula(new YakalamaYazDto { Metin = "kitap önerisi", YakalandiAt = An }));
    }

    [Fact]
    public void PhotoOnly_IsValid()
    {
        Assert.Empty(Dogrula(new YakalamaYazDto { FotografId = Guid.CreateVersion7(), YakalandiAt = An }));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void NoTextAndNoPhoto_FailsOnMetin(string? metin)
    {
        var sonuclar = Dogrula(new YakalamaYazDto { Metin = metin, YakalandiAt = An });

        Assert.True(AlanHatasiVar(sonuclar, "metin"));
    }

    [Fact]
    public void MissingYakalandiAt_Fails()
    {
        var sonuclar = Dogrula(new YakalamaYazDto { Metin = "x" });

        Assert.True(AlanHatasiVar(sonuclar, nameof(YakalamaYazDto.YakalandiAt)));
    }

    [Theory]
    [InlineData("projects/kitap-kulubu")]
    [InlineData("projects/a")]
    [InlineData("projects/kafamdakiler2")]
    [InlineData(null)]
    [InlineData("")]
    public void Hedef_ValidPatterns(string? hedef)
    {
        Assert.Empty(Dogrula(new YakalamaYazDto { Metin = "x", Hedef = hedef, YakalandiAt = An }));
    }

    [Theory]
    [InlineData("projects/../finans")]
    [InlineData("projects/")]
    [InlineData("projects/a/b")]
    [InlineData("projects/Kitap")]
    [InlineData("projects/kitap_kulubu")]
    [InlineData("projects/-kitap")]
    [InlineData("projects/kitap-")]
    [InlineData("projects/kitap--kulubu")]
    [InlineData("projects/kitap\n")]
    [InlineData("finans/borc")]
    [InlineData("/projects/kitap")]
    public void Hedef_BadPatterns_FailOnHedef(string hedef)
    {
        var sonuclar = Dogrula(new YakalamaYazDto { Metin = "x", Hedef = hedef, YakalandiAt = An });

        Assert.True(AlanHatasiVar(sonuclar, nameof(YakalamaYazDto.Hedef)));
    }

    [Fact]
    public void TooLongMetin_Fails()
    {
        var sonuclar = Dogrula(new YakalamaYazDto { Metin = new string('a', 5001), YakalandiAt = An });

        Assert.True(AlanHatasiVar(sonuclar, nameof(YakalamaYazDto.Metin)));
    }
}
