using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Dosyalar;

// The one rule for attaching a photo to a record (an item cover or a capture): the file must exist and must belong
// to no other record. Deleting a record (or replacing its photo) deletes the file, so a shared photo would vanish
// from the other record. Habits and captures both call this.
public static class FotografKurali
{
    // `kendiOge` / `kendiYakalama` are the record being updated (null on create); its own photo is not "another record".
    public static async Task<Sonuc?> HataAsync(AppDbContext db, Guid? fotografId, Guid? kendiOge, Guid? kendiYakalama, CancellationToken ct)
    {
        if (fotografId is not { } id)
            return null;
        if (!await db.Dosyalar.AnyAsync(d => d.Id == id, ct))
            return Sonuc.Gecersiz("fotografId", "Fotoğraf bulunamadı.");
        if (await db.Ogeler.AnyAsync(o => o.FotografId == id && o.Id != kendiOge, ct)
            || await db.Yakalamalar.AnyAsync(y => y.FotografId == id && y.Id != kendiYakalama, ct))
            return Sonuc.Gecersiz("fotografId", "Fotoğraf başka bir kayda bağlı.");

        return null;
    }
}
