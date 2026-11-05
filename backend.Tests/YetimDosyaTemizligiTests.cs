using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.Yakalamalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

public class YetimDosyaTemizligiTests : IAsyncLifetime
{
    private static readonly TimeSpan Yas = TimeSpan.FromHours(24);

    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    // Pure rule, no database: runs on plain lists.
    [Fact]
    public void Yetimler_PicksOnlyOldUnlinkedFiles()
    {
        var simdi = DateTimeOffset.UtcNow;
        var eskiYetim = new Dosya { YuklenmeAni = simdi.AddHours(-25) };
        var gencYetim = new Dosya { YuklenmeAni = simdi.AddHours(-1) };
        var eskiBagli = new Dosya { YuklenmeAni = simdi.AddHours(-48) };

        var sonuc = YetimDosyaTemizligi.Yetimler(
            new[] { eskiYetim, gencYetim, eskiBagli }.AsQueryable(), new[] { eskiBagli.Id }.AsQueryable(), simdi - Yas).ToList();

        Assert.Equal([eskiYetim], sonuc);
    }

    // A new table that points to Dosya must be added to BaglantiliDosyalar, or its files would be deleted as orphans.
    [Fact]
    public void BaglantiliDosyalar_CoversEveryForeignKeyToDosya()
    {
        var baglayanlar = _vt.Db.Model.GetEntityTypes()
            .SelectMany(t => t.GetForeignKeys())
            .Where(k => k.PrincipalEntityType.ClrType == typeof(Dosya))
            .Select(k => k.DeclaringEntityType.ClrType)
            .Order(Comparer<Type>.Create((a, b) => string.CompareOrdinal(a.Name, b.Name)))
            .ToList();

        Assert.Equal([typeof(Oge), typeof(Yakalama)], baglayanlar);
    }

    [Fact]
    public async Task Temizle_RemovesOldOrphan_KeepsLinkedAndYoung()
    {
        var db = _vt.Db;
        var eskiYetim = await _vt.DosyaEkleAsync(TimeSpan.FromHours(25));
        var gencYetim = await _vt.DosyaEkleAsync(TimeSpan.FromHours(1));
        var ogeKapagi = await _vt.DosyaEkleAsync(TimeSpan.FromDays(3));
        var yakalamaFotosu = await _vt.DosyaEkleAsync(TimeSpan.FromDays(3));

        var aliskanlik = new Aliskanlik { Ad = "Okuma", Tur = AliskanlikTuru.Raf, Ikon = "book", Renk = "blue" };
        db.Aliskanliklar.Add(aliskanlik);
        db.Ogeler.Add(new Oge { AliskanlikId = aliskanlik.Id, Ad = "Kitap", FotografId = ogeKapagi.Id });
        db.Yakalamalar.Add(new Yakalama { FotografId = yakalamaFotosu.Id, YakalandiAt = DateTimeOffset.UtcNow });
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);

        var silinen = await YetimDosyaTemizligi.TemizleAsync(db, _vt.Depo, Yas, DateTimeOffset.UtcNow, TestContext.Current.CancellationToken);

        Assert.Equal(1, silinen);
        Assert.False(await db.Dosyalar.AnyAsync(d => d.Id == eskiYetim.Id, TestContext.Current.CancellationToken));
        Assert.False(_vt.DiskteVarMi(eskiYetim));
        foreach (var kalan in new[] { gencYetim, ogeKapagi, yakalamaFotosu })
        {
            Assert.True(await db.Dosyalar.AnyAsync(d => d.Id == kalan.Id, TestContext.Current.CancellationToken));
            Assert.True(_vt.DiskteVarMi(kalan));
        }
    }

    [Fact]
    public async Task Temizle_NothingToRemove_ReturnsZero()
    {
        await _vt.DosyaEkleAsync(TimeSpan.FromHours(1));

        Assert.Equal(0, await YetimDosyaTemizligi.TemizleAsync(_vt.Db, _vt.Depo, Yas, DateTimeOffset.UtcNow, TestContext.Current.CancellationToken));
    }
}
