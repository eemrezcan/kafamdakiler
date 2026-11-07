namespace Kafamdakiler.Brifing;

// Every few minutes: is it time for today's briefing, and is there none yet? Then it is made. It works without Claude
// (the rules make the cards) and without the brain (those parts are empty), so unlike the inbox it never switches itself off.
// With the brain set up but unreadable nothing is stored, and the next round tries again.
public class BrifingServisi(IServiceScopeFactory kapsamlar, BrifingAyari ayar, ILogger<BrifingServisi> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (ayar.Uyari is not null)
            log.LogWarning("{Uyari}", ayar.Uyari);

        // The first look comes after one interval, not at start-up: a restart does not fire a burst of work. A person who opens the
        // app first gets the briefing made on the spot (BrifingHazirlayici.BugunAsync).
        using var zamanlayici = new PeriodicTimer(ayar.KontrolAraligi);
        while (await zamanlayici.WaitForNextTickAsync(ct))
        {
            try
            {
                using var kapsam = kapsamlar.CreateScope();
                var sonuc = await kapsam.ServiceProvider.GetRequiredService<BrifingHazirlayici>().TurAsync(ct);
                if (sonuc.Durum == BrifingDurumu.GirdiOkunamadi)
                    log.LogWarning("The briefing could not be made: {Mesaj} It will be tried again.", sonuc.Mesaj);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "The briefing round failed.");
            }
        }
    }
}

public static class BrifingServisleri
{
    public static IServiceCollection AddBrifing(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(BrifingAyari.Oku(config));
        services.AddScoped<BrifingGirdiOkuyucu>();
        services.AddScoped<BrifingHazirlayici>();
        services.AddHostedService<BrifingServisi>();
        return services;
    }
}
