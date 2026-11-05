using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Yakalamalar;

// The write rules of captures. The /api endpoints and the Razor pages both call these, so a rule lives in one place.
public static class YakalamaIslemleri
{
    public static async Task<(Sonuc Sonuc, Yakalama? Yakalama)> OlusturAsync(AppDbContext db, YakalamaYazDto dto, CancellationToken ct)
    {
        if (await FotografHatasi(db, dto.FotografId, null, ct) is { } hata)
            return (hata, null);

        var y = new Yakalama();
        if (dto.Id is { } id)
            y.Id = id;
        Uygula(y, dto);
        db.Yakalamalar.Add(y);
        await db.SaveChangesAsync(ct);
        return (Sonuc.Tamam, y);
    }

    public static async Task<Sonuc> GuncelleAsync(AppDbContext db, DosyaDeposu depo, Yakalama y, YakalamaYazDto dto, CancellationToken ct)
    {
        if (y.Durum != YakalamaDurumu.Bekliyor)
            return Sonuc.Catisma("Yalnız bekleyen yakalama değiştirilebilir.");
        if (YakalamaGonderimi.Gonderiliyor(y, DateTimeOffset.UtcNow))
            return Sonuc.Catisma(GonderiliyorMesaji);
        if (dto.FotografId != y.FotografId && await FotografHatasi(db, dto.FotografId, y.Id, ct) is { } hata)
            return hata;

        var eskiFotograf = y.FotografId;
        Uygula(y, dto);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            // The sender took the capture between our read and our save.
            return Sonuc.Catisma(GonderiliyorMesaji);
        }

        // A replaced or removed photo is no longer used by anything: remove it from the disk too.
        if (eskiFotograf is { } eski && eski != y.FotografId)
            await depo.SilAsync([eski], ct);

        return Sonuc.Tamam;
    }

    public static async Task<Sonuc> SilAsync(AppDbContext db, DosyaDeposu depo, Yakalama y, CancellationToken ct)
    {
        if (y.Durum != YakalamaDurumu.Bekliyor)
            return Sonuc.Catisma("Yalnız bekleyen yakalama silinebilir.");
        if (YakalamaGonderimi.Gonderiliyor(y, DateTimeOffset.UtcNow))
            return Sonuc.Catisma(GonderiliyorMesaji);

        var fotograf = y.FotografId;
        db.Yakalamalar.Remove(y);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException)
        {
            return Sonuc.Catisma(GonderiliyorMesaji);
        }

        if (fotograf is { } f)
            await depo.SilAsync([f], ct);

        return Sonuc.Tamam;
    }

    private static void Uygula(Yakalama y, YakalamaYazDto dto)
    {
        y.Metin = string.IsNullOrWhiteSpace(dto.Metin) ? null : dto.Metin.Trim();
        y.FotografId = dto.FotografId;
        y.Hedef = string.IsNullOrWhiteSpace(dto.Hedef) ? null : dto.Hedef;
        y.YakalandiAt = dto.YakalandiAt!.Value.ToUniversalTime();

        // An edit restarts the wait before sending, and a capture that failed to send gets a fresh start.
        // A capture still claimed (unsure whether it was sent) keeps its note until someone retries it by hand.
        y.GuncellendiAt = DateTimeOffset.UtcNow;
        if (y.GonderimBasladiAt is null)
        {
            y.DenemeSayisi = 0;
            y.SonDenemeAt = null;
            y.SonHata = null;
        }
    }

    // The mobile app tells this 409 ("try again later") from the permanent ones by this wording, so keep "gönderiliyor" in it.
    internal const string GonderiliyorMesaji = "Yakalama şu an beyne gönderiliyor; birazdan tekrar dene.";

    private static Task<Sonuc?> FotografHatasi(AppDbContext db, Guid? fotografId, Guid? kendisi, CancellationToken ct) =>
        FotografKurali.HataAsync(db, fotografId, null, kendisi, ct);
}
