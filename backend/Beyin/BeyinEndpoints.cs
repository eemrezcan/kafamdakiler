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

        beyin.MapGet("/gunler/{tarih}", (string tarih, BeyinIstemcisi b, GunAyari ayar, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Gun(tarih, b, log, ct, ayar));

        // The morning card: yesterday's plan, what is still open (yesterday by the 05:00 day-turn rule, worked out here).
        beyin.MapGet("/sabah", (BeyinIstemcisi b, TimeProvider saat, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Sabah(b, log, saat, ct));

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
