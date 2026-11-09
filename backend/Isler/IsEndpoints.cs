using System.Security.Claims;
using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Mvc;

namespace Kafamdakiler.Isler;

// /api/isler: the work cards of the brain for the phone. Reading needs `isler.oku`, writing `isler.yaz` (the Sahip passes both).
// Every write can carry an `Idempotency-Key` like the other brain writes (TekrarGuvenligi).
public static class IsEndpoints
{
    public static void MapIsEndpoints(this IEndpointRouteBuilder app)
    {
        const string Anahtar = TekrarGuvenligi.Baslik;

        var oku = app.MapGroup("/api/isler").WithTags("Isler")
            .RequireAuthorization(IsPolicies.Oku);

        oku.MapGet("/", (string? asama, string? proje, bool? kapali, BeyinIstemcisi b, TimeProvider saat, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            IsOkuma(IsKartlari.ListeAl(asama, proje, kapali ?? false, b, log, saat, ct)));

        oku.MapGet("/{kimlik}", (string kimlik, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
            IsOkuma(IsKartlari.Al(kimlik, b, log, ct)));

        var yaz = app.MapGroup("/api/isler").WithTags("Isler")
            .RequireAuthorization(IsPolicies.Yaz);

        yaz.MapPost("/", (IsAcGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "is-ac", new { girdi }, () => IsKartlari.Ac(girdi, b, log, CancellationToken.None), CancellationToken.None));

        yaz.MapPost("/{kimlik}/cevap", (string kimlik, IsCevapGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "is-cevap", new { kimlik, girdi }, () => IsKartlari.Cevapla(kimlik, girdi, b, log, CancellationToken.None), CancellationToken.None));

        yaz.MapPost("/{kimlik}/asama", (string kimlik, IsAsamaGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, TimeProvider saat, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "is-asama", new { kimlik, girdi }, () => IsKartlari.AsamaDegistir(kimlik, girdi, b, log, saat, CancellationToken.None), CancellationToken.None));

        yaz.MapPost("/{kimlik}/not", (string kimlik, IsNotGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "is-not", new { kimlik, girdi }, () => IsKartlari.NotYaz(kimlik, girdi, b, log, CancellationToken.None), CancellationToken.None));
    }

    private static async Task<IResult> IsOkuma<T>(Task<BeyinYaniti<T>> yanit) => (await yanit).Sonuc();
}
