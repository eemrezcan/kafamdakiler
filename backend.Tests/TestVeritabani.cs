using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Npgsql;

namespace Kafamdakiler.Tests;

// A throwaway PostgreSQL database and file folder per test class instance. The server comes from the
// KAFAMDAKILER_TEST_DB environment variable or, failing that, the app's own user-secrets connection string
// (`docker compose up -d` first). Without a server the tests are skipped with a message, not silently passed.
public sealed class TestVeritabani : IAsyncLifetime
{
    private string? _sunucu;
    private string? _veritabani;
    private string? _baglanti;

    public string Klasor { get; } = Path.Combine(Path.GetTempPath(), "kd-test-" + Guid.NewGuid().ToString("N"));

    public AppDbContext Db { get; private set; } = null!;

    // Connection string of this test's own database (for tests that start the whole app on it).
    public string Baglanti => _baglanti ?? throw new InvalidOperationException("Not initialized.");

    public DosyaDeposu Depo { get; private set; } = null!;

    public async ValueTask InitializeAsync()
    {
        var ayar = new ConfigurationBuilder()
            .AddUserSecrets(typeof(AppDbContext).Assembly)
            .AddEnvironmentVariables("KAFAMDAKILER_")
            .Build();
        _sunucu = ayar["TEST_DB"] ?? ayar["ConnectionStrings:Default"];
        Assert.SkipWhen(string.IsNullOrWhiteSpace(_sunucu), "No test database: run `docker compose up -d` or set KAFAMDAKILER_TEST_DB.");

        _veritabani = "kd_test_" + Guid.NewGuid().ToString("N");
        _baglanti = new NpgsqlConnectionStringBuilder(_sunucu) { Database = _veritabani, Pooling = false }.ConnectionString;
        Db = YeniDb();
        await Db.Database.EnsureCreatedAsync();

        var dosyaAyari = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { ["Dosyalar:Klasor"] = Klasor }).Build();
        Depo = new DosyaDeposu(Db, dosyaAyari, new OrtamKalibi());
    }

    // A second context on the same database, for tests that run two things at once (a context is not thread-safe).
    public AppDbContext YeniDb() => new(new DbContextOptionsBuilder<AppDbContext>().UseNpgsql(_baglanti).Options);

    public async ValueTask DisposeAsync()
    {
        if (Db is not null)
        {
            await Db.Database.EnsureDeletedAsync();
            await Db.DisposeAsync();
        }

        if (Directory.Exists(Klasor))
            Directory.Delete(Klasor, recursive: true);
    }

    // Stores a file row and its bytes on disk, uploaded `yas` ago.
    public async Task<Dosya> DosyaEkleAsync(TimeSpan yas)
    {
        var dosya = new Dosya
        {
            DiskAdi = Guid.NewGuid().ToString("N") + ".jpg",
            IcerikTuru = "image/jpeg",
            Boyut = 3,
            YuklenmeAni = DateTimeOffset.UtcNow - yas,
        };
        Directory.CreateDirectory(Klasor);
        await File.WriteAllBytesAsync(Depo.YolBul(dosya), [0xFF, 0xD8, 0xFF]);
        Db.Dosyalar.Add(dosya);
        await Db.SaveChangesAsync();
        return dosya;
    }

    public bool DiskteVarMi(Dosya dosya) => File.Exists(Depo.YolBul(dosya));

    // DosyaDeposu only reads ContentRootPath (to resolve a relative folder).
    private sealed class OrtamKalibi : IWebHostEnvironment
    {
        public string ApplicationName { get; set; } = "test";
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
        public string ContentRootPath { get; set; } = Path.GetTempPath();
        public string EnvironmentName { get; set; } = "Test";
        public string WebRootPath { get; set; } = Path.GetTempPath();
        public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
    }
}
