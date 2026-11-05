using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Yakalamalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The shared-photo rule lives in YakalamaIslemleri, which the API endpoints and the web form both call.
public class YakalamaFotografPaylasimTests : IAsyncLifetime
{
    private static readonly DateTimeOffset An = new(2026, 11, 5, 12, 0, 0, TimeSpan.Zero);

    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    private static YakalamaYazDto Yaz(Guid? fotograf) => new() { Metin = "x", FotografId = fotograf, YakalandiAt = An };

    private async Task<Guid> OgeKapagiAsync()
    {
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        var aliskanlik = new Aliskanlik { Ad = "Okuma", Tur = AliskanlikTuru.Raf, Ikon = "book", Renk = "blue" };
        _vt.Db.Aliskanliklar.Add(aliskanlik);
        _vt.Db.Ogeler.Add(new Oge { AliskanlikId = aliskanlik.Id, Ad = "Kitap", FotografId = dosya.Id });
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);
        return dosya.Id;
    }

    [Fact]
    public async Task Create_WithFreePhoto_Succeeds()
    {
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.Zero);

        var (sonuc, y) = await YakalamaIslemleri.OlusturAsync(_vt.Db, Yaz(dosya.Id), TestContext.Current.CancellationToken);

        Assert.True(sonuc.Basarili);
        Assert.Equal(dosya.Id, y!.FotografId);
    }

    [Fact]
    public async Task Create_WithPhotoOfItemCover_FailsOnFotografId()
    {
        var kapak = await OgeKapagiAsync();

        var (sonuc, y) = await YakalamaIslemleri.OlusturAsync(_vt.Db, Yaz(kapak), TestContext.Current.CancellationToken);

        Assert.False(sonuc.Basarili);
        Assert.Equal("fotografId", sonuc.Alan);
        Assert.Null(y);
        Assert.False(await _vt.Db.Yakalamalar.AnyAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task Create_WithPhotoOfAnotherCapture_FailsOnFotografId()
    {
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        await YakalamaIslemleri.OlusturAsync(_vt.Db, Yaz(dosya.Id), TestContext.Current.CancellationToken);

        var (sonuc, _) = await YakalamaIslemleri.OlusturAsync(_vt.Db, Yaz(dosya.Id), TestContext.Current.CancellationToken);

        Assert.Equal("fotografId", sonuc.Alan);
        Assert.Equal(1, await _vt.Db.Yakalamalar.CountAsync(TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task Create_WithUnknownPhoto_StillFailsOnFotografId()
    {
        var (sonuc, _) = await YakalamaIslemleri.OlusturAsync(_vt.Db, Yaz(Guid.NewGuid()), TestContext.Current.CancellationToken);

        Assert.Equal("fotografId", sonuc.Alan);
    }

    [Fact]
    public async Task Update_ToPhotoOfAnotherRecord_FailsAndKeepsOwnPhoto()
    {
        var kendi = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        var (_, y) = await YakalamaIslemleri.OlusturAsync(_vt.Db, Yaz(kendi.Id), TestContext.Current.CancellationToken);
        var kapak = await OgeKapagiAsync();

        var sonuc = await YakalamaIslemleri.GuncelleAsync(_vt.Db, _vt.Depo, y!, Yaz(kapak), TestContext.Current.CancellationToken);

        Assert.Equal("fotografId", sonuc.Alan);
        Assert.True(_vt.DiskteVarMi(kendi));
        Assert.True(await _vt.Db.Dosyalar.AnyAsync(d => d.Id == kapak, TestContext.Current.CancellationToken));
    }

    [Fact]
    public async Task Update_KeepingOwnPhoto_Succeeds()
    {
        var kendi = await _vt.DosyaEkleAsync(TimeSpan.Zero);
        var (_, y) = await YakalamaIslemleri.OlusturAsync(_vt.Db, Yaz(kendi.Id), TestContext.Current.CancellationToken);

        var sonuc = await YakalamaIslemleri.GuncelleAsync(_vt.Db, _vt.Depo, y!, Yaz(kendi.Id), TestContext.Current.CancellationToken);

        Assert.True(sonuc.Basarili);
    }
}
