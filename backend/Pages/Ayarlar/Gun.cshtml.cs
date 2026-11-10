using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Ayarlar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Ayarlar;

// The day capacity (K-0024, §5): how many minutes of planned work fit in a weekday and in a weekend day. The same row and the same limits as
// PUT /api/ayarlar/gun; the Bugün weight bar, the day warning and the briefing read it. The web is the Sahip's, so there is no further check.
public class GunModel(AppDbContext db, GunAyari yedek) : PageModel
{
    // Minutes, with the API's own limits (1 to 1440).
    [BindProperty]
    public GunAyarlariYazDto Input { get; set; } = new();

    // True while the setting is the `Gun:KapasiteSaat` fallback: nothing was saved yet.
    public bool Varsayilan { get; private set; }

    [TempData]
    public string? Bildirim { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        Varsayilan = !await db.GunAyarlari.AnyAsync(ct);
        var ayar = await GunKapasitesi.AyarAsync(db, yedek, ct);
        Input = new GunAyarlariYazDto { HaftaIciDk = ayar.HaftaIciDk, HaftaSonuDk = ayar.HaftaSonuDk };
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            Varsayilan = !await db.GunAyarlari.AnyAsync(ct);
            return Page();
        }

        var satir = await db.GunAyarlari.FirstOrDefaultAsync(ct);
        if (satir is null)
        {
            satir = new GunAyarlari();
            db.GunAyarlari.Add(satir);
        }

        satir.HaftaIciDk = Input.HaftaIciDk!.Value;
        satir.HaftaSonuDk = Input.HaftaSonuDk!.Value;
        await db.SaveChangesAsync(ct);

        Bildirim = "Kapasite kaydedildi";
        return RedirectToPage();
    }
}
