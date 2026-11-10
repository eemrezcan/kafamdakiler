using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

public class OgeDuzenleModel(AppDbContext db, DosyaDeposu depo) : PageModel
{
    [BindProperty]
    public OgeYazDto Input { get; set; } = new();

    // New cover chosen in the form.
    [BindProperty]
    public IFormFile? Kapak { get; set; }

    [BindProperty]
    public bool KapakKaldir { get; set; }

    public Aliskanlik Aliskanlik { get; private set; } = null!;

    public Guid? OgeId { get; private set; }

    public bool Yeni => OgeId is null;

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    // The start position is locked once a session exists.
    public bool OturumVar { get; private set; }

    public string? FotografUrl { get; private set; }

    public async Task<IActionResult> OnGetAsync(Guid? id, Guid? aliskanlikId, CancellationToken ct)
    {
        var (bulundu, oge) = await Yukle(id, aliskanlikId, ct);
        if (!bulundu)
            return NotFound();

        if (oge is null)
        {
            Input = new OgeYazDto { Durum = OgeDurumu.Devam };
            return Page();
        }

        Input = new OgeYazDto
        {
            Ad = oge.Ad, AltBaslik = oge.AltBaslik, Toplam = AliskanlikIslemleri.Sade(oge.Toplam),
            BaslangicKonumu = AliskanlikIslemleri.Sade(oge.BaslangicKonumu), FotografId = oge.FotografId,
            Durum = oge.Durum, Puan = oge.Puan, Not = oge.Not,
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(Guid? id, Guid? aliskanlikId, CancellationToken ct)
    {
        var (bulundu, oge) = await Yukle(id, aliskanlikId, ct);
        if (!bulundu)
            return NotFound();
        if (!ModelState.IsValid)
            return Page();

        // Photo: a new file replaces the old one; "remove" clears it; otherwise the old one stays.
        Guid? yuklenen = null;
        if (Kapak is { Length: > 0 })
        {
            var (dosya, hata) = await depo.YukleAsync(Kapak, ct);
            if (dosya is null)
            {
                ModelState.AddModelError(nameof(Kapak), hata!);
                return Page();
            }

            yuklenen = dosya.Id;
            Input.FotografId = dosya.Id;
        }
        else
        {
            Input.FotografId = KapakKaldir ? null : oge?.FotografId;
        }

        Sonuc sonuc;
        if (oge is null)
        {
            (sonuc, oge) = await AliskanlikIslemleri.OgeOlusturAsync(db, Aliskanlik, Input, ct);
        }
        else
        {
            sonuc = await AliskanlikIslemleri.OgeGuncelleAsync(db, depo, oge, Input, ct);
        }

        if (!sonuc.Basarili)
        {
            // The new file was stored but never used.
            if (yuklenen is { } bosta)
                await depo.SilAsync([bosta], ct);

            ModelState.AddModelError(sonuc.Alan is null ? string.Empty : "Input." + sonuc.Alan, sonuc.Mesaj!);
            return Page();
        }

        Bildirim = "Kaydedildi";
        return RedirectToPage("Oge", new { id = oge!.Id });
    }

    public async Task<IActionResult> OnPostSilAsync(Guid id, CancellationToken ct)
    {
        var oge = await db.Ogeler.FindAsync([id], ct);
        if (oge is null)
            return NotFound();

        var aliskanlikId = oge.AliskanlikId;
        await AliskanlikIslemleri.OgeSilAsync(db, depo, oge, ct);
        Bildirim = "Silindi";
        return RedirectToPage("Detay", null, new { id = aliskanlikId }, "raf");
    }

    // Loads the habit (and the item when editing). Found is false when either does not exist.
    private async Task<(bool Bulundu, Oge? Oge)> Yukle(Guid? id, Guid? aliskanlikId, CancellationToken ct)
    {
        Oge? oge = null;
        if (id is { } ogeId)
        {
            oge = await AliskanlikIslemleri.OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == ogeId, ct);
            if (oge is null)
                return (false, null);

            aliskanlikId = oge.AliskanlikId;
            OgeId = oge.Id;
            OturumVar = oge.Oturumlar.Count > 0;
            FotografUrl = OgeEndpoints.FotografUrl(oge.FotografId);
        }

        if (aliskanlikId is null)
            return (false, null);

        var a = await db.Aliskanliklar.FindAsync([aliskanlikId.Value], ct);
        if (a is null || a.Tur != AliskanlikTuru.Raf)
            return (false, null);

        Aliskanlik = a;
        return (true, oge);
    }
}
