using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Takvim;

// `Basarisiz` counts calendars whose round failed (nothing of theirs was changed); `ErisimSorunu` is set when no round could start.
public record EsitlemeOzeti(int Takvim, int Eklenen, int Guncellenen, int Silinen, int Basarisiz, ErisimDurumu? ErisimSorunu = null);

// Pulls the events of the chosen calendars from Google into TakvimEtkinligi (K2.3c). Incremental by sync token; a full sync
// when there is no token, when Google says the token is too old (410), and at least once a day so the 7-days-back, 60-days-ahead
// window keeps moving (a sync token keeps the window of the full sync it came from).
//
// What a failure may not do is lose data silently: every page of an answer is read before anything is written, then all of a
// calendar's changes and its new token are saved together. A round that fails halfway changes nothing and leaves the old token,
// so the next round starts from the same place.
public class TakvimEsitleyici(
    AppDbContext db, IGoogleTakvimIstemcisi istemci, GoogleErisimi erisim, TakvimAyari ayar, TimeProvider saat, ILogger<TakvimEsitleyici> gunluk)
{
    public static readonly TimeSpan TamEsitlemeAraligi = TimeSpan.FromHours(24);

    private const int EnCokSayfa = 100;
    private const int BaslikEnUzun = 500;
    private const string BasliksizAd = "(Başlıksız)";

    // The background round and a manual one must not run over each other.
    private static readonly SemaphoreSlim Kilit = new(1, 1);

    private sealed record Toplanan(Dictionary<string, GoogleEtkinlik> Etkinlikler, string SyncToken);

    public async Task<EsitlemeOzeti> TurAsync(CancellationToken ct)
    {
        if (!ayar.Acik)
            return new EsitlemeOzeti(0, 0, 0, 0, 0, ErisimDurumu.Kapali);

        await Kilit.WaitAsync(ct);
        try
        {
            var token = await erisim.TokenAlAsync(ct);
            if (!token.Basarili)
                return new EsitlemeOzeti(0, 0, 0, 0, 0, token.Durum);

            int eklenen = 0, guncellenen = 0, silinen = 0, basarisiz = 0;
            foreach (var takvim in ayar.Takvimler)
            {
                try
                {
                    var (e, g, s) = await TakvimiEsitleAsync(takvim, token.Token!, ct);
                    eklenen += e;
                    guncellenen += g;
                    silinen += s;
                }
                catch (GoogleYetkiGecersizException)
                {
                    // The access token went bad under us: a new one is made next round.
                    gunluk.LogWarning("Google refused the access token while syncing; it will be renewed.");
                    erisim.Unut();
                    db.ChangeTracker.Clear();
                    basarisiz++;
                    break;
                }
                catch (Exception e) when (e is not OperationCanceledException)
                {
                    // Nothing of this calendar was written, so the old token and the old rows stand.
                    gunluk.LogError(e, "Syncing calendar {Takvim} failed; it will be tried again.", takvim);
                    db.ChangeTracker.Clear();
                    basarisiz++;
                }
            }

            return new EsitlemeOzeti(ayar.Takvimler.Count, eklenen, guncellenen, silinen, basarisiz);
        }
        finally
        {
            Kilit.Release();
        }
    }

    private async Task<(int Eklenen, int Guncellenen, int Silinen)> TakvimiEsitleAsync(string takvim, string erisimToken, CancellationToken ct)
    {
        var simdi = saat.GetUtcNow();
        var durum = await db.TakvimEsitlemeleri.FindAsync([takvim], ct);
        var tam = durum?.SyncToken is null || durum.SonTamEsitleme is null || simdi - durum.SonTamEsitleme > TamEsitlemeAraligi;

        Toplanan? toplanan = null;
        if (!tam)
        {
            try
            {
                toplanan = await ToplaAsync(takvim, durum!.SyncToken, erisimToken, simdi, ct);
            }
            catch (GoogleSyncTokenGecersizException)
            {
                gunluk.LogInformation("The sync token of calendar {Takvim} expired (410); starting a full sync.", takvim);
                tam = true;
            }
        }

        toplanan ??= await ToplaAsync(takvim, null, erisimToken, simdi, ct);

        var mevcut = tam
            ? await db.TakvimEtkinlikleri.Where(e => e.TakvimKimligi == takvim).ToDictionaryAsync(e => e.GoogleKimligi, ct)
            : await MevcutlariAlAsync(takvim, toplanan.Etkinlikler.Keys.ToList(), ct);

        int eklenen = 0, guncellenen = 0, silinen = 0;
        foreach (var (kimlik, g) in toplanan.Etkinlikler)
        {
            mevcut.TryGetValue(kimlik, out var satir);
            if (g.Iptal)
            {
                if (satir is not null)
                {
                    db.TakvimEtkinlikleri.Remove(satir);
                    silinen++;
                }

                continue;
            }

            if (satir is not null && satir.Etag is not null && satir.Etag == g.Etag)
                continue;

            var yeniMi = satir is null;
            satir ??= new TakvimEtkinligi { TakvimKimligi = takvim, GoogleKimligi = kimlik };
            if (!Doldur(satir, g, simdi))
            {
                // No start or end: Google never sends that for an event it shows; nothing worth keeping.
                gunluk.LogWarning("An event of calendar {Takvim} has no start or end and was skipped.", takvim);
                continue;
            }

            if (yeniMi)
            {
                db.TakvimEtkinlikleri.Add(satir);
                eklenen++;
            }
            else
            {
                guncellenen++;
            }
        }

        // A full answer is the whole window: what is not in it is gone from Google (or fell out of the window).
        if (tam)
        {
            foreach (var satir in mevcut.Where(m => !toplanan.Etkinlikler.ContainsKey(m.Key)).Select(m => m.Value))
            {
                db.TakvimEtkinlikleri.Remove(satir);
                silinen++;
            }
        }

        if (durum is null)
        {
            durum = new TakvimEsitlemeDurumu { TakvimKimligi = takvim };
            db.TakvimEsitlemeleri.Add(durum);
        }

        durum.SyncToken = toplanan.SyncToken;
        durum.SonEsitleme = simdi;
        if (tam)
            durum.SonTamEsitleme = simdi;

        await db.SaveChangesAsync(ct);
        return (eklenen, guncellenen, silinen);
    }

    // Every page of one answer. No sync token at the end means the answer is not complete: it is not used.
    private async Task<Toplanan> ToplaAsync(string takvim, string? syncToken, string erisimToken, DateTimeOffset simdi, CancellationToken ct)
    {
        var etkinlikler = new Dictionary<string, GoogleEtkinlik>(StringComparer.Ordinal);
        string? sayfa = null;
        for (var i = 0; i < EnCokSayfa; i++)
        {
            var istek = new GoogleListeIstegi(
                takvim, syncToken,
                syncToken is null ? simdi.AddDays(-TakvimAyari.GecmisGun) : null,
                syncToken is null ? simdi.AddDays(TakvimAyari.GelecekGun) : null,
                sayfa);
            var yanit = await istemci.EtkinlikleriListeleAsync(istek, erisimToken, ct);
            foreach (var g in yanit.Etkinlikler)
                etkinlikler[g.Kimlik] = g;

            if (yanit.SonrakiSayfaToken is null)
            {
                return yanit.SonrakiSyncToken is { Length: > 0 } yeni
                    ? new Toplanan(etkinlikler, yeni)
                    : throw new InvalidOperationException("Google's last page carried no sync token.");
            }

            sayfa = yanit.SonrakiSayfaToken;
        }

        throw new InvalidOperationException($"Google's answer has more than {EnCokSayfa} pages.");
    }

    private async Task<Dictionary<string, TakvimEtkinligi>> MevcutlariAlAsync(string takvim, List<string> kimlikler, CancellationToken ct) =>
        kimlikler.Count == 0
            ? []
            : await db.TakvimEtkinlikleri.Where(e => e.TakvimKimligi == takvim && kimlikler.Contains(e.GoogleKimligi))
                .ToDictionaryAsync(e => e.GoogleKimligi, ct);

    private static bool Doldur(TakvimEtkinligi e, GoogleEtkinlik g, DateTimeOffset simdi)
    {
        if (g.Baslangic is not { } bas || g.Bitis is not { } bit)
            return false;

        e.Baslik = TakvimZamani.Duzelt(g.Baslik, BaslikEnUzun) is { Length: > 0 } baslik ? baslik : BasliksizAd;
        e.Yer = TakvimZamani.Duzelt(g.Yer, BaslikEnUzun) is { Length: > 0 } yer ? yer : null;
        e.Etag = g.Etag;
        e.GuncellemeAni = simdi;
        e.TumGun = bas.TumGun;

        var gece = TimeOnly.MinValue;
        if (bas.TumGun)
        {
            var ilk = bas.Gun!.Value;
            var son = bit.Gun ?? HatirlaticiHesap.IstanbulGunu(bit.An!.Value);
            if (son <= ilk)
                son = ilk.AddDays(1);

            e.BaslangicGunu = ilk;
            e.BitisGunu = son;
            e.Baslangic = HatirlaticiHesap.An(ilk, gece);
            e.Bitis = HatirlaticiHesap.An(son, gece);
        }
        else
        {
            var baslangic = bas.An!.Value.ToUniversalTime();
            var bitis = (bit.An ?? HatirlaticiHesap.An(bit.Gun!.Value, gece)).ToUniversalTime();
            if (bitis < baslangic)
                bitis = baslangic;

            e.Baslangic = baslangic;
            e.Bitis = bitis;
            e.BaslangicGunu = HatirlaticiHesap.IstanbulGunu(baslangic);
            e.BitisGunu = HatirlaticiHesap.IstanbulGunu(bitis);
        }

        return true;
    }
}

// Every few minutes: the chosen calendars are synced. With the Google settings missing it does nothing at all, quietly; with no
// account connected a round is a quick look at the database. The first round comes after one interval, not at start-up.
public class TakvimEsitlemeServisi(IServiceScopeFactory kapsamlar, TakvimAyari ayar, ILogger<TakvimEsitlemeServisi> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (ayar.Uyari is not null)
            log.LogWarning("{Uyari}", ayar.Uyari);
        if (!ayar.Acik)
        {
            log.LogInformation("Google Calendar is not configured; no calendar sync.");
            return;
        }

        using var zamanlayici = new PeriodicTimer(ayar.EsitlemeAraligi);
        while (await zamanlayici.WaitForNextTickAsync(ct))
        {
            try
            {
                using var kapsam = kapsamlar.CreateScope();
                var ozet = await kapsam.ServiceProvider.GetRequiredService<TakvimEsitleyici>().TurAsync(ct);
                if (ozet.Eklenen + ozet.Guncellenen + ozet.Silinen + ozet.Basarisiz > 0)
                    log.LogInformation("Calendar sync: {Added} added, {Updated} updated, {Deleted} deleted, {Failed} calendars failed.", ozet.Eklenen, ozet.Guncellenen, ozet.Silinen, ozet.Basarisiz);
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                log.LogError(e, "The calendar sync round failed.");
            }
        }
    }
}
