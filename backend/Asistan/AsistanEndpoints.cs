using System.Security.Claims;
using Kafamdakiler.Ses;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Asistan;

// The assistant's single entry and its feed (K-0024, §7). All of it needs `asistan.kullan`; what an input does is checked against the permission of
// what it touches, one result at a time (AsistanServisi). The existing /api/asistan/durum and /api/is-cikar are not touched.
public static class AsistanEndpoints
{
    public static void MapAsistanEndpoints(this IEndpointRouteBuilder app)
    {
        var asistan = app.MapGroup("/api/asistan").WithTags("Asistan").RequireAuthorization(SesPolicies.AsistanKullan);

        // The one entry. The same `id` again is the same answer.
        asistan.MapPost("/girdi", async (AsistanGirdisiDto girdi, AsistanServisi servis, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            var sonuc = await servis.GirdiAsync(girdi, kullanici, ct);
            return sonuc.Hata ?? Results.Ok(sonuc.Veri);
        });

        // The answer to the one question the assistant asked.
        asistan.MapPost("/sorular/{id:guid}/cevap", async (Guid id, AsistanCevabiDto dto, AsistanServisi servis, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            var sonuc = await servis.CevapAsync(id, dto.Cevap!, kullanici, ct);
            return sonuc.Hata ?? Results.Ok(sonuc.Veri);
        });

        asistan.MapGet("/akis", async (AsistanAkisi akis, ClaimsPrincipal kullanici, CancellationToken ct, DateTimeOffset? once = null, int limit = AsistanAkisi.VarsayilanSatir, string suzgec = "hepsi") =>
        {
            if (Kafamdakiler.Eylemler.EylemEndpoints.KullaniciId(kullanici) is not { } kullaniciId)
                return Results.Unauthorized();
            if (limit is < 1 or > AsistanAkisi.EnCokSatir)
                return Sorun("limit", $"Satır sayısı 1 ile {AsistanAkisi.EnCokSatir} arasında olmalı.");
            if (!AsistanAkisi.Suzgecler.Contains(suzgec))
                return Sorun("suzgec", "Süzgeç hepsi, bekleyen, isler ya da notlar olmalı.");

            return Results.Ok(await akis.AkisAsync(kullanici, kullaniciId, once, limit, suzgec, ct));
        });

        // The badge: how many things wait for the person.
        asistan.MapGet("/sayi", async (AsistanAkisi akis, ClaimsPrincipal kullanici, CancellationToken ct) =>
            Kafamdakiler.Eylemler.EylemEndpoints.KullaniciId(kullanici) is not { } kullaniciId
                ? Results.Unauthorized()
                : Results.Ok(new AsistanSayisiDto(await akis.BekleyenSayisiAsync(kullanici, kullaniciId, ct))));
    }

    public static IServiceCollection AddAsistan(this IServiceCollection services)
    {
        services.AddScoped<AsistanSiniflandirici>();
        services.AddScoped<AsistanServisi>();
        services.AddScoped<AsistanAkisi>();
        return services;
    }
}
