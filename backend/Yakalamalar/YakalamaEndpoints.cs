using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.EntityFrameworkCore;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;
using static Kafamdakiler.Yakalamalar.YakalamaIslemleri;

namespace Kafamdakiler.Yakalamalar;

public static class YakalamaEndpoints
{
    public static void MapYakalamaEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api/yakalamalar").WithTags("Yakalamalar")
            .RequireAuthorization(YakalamaPolicies.Oku);
        var yaz = app.MapGroup("/api/yakalamalar").WithTags("Yakalamalar")
            .RequireAuthorization(YakalamaPolicies.Yaz);

        oku.MapGet("/", async (AppDbContext db, CancellationToken ct, string? durum = null) =>
        {
            // The query takes the same camelCase text as the JSON ("beyneGitti"); enum binding would only take "BeyneGitti".
            YakalamaDurumu? filtre = null;
            if (!string.IsNullOrEmpty(durum))
            {
                if (!Enum.TryParse<YakalamaDurumu>(durum, ignoreCase: true, out var d) || !Enum.IsDefined(d))
                    return Sorun("durum", "Durum bekliyor, beyneGitti ya da islendi olmalı.");
                filtre = d;
            }

            var liste = await db.Yakalamalar.Where(y => filtre == null || y.Durum == filtre)
                .OrderByDescending(y => y.YakalandiAt).ThenByDescending(y => y.Id).ToListAsync(ct);
            return Results.Ok(liste.Select(DtoYap).ToList());
        });

        oku.MapGet("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var y = await db.Yakalamalar.FindAsync([id], ct);
            return y is null ? Results.NotFound() : Results.Ok(DtoYap(y));
        });

        yaz.MapPost("/", async (YakalamaYazDto dto, AppDbContext db, CancellationToken ct) =>
        {
            // The same client id twice (an offline retry) returns the existing record.
            if (dto.Id is { } id && await db.Yakalamalar.FindAsync([id], ct) is { } mevcut)
                return Results.Ok(DtoYap(mevcut));

            var (sonuc, y) = await OlusturAsync(db, dto, ct);
            return sonuc.Basarili ? Results.Created($"/api/yakalamalar/{y!.Id}", DtoYap(y)) : Yanit(sonuc);
        });

        yaz.MapPut("/{id:guid}", async (Guid id, YakalamaYazDto dto, AppDbContext db, DosyaDeposu depo, CancellationToken ct) =>
        {
            var y = await db.Yakalamalar.FindAsync([id], ct);
            if (y is null)
                return Results.NotFound();

            var sonuc = await GuncelleAsync(db, depo, y, dto, ct);
            return sonuc.Basarili ? Results.Ok(DtoYap(y)) : Yanit(sonuc);
        });

        yaz.MapDelete("/{id:guid}", async (Guid id, AppDbContext db, DosyaDeposu depo, CancellationToken ct) =>
        {
            var y = await db.Yakalamalar.FindAsync([id], ct);
            if (y is null)
                return Results.NotFound();

            var sonuc = await SilAsync(db, depo, y, ct);
            return sonuc.Basarili ? Results.NoContent() : Yanit(sonuc);
        });
    }

    internal static YakalamaDto DtoYap(Yakalama y) =>
        new(y.Id, y.Metin, y.FotografId, OgeEndpoints.FotografUrl(y.FotografId), y.Hedef, y.Durum, y.YakalandiAt, y.CreatedAt, y.DenemeSayisi, y.SonHata);
}
