using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;

namespace Kafamdakiler.Dosyalar;

public record DosyaYuklendiDto(Guid Id, string Url);

public static class DosyaEndpoints
{
    public static void MapDosyaEndpoints(this IEndpointRouteBuilder app)
    {
        var dosyalar = app.MapGroup("/api/dosyalar").WithTags("Dosyalar");

        // Bearer only, so no antiforgery token is needed.
        dosyalar.MapPost("/", async (IFormFile dosya, DosyaDeposu depo, CancellationToken ct) =>
        {
            var (kayit, hata) = await depo.YukleAsync(dosya, ct);
            if (kayit is null)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["dosya"] = [hata!] });

            var url = $"/api/dosyalar/{kayit.Id}";
            return Results.Created(url, new DosyaYuklendiDto(kayit.Id, url));
        })
        .DisableAntiforgery()
        .RequireAuthorization(AliskanlikPolicies.Yaz);

        dosyalar.MapGet("/{id:guid}", async (Guid id, AppDbContext db, DosyaDeposu depo, CancellationToken ct) =>
        {
            var kayit = await db.Dosyalar.FindAsync([id], ct);
            if (kayit is null)
                return Results.NotFound();

            var yol = depo.YolBul(kayit);
            return File.Exists(yol) ? Results.File(yol, kayit.IcerikTuru) : Results.NotFound();
        })
        .RequireAuthorization(AliskanlikPolicies.DosyaOku);
    }
}
