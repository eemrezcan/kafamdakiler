using Kafamdakiler.Ayarlar;
using Kafamdakiler.Data;
using Kafamdakiler.ProjeRepolari;

namespace Kafamdakiler.Beyin;

// /api/beyin: views of the second brain for the phone (K-0023), which need the `beyin.oku` permission, and the writes of
// the day plan and tasks (K2.3a, BeyinYazmaEndpoints), which need `plan.yaz` and `gorev.yaz`.
public static class BeyinEndpoints
{
    public static void MapBeyinEndpoints(this IEndpointRouteBuilder app)
    {
        var beyin = app.MapGroup("/api/beyin").WithTags("Beyin")
            .RequireAuthorization(BeyinPolicies.Oku);

        beyin.MapGet("/durum", BeyinOkuma.Durum);

        beyin.MapGet("/projeler", (BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Projeler(b, log, ct));

        beyin.MapGet("/projeler/{kimlik}", (string kimlik, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Proje(kimlik, b, log, ct));

        // The day's warning counts against the person's capacity for that kind of day (weekday or weekend, Ayarlar/GunAyarlari).
        beyin.MapGet("/gunler/{tarih}", async (string tarih, BeyinIstemcisi b, AppDbContext db, GunAyari ayar, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            await BeyinOkuma.Gun(tarih, b, log, ct, ayar, await GunKapasitesi.DkAsync(db, ayar, tarih, ct), b.Bagli ? await BeyinOkuma.IzinliGorevlerAl(b, log, ct) : null));

        // The morning card: yesterday's plan, what is still open (yesterday by the 05:00 day-turn rule, worked out here).
        // Both leave out what links to a task the API may not show (E9): the old screens get the same filter as the new ones.
        beyin.MapGet("/sabah", async (BeyinIstemcisi b, TimeProvider saat, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            await BeyinOkuma.Sabah(b, log, saat, ct, b.Bagli ? await BeyinOkuma.IzinliGorevlerAl(b, log, ct) : null));

        beyin.MapGet("/ara", (string? q, string? proje, int? limit, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Ara(q, proje, limit, b, log, ct));

        beyin.MapGet("/not", (string? yol, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Not(yol, b, log, ct));

        beyin.MapProjeRepoOkumaEndpoints();

        app.MapBeyinYazmaEndpoints();
    }

    // The day-plan setting and the repeat guard (scoped: it uses the database).
    public static IServiceCollection AddBeyinYazma(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(GunAyari.Oku(config));
        services.AddScoped<TekrarGuvenligi>();
        return services;
    }
}
