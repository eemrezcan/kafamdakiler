using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Yonetim;

// The Sahip's panel (T08): the Asistan's permissions, its sessions, the brain and the sending queue.
// The rules live in YonetimIslemleri, shared with /api/yonetim.
public class IndexModel(AppDbContext db, UserManager<IdentityUser<Guid>> kullanicilar, BeyinIstemcisi beyin, BeyinAyari ayar) : PageModel
{
    public List<IzinDto> IzinListesi { get; private set; } = [];

    public BeyinDurumDto BeyinDurumu { get; private set; } = new(false, null, 0, 0);

    // Only the captures that need a look (a failed send, or one stuck after a crash or a timeout).
    public List<GonderimDto> Kuyruk { get; private set; } = [];

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    [TempData]
    public string? Hata { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        var simdi = DateTimeOffset.UtcNow;
        IzinListesi = await YonetimIslemleri.IzinleriGetirAsync(kullanicilar);
        BeyinDurumu = await YonetimIslemleri.BeyinDurumuAsync(db, beyin, ayar, simdi, ct);
        Kuyruk = await YonetimIslemleri.KuyrukAsync(db, simdi, yalnizIlgilenilecek: true, ct);
    }

    public async Task<IActionResult> OnPostIzinAsync(string izin, bool acik)
    {
        if (!Izinler.Gecerli(izin))
            return BadRequest();

        await YonetimIslemleri.IzinAyarlaAsync(kullanicilar, izin, acik);
        Bildirim = acik ? "İzin açıldı" : "İzin kapatıldı";
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostOturumlariKapatAsync()
    {
        await YonetimIslemleri.AsistaninOturumlariniKapatAsync(kullanicilar);
        Bildirim = "Asistan'ın oturumları kapatıldı";
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostYenidenDeneAsync(Guid id, CancellationToken ct)
    {
        var sonuc = await YonetimIslemleri.YenidenDeneAsync(db, id, DateTimeOffset.UtcNow, ct);
        if (sonuc is null)
            Hata = "Yakalama bulunamadı; silinmiş olabilir.";
        else if (!sonuc.Basarili)
            Hata = sonuc.Mesaj;
        else
            Bildirim = "Yeniden gönderilecek";

        return RedirectToPage();
    }
}
