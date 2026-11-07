using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Kafamdakiler.Beyin;

// Repeat safety for the writes (K2.3a): the phone's offline queue may send the same request twice. A request that carries an
// `Idempotency-Key` header is applied once; the second one gets the first answer back (marked `Idempotent-Replayed: true`)
// and the brain is not called again. Without the header (the web) the request is simply run.
//
// The first request claims the key by inserting a row (the database's unique key settles two requests arriving together),
// runs, then keeps its answer on the row. What is kept: a write (200), a half-done run (207) and an uncertain one (202).
// A write the brain refused is dropped: nothing was written, the same key may be tried again.
public sealed partial class TekrarGuvenligi(AppDbContext db, TimeProvider saat, ILogger<TekrarGuvenligi> log)
{
    public const string Baslik = "Idempotency-Key";

    // The records are only needed while a queue could still resend; older ones are removed on the next write.
    public static readonly TimeSpan SaklamSuresi = TimeSpan.FromDays(7);

    // A claim still `Calisiyor` this long after it was made belongs to a run that died with the server.
    public static readonly TimeSpan TakilmaSuresi = TimeSpan.FromMinutes(10);

    [GeneratedRegex(@"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,99}\z", RegexOptions.CultureInvariant)]
    private static partial Regex AnahtarKalibi();

    public static string Parmakizi(string islem, object? girdi) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(
            islem + "\n" + System.Text.Json.JsonSerializer.Serialize(girdi, BeyinYazma.JsonSecenekleri))));

    // `girdi` is everything that makes the request what it is (route values and body): the same key with other input is refused.
    public async Task<IResult> CalistirAsync(
        ClaimsPrincipal kullanici, string? anahtar, string islem, object? girdi, Func<Task<YazmaYaniti>> calistir, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(anahtar))
            return (await calistir()).Sonuc();

        anahtar = anahtar.Trim();
        if (!AnahtarKalibi().IsMatch(anahtar))
            return Results.ValidationProblem(new Dictionary<string, string[]> { [Baslik] = ["Anahtar harf, rakam ve _ . : - karakterlerinden oluşan en çok 100 karakter olmalı."] });
        if (!Guid.TryParse(kullanici.FindFirstValue(ClaimTypes.NameIdentifier), out var kullaniciId))
            return Results.Unauthorized();

        var parmakizi = Parmakizi(islem, girdi);

        // Two attempts: a claim we meet may be dropped by its owner (a refused write) before we read it.
        for (var deneme = 0; deneme < 2; deneme++)
        {
            var kayit = new BeyinIslemi { KullaniciId = kullaniciId, Anahtar = anahtar, Parmakizi = parmakizi, CreatedAt = saat.GetUtcNow() };
            db.BeyinIslemleri.Add(kayit);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
            {
                db.Entry(kayit).State = EntityState.Detached;
                if (await Tekrar(kullaniciId, anahtar, parmakizi) is { } cevap)
                    return cevap;
                continue;
            }

            return await IlkIstekAsync(kayit, calistir);
        }

        return Results.Problem(title: "İstek işlenemedi", detail: "Aynı anahtarla gelen istek şu an işleniyor, biraz sonra tekrar dene.", statusCode: StatusCodes.Status409Conflict);
    }

    // From the claim on, the work is not tied to the request: a phone that drops the connection must not leave a write
    // half known. The brain's own time limit still ends a hung command.
    private async Task<IResult> IlkIstekAsync(BeyinIslemi kayit, Func<Task<YazmaYaniti>> calistir)
    {
        await EskileriTemizle();

        YazmaYaniti yanit;
        try
        {
            yanit = await calistir();
        }
        catch (Exception e)
        {
            // Something broke around the brain call: the write may have happened.
            log.LogError(e, "A brain write failed unexpectedly under an Idempotency-Key");
            yanit = YazmaYaniti.Belirsiz("İşlem sırasında beklenmeyen bir hata oldu; yazılmış olabilir. Günün planına bak.");
        }

        if (!yanit.Hatirlanir)
        {
            await db.BeyinIslemleri.Where(x => x.KullaniciId == kayit.KullaniciId && x.Anahtar == kayit.Anahtar).ExecuteDeleteAsync(CancellationToken.None);
            return yanit.Sonuc();
        }

        var json = yanit.Json();
        kayit.Durum = yanit.Tur == YazmaTuru.Belirsiz ? BeyinIslemiDurumu.Belirsiz : BeyinIslemiDurumu.Tamam;
        kayit.DurumKodu = yanit.Durum;
        kayit.Cevap = json;
        await db.SaveChangesAsync(CancellationToken.None);
        return new JsonCevabi(yanit.Durum, json);
    }

    // The answer to a request whose key is already claimed. Null: the claim is gone (its owner's write was refused), try to claim again.
    private async Task<IResult?> Tekrar(Guid kullaniciId, string anahtar, string parmakizi)
    {
        var mevcut = await db.BeyinIslemleri.AsNoTracking()
            .SingleOrDefaultAsync(x => x.KullaniciId == kullaniciId && x.Anahtar == anahtar, CancellationToken.None);
        if (mevcut is null)
            return null;

        if (mevcut.Parmakizi != parmakizi)
            return Results.Problem(title: "Anahtar başka bir isteğe ait", detail: "Bu Idempotency-Key başka bir istekle kullanıldı; her istek için yeni bir anahtar üret.", statusCode: StatusCodes.Status422UnprocessableEntity);

        if (mevcut.Durum != BeyinIslemiDurumu.Calisiyor)
            return new JsonCevabi(mevcut.DurumKodu, mevcut.Cevap!, tekrar: true);

        if (saat.GetUtcNow() - mevcut.CreatedAt < TakilmaSuresi)
            return Results.Problem(title: "İstek işleniyor", detail: "Aynı anahtarla gelen ilk istek hâlâ sürüyor; biraz sonra tekrar dene.", statusCode: StatusCodes.Status409Conflict);

        // The first request never reported back (the server died under it): whether it wrote is unknown, and it is
        // not run again by itself. Keep that as its answer, so every repeat gets the same one.
        var belirsiz = YazmaYaniti.Belirsiz("İlk istek tamamlanmadı; yazılmış olabilir. Günün planına bak, gerekirse yeni bir anahtarla tekrar dene.");
        var json = belirsiz.Json();
        await db.BeyinIslemleri
            .Where(x => x.KullaniciId == kullaniciId && x.Anahtar == anahtar && x.Durum == BeyinIslemiDurumu.Calisiyor)
            .ExecuteUpdateAsync(s => s
                .SetProperty(x => x.Durum, BeyinIslemiDurumu.Belirsiz)
                .SetProperty(x => x.DurumKodu, belirsiz.Durum)
                .SetProperty(x => x.Cevap, json), CancellationToken.None);
        return new JsonCevabi(belirsiz.Durum, json, tekrar: true);
    }

    private async Task EskileriTemizle()
    {
        var sinir = saat.GetUtcNow() - SaklamSuresi;
        await db.BeyinIslemleri.Where(x => x.CreatedAt < sinir).ExecuteDeleteAsync(CancellationToken.None);
    }
}
