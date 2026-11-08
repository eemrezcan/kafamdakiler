using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The Gmail table has a generated migration, so the snapshot must say what the model says, and the migrations must run on an empty database.
public class GmailGocTests : IAsyncLifetime
{
    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    [Fact]
    public void TheMigrations_MatchTheModel_AndTheGmailTableIsInThem()
    {
        Assert.Contains(_vt.Db.Database.GetMigrations(), m => m.EndsWith("_GmailMesajlari", StringComparison.Ordinal));
        Assert.False(_vt.Db.Database.HasPendingModelChanges());
    }

    [Fact]
    public async Task TheMigrations_RunOnAnEmptyDatabase_AndTheGmailIdIsUnique()
    {
        // A second database made by the migrations themselves, not by EnsureCreated.
        await using var db = _vt.YeniDb();
        await db.Database.EnsureDeletedAsync(TestContext.Current.CancellationToken);
        await db.Database.MigrateAsync(TestContext.Current.CancellationToken);

        Assert.Empty(await db.GmailMesajlari.ToListAsync(TestContext.Current.CancellationToken));
        db.GmailMesajlari.Add(new Kafamdakiler.Gmail.GmailMesaji { GmailKimligi = "ayni" });
        db.GmailMesajlari.Add(new Kafamdakiler.Gmail.GmailMesaji { GmailKimligi = "ayni" });
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync(TestContext.Current.CancellationToken));
    }
}
