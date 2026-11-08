using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Yakalamalar;

public class DuzenleModel(AppDbContext db, DosyaDeposu depo) : PageModel
{
    [BindProperty]
    public YakalamaYazDto Input { get; set; } = new();

    // New photo chosen in the form.
    [BindProperty]
    public IFormFile? Fotograf { get; set; }

    [BindProperty]
    public bool FotografKaldir { get; set; }

    public Guid? YakalamaId { get; private set; }

    public bool Yeni => YakalamaId is null;

    public string? FotografUrl { get; private set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    // Shown on the inbox page when a capture cannot be changed (the key the Beyin pages use for a refused write).
    [TempData]
    public string? YazmaHatasi { get; set; }

    public async Task<IActionResult> OnGetAsync(Guid? id, CancellationToken ct)
    {
        if (id is null)
        {
            // The client time travels in a hidden field, so the same validation rules run on the form as on the API.
            Input = new YakalamaYazDto { YakalandiAt = DateTimeOffset.UtcNow };
            return Page();
        }

        var y = await db.Yakalamalar.FindAsync([id.Value], ct);
        if (y is null)
            return NotFound();
        if (y.Durum != YakalamaDurumu.Bekliyor)
            return Reddet("Yalnız bekleyen yakalama değiştirilebilir.");

        YakalamaId = y.Id;
        FotografUrl = YakalamaEndpoints.DtoYap(y).FotografUrl;
        Input = new YakalamaYazDto { Metin = y.Metin, FotografId = y.FotografId, Hedef = y.Hedef, YakalandiAt = y.YakalandiAt };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(Guid? id, CancellationToken ct)
    {
        Yakalama? y = null;
        if (id is { } yakalamaId)
        {
            y = await db.Yakalamalar.FindAsync([yakalamaId], ct);
            if (y is null)
                return NotFound();

            YakalamaId = y.Id;
            FotografUrl = YakalamaEndpoints.DtoYap(y).FotografUrl;
        }

        // Photo: a new file replaces the old one; "remove" clears it; otherwise the old one stays.
        Guid? yuklenen = null;
        if (Fotograf is { Length: > 0 })
        {
            var (dosya, hata) = await depo.YukleAsync(Fotograf, ct);
            if (dosya is null)
            {
                ModelState.AddModelError(nameof(Fotograf), hata!);
                return Page();
            }

            yuklenen = dosya.Id;
            Input.FotografId = dosya.Id;
        }
        else
        {
            Input.FotografId = FotografKaldir ? null : y?.FotografId;
        }

        // The "text or photo" rule needs the photo decided above, so validate again with the final value.
        ModelState.Clear();
        if (!TryValidateModel(Input, nameof(Input)))
        {
            await BostaKalaniSil(yuklenen, ct);
            return Page();
        }

        Sonuc sonuc;
        if (y is null)
        {
            (sonuc, y) = await YakalamaIslemleri.OlusturAsync(db, Input, ct);
        }
        else
        {
            sonuc = await YakalamaIslemleri.GuncelleAsync(db, depo, y, Input, ct);
        }

        if (!sonuc.Basarili)
        {
            // The new file was stored but never used.
            await BostaKalaniSil(yuklenen, ct);
            ModelState.AddModelError(sonuc.Alan is null ? string.Empty : "Input." + sonuc.Alan, sonuc.Mesaj!);
            return Page();
        }

        Bildirim = "Kaydedildi";
        return RedirectToPage("/Gelen/Index");
    }

    public async Task<IActionResult> OnPostSilAsync(Guid id, CancellationToken ct)
    {
        var y = await db.Yakalamalar.FindAsync([id], ct);
        if (y is null)
            return NotFound();

        var sonuc = await YakalamaIslemleri.SilAsync(db, depo, y, ct);
        if (!sonuc.Basarili)
            return Reddet(sonuc.Mesaj!);

        Bildirim = "Silindi";
        return RedirectToPage("/Gelen/Index");
    }

    private IActionResult Reddet(string mesaj)
    {
        YazmaHatasi = mesaj;
        return RedirectToPage("/Gelen/Index");
    }

    private async Task BostaKalaniSil(Guid? yuklenen, CancellationToken ct)
    {
        if (yuklenen is { } bosta)
            await depo.SilAsync([bosta], ct);
    }
}
