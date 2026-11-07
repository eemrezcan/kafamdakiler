using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The migrations are written by hand for the inbox table, so the snapshot must say what the model says.
public class GelenGocTests : IAsyncLifetime
{
    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    [Fact]
    public void TheMigrations_MatchTheModel_AndTheInboxTableIsInThem()
    {
        Assert.Contains(_vt.Db.Database.GetMigrations(), m => m.EndsWith("_AddGelenKartlari", StringComparison.Ordinal));
        Assert.False(_vt.Db.Database.HasPendingModelChanges());
    }

    [Fact]
    public async Task TheMigrations_RunOnAnEmptyDatabase()
    {
        // A second database made by the migrations themselves, not by EnsureCreated.
        await using var db = _vt.YeniDb();
        await db.Database.EnsureDeletedAsync(TestContext.Current.CancellationToken);
        await db.Database.MigrateAsync(TestContext.Current.CancellationToken);

        Assert.Empty(await db.GelenKartlari.ToListAsync(TestContext.Current.CancellationToken));
        Assert.Empty(await db.Database.GetPendingMigrationsAsync(TestContext.Current.CancellationToken));
    }
}
