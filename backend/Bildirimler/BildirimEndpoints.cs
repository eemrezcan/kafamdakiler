using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Kafamdakiler.Data;
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

public record BildirimDto(Guid Id, string Baslik, string Metin, string? Rota, string? HedefKimligi, string KaynakTuru, DateTimeOffset OlusmaAni);

public record PushDurumDto(bool Acik, int CihazSayisi, SonGonderim? SonGonderim);

public record TestSonucuDto(Guid BildirimId, int Hedef, int Giden, int Silinen, int Hatali);

// The server-to-phone channel: devices register their FCM token, FCM only says "wake up" with a notification id, and the phone
// reads the text here. Any signed-in user may register devices and read their own notifications; the test send is the Sahip's.
public static class BildirimEndpoints
{
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

        // Somebody else's notification is a 404, not a 403: the id of another user's row must not be confirmed.
        girisli.MapGet("/bildirimler/{id:guid}", async (Guid id, AppDbContext db, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            if (KullaniciId(kullanici) is not { } kullaniciId)
                return Results.Unauthorized();

            var b = await db.Bildirimler.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id && x.KullaniciId == kullaniciId, ct);
            return b is null
                ? Results.NotFound()
                : Results.Ok(new BildirimDto(b.Id, b.Baslik, b.Metin, b.Rota, b.HedefKimligi, b.KaynakTuru, b.OlusmaAni));
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

    internal static Guid? KullaniciId(ClaimsPrincipal kullanici) =>
        Guid.TryParse(kullanici.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;

    public static IServiceCollection AddBildirimler(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(PushAyari.Oku(config));
        services.AddSingleton<PushDurumu>();
        // A fake from a test replaces this registration; with push off the real sender is never called.
        services.AddSingleton<IPushGondericisi, FirebasePushGondericisi>();
        services.AddScoped<BildirimServisi>();
        return services;
    }
}
