using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.ProjeRepolari;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Kafamdakiler.Tests;

// The migration of H4 and K2.5 is written by hand, so the snapshot must say what the model says, and it must work on a database
// that already has reminders.
public class IsrarProjeRepoGocTests : IAsyncLifetime
{
    private const string Onceki = "20261107233000_AddTakvim";
    private const string Bu = "20261108000000_AddIsrarVeProjeRepo";

    private readonly TestVeritabani _vt = new();

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public ValueTask DisposeAsync() => _vt.DisposeAsync();

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    [Fact]
    public void TheMigrations_MatchTheModel_AndTheNewMigrationIsLast()
    {
        Assert.Equal(Bu, _vt.Db.Database.GetMigrations().Last());
        Assert.False(_vt.Db.Database.HasPendingModelChanges());
    }

    [Fact]
    public async Task TheMigration_KeepsOldReminders_AsNotPersistent_AndCreatesTheMappingTable()
    {
        await using var db = _vt.YeniDb();
        await db.Database.EnsureDeletedAsync(Ct);
        await db.Database.GetService<IMigrator>().MigrateAsync(Onceki, Ct);

        var id = Guid.CreateVersion7();
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO "Hatirlaticilar" ("Id", "Baslik", "Tur", "Gun", "Tekrar", "OnceGun", "Durum", "SonrakiAn", "CreatedAt")
            VALUES ({id}, 'Eski', 'gorev', {new DateOnly(2026, 12, 1)}, 'yok', 0, 'acik', {DateTimeOffset.UtcNow}, {DateTimeOffset.UtcNow})
            """, Ct);

        await db.Database.MigrateAsync(Ct);

        Assert.Empty(await db.Database.GetPendingMigrationsAsync(Ct));
        var h = await db.Hatirlaticilar.AsNoTracking().SingleAsync(x => x.Id == id, Ct);
        Assert.False(h.Israrli);
        Assert.False(h.Acil);
        Assert.Equal(Hatirlatici.VarsayilanIsrarAraligi, h.IsrarAraligiDakika);
        Assert.Equal(Hatirlatici.VarsayilanIsrarEnCok, h.IsrarEnCok);

        db.ProjeRepolari.Add(new ProjeRepo { ProjeKimligi = "kitap-kulubu", Depo = "emre/kafamdakiler" });
        await db.SaveChangesAsync(Ct);
        Assert.Equal("emre/kafamdakiler", (await db.ProjeRepolari.AsNoTracking().SingleAsync(Ct)).Depo);
    }

    [Fact]
    public async Task TheMigration_GoesDownAndUpAgain()
    {
        await using var db = _vt.YeniDb();
        await db.Database.EnsureDeletedAsync(Ct);
        var gocmen = db.Database.GetService<IMigrator>();
        await gocmen.MigrateAsync(null, Ct);

        await gocmen.MigrateAsync(Onceki, Ct);
        Assert.Equal([Bu], await db.Database.GetPendingMigrationsAsync(Ct));

        await gocmen.MigrateAsync(null, Ct);
        Assert.Empty(await db.Database.GetPendingMigrationsAsync(Ct));
    }
}
