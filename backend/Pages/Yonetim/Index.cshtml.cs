using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Yonetim;

// The Sahip's panel (T08): the Asistan's permissions, its sessions, the brain and the sending queue.
// The rules live in YonetimIslemleri, shared with /api/yonetim.
public class IndexModel(AppDbContext db, UserManager<IdentityUser<Guid>> kullanicilar, BeyinIstemcisi beyin, BeyinAyari ayar, EylemServisi eylemler) : PageModel
{
    public List<IzinDto> IzinListesi { get; private set; } = [];

    // The mode of every kind of action the Asistan may suggest (K2.6).
    public List<EylemKipiDto> EylemKipleri { get; private set; } = [];

    public BeyinDurumDto BeyinDurumu { get; private set; } = new(false, null, 0, 0);

    // Only the captures that need a look (a failed send, or one stuck after a crash or a timeout).
    public List<GonderimDto> Kuyruk { get; private set; } = [];

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    [TempData]
    public string? Hata { get; set; }

    // The "Asistan'ın şifresi" form. Only OnPostAsistanSifre looks at it; the other handlers ignore it.
    [BindProperty]
    public AsistanSifreGirdisi Sifre { get; set; } = new();

    public class AsistanSifreGirdisi
    {
        [Required(ErrorMessage = "Yeni şifre zorunlu.")]
        [DataType(DataType.Password)]
        [Display(Name = "Yeni şifre")]
        public string YeniSifre { get; set; } = "";

        [Required(ErrorMessage = "Şifreyi tekrar yaz.")]
        [Compare(nameof(YeniSifre), ErrorMessage = "Şifreler aynı değil.")]
        [DataType(DataType.Password)]
        [Display(Name = "Yeni şifre (tekrar)")]
        public string YeniSifreTekrar { get; set; } = "";
    }

    public async Task OnGetAsync(CancellationToken ct) => await YukleAsync(ct);

    private async Task YukleAsync(CancellationToken ct)
    {
        var simdi = DateTimeOffset.UtcNow;
        IzinListesi = await YonetimIslemleri.IzinleriGetirAsync(kullanicilar);
        EylemKipleri = await eylemler.KipleriGetirAsync(ct);
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

    // `kip` is read as text: a value that is not a mode name must not silently become the default mode.
    public async Task<IActionResult> OnPostEylemKipiAsync(string tur, string kip, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(kip) || !char.IsLetter(kip[0]) || !Enum.TryParse<EylemKipi>(kip, ignoreCase: true, out var yeniKip) || !Enum.IsDefined(yeniKip))
            return BadRequest();

        if (await eylemler.KipAyarlaAsync(tur, yeniKip, EylemEndpoints.KullaniciId(User), ct) is null)
            return NotFound();

        Bildirim = "Kip kaydedildi";
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostOturumlariKapatAsync()
    {
        await YonetimIslemleri.AsistaninOturumlariniKapatAsync(kullanicilar);
        Bildirim = "Asistan'ın oturumları kapatıldı";
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostAsistanSifreAsync(CancellationToken ct)
    {
        // Only this form's fields count; the other handlers' posts carry none of them.
        if (!ModelState.IsValid)
        {
            await YukleAsync(ct);
            return Page();
        }

        var sonuc = await YonetimIslemleri.AsistaninSifresiniYenileAsync(kullanicilar, Sifre.YeniSifre);
        if (!sonuc.Succeeded)
        {
            foreach (var hata in sonuc.Errors)
                ModelState.AddModelError($"{nameof(Sifre)}.{nameof(Sifre.YeniSifre)}", hata.Description);

            await YukleAsync(ct);
            return Page();
        }

        Bildirim = "Asistan'ın şifresi değişti, oturumları kapatıldı";
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
