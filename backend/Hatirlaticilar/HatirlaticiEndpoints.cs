using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;
using static Kafamdakiler.Hatirlaticilar.HatirlaticiIslemleri;

namespace Kafamdakiler.Hatirlaticilar;

public static class HatirlaticiEndpoints
{
    public static void MapHatirlaticiEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api/hatirlaticilar").WithTags("Hatirlaticilar")
            .RequireAuthorization(HatirlaticiPolicies.Oku);
        var yaz = app.MapGroup("/api/hatirlaticilar").WithTags("Hatirlaticilar")
            .RequireAuthorization(HatirlaticiPolicies.Yaz);

        // `durum`: acik, tamam or arsiv. `yaklasan=N`: open reminders due within N days (overdue ones included).
        oku.MapGet("/", async (AppDbContext db, TimeProvider saat, CancellationToken ct, string? durum = null, int? yaklasan = null) =>
        {
            HatirlaticiDurumu? filtre = null;
            if (!string.IsNullOrEmpty(durum))
            {
                if (!Enum.TryParse<HatirlaticiDurumu>(durum, ignoreCase: true, out var d) || !Enum.IsDefined(d))
                    return Sorun("durum", "Durum acik, tamam ya da arsiv olmalı.");
                filtre = d;
            }

            if (yaklasan is < 0 or > 3650)
                return Sorun("yaklasan", "Yaklaşan gün sayısı 0 ile 3650 arasında olmalı.");

            var simdi = saat.GetUtcNow();
            if (yaklasan is { } gun)
            {
                filtre ??= HatirlaticiDurumu.Acik;
                // Up to the end of the Nth day from today (Istanbul).
                var sinir = HatirlaticiHesap.An(HatirlaticiHesap.IstanbulGunu(simdi).AddDays(gun + 1), TimeOnly.MinValue);
                var yaklasanlar = await db.Hatirlaticilar
                    .Where(h => h.Durum == filtre && (h.ErteleAn ?? h.SonrakiAn) < sinir)
                    .OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id).ToListAsync(ct);
                return Results.Ok(yaklasanlar.Select(h => DtoYap(h, simdi)).ToList());
            }

            var liste = await db.Hatirlaticilar.Where(h => filtre == null || h.Durum == filtre)
                .OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id).ToListAsync(ct);
            return Results.Ok(liste.Select(h => DtoYap(h, simdi)).ToList());
        });

        oku.MapGet("/{id:guid}", async (Guid id, AppDbContext db, TimeProvider saat, CancellationToken ct) =>
        {
            var h = await db.Hatirlaticilar.FindAsync([id], ct);
            return h is null ? Results.NotFound() : Results.Ok(DtoYap(h, saat.GetUtcNow()));
        });

        yaz.MapPost("/", async (HatirlaticiYazDto dto, AppDbContext db, HatirlaticiAyari ayar, TimeProvider saat, CancellationToken ct) =>
        {
            var simdi = saat.GetUtcNow();
            // The same client id twice (an offline retry) returns the existing record.
            if (dto.Id is { } id && await db.Hatirlaticilar.FindAsync([id], ct) is { } mevcut)
                return Results.Ok(DtoYap(mevcut, simdi));

            var h = new Hatirlatici();
            if (dto.Id is { } yeniId)
                h.Id = yeniId;
            Uygula(h, dto, ayar.VarsayilanSaat, simdi);
            db.Hatirlaticilar.Add(h);
            await db.SaveChangesAsync(ct);

            return Results.Created($"/api/hatirlaticilar/{h.Id}", DtoYap(h, simdi));
        });

        yaz.MapPut("/{id:guid}", async (Guid id, HatirlaticiYazDto dto, AppDbContext db, HatirlaticiAyari ayar, TimeProvider saat, CancellationToken ct) =>
        {
            var h = await db.Hatirlaticilar.FindAsync([id], ct);
            if (h is null)
                return Results.NotFound();

            var simdi = saat.GetUtcNow();
            Uygula(h, dto, ayar.VarsayilanSaat, simdi);
            await db.SaveChangesAsync(ct);
            return Results.Ok(DtoYap(h, simdi));
        });

        yaz.MapDelete("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var h = await db.Hatirlaticilar.FindAsync([id], ct);
            if (h is null)
                return Results.NotFound();

            db.Hatirlaticilar.Remove(h);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        yaz.MapPost("/{id:guid}/yaptim", async (Guid id, AppDbContext db, HatirlaticiAyari ayar, TimeProvider saat, CancellationToken ct) =>
        {
            var h = await db.Hatirlaticilar.FindAsync([id], ct);
            if (h is null)
                return Results.NotFound();

            var simdi = saat.GetUtcNow();
            var sonuc = Yaptim(db, h, ayar.VarsayilanSaat, simdi);
            if (!sonuc.Basarili)
                return Yanit(sonuc);

            await db.SaveChangesAsync(ct);
            return Results.Ok(DtoYap(h, simdi));
        });

        yaz.MapPost("/{id:guid}/ertele", async (Guid id, ErteleDto dto, AppDbContext db, HatirlaticiAyari ayar, TimeProvider saat, CancellationToken ct) =>
        {
            var h = await db.Hatirlaticilar.FindAsync([id], ct);
            if (h is null)
                return Results.NotFound();

            var simdi = saat.GetUtcNow();
            var sonuc = Ertele(db, h, dto.Sure, ayar.VarsayilanSaat, simdi);
            if (!sonuc.Basarili)
                return Yanit(sonuc);

            await db.SaveChangesAsync(ct);
            return Results.Ok(DtoYap(h, simdi));
        });
    }
}
