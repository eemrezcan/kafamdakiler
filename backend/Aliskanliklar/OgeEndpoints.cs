using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.EntityFrameworkCore;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;
using static Kafamdakiler.Aliskanliklar.AliskanlikIslemleri;

namespace Kafamdakiler.Aliskanliklar;

public static class OgeEndpoints
{
    public static void MapOgeEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api").WithTags("Öğeler ve oturumlar")
            .RequireAuthorization(AliskanlikPolicies.Oku);
        var yaz = app.MapGroup("/api").WithTags("Öğeler ve oturumlar")
            .RequireAuthorization(AliskanlikPolicies.Yaz);

        // Items

        oku.MapGet("/aliskanliklar/{aliskanlikId:guid}/ogeler", async (Guid aliskanlikId, AppDbContext db, CancellationToken ct, OgeDurumu? durum = null) =>
        {
            if (!await db.Aliskanliklar.AnyAsync(a => a.Id == aliskanlikId, ct))
                return Results.NotFound();

            var ogeler = await OgeSorgu(db).Where(o => o.AliskanlikId == aliskanlikId && (durum == null || o.Durum == durum))
                .OrderBy(o => o.CreatedAt).ToListAsync(ct);
            var bugun = Bugun();
            return Results.Ok(ogeler.Select(o => OgeDtoYap(o, bugun)).ToList());
        });

        yaz.MapPost("/aliskanliklar/{aliskanlikId:guid}/ogeler", async (Guid aliskanlikId, OgeYazDto dto, AppDbContext db, CancellationToken ct) =>
        {
            var a = await db.Aliskanliklar.FindAsync([aliskanlikId], ct);
            if (a is null)
                return Results.NotFound();

            // The same client id twice returns the existing item.
            if (dto.Id is { } id && await OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == id, ct) is { } mevcut)
                return mevcut.AliskanlikId == aliskanlikId
                    ? Results.Ok(OgeDtoYap(mevcut, Bugun()))
                    : Cakisma("Bu kimlik başka bir alışkanlığın öğesinde kullanılıyor.");

            var (sonuc, oge) = await OgeOlusturAsync(db, a, dto, ct);
            return sonuc.Basarili ? Results.Created($"/api/ogeler/{oge!.Id}", OgeDtoYap(oge, Bugun())) : Yanit(sonuc);
        });

        oku.MapGet("/ogeler/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var oge = await OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == id, ct);
            return oge is null ? Results.NotFound() : Results.Ok(OgeDtoYap(oge, Bugun()));
        });

        yaz.MapPut("/ogeler/{id:guid}", async (Guid id, OgeYazDto dto, AppDbContext db, DosyaDeposu depo, CancellationToken ct) =>
        {
            var oge = await OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == id, ct);
            if (oge is null)
                return Results.NotFound();

            var sonuc = await OgeGuncelleAsync(db, depo, oge, dto, ct);
            return sonuc.Basarili ? Results.Ok(OgeDtoYap(oge, Bugun())) : Yanit(sonuc);
        });

        yaz.MapDelete("/ogeler/{id:guid}", async (Guid id, AppDbContext db, DosyaDeposu depo, CancellationToken ct) =>
        {
            var oge = await db.Ogeler.FindAsync([id], ct);
            if (oge is null)
                return Results.NotFound();

            await OgeSilAsync(db, depo, oge, ct);
            return Results.NoContent();
        });

        // Sessions

        oku.MapGet("/ogeler/{ogeId:guid}/oturumlar", async (Guid ogeId, AppDbContext db, CancellationToken ct) =>
        {
            if (!await db.Ogeler.AnyAsync(o => o.Id == ogeId, ct))
                return Results.NotFound();

            var oturumlar = await db.Oturumlar.Where(t => t.OgeId == ogeId).OrderByDescending(t => t.BitisKonum).ToListAsync(ct);
            return Results.Ok(oturumlar.Select((t, i) => OturumDtoYap(t, son: i == 0)).ToList());
        });

        yaz.MapPost("/ogeler/{ogeId:guid}/oturumlar", async (Guid ogeId, OturumEkleDto dto, AppDbContext db, CancellationToken ct) =>
        {
            var oge = await OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == ogeId, ct);
            if (oge is null)
                return Results.NotFound();

            // The same client id twice (an offline retry) returns the existing session.
            if (dto.Id is { } id && await db.Oturumlar.FindAsync([id], ct) is { } mevcut)
            {
                if (mevcut.OgeId != ogeId)
                    return Cakisma("Bu kimlik başka bir öğenin oturumunda kullanılıyor.");

                var sonBitis = oge.Oturumlar.Max(t => t.BitisKonum);
                return Results.Ok(OturumDtoYap(mevcut, mevcut.BitisKonum == sonBitis));
            }

            var (sonuc, oturum) = await OturumEkleAsync(db, oge, dto, ct);
            return sonuc.Basarili ? Results.Created($"/api/ogeler/{ogeId}", OturumDtoYap(oturum!, son: true)) : Yanit(sonuc);
        });

        yaz.MapPut("/oturumlar/{id:guid}", async (Guid id, OturumGuncelleDto dto, AppDbContext db, CancellationToken ct) =>
        {
            var oturum = await db.Oturumlar.Include(t => t.Oge).FirstOrDefaultAsync(t => t.Id == id, ct);
            if (oturum is null)
                return Results.NotFound();

            var sonuc = await OturumGuncelleAsync(db, oturum, dto.BitisKonum, dto.Dakika, ct);
            return sonuc.Basarili ? Results.Ok(OturumDtoYap(oturum, son: true)) : Yanit(sonuc);
        });

        yaz.MapDelete("/oturumlar/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var oturum = await db.Oturumlar.Include(t => t.Oge).FirstOrDefaultAsync(t => t.Id == id, ct);
            if (oturum is null)
                return Results.NotFound();

            var sonuc = await OturumSilAsync(db, oturum, ct);
            return sonuc.Basarili ? Results.NoContent() : Yanit(sonuc);
        });
    }

    internal static string? FotografUrl(Guid? fotografId) =>
        fotografId is { } id ? $"/api/dosyalar/{id}" : null;

    internal static OgeDto OgeDtoYap(Oge oge, DateOnly bugun)
    {
        var konum = GuncelKonum(oge);
        var ilerleme = OgeHesap.Ilerleme(konum, oge.Toplam);
        var hiz = OgeHesap.Hiz(oge.Oturumlar.Select(t => (t.Tarih, t.Miktar)), bugun);
        var devamEdiyor = oge.Durum is OgeDurumu.Siradaki or OgeDurumu.Devam;

        return new OgeDto(
            oge.Id, oge.AliskanlikId, oge.Ad, oge.AltBaslik, Sade(oge.Toplam), Sade(oge.BaslangicKonumu), Sade(konum),
            ilerleme is { } i ? Yuvarla(i) : null, oge.FotografId, FotografUrl(oge.FotografId), oge.Durum,
            oge.BaslamaTarihi, oge.BitisTarihi, oge.Puan, oge.Not, Sade(Yuvarla(hiz)),
            devamEdiyor ? OgeHesap.TahminiBitis(konum, oge.Toplam, hiz, bugun) : null,
            oge.Oturumlar.Sum(t => t.Dakika ?? 0), oge.CreatedAt);
    }

    internal static OturumDto OturumDtoYap(Oturum t, bool son) =>
        new(t.Id, t.OgeId, t.Tarih, Sade(t.BaslangicKonum), Sade(t.BitisKonum), Sade(t.Miktar), t.Dakika, t.CreatedAt, son);
}
