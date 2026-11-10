using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Isler;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Bildirimler;

public class CihazYazDto
{
    [Required(ErrorMessage = "Token zorunlu.")]
    [StringLength(1024, ErrorMessage = "Token en çok 1024 karakter olabilir.")]
    public string? Token { get; set; }

    [StringLength(100, ErrorMessage = "Cihaz adı en çok 100 karakter olabilir.")]
    public string? CihazAdi { get; set; }
}

public class CihazSilDto
{
    [Required(ErrorMessage = "Token zorunlu.")]
    public string? Token { get; set; }
}

// `Secenekler`: the buttons the notification can show (work cards: the answers of a decision, "Onayla" at the code gate). The push carries
// only the id, so they come from here, worked out when the notification is read, from the card as it is now.
public record BildirimDto(
    Guid Id, string Baslik, string Metin, string? Rota, string? HedefKimligi, string KaynakTuru, DateTimeOffset OlusmaAni, string? Anahtar,
    List<BildirimSecenegiDto>? Secenekler = null);

// A row of the notification center: what a notification says, and whether it was read. No buttons here (they are worked out from the card
// as it is now, when one notification is opened with GET /api/bildirimler/{id}).
public record BildirimSatiriDto(
    Guid Id, string Baslik, string Metin, string? Rota, string? HedefKimligi, string KaynakTuru, DateTimeOffset OlusmaAni, string? Anahtar, bool Okundu);

public record OkunmamisSayisiDto(int Okunmamis);

public record PushDurumDto(bool Acik, int CihazSayisi, SonGonderim? SonGonderim);

public record TestSonucuDto(Guid BildirimId, int Hedef, int Giden, int Silinen, int Hatali);

// The server-to-phone channel: devices register their FCM token, FCM only says "wake up" with a notification id, and the phone
// reads the text here. Any signed-in user may register devices and read their own notifications; the test send is the Sahip's.
public static class BildirimEndpoints
{
    public const int VarsayilanSatir = 30;
    public const int EnCokSatir = 100;

    public static void MapBildirimEndpoints(this IEndpointRouteBuilder app)
    {
        var girisli = app.MapGroup("/api").WithTags("Bildirimler")
            .RequireAuthorization(policy => policy
                .AddAuthenticationSchemes(IdentityConstants.BearerScheme)
                .RequireAuthenticatedUser());

        girisli.MapPost("/bildirim/cihaz", async (CihazYazDto dto, BildirimServisi servis, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            if (KullaniciId(kullanici) is not { } id)
                return Results.Unauthorized();

            await servis.CihazKaydetAsync(id, dto.Token!.Trim(), string.IsNullOrWhiteSpace(dto.CihazAdi) ? null : dto.CihazAdi.Trim(), ct);
            return Results.NoContent();
        });

        girisli.MapDelete("/bildirim/cihaz", async ([FromBody] CihazSilDto dto, BildirimServisi servis, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            if (KullaniciId(kullanici) is not { } id)
                return Results.Unauthorized();

            // Idempotent: a token that is already gone is not an error (the app signs out whatever happened before).
            await servis.CihazSilAsync(id, dto.Token!.Trim(), ct);
            return Results.NoContent();
        });

        // The notification center (K-0024, §6): the person's own rows, newest first, `once` is the moment to continue from (the oldest row
        // of the page before), 30 rows unless `limit` says otherwise (1 to 100).
        girisli.MapGet("/bildirimler", async (AppDbContext db, ClaimsPrincipal kullanici, CancellationToken ct, DateTimeOffset? once = null, int limit = VarsayilanSatir) =>
        {
            if (KullaniciId(kullanici) is not { } kullaniciId)
                return Results.Unauthorized();
            if (limit is < 1 or > EnCokSatir)
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["limit"] = [$"Satır sayısı 1 ile {EnCokSatir} arasında olmalı."] });

            var sorgu = db.Bildirimler.AsNoTracking().Where(b => b.KullaniciId == kullaniciId);
            if (once is { } sinir)
                sorgu = sorgu.Where(b => b.OlusmaAni < sinir);

            var satirlar = await sorgu.OrderByDescending(b => b.OlusmaAni).ThenByDescending(b => b.Id).Take(limit)
                .Select(b => new BildirimSatiriDto(b.Id, b.Baslik, b.Metin, b.Rota, b.HedefKimligi, b.KaynakTuru, b.OlusmaAni, b.Anahtar, b.OkunmaAni != null))
                .ToListAsync(ct);
            return Results.Ok(satirlar);
        });

        girisli.MapGet("/bildirimler/sayi", async (AppDbContext db, ClaimsPrincipal kullanici, CancellationToken ct) =>
            KullaniciId(kullanici) is not { } kullaniciId
                ? Results.Unauthorized()
                : Results.Ok(new OkunmamisSayisiDto(await db.Bildirimler.CountAsync(b => b.KullaniciId == kullaniciId && b.OkunmaAni == null, ct))));

        // Marks one as read (its first reading stays: reading it again changes nothing). Somebody else's is a 404, as for the single read.
        girisli.MapPost("/bildirimler/{id:guid}/okundu", async (Guid id, AppDbContext db, ClaimsPrincipal kullanici, TimeProvider saat, CancellationToken ct) =>
        {
            if (KullaniciId(kullanici) is not { } kullaniciId)
                return Results.Unauthorized();

            var b = await db.Bildirimler.FirstOrDefaultAsync(x => x.Id == id && x.KullaniciId == kullaniciId, ct);
            if (b is null)
                return Results.NotFound();

            if (b.OkunmaAni is null)
            {
                b.OkunmaAni = saat.GetUtcNow();
                await db.SaveChangesAsync(ct);
            }

            return Results.NoContent();
        });

        // Marks all of the person's unread rows as read.
        girisli.MapPost("/bildirimler/okundu", async (AppDbContext db, ClaimsPrincipal kullanici, TimeProvider saat, CancellationToken ct) =>
        {
            if (KullaniciId(kullanici) is not { } kullaniciId)
                return Results.Unauthorized();

            var an = saat.GetUtcNow();
            await db.Bildirimler.Where(b => b.KullaniciId == kullaniciId && b.OkunmaAni == null)
                .ExecuteUpdateAsync(s => s.SetProperty(b => b.OkunmaAni, an), ct);
            return Results.NoContent();
        });

        // Somebody else's notification is a 404, not a 403: the id of another user's row must not be confirmed.
        girisli.MapGet("/bildirimler/{id:guid}", async (Guid id, AppDbContext db, ClaimsPrincipal kullanici, BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
        {
            if (KullaniciId(kullanici) is not { } kullaniciId)
                return Results.Unauthorized();

            var b = await db.Bildirimler.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id && x.KullaniciId == kullaniciId, ct);
            if (b is null)
                return Results.NotFound();

            // Buttons only for a person who may write to the cards: a tap on one is a write.
            var secenekler = b.KaynakTuru == IsBildirimci.KaynakTuru && b.HedefKimligi is not null && IzinVar(kullanici, IsPolicies.Yaz)
                ? await IsSecenekleriAsync(b.HedefKimligi, beyin, log, ct)
                : null;
            return Results.Ok(new BildirimDto(b.Id, b.Baslik, b.Metin, b.Rota, b.HedefKimligi, b.KaynakTuru, b.OlusmaAni, b.Anahtar, secenekler));
        });

        var sahip = app.MapGroup("/api/bildirim").WithTags("Bildirimler")
            .RequireAuthorization(YonetimPolicies.Sahip);

        sahip.MapGet("/durum", async (BildirimServisi servis, PushDurumu durum, CancellationToken ct) =>
            Results.Ok(new PushDurumDto(servis.PushAcik, await servis.CihazSayisiAsync(ct), durum.Son)));

        // 409 while push is off (no key file) or no phone is registered, with a message that says which.
        sahip.MapPost("/test", async (BildirimServisi servis, ClaimsPrincipal kullanici, AppDbContext db, CancellationToken ct) =>
        {
            if (KullaniciId(kullanici) is not { } id)
                return Results.Unauthorized();

            if (!servis.PushAcik)
                return Results.Problem(title: "Push kapalı", detail: "Firebase:AnahtarDosyasi ayarlı değil; bildirim gönderilemez.", statusCode: StatusCodes.Status409Conflict);

            if (!await db.BildirimCihazlari.AnyAsync(c => c.KullaniciId == id, ct))
                return Results.Problem(title: "Kayıtlı cihaz yok", detail: "Bu hesapta kayıtlı cihaz yok; uygulamayı açıp giriş yap.", statusCode: StatusCodes.Status409Conflict);

            var bildirim = await servis.OlusturAsync(id, "Test bildirimi", "Sunucudan telefona anlık bildirim çalışıyor.", "test", rota: null, hedefKimligi: null, ct);
            var sonuc = (await servis.GonderAsync(bildirim, ct))!;
            return Results.Ok(new TestSonucuDto(bildirim.Id, sonuc.Hedef, sonuc.Giden, sonuc.Silinen, sonuc.Hatali));
        });
    }

    private static bool IzinVar(ClaimsPrincipal kullanici, string izin) =>
        kullanici.IsInRole(SeedData.OwnerRole) || kullanici.HasClaim(Aliskanliklar.AliskanlikPolicies.IzinClaim, izin);

    // The card as it is now; when it cannot be read the notification simply has no buttons (opening it still works).
    private static async Task<List<BildirimSecenegiDto>> IsSecenekleriAsync(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var kart = await IsKartlari.Al(kimlik, beyin, log, ct);
        return kart.Basarili ? IsKartlari.BildirimSecenekleri(kart.Veri!) : [];
    }

    internal static Guid? KullaniciId(ClaimsPrincipal kullanici) =>
        Guid.TryParse(kullanici.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;

    public static IServiceCollection AddBildirimler(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(PushAyari.Oku(config));
        services.AddSingleton<PushDurumu>();
        // A fake from a test replaces this registration; with push off the real sender is never called.
        services.AddSingleton<IPushGondericisi, FirebasePushGondericisi>();
        services.AddScoped<BildirimServisi>();
        services.AddBildirimHatti(config);
        return services;
    }
}
