using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

public class OgeModel(AppDbContext db) : PageModel
{
    public Aliskanlik Aliskanlik { get; private set; } = null!;

    public OgeDto Oge { get; private set; } = null!;

    // Newest first; the first one is the only one that can be changed or deleted.
    public List<OturumDto> Oturumlar { get; private set; } = [];

    [TempData]
    public string? Hata { get; set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    public async Task<IActionResult> OnGetAsync(Guid id, CancellationToken ct)
    {
        var oge = await AliskanlikIslemleri.OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == id, ct);
        if (oge is null)
            return NotFound();

        Aliskanlik = (await db.Aliskanliklar.FindAsync([oge.AliskanlikId], ct))!;
        Oge = OgeEndpoints.OgeDtoYap(oge, AliskanlikIslemleri.Bugun());
        Oturumlar = oge.Oturumlar.OrderByDescending(t => t.BitisKonum)
            .Select((t, i) => OgeEndpoints.OturumDtoYap(t, son: i == 0)).ToList();
        return Page();
    }

    // "I got to page 35".
    public async Task<IActionResult> OnPostIlerlemeAsync(Guid id, decimal? bitisKonum, int? dakika, CancellationToken ct)
    {
        var oge = await AliskanlikIslemleri.OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == id, ct);
        if (oge is null)
            return NotFound();
        if (bitisKonum is null)
            return Don(id, Sonuc.Gecersiz("bitisKonum", "Nereye kadar geldiğini yaz."));

        var (sonuc, _) = await AliskanlikIslemleri.OturumEkleAsync(db, oge,
            new OturumEkleDto { BitisKonum = bitisKonum.Value, Dakika = dakika }, ct);
        return Don(id, sonuc, "Oturum kaydedildi");
    }

    public async Task<IActionResult> OnPostOturumGuncelleAsync(Guid id, Guid oturumId, decimal? bitisKonum, int? dakika, CancellationToken ct)
    {
        var oturum = await db.Oturumlar.Include(t => t.Oge).FirstOrDefaultAsync(t => t.Id == oturumId && t.OgeId == id, ct);
        if (oturum is null)
            return NotFound();
        if (bitisKonum is null)
            return Don(id, Sonuc.Gecersiz("bitisKonum", "Nereye kadar geldiğini yaz."));

        return Don(id, await AliskanlikIslemleri.OturumGuncelleAsync(db, oturum, bitisKonum.Value, dakika, ct), "Oturum güncellendi");
    }

    public async Task<IActionResult> OnPostOturumSilAsync(Guid id, Guid oturumId, CancellationToken ct)
    {
        var oturum = await db.Oturumlar.Include(t => t.Oge).FirstOrDefaultAsync(t => t.Id == oturumId && t.OgeId == id, ct);
        if (oturum is null)
            return NotFound();

        return Don(id, await AliskanlikIslemleri.OturumSilAsync(db, oturum, ct), "Oturum silindi");
    }

    // Move the item to another shelf (continue, finish by hand, give up).
    public async Task<IActionResult> OnPostDurumAsync(Guid id, OgeDurumu durum, CancellationToken ct)
    {
        var oge = await db.Ogeler.FindAsync([id], ct);
        if (oge is null)
            return NotFound();

        await AliskanlikIslemleri.OgeDurumAsync(db, oge, durum, ct);
        return Don(id, Sonuc.Tamam, "Raf: " + Gorunum.DurumAdi(durum));
    }

    // Post-redirect-get.
    private IActionResult Don(Guid id, Sonuc sonuc, string? bildirim = null)
    {
        if (!sonuc.Basarili)
            Hata = sonuc.Mesaj;
        else
            Bildirim = bildirim;

        return RedirectToPage("Oge", new { id });
    }
}
