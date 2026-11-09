namespace Kafamdakiler.Ozet;

// The "HaftalikOzet" settings: how often the server looks whether a week's summary is due, and how long after start-up it first looks.
public class HaftalikOzetAyari
{
    public TimeSpan KontrolAraligi { get; init; } = TimeSpan.FromMinutes(10);

    // The first look comes a little after start-up (not at once), so a missed Sunday is made up on the next opening.
    public TimeSpan IlkGecikme { get; init; } = TimeSpan.FromSeconds(30);

    public static HaftalikOzetAyari Oku(IConfiguration config)
    {
        var bolum = config.GetSection("HaftalikOzet");
        return new HaftalikOzetAyari
        {
            KontrolAraligi = TimeSpan.FromMinutes(Math.Max(0.05, bolum.GetValue("KontrolDakika", 10.0))),
            IlkGecikme = TimeSpan.FromSeconds(Math.Max(0, bolum.GetValue("IlkGecikmeSaniye", 30.0))),
        };
    }
}

// Every few minutes: is this week's summary due (Sunday 21:00, Istanbul) or last week's still missing? Then it is written, once.
// Without the brain nothing is written and the next round tries again.
public class HaftalikOzetServisi(IServiceScopeFactory kapsamlar, HaftalikOzetAyari ayar, ILogger<HaftalikOzetServisi> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await Task.Delay(ayar.IlkGecikme, ct);
        using var zamanlayici = new PeriodicTimer(ayar.KontrolAraligi);
        do
        {
            try
            {
                using var kapsam = kapsamlar.CreateScope();
                var sonuc = await kapsam.ServiceProvider.GetRequiredService<HaftalikOzetYazici>().TurAsync(ct);
                if (sonuc.Durum == OzetDurumu.Yazildi)
                    log.LogInformation("The weekly summary for {Hafta} was written.", sonuc.Hafta);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "The weekly summary round failed.");
            }
        }
        while (await zamanlayici.WaitForNextTickAsync(ct));
    }
}

public static class HaftalikOzetServisleri
{
    public static IServiceCollection AddHaftalikOzet(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(HaftalikOzetAyari.Oku(config));
        services.AddScoped<HaftalikOzetYazici>();
        services.AddHostedService<HaftalikOzetServisi>();
        return services;
    }
}
