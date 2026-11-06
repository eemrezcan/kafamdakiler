using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Hatirlaticilar;

public class DuzenleModel(AppDbContext db, HatirlaticiAyari ayar, TimeProvider saat) : PageModel
{
    [BindProperty]
    public HatirlaticiYazDto Input { get; set; } = new();

    public Guid? HatirlaticiId { get; private set; }

    public bool Yeni => HatirlaticiId is null;

    public TimeOnly VarsayilanSaat => ayar.VarsayilanSaat;

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    public async Task<IActionResult> OnGetAsync(Guid? id, CancellationToken ct)
    {
        if (id is null)
        {
            Input = new HatirlaticiYazDto { Gun = HatirlaticiHesap.IstanbulGunu(saat.GetUtcNow()) };
            return Page();
        }

        var h = await db.Hatirlaticilar.FindAsync([id.Value], ct);
        if (h is null)
            return NotFound();

        HatirlaticiId = h.Id;
        Input = new HatirlaticiYazDto
        {
            Baslik = h.Baslik, Not = h.Not, Tur = h.Tur, Kime = h.Kime, Gun = h.Gun, Saat = h.Saat,
            Tekrar = h.Tekrar, OnceGun = h.OnceGun, Durum = h.Durum,
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(Guid? id, CancellationToken ct)
    {
        Hatirlatici? h = null;
        if (id is { } hatirlaticiId)
        {
            h = await db.Hatirlaticilar.FindAsync([hatirlaticiId], ct);
            if (h is null)
                return NotFound();

            HatirlaticiId = h.Id;
        }

        if (!ModelState.IsValid)
            return Page();

        if (h is null)
        {
            h = new Hatirlatici();
            db.Hatirlaticilar.Add(h);
        }

        HatirlaticiIslemleri.Uygula(h, Input, ayar.VarsayilanSaat, saat.GetUtcNow());
        await db.SaveChangesAsync(ct);

        Bildirim = "Kaydedildi";
        return RedirectToPage("Index");
    }

    public async Task<IActionResult> OnPostSilAsync(Guid id, CancellationToken ct)
    {
        var h = await db.Hatirlaticilar.FindAsync([id], ct);
        if (h is null)
            return NotFound();

        db.Hatirlaticilar.Remove(h);
        await db.SaveChangesAsync(ct);

        Bildirim = "Silindi";
        return RedirectToPage("Index");
    }
}
