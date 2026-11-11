using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

public class DetayModel(AppDbContext db) : PageModel
{
    // The heat map covers at most ~6 months, the bar charts at most 90 days. Both start on the
    // habit's first day, but show a minimum span so a young habit does not get a single cell or bar.
    private const int HaritaGunu = 183;
    private const int GrafikGunu = 90;
    private const int EnAzHaritaGunu = 28;
    private const int EnAzGrafikGunu = 14;

    public AliskanlikDto Aliskanlik { get; private set; } = null!;

    // Heat map cells, week by week (Monday first); null pads the first and last week.
    public List<GunDto?> Hucreler { get; private set; } = [];

    public string HaritaBasligi { get; private set; } = "";

    public bool KayitVar { get; private set; }

    public object Grafik { get; private set; } = null!;

    // A shelf habit's shelf, on the page itself; empty for the other kinds.
    public RafVerisi Raf { get; private set; } = RafVerisi.Bos;

    [TempData]
    public string? Hata { get; set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    public async Task<IActionResult> OnGetAsync(Guid id, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([id], ct);
        if (a is null)
            return NotFound();

        var bugun = AliskanlikIslemleri.Bugun();
        Aliskanlik = (await AliskanlikEndpoints.DtoYapAsync(db, [a], ct))[0];
        var gunler = await AliskanlikEndpoints.GunleriHesaplaAsync(db, a, bugun.AddDays(-(HaritaGunu - 1)), bugun, ct);
        var ilkGun = AliskanlikHesap.AliskanlikGunu(Aliskanlik.Olusturulma);
        static DateOnly Erken(DateOnly x, DateOnly y) => x < y ? x : y;

        var haritaBasi = Erken(ilkGun, bugun.AddDays(-(EnAzHaritaGunu - 1)));
        var haritaGunleri = gunler.Where(g => g.Tarih >= haritaBasi).ToList();
        HaritaBasligi = haritaGunleri.Count == gunler.Count ? "Son 6 ay"
            : ilkGun == haritaBasi ? "Başladığından beri"
            : "Son 4 hafta";

        // Pad the start so the first column begins on a Monday.
        var bos = ((int)haritaGunleri[0].Tarih.DayOfWeek + 6) % 7;
        Hucreler = [.. Enumerable.Repeat<GunDto?>(null, bos), .. haritaGunleri];
        KayitVar = gunler.Any(g => g.Miktar > 0);

        var grafikBasi = Erken(ilkGun, bugun.AddDays(-(EnAzGrafikGunu - 1)));
        var gucGunleri = gunler.Where(g => g.Tarih >= grafikBasi).ToList();
        var son = gucGunleri.TakeLast(GrafikGunu).ToList();
        Grafik = new
        {
            etiketler = son.Select(g => Gorunum.GunAy(g.Tarih)).ToArray(),
            miktar = son.Select(g => g.Miktar).ToArray(),
            dakika = son.Select(g => g.Dakika ?? 0).ToArray(),
            dakikaVar = son.Any(g => g.Dakika is > 0),
            hedef = Aliskanlik.GunlukHedef,
            birim = Aliskanlik.Birim ?? "",
            gucEtiketleri = gucGunleri.Select(g => Gorunum.GunAy(g.Tarih)).ToArray(),
            guc = gucGunleri.Select(g => Math.Round(g.Guc * 100, 1)).ToArray(),
        };

        if (a.Tur == AliskanlikTuru.Raf)
            Raf = await RafVerisi.YukleAsync(db, a.Id, ct);
        return Page();
    }

    // The reading log of the modal: which book, where the person got to, and how long it took. The same rules as the item page's progress form.
    public async Task<IActionResult> OnPostOkumaAsync(Guid id, Guid ogeId, decimal? bitisKonum, int? dakika, string? donus, CancellationToken ct)
    {
        var oge = await AliskanlikIslemleri.OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == ogeId && o.AliskanlikId == id, ct);
        if (oge is null)
            return NotFound();

        string? hata = null;
        if (bitisKonum is null)
        {
            hata = "Nereye kadar geldiğini yaz.";
        }
        else
        {
            var (sonuc, _) = await AliskanlikIslemleri.OturumEkleAsync(db, oge, new OturumEkleDto { BitisKonum = bitisKonum.Value, Dakika = dakika }, ct);
            if (sonuc.Basarili)
                Bildirim = "Okuma kaydedildi";
            else
                hata = sonuc.Mesaj;
        }

        // The modal on Bugün says "donus=bugun" (nothing else is read from it): back to Bugün, which shows its own error line.
        if (donus == "bugun")
        {
            if (hata is not null)
                TempData["YazmaHatasi"] = hata;
            return RedirectToPage("/Index", null, null, "h-" + id);
        }

        Hata = hata;
        return RedirectToPage(null, null, new { id }, "raf");
    }
}
