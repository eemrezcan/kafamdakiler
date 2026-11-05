using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.Yakalamalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Beyin;

// Sends waiting captures to the brain as inbox cards (`gelen ekle`) and marks them BeyneGitti.
//
// A card must not be made twice, and the brain has no "already added" check, so the sender claims a capture first:
// one UPDATE ... WHERE GonderimBasladiAt IS NULL, and only the caller that changed the row sends it. Two overlapping
// rounds (or two app instances) therefore never send the same capture. The claim is cleared only when the brain
// said it failed and wrote nothing; after a timeout, a crash or unreadable output the capture stays claimed (it may
// already be a card) and is left for a manual retry instead of risking a duplicate.
public static class YakalamaGonderimi
{
    // A claim younger than this means a send may be running; the user cannot edit or delete the capture meanwhile.
    public static readonly TimeSpan ElKoymaSuresi = TimeSpan.FromMinutes(5);

    public static bool Gonderiliyor(Yakalama y, DateTimeOffset simdi) =>
        y.GonderimBasladiAt is { } t && simdi - t < ElKoymaSuresi;

    // Failed sends wait one more minute each time, up to half an hour.
    public static TimeSpan Bekleme(int denemeSayisi) => TimeSpan.FromMinutes(Math.Clamp(denemeSayisi, 1, 30));

    public record TurOzeti(int Gonderilen, int Hatali, int Belirsiz);

    public static async Task<TurOzeti> TurAsync(
        AppDbContext db, DosyaDeposu depo, BeyinIstemcisi beyin, BeyinAyari ayar, DateTimeOffset simdi, CancellationToken ct)
    {
        if (!beyin.Bagli)
            return new TurOzeti(0, 0, 0);

        var hazirSinir = simdi - ayar.GonderimGecikmesi;
        var adaylar = await db.Yakalamalar.AsNoTracking()
            .Where(y => y.Durum == YakalamaDurumu.Bekliyor && y.GonderimBasladiAt == null && y.GuncellendiAt <= hazirSinir)
            .OrderBy(y => y.YakalandiAt).ThenBy(y => y.Id)
            .Select(y => new { y.Id, y.GuncellendiAt, y.DenemeSayisi, y.SonDenemeAt })
            .ToListAsync(ct);

        int gonderilen = 0, hatali = 0, belirsiz = 0;
        foreach (var aday in adaylar)
        {
            if (aday.SonDenemeAt is { } son && simdi - son < Bekleme(aday.DenemeSayisi))
                continue;

            // The claim: it matches only if nobody edited the capture or took it since the list above.
            var alindi = await db.Yakalamalar
                .Where(y => y.Id == aday.Id && y.Durum == YakalamaDurumu.Bekliyor && y.GonderimBasladiAt == null && y.GuncellendiAt == aday.GuncellendiAt)
                .ExecuteUpdateAsync(s => s.SetProperty(y => y.GonderimBasladiAt, simdi), ct);
            if (alindi == 0)
                continue;

            var sonuc = await GonderAsync(db, depo, beyin, aday.Id, ct);
            switch (sonuc)
            {
                case { Durum: BeyinDurumu.Tamam }:
                    await db.Yakalamalar.Where(y => y.Id == aday.Id).ExecuteUpdateAsync(s => s
                        .SetProperty(y => y.Durum, YakalamaDurumu.BeyneGitti)
                        .SetProperty(y => y.SonHata, (string?)null)
                        .SetProperty(y => y.SonDenemeAt, simdi), ct);
                    gonderilen++;
                    break;

                case { GuvenleTekrarlanir: true }:
                    // Known to have written nothing: release the claim and try again later.
                    await db.Yakalamalar.Where(y => y.Id == aday.Id).ExecuteUpdateAsync(s => s
                        .SetProperty(y => y.GonderimBasladiAt, (DateTimeOffset?)null)
                        .SetProperty(y => y.DenemeSayisi, y => y.DenemeSayisi + 1)
                        .SetProperty(y => y.SonDenemeAt, simdi)
                        .SetProperty(y => y.SonHata, Kisalt(sonuc.Mesaj)), ct);
                    hatali++;
                    break;

                default:
                    // Timeout or unreadable output: keep the claim, say so.
                    await db.Yakalamalar.Where(y => y.Id == aday.Id).ExecuteUpdateAsync(s => s
                        .SetProperty(y => y.DenemeSayisi, y => y.DenemeSayisi + 1)
                        .SetProperty(y => y.SonDenemeAt, simdi)
                        .SetProperty(y => y.SonHata, Kisalt("Gönderim sonucu belirsiz, kart beyinde olabilir; elle kontrol et. " + sonuc.Mesaj)), ct);
                    belirsiz++;
                    break;
            }
        }

        return new TurOzeti(gonderilen, hatali, belirsiz);
    }

    private static async Task<BeyinSonucu> GonderAsync(AppDbContext db, DosyaDeposu depo, BeyinIstemcisi beyin, Guid id, CancellationToken ct)
    {
        string? gecici = null;
        try
        {
            var y = await db.Yakalamalar.AsNoTracking().Include(x => x.Fotograf).SingleAsync(x => x.Id == id, ct);

            string? gorsel = null;
            if (y.Fotograf is { } dosya)
            {
                try
                {
                    (gorsel, gecici) = JpegCevirici.Hazirla(depo.YolBul(dosya), dosya.IcerikTuru);
                }
                catch (Exception e) when (e is IOException or InvalidDataException)
                {
                    // Nothing was sent yet, so this counts as a clean failure.
                    return new BeyinSonucu(BeyinDurumu.BeyinHatasi, HataKodu: "fotograf", Mesaj: "Fotoğraf hazırlanamadı: " + e.Message);
                }
            }

            return await beyin.GelenEkleAsync(y.Metin, gorsel, y.Hedef, y.YakalandiAt, ct);
        }
        finally
        {
            if (gecici is not null)
                File.Delete(gecici);
        }
    }

    private static string Kisalt(string? mesaj) =>
        string.IsNullOrEmpty(mesaj) ? "Bilinmeyen hata." : mesaj.Length <= 1000 ? mesaj : mesaj[..1000];
}

// Runs a round every GonderimAraligi. The brain being off or missing is not an error: the round does nothing.
public class YakalamaGondericisi(IServiceScopeFactory kapsamlar, BeyinAyari ayar, ILogger<YakalamaGondericisi> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (!ayar.Acik)
        {
            log.LogInformation("Brain is not configured; captures stay in the app.");
            return;
        }

        using var zamanlayici = new PeriodicTimer(ayar.GonderimAraligi);
        do
        {
            try
            {
                using var kapsam = kapsamlar.CreateScope();
                var ozet = await YakalamaGonderimi.TurAsync(
                    kapsam.ServiceProvider.GetRequiredService<AppDbContext>(),
                    kapsam.ServiceProvider.GetRequiredService<DosyaDeposu>(),
                    kapsam.ServiceProvider.GetRequiredService<BeyinIstemcisi>(), ayar, DateTimeOffset.UtcNow, ct);
                if (ozet.Gonderilen + ozet.Hatali + ozet.Belirsiz > 0)
                    log.LogInformation("Captures to brain: {Sent} sent, {Failed} failed (will retry), {Unsure} unsure.", ozet.Gonderilen, ozet.Hatali, ozet.Belirsiz);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "Sending captures to the brain failed.");
            }
        } while (await zamanlayici.WaitForNextTickAsync(ct));
    }
}
