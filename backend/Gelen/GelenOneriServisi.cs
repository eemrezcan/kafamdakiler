using Kafamdakiler.Beyin;
using Kafamdakiler.Claude;

namespace Kafamdakiler.Gelen;

// Every few minutes: new inbox cards get a suggestion from Claude. With Claude or the brain not set up it does
// nothing at all, quietly. The daily cap of ClaudeIstemcisi decides how many calls a day; when it is reached the round ends.
public class GelenOneriServisi(IServiceScopeFactory kapsamlar, ClaudeAyari claudeAyari, BeyinAyari beyinAyari, GelenAyari ayar, ILogger<GelenOneriServisi> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (!claudeAyari.Acik || !beyinAyari.Acik)
        {
            log.LogInformation("Claude or the brain is not configured; inbox cards get no suggestions.");
            return;
        }

        // The first round comes after one interval, not at start-up: a restart does not fire a burst of Claude calls.
        using var zamanlayici = new PeriodicTimer(ayar.OneriAraligi);
        while (await zamanlayici.WaitForNextTickAsync(ct))
        {
            try
            {
                using var kapsam = kapsamlar.CreateScope();
                var ozet = await kapsam.ServiceProvider.GetRequiredService<GelenOnerici>().TurAsync(ct);
                if (ozet.Onerilen + ozet.Basarisiz + ozet.Atlanan > 0)
                    log.LogInformation("Inbox suggestions: {Made} made, {Failed} failed (will retry), {Skipped} skipped.", ozet.Onerilen, ozet.Basarisiz, ozet.Atlanan);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "The inbox suggestion round failed.");
            }
        }
    }
}

public static class GelenServisleri
{
    public static IServiceCollection AddGelen(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(GelenAyari.Oku(config));
        services.AddScoped<GelenOnerici>();
        services.AddHostedService<GelenOneriServisi>();
        return services;
    }
}
