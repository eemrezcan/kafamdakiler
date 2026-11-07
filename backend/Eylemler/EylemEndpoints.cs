using System.Security.Claims;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Eylemler;

// The approval queue (K2.6). There is no endpoint to add a suggestion: the modules that make them (inbox, voice,
// briefing...) call EylemServisi.OnerAsync inside the app.
public static class EylemEndpoints
{
    public static void MapEylemEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api/eylemler").WithTags("Eylemler")
            .RequireAuthorization(EylemPolicies.Oku);
        var onayla = app.MapGroup("/api/eylemler").WithTags("Eylemler")
            .RequireAuthorization(EylemPolicies.Onayla);

        // `durum`: bekliyor (default), uygulandi, reddedildi, geriAlindi or hatali.
        oku.MapGet("/", async (EylemServisi servis, CancellationToken ct, string? durum = null) =>
        {
            var filtre = EylemDurumu.Bekliyor;
            if (!string.IsNullOrEmpty(durum) && (!Enum.TryParse(durum, ignoreCase: true, out filtre) || !Enum.IsDefined(filtre)))
                return Sorun("durum", "Durum bekliyor, uygulandi, reddedildi, geriAlindi ya da hatali olmalı.");

            var liste = await servis.ListeAsync(filtre, ct);
            return Results.Ok(liste.Select(servis.DtoYap).ToList());
        });

        oku.MapGet("/{id:guid}", async (Guid id, EylemServisi servis, CancellationToken ct) =>
            await servis.GetirAsync(id, ct) is { } eylem ? Results.Ok(servis.DtoYap(eylem)) : Results.NotFound());

        // The body is optional: with a `yuk` it replaces the suggested payload (checked again) before applying.
        onayla.MapPost("/{id:guid}/uygula", async (Guid id, EylemServisi servis, ClaimsPrincipal kullanici, CancellationToken ct, EylemUygulaDto? dto = null) =>
            Yanit(servis, await servis.UygulaAsync(id, dto?.Yuk, KullaniciId(kullanici), ct)));

        onayla.MapPost("/{id:guid}/reddet", async (Guid id, EylemServisi servis, ClaimsPrincipal kullanici, CancellationToken ct, EylemReddetDto? dto = null) =>
            Yanit(servis, await servis.ReddetAsync(id, dto?.BirDahaOnerme ?? false, KullaniciId(kullanici), ct)));

        // 409 unless the action was applied.
        onayla.MapPost("/{id:guid}/geri-al", async (Guid id, EylemServisi servis, ClaimsPrincipal kullanici, CancellationToken ct) =>
            Yanit(servis, await servis.GeriAlAsync(id, KullaniciId(kullanici), ct)));
    }

    internal static Guid? KullaniciId(ClaimsPrincipal kullanici) =>
        Guid.TryParse(kullanici.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;

    private static IResult Yanit(EylemServisi servis, EylemSonucu sonuc) => sonuc.Tur switch
    {
        EylemSonucuTuru.Tamam => Results.Ok(servis.DtoYap(sonuc.Eylem!)),
        EylemSonucuTuru.Bulunamadi => Results.NotFound(),
        EylemSonucuTuru.Gecersiz => Sorun(sonuc.Alan ?? "yuk", sonuc.Mesaj!),
        EylemSonucuTuru.Catisma => Cakisma(sonuc.Mesaj!),
        _ => Results.Problem(title: "Eylem işlenemedi", detail: sonuc.Mesaj, statusCode: StatusCodes.Status500InternalServerError),
    };
}
