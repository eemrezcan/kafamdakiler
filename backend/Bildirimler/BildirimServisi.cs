using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Bildirimler;

// How the last send went, for Yönetim. Kept in memory: it is a status light, not a record (the notification rows are the record).
public record SonGonderim(DateTimeOffset An, int Hedef, int Giden, int Silinen, int Hatali);

public class PushDurumu
{
    private SonGonderim? _son;

    public SonGonderim? Son => Volatile.Read(ref _son);

    public void Yaz(SonGonderim son) => Volatile.Write(ref _son, son);
}

// Makes the notification row and wakes the user's phones. Other modules (F: reminders, brain tasks) call OlusturVeGonderAsync.
public class BildirimServisi(AppDbContext db, PushAyari ayar, IPushGondericisi gondericisi, PushDurumu durum, TimeProvider saat)
{
    public bool PushAcik => ayar.Acik;

    public async Task<Bildirim> OlusturAsync(
        Guid kullaniciId, string baslik, string metin, string kaynakTuru, string? rota, string? hedefKimligi, CancellationToken ct)
    {
        var bildirim = new Bildirim
        {
            KullaniciId = kullaniciId, Baslik = baslik, Metin = metin, KaynakTuru = kaynakTuru, Rota = rota, HedefKimligi = hedefKimligi,
            OlusmaAni = saat.GetUtcNow(),
        };
        db.Bildirimler.Add(bildirim);
        await db.SaveChangesAsync(ct);
        return bildirim;
    }

    // Sends to every device of the notification's user. Dead tokens are deleted. Does nothing (null) while push is off.
    public async Task<SonGonderim?> GonderAsync(Bildirim bildirim, CancellationToken ct)
    {
        if (!ayar.Acik)
            return null;

        var cihazlar = await db.BildirimCihazlari.Where(c => c.KullaniciId == bildirim.KullaniciId).ToListAsync(ct);
        int giden = 0, hatali = 0;
        var olenler = new List<BildirimCihazi>();
        foreach (var cihaz in cihazlar)
        {
            switch (await gondericisi.GonderAsync(cihaz.Token, bildirim.Id, ct))
            {
                case PushSonucu.Gitti:
                    giden++;
                    break;
                case PushSonucu.GecersizToken:
                    olenler.Add(cihaz);
                    break;
                default:
                    hatali++;
                    break;
            }
        }

        if (olenler.Count > 0)
        {
            db.BildirimCihazlari.RemoveRange(olenler);
            await db.SaveChangesAsync(ct);
        }

        var son = new SonGonderim(saat.GetUtcNow(), cihazlar.Count, giden, olenler.Count, hatali);
        durum.Yaz(son);
        return son;
    }

    public async Task<SonGonderim?> OlusturVeGonderAsync(
        Guid kullaniciId, string baslik, string metin, string kaynakTuru, string? rota, string? hedefKimligi, CancellationToken ct) =>
        await GonderAsync(await OlusturAsync(kullaniciId, baslik, metin, kaynakTuru, rota, hedefKimligi, ct), ct);

    // A token that comes again is moved to this user and refreshed, not added twice.
    public async Task<BildirimCihazi> CihazKaydetAsync(Guid kullaniciId, string token, string? cihazAdi, CancellationToken ct)
    {
        var simdi = saat.GetUtcNow();
        var cihaz = await db.BildirimCihazlari.FirstOrDefaultAsync(c => c.Token == token, ct);
        if (cihaz is null)
        {
            cihaz = new BildirimCihazi { Token = token, KayitAni = simdi };
            db.BildirimCihazlari.Add(cihaz);
        }

        cihaz.KullaniciId = kullaniciId;
        cihaz.CihazAdi = cihazAdi;
        cihaz.GuncellemeAni = simdi;
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // The same token arrived twice at once and the other request won the unique index: update that row instead.
            db.ChangeTracker.Clear();
            if (!await db.BildirimCihazlari.AsNoTracking().AnyAsync(c => c.Token == token, ct))
                throw;

            return await CihazKaydetAsync(kullaniciId, token, cihazAdi, ct);
        }

        return cihaz;
    }

    // Only the user's own row goes. Returns whether one was deleted.
    public async Task<bool> CihazSilAsync(Guid kullaniciId, string token, CancellationToken ct) =>
        await db.BildirimCihazlari.Where(c => c.KullaniciId == kullaniciId && c.Token == token).ExecuteDeleteAsync(ct) > 0;

    public Task<int> CihazSayisiAsync(CancellationToken ct) => db.BildirimCihazlari.CountAsync(ct);
}
