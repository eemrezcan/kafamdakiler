using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Yakalamalar;

// The write rules of captures. The /api endpoints and the Razor pages both call these, so a rule lives in one place.
public static class YakalamaIslemleri
{
    public static async Task<(Sonuc Sonuc, Yakalama? Yakalama)> OlusturAsync(AppDbContext db, YakalamaYazDto dto, CancellationToken ct)
    {
        if (await FotografYokMu(db, dto.FotografId, ct))
            return (Sonuc.Gecersiz("fotografId", "Fotoğraf bulunamadı."), null);

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
        if (dto.FotografId != y.FotografId && await FotografYokMu(db, dto.FotografId, ct))
            return Sonuc.Gecersiz("fotografId", "Fotoğraf bulunamadı.");

        var eskiFotograf = y.FotografId;
        Uygula(y, dto);
        await db.SaveChangesAsync(ct);

        // A replaced or removed photo is no longer used by anything: remove it from the disk too.
        if (eskiFotograf is { } eski && eski != y.FotografId)
            await depo.SilAsync([eski], ct);

        return Sonuc.Tamam;
    }

    public static async Task<Sonuc> SilAsync(AppDbContext db, DosyaDeposu depo, Yakalama y, CancellationToken ct)
    {
        if (y.Durum != YakalamaDurumu.Bekliyor)
            return Sonuc.Catisma("Yalnız bekleyen yakalama silinebilir.");

        var fotograf = y.FotografId;
        db.Yakalamalar.Remove(y);
        await db.SaveChangesAsync(ct);
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
    }

    private static async Task<bool> FotografYokMu(AppDbContext db, Guid? fotografId, CancellationToken ct) =>
        fotografId is { } id && !await db.Dosyalar.AnyAsync(d => d.Id == id, ct);
}
