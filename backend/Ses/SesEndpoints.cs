using System.Security.Claims;
using Kafamdakiler.Claude;

namespace Kafamdakiler.Ses;

// Voice and text (K2.4). The phone turns speech into text (K2.4 karar 8: no audio file, nothing audio reaches the server); these
// endpoints work on that text. Nothing here saves anything except `uygula`, and that only for what the person chose in the preview.
public static class SesEndpoints
{
    public static void MapSesEndpoints(this IEndpointRouteBuilder app)
    {
        var asistan = app.MapGroup("/api").WithTags("Ses").RequireAuthorization(SesPolicies.AsistanKullan);

        // Whether the assistant is connected (Claude:Komut set), so a client can hide the buttons that would only fail.
        asistan.MapGet("/asistan/durum", (ClaudeAyari ayar) => Results.Ok(new AsistanDurumu(ayar.Acik)));

        // The preview: Claude suggests, nothing is saved.
        asistan.MapPost("/is-cikar", async (IsCikarGirdi girdi, IsCikarServisi servis, CancellationToken ct) =>
        {
            var sonuc = await servis.CikarAsync(girdi, ct);
            return sonuc.Hata ?? Results.Ok(sonuc.Veri);
        });

        // A summary or a bullet list of the text. Saves nothing: the person decides what to do with it.
        asistan.MapPost("/metin/yeniden-yaz", async (YenidenYazGirdi girdi, IsCikarServisi servis, CancellationToken ct) =>
        {
            var sonuc = await servis.YenidenYazAsync(girdi, ct);
            return sonuc.Hata ?? Results.Ok(sonuc.Veri);
        });

        // The chosen suggestions are applied one by one: 200 when all went through, 207 when some did not (the others stay applied).
        var uygula = app.MapGroup("/api/is-cikar").WithTags("Ses").RequireAuthorization(SesPolicies.Uygula);

        uygula.MapPost("/uygula", async (IsCikarUygulaGirdi girdi, IsCikarServisi servis, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            var sonuc = await servis.UygulaAsync(girdi, kullanici, ct);
            if (sonuc.Hata is not null)
                return sonuc.Hata;

            return Results.Json(sonuc.Veri, statusCode: sonuc.Veri!.Basarisiz == 0 ? StatusCodes.Status200OK : StatusCodes.Status207MultiStatus);
        });
    }
}

public static class SesServisleri
{
    public static IServiceCollection AddSes(this IServiceCollection services)
    {
        services.AddScoped<IsCikarServisi>();
        return services;
    }
}
