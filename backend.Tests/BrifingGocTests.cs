using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The migration is written by hand for the briefing tables, so the snapshot must say what the model says.
public class BrifingGocTests : IAsyncLifetime
{
    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    [Fact]
    public void TheMigrations_MatchTheModel_AndTheBriefingTablesAreInThem()
    {
        Assert.Contains(_vt.Db.Database.GetMigrations(), m => m.EndsWith("_AddBrifing", StringComparison.Ordinal));
        Assert.False(_vt.Db.Database.HasPendingModelChanges());
    }

    [Fact]
    public async Task TheMigrations_RunOnAnEmptyDatabase_AndTheTablesTakeRows()
    {
        // A second database made by the migrations themselves, not by EnsureCreated.
        await using var db = _vt.YeniDb();
        await db.Database.EnsureDeletedAsync(TestContext.Current.CancellationToken);
        await db.Database.MigrateAsync(TestContext.Current.CancellationToken);

        Assert.Empty(await db.Brifingler.ToListAsync(TestContext.Current.CancellationToken));
        Assert.Empty(await db.BrifingOylari.ToListAsync(TestContext.Current.CancellationToken));
        Assert.Empty(await db.Database.GetPendingMigrationsAsync(TestContext.Current.CancellationToken));

        // The jsonb column and the string-valued method really are what the model stores.
        var gun = new DateOnly(2026, 11, 7);
        db.Brifingler.Add(new Kafamdakiler.Brifing.GunlukBrifing
        {
            Gun = gun, Kartlar = """[{"tur":"bos","baslik":"B","metin":"M","bagliKimlikler":[]}]""", UretimAni = DateTimeOffset.UtcNow,
            Yontem = Kafamdakiler.Brifing.BrifingYontemi.Hesap,
        });
        db.BrifingOylari.Add(new Kafamdakiler.Brifing.BrifingOyu { Gun = gun, Sira = 0, Tur = "bos", Oy = 1, Zaman = DateTimeOffset.UtcNow });
        await db.SaveChangesAsync(TestContext.Current.CancellationToken);

        await using var okuma = _vt.YeniDb();
        Assert.Equal(Kafamdakiler.Brifing.BrifingYontemi.Hesap, (await okuma.Brifingler.SingleAsync(TestContext.Current.CancellationToken)).Yontem);
        Assert.Equal(1, (await okuma.BrifingOylari.SingleAsync(TestContext.Current.CancellationToken)).Oy);
    }
}
