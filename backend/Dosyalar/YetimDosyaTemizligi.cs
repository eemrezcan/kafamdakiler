using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Yakalamalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Dosyalar;

// Files that no record points to (a replaced mobile photo that was never sent, an upload whose form was abandoned, ...).
// The grace period keeps a file that was uploaded a moment ago and not yet saved on a record.
public static class YetimDosyaTemizligi
{
    // The one list of "who points to a file". A new table that references Dosya must be added here;
    // a test compares this list with the model, so forgetting it fails the build instead of deleting a live file.
    public static IQueryable<Guid> BaglantiliDosyalar(AppDbContext db) =>
        db.Ogeler.Where(o => o.FotografId != null).Select(o => o.FotografId!.Value)
            .Union(db.Yakalamalar.Where(y => y.FotografId != null).Select(y => y.FotografId!.Value));

    // Pure selection rule, so it runs on a database query and on plain lists alike.
    public static IQueryable<Dosya> Yetimler(IQueryable<Dosya> dosyalar, IQueryable<Guid> baglilar, DateTimeOffset sinir) =>
        dosyalar.Where(d => d.YuklenmeAni < sinir && !baglilar.Contains(d.Id));

    // Removes the old orphans (rows and files) and returns how many.
    public static async Task<int> TemizleAsync(AppDbContext db, DosyaDeposu depo, TimeSpan yas, DateTimeOffset simdi, CancellationToken ct)
    {
        var idler = await Yetimler(db.Dosyalar, BaglantiliDosyalar(db), simdi - yas).Select(d => d.Id).ToListAsync(ct);
        await depo.SilAsync(idler, ct);
        return idler.Count;
    }
}

// Runs the cleanup once a day. Both durations come from settings (Dosyalar:YetimYasSaat, Dosyalar:TemizlikAraligiSaat).
public class YetimDosyaTemizleyici(IServiceScopeFactory kapsamlar, IConfiguration config, ILogger<YetimDosyaTemizleyici> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var yas = TimeSpan.FromHours(config.GetValue("Dosyalar:YetimYasSaat", 24.0));
        var aralik = TimeSpan.FromHours(config.GetValue("Dosyalar:TemizlikAraligiSaat", 24.0));

        using var zamanlayici = new PeriodicTimer(aralik);
        do
        {
            try
            {
                using var kapsam = kapsamlar.CreateScope();
                var sayi = await YetimDosyaTemizligi.TemizleAsync(
                    kapsam.ServiceProvider.GetRequiredService<AppDbContext>(),
                    kapsam.ServiceProvider.GetRequiredService<DosyaDeposu>(), yas, DateTimeOffset.UtcNow, ct);
                log.LogInformation("Orphan file cleanup removed {Count} file(s).", sayi);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                // A failed run is retried at the next tick; the app keeps running.
                log.LogError(e, "Orphan file cleanup failed.");
            }
        } while (await zamanlayici.WaitForNextTickAsync(ct));
    }
}
