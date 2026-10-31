using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Aliskanliklar;

public class DetayModel(AppDbContext db) : PageModel
{
    // The heat map covers the last ~6 months, the bar charts the last 90 days.
    private const int HaritaGunu = 183;
    private const int GrafikGunu = 90;

    public AliskanlikDto Aliskanlik { get; private set; } = null!;

    // Heat map cells, week by week (Monday first); null pads the first and last week.
    public List<GunDto?> Hucreler { get; private set; } = [];

    public bool KayitVar { get; private set; }

    public object Grafik { get; private set; } = null!;

    public async Task<IActionResult> OnGetAsync(Guid id, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([id], ct);
        if (a is null)
            return NotFound();

        var bugun = AliskanlikIslemleri.Bugun();
        Aliskanlik = (await AliskanlikEndpoints.DtoYapAsync(db, [a], ct))[0];
        var gunler = await AliskanlikEndpoints.GunleriHesaplaAsync(db, a, bugun.AddDays(-(HaritaGunu - 1)), bugun, ct);

        // Pad the start so the first column begins on a Monday.
        var bos = ((int)gunler[0].Tarih.DayOfWeek + 6) % 7;
        Hucreler = [.. Enumerable.Repeat<GunDto?>(null, bos), .. gunler];
        KayitVar = gunler.Any(g => g.Miktar > 0);

        var son = gunler.TakeLast(GrafikGunu).ToList();
        Grafik = new
        {
            etiketler = son.Select(g => Gorunum.GunAy(g.Tarih)).ToArray(),
            miktar = son.Select(g => g.Miktar).ToArray(),
            dakika = son.Select(g => g.Dakika ?? 0).ToArray(),
            dakikaVar = son.Any(g => g.Dakika is > 0),
            hedef = Aliskanlik.GunlukHedef,
            birim = Aliskanlik.Birim ?? "",
            gucEtiketleri = gunler.Select(g => Gorunum.GunAy(g.Tarih)).ToArray(),
            guc = gunler.Select(g => Math.Round(g.Guc * 100, 1)).ToArray(),
        };
        return Page();
    }
}
