using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Hatirlaticilar;

public class IndexModel(AppDbContext db, HatirlaticiAyari ayar, TimeProvider saat) : PageModel
{
    public List<HatirlaticiDto> Hatirlaticilar { get; private set; } = [];

    // How many reminders each status has, for the tabs.
    public Dictionary<HatirlaticiDurumu, int> Sayilar { get; private set; } = [];

    public DateTimeOffset Simdi { get; private set; }

    // /Hatirlaticilar?durum=Tamam&tur=Soz; the open ones are the default tab.
    [BindProperty(SupportsGet = true)]
    public HatirlaticiDurumu Durum { get; set; } = HatirlaticiDurumu.Acik;

    [BindProperty(SupportsGet = true)]
    public HatirlaticiTuru? Tur { get; set; }

    [TempData]
    public string? Hata { get; set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        Simdi = saat.GetUtcNow();
        var sorgu = db.Hatirlaticilar.Where(h => h.Durum == Durum && (Tur == null || h.Tur == Tur));
        // Open ones soonest first (overdue on top); closed ones newest first.
        var liste = Durum == HatirlaticiDurumu.Acik
            ? await sorgu.OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id).ToListAsync(ct)
            : await sorgu.OrderByDescending(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id).ToListAsync(ct);
        Hatirlaticilar = liste.Select(h => HatirlaticiIslemleri.DtoYap(h, Simdi)).ToList();

        Sayilar = await db.Hatirlaticilar.GroupBy(h => h.Durum)
            .Select(g => new { Durum = g.Key, Sayi = g.Count() })
            .ToDictionaryAsync(x => x.Durum, x => x.Sayi, ct);
    }

    public async Task<IActionResult> OnPostYaptimAsync(Guid id, CancellationToken ct)
    {
        var h = await db.Hatirlaticilar.FindAsync([id], ct);
        if (h is null)
            return NotFound();

        var sonuc = HatirlaticiIslemleri.Yaptim(h, ayar.VarsayilanSaat, saat.GetUtcNow());
        if (sonuc.Basarili)
        {
            await db.SaveChangesAsync(ct);
            Bildirim = h.Durum == HatirlaticiDurumu.Tamam ? "Tamamlandı" : "Sıradaki tekrara geçti";
        }
        else
        {
            Hata = sonuc.Mesaj;
        }

        return Don();
    }

    public async Task<IActionResult> OnPostErteleAsync(Guid id, string sure, CancellationToken ct)
    {
        var h = await db.Hatirlaticilar.FindAsync([id], ct);
        if (h is null)
            return NotFound();

        var sonuc = HatirlaticiIslemleri.Ertele(h, sure, ayar.VarsayilanSaat, saat.GetUtcNow());
        if (sonuc.Basarili)
        {
            await db.SaveChangesAsync(ct);
            Bildirim = "Ertelendi";
        }
        else
        {
            Hata = sonuc.Mesaj;
        }

        return Don();
    }

    // Back to the same tab and filter.
    private IActionResult Don() => RedirectToPage(null, new { durum = Durum, tur = Tur });
}
