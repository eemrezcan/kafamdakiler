using Kafamdakiler.Data;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Yakalamalar;

public class IndexModel(AppDbContext db) : PageModel
{
    public List<YakalamaDto> Yakalamalar { get; private set; } = [];

    // How many captures each status has, for the filter chips.
    public Dictionary<YakalamaDurumu, int> Sayilar { get; private set; } = [];

    public int Toplam => Sayilar.Values.Sum();

    // /Yakalamalar?durum=Bekliyor lists one status; empty lists all.
    [BindProperty(SupportsGet = true)]
    public YakalamaDurumu? Durum { get; set; }

    [TempData]
    public string? Hata { get; set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        var liste = await db.Yakalamalar.Where(y => Durum == null || y.Durum == Durum)
            .OrderByDescending(y => y.YakalandiAt).ThenByDescending(y => y.Id).ToListAsync(ct);
        Yakalamalar = liste.Select(YakalamaEndpoints.DtoYap).ToList();

        Sayilar = await db.Yakalamalar.GroupBy(y => y.Durum)
            .Select(g => new { Durum = g.Key, Sayi = g.Count() })
            .ToDictionaryAsync(x => x.Durum, x => x.Sayi, ct);
    }
}
