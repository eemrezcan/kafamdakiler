using Kafamdakiler.Claude;
using Kafamdakiler.Takvim;

namespace Kafamdakiler.Gmail;

// When the last scan round got as far as asking Gmail. Held in memory: after a restart it is empty until the next round.
public class GmailTaramaDurumu
{
    private long _sonTarama;

    public DateTimeOffset? SonTarama
    {
        get => Volatile.Read(ref _sonTarama) is var tik and > 0 ? new DateTimeOffset(tik, TimeSpan.Zero) : null;
        set => Volatile.Write(ref _sonTarama, value?.UtcTicks ?? 0);
    }
}

// Every few minutes: the primary inbox is scanned. With Gmail switched off in the settings, or Google or Claude not set up, it does nothing
// at all, quietly. The first round comes after one interval, not at start-up: a restart does not fire a burst of Claude calls.
public class GmailTaramaServisi(
    IServiceScopeFactory kapsamlar, GmailAyari ayar, TakvimAyari takvimAyari, ClaudeAyari claudeAyari, ILogger<GmailTaramaServisi> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (!ayar.Acik || !takvimAyari.Acik || !claudeAyari.Acik)
        {
            log.LogInformation("Gmail scan is off (Gmail:Acik, the Google settings and Claude:Komut must all be set).");
            return;
        }

        using var zamanlayici = new PeriodicTimer(ayar.Aralik);
        while (await zamanlayici.WaitForNextTickAsync(ct))
        {
            try
            {
                using var kapsam = kapsamlar.CreateScope();
                var ozet = await kapsam.ServiceProvider.GetRequiredService<GmailTarayici>().TurAsync(ct);
                if (ozet.ErisimSorunu is { } sorun)
                    log.LogInformation("Gmail scan waits: {Sorun}.", sorun);
                else if (ozet.SinirDoldu)
                    log.LogInformation("Gmail scan stopped: Claude's daily calls are nearly used up.");

                if (ozet.Islenen + ozet.Atlanan + ozet.Basarisiz > 0)
                    log.LogInformation("Gmail scan: {Read} read ({Suggested} suggestions), {Skipped} skipped, {Failed} failed (will retry).", ozet.Islenen, ozet.Onerilen, ozet.Atlanan, ozet.Basarisiz);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "The Gmail scan round failed.");
            }
        }
    }
}

public static class GmailServisleri
{
    public static IServiceCollection AddGmail(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(GmailAyari.Oku(config));
        services.AddSingleton<IGmailIstemcisi, GmailIstemcisi>();
        services.AddSingleton<GmailTaramaDurumu>();
        services.AddScoped<GmailTarayici>();
        services.AddHostedService<GmailTaramaServisi>();
        return services;
    }
}
