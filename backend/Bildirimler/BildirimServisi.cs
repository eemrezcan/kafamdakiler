using Kafamdakiler.Aliskanliklar;
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
        Guid kullaniciId, string baslik, string metin, string kaynakTuru, string? rota, string? hedefKimligi, CancellationToken ct,
        string? anahtar = null)
    {
        var bildirim = new Bildirim
        {
            KullaniciId = kullaniciId, Baslik = baslik, Metin = metin, KaynakTuru = kaynakTuru, Rota = rota, HedefKimligi = hedefKimligi,
            Anahtar = anahtar, OlusmaAni = saat.GetUtcNow(),
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

    // Sends a notification that is "one per occurrence": the same `anahtar` for the same user is never made twice. Returns false when
    // it already exists (nothing is sent). If every device failed (a network or FCM error, not a dead token) the row is taken
    // back, so the next round can try the same occurrence again; a dead token or a send that went through keeps it.
    public async Task<bool> BirKezOlusturVeGonderAsync(
        Guid kullaniciId, string baslik, string metin, string kaynakTuru, string? rota, string? hedefKimligi, string anahtar, CancellationToken ct)
    {
        if (await db.Bildirimler.AnyAsync(b => b.KullaniciId == kullaniciId && b.Anahtar == anahtar, ct))
            return false;

        Bildirim bildirim;
        try
        {
            bildirim = await OlusturAsync(kullaniciId, baslik, metin, kaynakTuru, rota, hedefKimligi, ct, anahtar);
        }
        catch (DbUpdateException)
        {
            // Two rounds at once made the same occurrence; the unique index kept one.
            db.ChangeTracker.Clear();
            return false;
        }

        var sonuc = await GonderAsync(bildirim, ct);
        if (sonuc is { Giden: 0, Hatali: > 0 })
        {
            db.Bildirimler.Remove(bildirim);
            await db.SaveChangesAsync(ct);
            return false;
        }

        return true;
    }

    // The users who have a phone registered and may read what a notification says: the Sahip, or the holders of every named
    // permission. A notification is made per user, so nobody is told what their permissions would not let them open.
    public async Task<List<Guid>> AlicilarAsync(string[] izinler, CancellationToken ct)
    {
        var cihazliOlanlar = await db.BildirimCihazlari.Select(c => c.KullaniciId).Distinct().ToListAsync(ct);
        if (cihazliOlanlar.Count == 0)
            return [];

        var sahipler = await (from ur in db.UserRoles
                              join r in db.Roles on ur.RoleId equals r.Id
                              where r.Name == SeedData.OwnerRole && cihazliOlanlar.Contains(ur.UserId)
                              select ur.UserId).ToListAsync(ct);
        var verilenler = await db.UserClaims
            .Where(c => c.ClaimType == AliskanlikPolicies.IzinClaim && c.ClaimValue != null && izinler.Contains(c.ClaimValue) && cihazliOlanlar.Contains(c.UserId))
            .Select(c => new { c.UserId, Izin = c.ClaimValue! }).ToListAsync(ct);

        return cihazliOlanlar
            .Where(id => sahipler.Contains(id) || izinler.All(izin => verilenler.Any(v => v.UserId == id && v.Izin == izin)))
            .ToList();
    }

    // A token that comes again is moved to this user and refreshed, not added twice. One statement (insert, or update on the unique
    // token): two requests with the same new token at once cannot collide, so there is no failed insert to catch and no error to log.
    public async Task<BildirimCihazi> CihazKaydetAsync(Guid kullaniciId, string token, string? cihazAdi, CancellationToken ct)
    {
        var simdi = saat.GetUtcNow();
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO "BildirimCihazlari" ("Id", "KullaniciId", "Token", "CihazAdi", "KayitAni", "GuncellemeAni")
            VALUES ({Guid.CreateVersion7()}, {kullaniciId}, {token}, CAST({cihazAdi} AS text), {simdi}, {simdi})
            ON CONFLICT ("Token") DO UPDATE
            SET "KullaniciId" = EXCLUDED."KullaniciId", "CihazAdi" = EXCLUDED."CihazAdi", "GuncellemeAni" = EXCLUDED."GuncellemeAni"
            """, ct);
        return await db.BildirimCihazlari.AsNoTracking().FirstAsync(c => c.Token == token, ct);
    }

    // Only the user's own row goes. Returns whether one was deleted.
    public async Task<bool> CihazSilAsync(Guid kullaniciId, string token, CancellationToken ct) =>
        await db.BildirimCihazlari.Where(c => c.KullaniciId == kullaniciId && c.Token == token).ExecuteDeleteAsync(ct) > 0;

    public Task<int> CihazSayisiAsync(CancellationToken ct) => db.BildirimCihazlari.CountAsync(ct);
}
