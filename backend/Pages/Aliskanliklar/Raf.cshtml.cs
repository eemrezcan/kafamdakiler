using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

public class RafModel(AppDbContext db) : PageModel
{
    public Aliskanlik Aliskanlik { get; private set; } = null!;

    // The four shelves, in display order.
    public IReadOnlyList<(OgeDurumu Durum, List<OgeDto> Ogeler)> Raflar { get; private set; } = [];

    public IReadOnlyList<(int Yil, int Adet, decimal Miktar)> YilOzeti { get; private set; } = [];

    public async Task<IActionResult> OnGetAsync(Guid aliskanlikId, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([aliskanlikId], ct);
        if (a is null)
            return NotFound();
        if (a.Tur != AliskanlikTuru.Raf)
            return RedirectToPage("Detay", new { id = a.Id });

        Aliskanlik = a;
        var bugun = AliskanlikIslemleri.Bugun();
        var ogeler = (await AliskanlikIslemleri.OgeSorgu(db).Where(o => o.AliskanlikId == aliskanlikId).ToListAsync(ct))
            .Select(o => OgeEndpoints.OgeDtoYap(o, bugun)).ToList();

        Raflar =
        [
            (OgeDurumu.Devam, ogeler.Where(o => o.Durum == OgeDurumu.Devam).OrderBy(o => o.Olusturulma).ToList()),
            (OgeDurumu.Siradaki, ogeler.Where(o => o.Durum == OgeDurumu.Siradaki).OrderBy(o => o.Olusturulma).ToList()),
            (OgeDurumu.Bitti, ogeler.Where(o => o.Durum == OgeDurumu.Bitti).OrderByDescending(o => o.BitisTarihi).ToList()),
            (OgeDurumu.Birakildi, ogeler.Where(o => o.Durum == OgeDurumu.Birakildi).OrderByDescending(o => o.Olusturulma).ToList()),
        ];

        YilOzeti = OgeHesap.YilOzeti(ogeler.Where(o => o.Durum == OgeDurumu.Bitti)
            .Select(o => (o.BitisTarihi ?? bugun, o.GuncelKonum - o.BaslangicKonumu)));
        return Page();
    }
}
