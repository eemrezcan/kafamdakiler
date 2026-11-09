using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Isler;

namespace Kafamdakiler.Bildirimler;

// The one timer of the notification line. Every minute: the reminders that came due are sent, and the work cards that have fallen to the person are told about. At the set hours of the day
// (Istanbul): the brain's due tasks are looked at, once for each hour. A late start (the server was down at 09:00) still makes that
// hour's round if it is within the window; later than that the hour is skipped, not made up.
public class BildirimZamanlayici(IServiceScopeFactory kapsamlar, BildirimHattiAyari ayar, TimeProvider saat, ILogger<BildirimZamanlayici> log) : BackgroundService
{
    // The hours already looked at in this run, by day and hour. A restart inside the window looks again; the daily key of a
    // task notification keeps that from telling anyone twice.
    private readonly HashSet<(DateOnly Gun, TimeOnly Saat)> _yapilanlar = [];

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await Task.Delay(ayar.IlkGecikme, ct);
        using var zamanlayici = new PeriodicTimer(ayar.KontrolAraligi);
        do
        {
            await TurAsync(ct);
        }
        while (await zamanlayici.WaitForNextTickAsync(ct));
    }

    // One round. Public so a test can run it without waiting for the timer.
    public async Task TurAsync(CancellationToken ct)
    {
        try
        {
            using var kapsam = kapsamlar.CreateScope();
            var yapilan = await kapsam.ServiceProvider.GetRequiredService<HatirlaticiBildirimci>().TurAsync(ct);
            if (yapilan > 0)
                log.LogInformation("{Sayi} reminder notification(s) were sent.", yapilan);

            // The card watcher is its own try: a trouble with the brain's cards must not stop the task round below.
            try
            {
                var isler = await kapsam.ServiceProvider.GetRequiredService<IsBildirimci>().TurAsync(ct);
                if (isler.Bildirilen > 0)
                    log.LogInformation("{Sayi} work card notification(s) were sent.", isler.Bildirilen);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "The work card round failed.");
            }

            if (GorevSaati(ayar, saat.GetUtcNow()) is { } vakit && !_yapilanlar.Contains(vakit))
            {
                var ozet = await kapsam.ServiceProvider.GetRequiredService<GorevBildirimci>().TurAsync(ct);
                // The brain did not answer: this hour stays open and the next minute tries again, until the window ends.
                if (ozet.Okundu)
                {
                    _yapilanlar.Add(vakit);
                    // Yesterday's hours are of no use any more.
                    _yapilanlar.RemoveWhere(v => v.Gun < vakit.Gun);
                    log.LogInformation("Task round {Saat}: {Aday} candidate(s), {Kapatilan} closed, {Sorulan} asked, {Hatirlatilan} reminded.",
                        vakit.Saat, ozet.Aday, ozet.Kapatilan, ozet.Sorulan, ozet.Hatirlatilan);
                }
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogError(e, "The notification round failed.");
        }
    }

    // The hour of the day whose window `simdi` is in, or null.
    public static (DateOnly Gun, TimeOnly Saat)? GorevSaati(BildirimHattiAyari ayar, DateTimeOffset simdi)
    {
        var gun = HatirlaticiHesap.IstanbulGunu(simdi);
        foreach (var saatDilimi in ayar.GorevSaatleri.OrderDescending())
        {
            var baslangic = HatirlaticiHesap.An(gun, saatDilimi);
            if (simdi >= baslangic && simdi < baslangic + ayar.GorevPenceresi)
                return (gun, saatDilimi);
        }

        return null;
    }
}

public static class BildirimHattiServisleri
{
    public static IServiceCollection AddBildirimHatti(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(BildirimHattiAyari.Oku(config));
        services.AddSingleton<IKomitOkuyucu, GitKomitOkuyucu>();
        services.AddScoped<HatirlaticiBildirimci>();
        services.AddScoped<GorevBildirimci>();
        services.AddScoped<IsBildirimci>();
        services.AddSingleton<BildirimZamanlayici>();
        services.AddHostedService(sp => sp.GetRequiredService<BildirimZamanlayici>());
        return services;
    }
}
