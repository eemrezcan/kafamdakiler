using Kafamdakiler.Beyin;
using SkiaSharp;

namespace Kafamdakiler.Tests;

// The client against the real beyin.py and a throwaway copy of ornek-beyin/ (the template is never written to).
// Skipped when beyin.py is not on this machine (see TestAyari.GercekBeyin).
public sealed class GercekBeyinTests : IDisposable
{
    private readonly string _vault = Path.Combine(Path.GetTempPath(), "kd-gercek-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(_vault))
            Directory.Delete(_vault, recursive: true);
    }

    private BeyinIstemcisi Hazirla()
    {
        var ayar = TestAyari.GercekBeyin(_vault);
        Assert.True(OrnekBeyinKopyasi.HazirlaGerekirse(ayar));
        return new BeyinIstemcisi(ayar);
    }

    [Fact]
    public async Task TextAndPngCapture_BecomeTwoCards_InTheCopy()
    {
        var ct = TestContext.Current.CancellationToken;
        var beyin = Hazirla();
        var oncekiler = (await beyin.CalistirAsync(["gelen", "liste"], ct)).Veri!.Value.GetArrayLength();

        var an = new DateTimeOffset(2026, 11, 5, 13, 7, 0, TimeSpan.Zero);
        var metin = await beyin.GelenEkleAsync("- gerçek komut denemesi, \"tırnaklı\" ve ğüşiöç", null, "projects/kitap-kulubu", an, ct);

        var png = Path.Combine(_vault, "..", "kd-png-" + Guid.NewGuid().ToString("N") + ".png");
        using (var bitmap = new SKBitmap(20, 10))
        {
            bitmap.Erase(SKColors.Tomato);
            using var veri = SKImage.FromBitmap(bitmap).Encode(SKEncodedImageFormat.Png, 100);
            await File.WriteAllBytesAsync(png, veri.ToArray(), ct);
        }

        var (jpeg, gecici) = JpegCevirici.Hazirla(png, "image/png");
        BeyinSonucu fotograf;
        try
        {
            fotograf = await beyin.GelenEkleAsync(null, jpeg, null, an.AddMinutes(1), ct);
        }
        finally
        {
            File.Delete(gecici!);
            File.Delete(png);
        }

        Assert.True(metin.Basarili, metin.Mesaj);
        Assert.True(fotograf.Basarili, fotograf.Mesaj);
        var liste = (await beyin.CalistirAsync(["gelen", "liste"], ct)).Veri!.Value;
        Assert.Equal(oncekiler + 2, liste.GetArrayLength());
    }

    [Fact]
    public async Task BeyinRefusal_ComesBackAsBeyinHatasi()
    {
        var beyin = Hazirla();

        var sonuc = await beyin.GelenEkleAsync(null, Path.Combine(_vault, "yok.jpg"), null, DateTimeOffset.UtcNow, TestContext.Current.CancellationToken);

        Assert.Equal(BeyinDurumu.BeyinHatasi, sonuc.Durum);
        Assert.False(string.IsNullOrEmpty(sonuc.HataKodu));
    }
}
