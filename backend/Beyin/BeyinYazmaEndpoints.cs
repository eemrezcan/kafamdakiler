using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;

namespace Kafamdakiler.Beyin;

// The writes (K2.3a). Every one can carry an `Idempotency-Key` header (TekrarGuvenligi): the phone's offline queue sends the
// same request twice now and then, and the second one must not write again. The plan item is named in the body by its
// permanent id; the date is in the route and always reaches the brain explicitly.
public static class BeyinYazmaEndpoints
{
    public static void MapBeyinYazmaEndpoints(this IEndpointRouteBuilder app)
    {
        const string Anahtar = TekrarGuvenligi.Baslik;

        var plan = app.MapGroup("/api/beyin/gunler/{tarih}").WithTags("Beyin")
            .RequireAuthorization(BeyinPolicies.PlanYaz);

        plan.MapPost("/maddeler", (string tarih, MaddeEkleGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "madde-ekle", new { tarih, girdi }, () => BeyinYazma.MaddeEkle(tarih, girdi, b, log, CancellationToken.None), CancellationToken.None));

        plan.MapPost("/isaretle", (string tarih, MaddeIsaretleGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "madde-isaretle", new { tarih, girdi }, () => BeyinYazma.MaddeIsaretle(tarih, girdi, b, log, CancellationToken.None), CancellationToken.None));

        plan.MapPost("/devret", (string tarih, MaddeDevretGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "madde-devret", new { tarih, girdi }, () => BeyinYazma.MaddeDevret(tarih, girdi, b, log, CancellationToken.None), CancellationToken.None));

        plan.MapPost("/not", (string tarih, MaddeNotGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "madde-not", new { tarih, girdi }, () => BeyinYazma.MaddeNotu(tarih, girdi, b, log, CancellationToken.None), CancellationToken.None));

        // Splitting a task over days writes plan items: the plan permission, not the task one.
        var bol = app.MapGroup("/api/beyin/gorevler").WithTags("Beyin")
            .RequireAuthorization(BeyinPolicies.PlanYaz);

        bol.MapPost("/{kimlik}/gunlere-bol", (string kimlik, GunlereBolGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, TimeProvider saat, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "gunlere-bol", new { kimlik, girdi }, () => BeyinYazma.GunlereBol(kimlik, girdi, b, log, saat, CancellationToken.None), CancellationToken.None));

        var gorev = app.MapGroup("/api/beyin/gorevler").WithTags("Beyin")
            .RequireAuthorization(BeyinPolicies.GorevYaz);

        gorev.MapPost("/", (GorevEkleGirdi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "gorev-ekle", new { girdi }, () => BeyinYazma.GorevEkle(girdi, b, log, CancellationToken.None), CancellationToken.None));

        gorev.MapPost("/{kimlik}/bitir", (string kimlik, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
                TekrarGuvenligi tekrar, BeyinIstemcisi b, TimeProvider saat, ILogger<BeyinIstemcisi> log) =>
            tekrar.CalistirAsync(kullanici, anahtar, "gorev-bitir", new { kimlik }, () => BeyinYazma.GorevBitir(kimlik, b, log, saat, CancellationToken.None), CancellationToken.None));
    }
}
