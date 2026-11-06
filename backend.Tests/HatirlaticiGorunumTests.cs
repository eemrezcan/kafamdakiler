using Kafamdakiler.Hatirlaticilar;

namespace Kafamdakiler.Tests;

// The Turkish display texts of the reminder pages.
public class HatirlaticiGorunumTests
{
    [Theory]
    [InlineData(0, "bugün")]
    [InlineData(1, "yarın")]
    [InlineData(3, "3 gün sonra")]
    [InlineData(-1, "1 gün gecikti")]
    [InlineData(-2, "2 gün gecikti")]
    public void KalanGunMetni_ReadsNaturally(int gun, string beklenen) =>
        Assert.Equal(beklenen, HatirlaticiGorunum.KalanGunMetni(gun));

    [Theory]
    [InlineData(Tekrar.Yok, "2026-10-31", null)]
    [InlineData(Tekrar.Gunluk, "2026-10-31", "her gün")]
    [InlineData(Tekrar.Haftalik, "2026-11-02", "her hafta Pazartesi")]
    [InlineData(Tekrar.Aylik, "2026-10-31", "her ay 31'inde")]
    [InlineData(Tekrar.Aylik, "2026-10-02", "her ay 2'sinde")]
    [InlineData(Tekrar.Aylik, "2026-10-03", "her ay 3'ünde")]
    [InlineData(Tekrar.Aylik, "2026-10-06", "her ay 6'sında")]
    [InlineData(Tekrar.Aylik, "2026-10-30", "her ay 30'unda")]
    [InlineData(Tekrar.Yillik, "2024-02-29", "her yıl 29 Şubat")]
    public void TekrarOzeti_SummarisesTheRule(Tekrar tekrar, string gun, string? beklenen) =>
        Assert.Equal(beklenen, HatirlaticiGorunum.TekrarOzeti(tekrar, DateOnly.Parse(gun)));

    [Theory]
    [InlineData(0, null)]
    [InlineData(1, "1 gün önce de haber verilir")]
    [InlineData(3, "3 gün önce de haber verilir")]
    public void OnceNotu_OnlyWhenThereIsAHeadsUp(int gun, string? beklenen) =>
        Assert.Equal(beklenen, HatirlaticiGorunum.OnceNotu(gun));

    [Fact]
    public void Names_AreTurkish()
    {
        Assert.Equal("Özel tarih", HatirlaticiGorunum.TurAdi(HatirlaticiTuru.OzelTarih));
        Assert.Equal("Arşiv", HatirlaticiGorunum.DurumAdi(HatirlaticiDurumu.Arsiv));
        Assert.Equal("Her yıl", HatirlaticiGorunum.TekrarAdi(Tekrar.Yillik));
    }
}
