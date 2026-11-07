using System.Security.Claims;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Microsoft.AspNetCore.Identity;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Yonetim;

// /api/yonetim: what the Sahip manages from the phone (T08, M07). Sahip role only; the Asistan gets 403 whatever its permissions.
public static class YonetimEndpoints
{
    public static void MapYonetimEndpoints(this IEndpointRouteBuilder app)
    {
        var yonetim = app.MapGroup("/api/yonetim").WithTags("Yönetim")
            .RequireAuthorization(YonetimPolicies.Sahip);

        yonetim.MapGet("/izinler", async (UserManager<IdentityUser<Guid>> kullanicilar) =>
            Results.Ok(await YonetimIslemleri.IzinleriGetirAsync(kullanicilar)));

        yonetim.MapPut("/izinler/{izin}", async (string izin, IzinYazDto dto, UserManager<IdentityUser<Guid>> kullanicilar) =>
        {
            if (!Izinler.Gecerli(izin))
                return Results.NotFound();

            await YonetimIslemleri.IzinAyarlaAsync(kullanicilar, izin, dto.Acik!.Value);
            return Results.Ok((await YonetimIslemleri.IzinleriGetirAsync(kullanicilar)).Single(i => i.Izin == izin));
        });

        // 400 when the new password breaks Identity's rules (Turkish messages under `yeniSifre`); on success the Asistan's sessions are closed too.
        yonetim.MapPut("/asistan/sifre", async (AsistanSifreYazDto dto, UserManager<IdentityUser<Guid>> kullanicilar) =>
        {
            var sonuc = await YonetimIslemleri.AsistaninSifresiniYenileAsync(kullanicilar, dto.YeniSifre!);
            return sonuc.Succeeded
                ? Results.NoContent()
                : Results.ValidationProblem(new Dictionary<string, string[]> { ["yeniSifre"] = sonuc.Errors.Select(e => e.Description).ToArray() });
        });

        // The mode of every action kind: sor (ask first, the default), kendinYap (apply at once, undo stays possible) or yasak (never suggest).
        yonetim.MapGet("/eylem-izinleri", async (EylemServisi servis, CancellationToken ct) =>
            Results.Ok(await servis.KipleriGetirAsync(ct)));

        yonetim.MapPut("/eylem-izinleri/{tur}", async (string tur, EylemKipYazDto dto, EylemServisi servis, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            if (!Enum.IsDefined(dto.Kip!.Value))
                return Sorun("kip", "Kip sor, kendinYap ya da yasak olmalı.");

            return await servis.KipAyarlaAsync(tur, dto.Kip.Value, EylemEndpoints.KullaniciId(kullanici), ct) is { } kip
                ? Results.Ok(kip)
                : Results.NotFound();
        });

        yonetim.MapGet("/beyin",async (AppDbContext db, BeyinIstemcisi beyin, BeyinAyari ayar, CancellationToken ct) =>
            Results.Ok(await YonetimIslemleri.BeyinDurumuAsync(db, beyin, ayar, DateTimeOffset.UtcNow, ct)));

        // Every capture, the ones that need a look first (a failed send, or one stuck after a crash or a timeout).
        yonetim.MapGet("/gonderim", async (AppDbContext db, CancellationToken ct) =>
            Results.Ok(await YonetimIslemleri.KuyrukAsync(db, DateTimeOffset.UtcNow, yalnizIlgilenilecek: false, ct)));

        // 409: it is being sent right now, or it already left `bekliyor`. On a stuck capture the card may already exist in the brain.
        yonetim.MapPost("/gonderim/{id:guid}/yeniden-dene", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var simdi = DateTimeOffset.UtcNow;
            var sonuc = await YonetimIslemleri.YenidenDeneAsync(db, id, simdi, ct);
            if (sonuc is null)
                return Results.NotFound();

            return sonuc.Basarili
                ? Results.Ok(await YonetimIslemleri.GonderimGetirAsync(db, id, simdi, ct))
                : Yanit(sonuc);
        });
    }
}
