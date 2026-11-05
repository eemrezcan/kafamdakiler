namespace Kafamdakiler.Beyin;

// /api/beyin: read-only views of the second brain for the phone (K-0023). Needs the `beyin.oku` permission.
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

        beyin.MapGet("/gunler/{tarih}", (string tarih, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Gun(tarih, b, log, ct));

        beyin.MapGet("/ara", (string? q, string? proje, int? limit, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Ara(q, proje, limit, b, log, ct));

        beyin.MapGet("/not", (string? yol, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            BeyinOkuma.Not(yol, b, log, ct));
    }
}
