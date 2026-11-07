using System.Globalization;
using Kafamdakiler.Yonetim;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Brifing;

// The morning briefing (K2.7): a few cards about the day, made once a day at the set hour. Reading and voting need `brifing.oku`;
// asking for a new one is the Sahip's. Writing into the briefing box goes through /api/is-cikar (kaynak "brifing"), not here.
public static class BrifingEndpoints
{
    public static void MapBrifingEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api/brifing").WithTags("Brifing").RequireAuthorization(BrifingPolicies.Oku);
        var sahip = app.MapGroup("/api/brifing").WithTags("Brifing").RequireAuthorization(YonetimPolicies.Sahip);

        // Today's briefing; made now if the hour has passed and none exists yet. 404 before the hour.
        oku.MapGet("/bugun", async (BrifingHazirlayici hazirlayici, CancellationToken ct) =>
            await Yanit(hazirlayici, await hazirlayici.BugunAsync(ct), ct));

        // A stored briefing of a day (yyyy-MM-dd, or "bugun"). Never makes one.
        oku.MapGet("/{gun}", async (string gun, BrifingHazirlayici hazirlayici, CancellationToken ct) =>
        {
            if (GunCoz(gun, hazirlayici) is not { } tarih)
                return GunHatasi;

            return await hazirlayici.GetirAsync(tarih, ct) is { } brifing
                ? Results.Ok(await hazirlayici.DtoYapAsync(brifing, ct))
                : Results.Problem(title: "Bulunamadı", detail: "O güne ait brifing yok.", statusCode: StatusCodes.Status404NotFound);
        });

        oku.MapPost("/{gun}/kartlar/{sira:int}/oy", async (string gun, int sira, BrifingOyGirdisi girdi, BrifingHazirlayici hazirlayici, CancellationToken ct) =>
        {
            if (GunCoz(gun, hazirlayici) is not { } tarih)
                return GunHatasi;
            if (girdi.Oy is not { } oy)
                return Sorun("oy", "Oy zorunlu: 1, -1 ya da 0.");

            return await Yanit(hazirlayici, await hazirlayici.OyVerAsync(tarih, sira, oy, ct), ct);
        });

        // Makes today's briefing again (the Sahip): at most three times a day.
        sahip.MapPost("/bugun/yenile", async (BrifingHazirlayici hazirlayici, CancellationToken ct) =>
            await Yanit(hazirlayici, await hazirlayici.YenileAsync(ct), ct));
    }

    private static readonly IResult GunHatasi = Sorun("gun", "Gün yyyy-MM-dd biçiminde ya da bugun olmalı.");

    private static DateOnly? GunCoz(string gun, BrifingHazirlayici hazirlayici)
    {
        if (gun == "bugun")
            return hazirlayici.Bugun;

        return DateOnly.TryParseExact(gun, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var tarih) ? tarih : null;
    }

    private static async Task<IResult> Yanit(BrifingHazirlayici hazirlayici, BrifingSonucu sonuc, CancellationToken ct) => sonuc.Durum switch
    {
        BrifingDurumu.Tamam => Results.Ok(await hazirlayici.DtoYapAsync(sonuc.Brifing!, ct)),
        BrifingDurumu.HenuzHazirDegil => Results.Problem(title: "Brifing henüz hazır değil", detail: sonuc.Mesaj, statusCode: StatusCodes.Status404NotFound),
        BrifingDurumu.Bulunamadi => Results.Problem(title: "Bulunamadı", detail: sonuc.Mesaj, statusCode: StatusCodes.Status404NotFound),
        BrifingDurumu.Gecersiz => Sorun(sonuc.Alan ?? "oy", sonuc.Mesaj!),
        BrifingDurumu.SinirDoldu => Results.Problem(title: "Bugünlük yenileme sınırı doldu", detail: sonuc.Mesaj, statusCode: StatusCodes.Status429TooManyRequests),
        _ => Results.Problem(title: "Brifing hazırlanamadı", detail: sonuc.Mesaj, statusCode: StatusCodes.Status503ServiceUnavailable),
    };
}
