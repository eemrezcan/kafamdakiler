using Kafamdakiler.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// The whole app (real pipeline, Identity, bearer tokens) on a throwaway PostgreSQL database, in-memory server.
// The environment is not Development, so user-secrets and the brain settings are not read: the brain is off.
// Skipped, like the other database tests, when there is no database server.
public sealed class UygulamaFabrikasi : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string SahipEposta = "sahip@test.local";
    public const string AsistanEposta = "asistan@test.local";
    public const string Parola = "Test-Parola-1!";

    private readonly TestVeritabani _veritabani = new();

    public async ValueTask InitializeAsync()
    {
        await _veritabani.InitializeAsync();
        // The app seeds the accounts at startup and expects the tables to exist (production: migrations).
        // TestVeritabani already created the schema; the first client starts the app.
        _ = Services;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Default", _veritabani.Baglanti);
        builder.UseSetting("Dosyalar:Klasor", _veritabani.Klasor);
        // The notification timer would wake up in the middle of a test; the tests run its rounds by hand when they want one.
        builder.UseSetting("BildirimHatti:IlkGecikmeSaniye", "3600");
        builder.UseSetting("Seed:SahipEmail", SahipEposta);
        builder.UseSetting("Seed:SahipPassword", Parola);
        builder.UseSetting("Seed:AsistanEmail", AsistanEposta);
        builder.UseSetting("Seed:AsistanPassword", Parola);
    }

    // A scope for tests that read or write the database directly.
    public AppDbContext YeniDb() => _veritabani.YeniDb();

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync();
        await _veritabani.DisposeAsync();
    }
}
