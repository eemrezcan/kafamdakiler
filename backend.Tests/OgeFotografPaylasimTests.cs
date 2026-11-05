using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Yakalamalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// Item covers follow the same shared-photo rule as captures (FotografKurali).
public class OgeFotografPaylasimTests : IAsyncLifetime
{
    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    private static OgeYazDto Yaz(Guid? fotograf) => new() { Ad = "Kitap", FotografId = fotograf };

    private async Task<Aliskanlik> RafAsync()
    {
        var aliskanlik = new Aliskanlik { Ad = "Okuma", Tur = AliskanlikTuru.Raf, Ikon = "book", Renk = "blue" };
        _vt.Db.Aliskanliklar.Add(aliskanlik);
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);
        return aliskanlik;
    }

    [Fact]
    public async Task Create_WithFreePhoto_Succeeds()
    {
        var raf = await RafAsync();
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.Zero);

        var (sonuc, oge) = await AliskanlikIslemleri.OgeOlusturAsync(_vt.Db, raf, Yaz(dosya.Id), TestContext.Current.CancellationToken);

        Assert.True(sonuc.Basarili);
        Assert.Equal(dosya.Id, oge!.FotografId);
    }

    [Fact]
    public async Task Create_WithPhotoOfAnotherItem_FailsOnFotografId()
    {
        var raf = await RafAsync();
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        await AliskanlikIslemleri.OgeOlusturAsync(_vt.Db, raf, Yaz(dosya.Id), TestContext.Current.CancellationToken);

        var (sonuc, oge) = await AliskanlikIslemleri.OgeOlusturAsync(_vt.Db, raf, Yaz(dosya.Id), TestContext.Current.CancellationToken);

        Assert.Equal("fotografId", sonuc.Alan);
        Assert.Null(oge);
        Assert.Equal(1, await _vt.Db.Ogeler.CountAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task Create_WithPhotoOfCapture_FailsOnFotografId()
    {
        var raf = await RafAsync();
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        _vt.Db.Yakalamalar.Add(new Yakalama { FotografId = dosya.Id, YakalandiAt = DateTimeOffset.UtcNow });
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);

        var (sonuc, _) = await AliskanlikIslemleri.OgeOlusturAsync(_vt.Db, raf, Yaz(dosya.Id), TestContext.Current.CancellationToken);

        Assert.Equal("fotografId", sonuc.Alan);
    }

    [Fact]
    public async Task Update_ToPhotoOfCapture_FailsAndKeepsOwnPhoto()
    {
        var raf = await RafAsync();
        var kendi = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        var (_, oge) = await AliskanlikIslemleri.OgeOlusturAsync(_vt.Db, raf, Yaz(kendi.Id), TestContext.Current.CancellationToken);
        var baskasi = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        _vt.Db.Yakalamalar.Add(new Yakalama { FotografId = baskasi.Id, YakalandiAt = DateTimeOffset.UtcNow });
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);

        var sonuc = await AliskanlikIslemleri.OgeGuncelleAsync(_vt.Db, _vt.Depo, oge!, Yaz(baskasi.Id), TestContext.Current.CancellationToken);

        Assert.Equal("fotografId", sonuc.Alan);
        Assert.Equal(kendi.Id, oge!.FotografId);
        Assert.True(_vt.DiskteVarMi(kendi));
    }

    [Fact]
    public async Task Update_KeepingOwnPhoto_Succeeds()
    {
        var raf = await RafAsync();
        var kendi = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        var (_, oge) = await AliskanlikIslemleri.OgeOlusturAsync(_vt.Db, raf, Yaz(kendi.Id), TestContext.Current.CancellationToken);

        var sonuc = await AliskanlikIslemleri.OgeGuncelleAsync(_vt.Db, _vt.Depo, oge!, Yaz(kendi.Id), TestContext.Current.CancellationToken);

        Assert.True(sonuc.Basarili);
    }
}
