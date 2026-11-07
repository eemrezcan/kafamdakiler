using Kafamdakiler.Takvim;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Kafamdakiler.Tests;

// The calendar migration is written by hand, so the snapshot must say what the model says, and the migration must really build the tables.
public class TakvimGocTests : IAsyncLifetime
{
    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    [Fact]
    public void TheMigrations_MatchTheModel_AndTheCalendarTablesAreInThem()
    {
        Assert.Contains(_vt.Db.Database.GetMigrations(), m => m.EndsWith("_AddTakvim", StringComparison.Ordinal));
        Assert.False(_vt.Db.Database.HasPendingModelChanges());
    }

    [Fact]
    public async Task TheMigrations_RunOnAnEmptyDatabase_AndTheTablesTakeRows()
    {
        // A second database made by the migrations themselves, not by EnsureCreated.
        await using var db = _vt.YeniDb();
        await db.Database.EnsureDeletedAsync(Ct);
        await db.Database.MigrateAsync(Ct);

        Assert.Empty(await db.Database.GetPendingMigrationsAsync(Ct));
        Assert.Empty(await db.TakvimEtkinlikleri.ToListAsync(Ct));
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));

        // The unique index of the migration is the one that keeps a Google event to one row.
        db.TakvimEtkinlikleri.Add(Satir());
        db.TakvimEtkinlikleri.Add(Satir());
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync(Ct));
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static TakvimEtkinligi Satir() => new()
    {
        TakvimKimligi = "primary", GoogleKimligi = "ayni", Baslik = "x", Baslangic = DateTimeOffset.UtcNow, Bitis = DateTimeOffset.UtcNow,
    };
}

// The settings decide whether the module exists at all: all three of the id, the secret and the return address, or nothing.
public class TakvimAyariTests
{
    private static TakvimAyari Oku(params (string, string?)[] degerler) =>
        TakvimAyari.Oku(new ConfigurationBuilder().AddInMemoryCollection(degerler.Select(d => new KeyValuePair<string, string?>(d.Item1, d.Item2))).Build());

    [Fact]
    public void WithNothingSet_TheModuleIsOff_WithoutAWarning()
    {
        var ayar = Oku();
        Assert.False(ayar.Acik);
        Assert.Null(ayar.Uyari);
        Assert.Equal(["primary"], ayar.Takvimler);
    }

    [Fact]
    public void WithAllThree_TheModuleIsOn()
    {
        var ayar = Oku(("Google:ClientId", "a"), ("Google:ClientSecret", "b"), ("Google:DonusAdresi", "https://x.test/google/donus"));
        Assert.True(ayar.Acik);
        Assert.Null(ayar.Uyari);
    }

    [Theory]
    [InlineData("a", "", "https://x.test/google/donus")]
    [InlineData("", "b", "https://x.test/google/donus")]
    [InlineData("a", "b", "")]
    [InlineData("a", "b", "/google/donus")]
    [InlineData("a", "b", "ftp://x.test/google/donus")]
    public void WithAnythingMissingOrUnusable_TheModuleStaysOff_AndSaysWhy(string id, string gizli, string donus)
    {
        var ayar = Oku(("Google:ClientId", id), ("Google:ClientSecret", gizli), ("Google:DonusAdresi", donus));
        Assert.False(ayar.Acik);
        Assert.NotNull(ayar.Uyari);
    }

    [Fact]
    public void TheCalendars_ComeAsAnArrayOrOneCommaSeparatedText_AndBadOnesAreDropped()
    {
        Assert.Equal(["a", "b"], Oku(("Google:Takvimler", "a, b ,a")).Takvimler);
        Assert.Equal(["x", "y"], Oku(("Google:Takvimler:0", "x"), ("Google:Takvimler:1", "y")).Takvimler);
        Assert.Equal(["primary"], Oku(("Google:Takvimler", " , ")).Takvimler);
        Assert.Equal(["ok"], Oku(("Google:Takvimler", "ok,bad\nid")).Takvimler);
    }
}
