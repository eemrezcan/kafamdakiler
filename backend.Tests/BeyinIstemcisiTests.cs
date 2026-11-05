using System.Diagnostics;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Tests;

// The client runs a real child process; the process is a fake beyin.py (SahteBeyin), not the brain.
public class BeyinIstemcisiTests
{
    private static readonly string[] Bos = [];

    [Fact]
    public async Task Success_ReturnsJson_AndAddsJsonAndVault()
    {
        using var beyin = new SahteBeyin("ok");

        var sonuc = await beyin.Istemci().CalistirAsync(["gelen", "liste"], TestContext.Current.CancellationToken);

        Assert.Equal(BeyinDurumu.Tamam, sonuc.Durum);
        Assert.Equal("gelen/x.md", sonuc.Veri!.Value.GetProperty("yol").GetString());
        Assert.Equal(["gelen", "liste", "--json", "--vault", beyin.Vault], SahteBeyin.Argumanlar(beyin.Cagrilar().Single()));
    }

    [Fact]
    public async Task ErrorJson_IsBeyinHatasi_WithCodeAndMessage()
    {
        using var beyin = new SahteBeyin("hata");

        var sonuc = await beyin.Istemci().CalistirAsync(Bos, TestContext.Current.CancellationToken);

        Assert.Equal(BeyinDurumu.BeyinHatasi, sonuc.Durum);
        Assert.Equal("gecersiz", sonuc.HataKodu);
        Assert.Equal("kötü istek", sonuc.Mesaj);
        Assert.True(sonuc.GuvenleTekrarlanir);
    }

    [Fact]
    public async Task Timeout_KillsTheProcess_AndIsNotSafeToRepeat()
    {
        using var beyin = new SahteBeyin("uyku");
        var saat = Stopwatch.StartNew();

        var sonuc = await beyin.Istemci(TimeSpan.FromSeconds(1)).CalistirAsync(Bos, TestContext.Current.CancellationToken);

        Assert.Equal(BeyinDurumu.ZamanAsimi, sonuc.Durum);
        Assert.False(sonuc.GuvenleTekrarlanir);
        Assert.True(saat.Elapsed < TimeSpan.FromSeconds(30), "the 60 s sleep must have been cut short");
    }

    [Fact]
    public async Task UnreadableOutput_IsBozukCikti_AndNotSafeToRepeat()
    {
        using var beyin = new SahteBeyin("bozuk");

        var sonuc = await beyin.Istemci().CalistirAsync(Bos, TestContext.Current.CancellationToken);

        Assert.Equal(BeyinDurumu.BozukCikti, sonuc.Durum);
        Assert.False(sonuc.GuvenleTekrarlanir);
    }

    [Fact]
    public async Task NonZeroExit_WithoutErrorJson_IsBozukCikti()
    {
        using var beyin = new SahteBeyin("ok");
        // A command that exits 3 and prints valid JSON that is not an error object.
        File.WriteAllText(beyin.Komut, "import sys\nprint('{\"x\": 1}')\nsys.exit(3)\n");

        var sonuc = await beyin.Istemci().CalistirAsync(Bos, TestContext.Current.CancellationToken);

        Assert.Equal(BeyinDurumu.BozukCikti, sonuc.Durum);
    }

    [Fact]
    public async Task NotConfigured_IsBagliDegil_WithoutStartingAnything()
    {
        var sonuc = await new BeyinIstemcisi(new BeyinAyari()).CalistirAsync(Bos, TestContext.Current.CancellationToken);

        Assert.Equal(BeyinDurumu.BagliDegil, sonuc.Durum);
        Assert.True(sonuc.GuvenleTekrarlanir);
    }

    [Fact]
    public async Task MissingCommandOrVault_IsBagliDegil()
    {
        using var beyin = new SahteBeyin("ok");
        var yok = Path.Combine(beyin.Klasor, "yok");

        var komutYok = new BeyinIstemcisi(new BeyinAyari { Komut = yok, Vault = beyin.Vault });
        var vaultYok = new BeyinIstemcisi(new BeyinAyari { Komut = beyin.Komut, Vault = yok });

        Assert.False(komutYok.Bagli);
        Assert.False(vaultYok.Bagli);
        Assert.Equal(BeyinDurumu.BagliDegil, (await vaultYok.CalistirAsync(Bos, TestContext.Current.CancellationToken)).Durum);
        Assert.Empty(beyin.Cagrilar());
    }

    // Text with spaces, quotes, shell characters and a leading dash must reach the command untouched:
    // there is no shell, and the text travels in a file rather than as an option value.
    [Theory]
    [InlineData("-")]
    [InlineData("--vault")]
    [InlineData("bir iki \"üç\" 'dört'; rm -rf / $(id) `id` && echo")]
    [InlineData("satır bir\nsatır iki ğüşiöç")]
    public async Task GelenEkle_PassesTextExactly_AndRemovesItsTempFile(string metin)
    {
        using var beyin = new SahteBeyin("ok");
        var an = new DateTimeOffset(2026, 11, 5, 13, 7, 0, TimeSpan.Zero);

        var sonuc = await beyin.Istemci().GelenEkleAsync(metin, null, "projects/kitap-kulubu", an, TestContext.Current.CancellationToken);

        Assert.True(sonuc.Basarili);
        var cagri = beyin.Cagrilar().Single();
        Assert.Equal(metin, cagri.GetProperty("metin").GetString());
        var argumanlar = SahteBeyin.Argumanlar(cagri);
        Assert.Contains("--hedef=projects/kitap-kulubu", argumanlar);
        Assert.Contains($"--yakalandi={an.ToLocalTime():yyyy-MM-dd'T'HH:mm}", argumanlar);
        var metinDosyasi = argumanlar.Single(a => a.StartsWith("--metin-dosya=")).Split('=', 2)[1];
        Assert.False(File.Exists(metinDosyasi));
    }
}
