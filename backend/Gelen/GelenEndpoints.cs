using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Yonetim;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Gelen;

// The inbox (K2.2): the cards waiting in the brain, the suggestions Claude made for them, and the hand-made placements.
// A suggestion becomes an action in the approval queue (/api/eylemler); approving it there places the card.
public static class GelenEndpoints
{
    public static void MapGelenEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api/gelen").WithTags("Gelen").RequireAuthorization(GelenPolicies.Oku);
        var yaz = app.MapGroup("/api/gelen").WithTags("Gelen").RequireAuthorization(GelenPolicies.Yaz);
        var sahip = app.MapGroup("/api/gelen").WithTags("Gelen").RequireAuthorization(YonetimPolicies.Sahip);

        oku.MapGet("/", async (BeyinIstemcisi beyin, AppDbContext db, ILogger<GelenOnerici> log, CancellationToken ct) =>
            (await GelenIslemleri.ListeAl(beyin, db, log, ct)).Sonuc());

        // "Suggest again": asks Claude now and answers when it is done (up to the Claude timeout).
        yaz.MapPost("/{kart}/oneri", async (string kart, GelenOnerici onerici, EylemServisi eylemler, CancellationToken ct) =>
        {
            if (!GelenBeyin.KartKimligiGecerli(kart))
                return Sorun("kart", "Kart adı geçerli değil.");

            var sonuc = await onerici.OnerAsync(kart, ct);
            return sonuc.Durum switch
            {
                OneriDurumu.Olustu => Results.Ok(new GelenOneriYaniti("olustu", null, eylemler.DtoYap(sonuc.Eylem!))),
                OneriDurumu.LaptoptaIslenecek => Results.Ok(new GelenOneriYaniti("laptoptaIslenecek", sonuc.Mesaj, null)),
                OneriDurumu.Atlandi => Results.Ok(new GelenOneriYaniti("atlandi", sonuc.Mesaj, null)),
                OneriDurumu.KartYok => Results.Problem(title: "Bulunamadı", detail: sonuc.Mesaj, statusCode: StatusCodes.Status404NotFound),
                OneriDurumu.BekleyenVar => Cakisma(sonuc.Mesaj!),
                OneriDurumu.Gonderilemez or OneriDurumu.MetinYok =>
                    Results.Problem(title: "Öneri istenemez", detail: sonuc.Mesaj, statusCode: StatusCodes.Status422UnprocessableEntity),
                OneriDurumu.BagliDegil =>
                    Results.Problem(title: "Claude ya da beyin bağlı değil", detail: "Bu makinede Claude ya da beyin ayarlı değil.", statusCode: StatusCodes.Status503ServiceUnavailable),
                OneriDurumu.SinirDoldu =>
                    Results.Problem(title: "Claude için bugünlük sınır doldu", detail: "Yarın tekrar dene ya da kartı elle yerleştir.", statusCode: StatusCodes.Status429TooManyRequests),
                _ => Results.Problem(title: "Öneri üretilemedi", detail: "Claude öneri üretemedi ya da önerisi kurallara uymadı. Kart yerinde duruyor.", statusCode: StatusCodes.Status502BadGateway),
            };
        });

        yaz.MapPost("/{kart}/isle", async (string kart, GelenIsleGirdi girdi, BeyinIstemcisi beyin, ILogger<GelenOnerici> log, CancellationToken ct) =>
            (await GelenIslemleri.Isle(kart, girdi, beyin, log, ct)).Sonuc());

        sahip.MapDelete("/{kart}", async (string kart, BeyinIstemcisi beyin, ILogger<GelenOnerici> log, CancellationToken ct) =>
            (await GelenIslemleri.Sil(kart, beyin, log, ct)).Sonuc());
    }
}
