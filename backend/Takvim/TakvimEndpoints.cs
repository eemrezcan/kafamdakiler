using System.Security.Claims;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Yonetim;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Takvim;

public record GoogleBaglanDto(string Adres);

// Google Calendar (K2.3c). Connecting, cutting and the status are the Sahip's (bearer); the callback Google sends the browser back to
// is the Sahip's too, with the web cookie, so a callback opened by anyone else leads nowhere. The timeline needs `takvim.oku`.
public static class TakvimEndpoints
{
    // Where the callback sends the browser: the management page, which says how it went.
    private const string YonetimSayfasi = "/Yonetim";

    public static void MapTakvimEndpoints(this IEndpointRouteBuilder app)
    {
        var sahip = app.MapGroup("/api/google").WithTags("Google Takvim").RequireAuthorization(YonetimPolicies.Sahip);

        sahip.MapGet("/durum", async (GoogleBaglanti baglanti, CancellationToken ct) =>
            Results.Ok(await baglanti.DurumAsync(ct)));

        // The address of Google's consent screen; the app (or the browser) goes there. 503 when the Google settings are missing.
        sahip.MapPost("/baglan", async (GoogleBaglanti baglanti, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            if (EylemEndpoints.KullaniciId(kullanici) is not { } id)
                return Results.Unauthorized();

            return await baglanti.BaslatAsync(id, ct) is { } adres
                ? Results.Ok(new GoogleBaglanDto(adres.AbsoluteUri))
                : Kapali();
        });

        // Cuts the connection: the token is revoked at Google, then it and the synced events are deleted here.
        sahip.MapDelete("/baglanti", async (GoogleBaglanti baglanti, CancellationToken ct) =>
            Results.Ok(await baglanti.KesAsync(ct)));

        // A sync now, instead of waiting for the next round.
        sahip.MapPost("/esitle", async (TakvimEsitleyici esitleyici, CancellationToken ct) =>
        {
            var ozet = await esitleyici.TurAsync(ct);
            return ozet.ErisimSorunu switch
            {
                null => Results.Ok(ozet),
                ErisimDurumu.Kapali => Kapali(),
                var sorun => Cakisma(new ErisimSonucu(sorun.Value).Mesaj),
            };
        });

        // Google sends the browser back here with ?code=...&state=... (or ?error=...). Only the Sahip's browser session gets through
        // (the same policy as the web pages); the state ties the answer to the connect that this Sahip started.
        app.MapGet("/google/donus", async (
            HttpContext http, GoogleBaglanti baglanti, TakvimEsitleyici esitleyici, ILoggerFactory gunlukler, ClaimsPrincipal kullanici,
            CancellationToken ct, string? state = null, string? code = null, string? error = null) =>
        {
            // The address holds a one-time code: not kept by a cache or passed on in a Referer header.
            http.Response.Headers.CacheControl = "no-store";
            http.Response.Headers["Referrer-Policy"] = "no-referrer";

            if (EylemEndpoints.KullaniciId(kullanici) is not { } id)
                return Results.Redirect($"{YonetimSayfasi}?google=hata&neden=kullanici");

            var sonuc = await baglanti.TamamlaAsync(id, state, code, error, ct);
            if (!sonuc.Basarili)
                return Results.Redirect($"{YonetimSayfasi}?google=hata&neden={Neden(sonuc.Tur)}");

            // The first sync, so the calendar is not empty until the next round. Its failure does not undo the connection.
            try
            {
                await esitleyici.TurAsync(ct);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                gunlukler.CreateLogger("Kafamdakiler.Takvim").LogWarning(e, "The first calendar sync after connecting failed; the next round will try again.");
            }

            return Results.Redirect($"{YonetimSayfasi}?google=bagli");
        }).RequireAuthorization(SeedData.OwnerRole);

        var cizelge = app.MapGroup("/api/zaman-cizelgesi").WithTags("Zaman çizelgesi").RequireAuthorization(TakvimPolicies.Oku);

        // The one timeline of a day (`gun` is yyyy-MM-dd; today by the 05:00 rule when left out).
        cizelge.MapGet("/", async (ZamanCizelgesiServisi servis, TimeProvider saat, CancellationToken ct, string? gun = null) =>
        {
            var tarih = GunSiniri.Bugun(saat.GetUtcNow());
            if (!string.IsNullOrEmpty(gun) && (!TakvimZamani.GunCoz(gun, out tarih) || tarih.Year is < 2000 or > 2100))
                return Sorun("gun", "Gün yyyy-MM-dd biçiminde olmalı.");

            return Results.Ok(await servis.GetirAsync(tarih, ct));
        });
    }

    private static IResult Kapali() =>
        Results.Problem(title: "Google Takvim kapalı", detail: "Google ayarları (ClientId, ClientSecret, DonusAdresi) yapılmamış.", statusCode: StatusCodes.Status503ServiceUnavailable);

    private static string Neden(BaglantiSonucuTuru tur) => tur switch
    {
        BaglantiSonucuTuru.Kapali => "kapali",
        BaglantiSonucuTuru.StateGecersiz => "state",
        BaglantiSonucuTuru.StateSuresiDolmus => "sureDoldu",
        BaglantiSonucuTuru.KullaniciUyusmuyor => "kullanici",
        BaglantiSonucuTuru.Reddedildi => "reddedildi",
        BaglantiSonucuTuru.EksikIzin => "eksikIzin",
        _ => "kod",
    };
}
