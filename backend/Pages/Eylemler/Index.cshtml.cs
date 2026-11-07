using Kafamdakiler.Eylemler;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Eylemler;

// The approval queue (K2.6): what the Asistan or Claude suggested and waits for a yes. The rules live in EylemServisi,
// shared with /api/eylemler.
public class IndexModel(EylemServisi servis) : PageModel
{
    // How many applied actions the "recently applied" part shows.
    private const int SonUygulananSayisi = 10;

    public List<Eylem> Bekleyenler { get; private set; } = [];

    public List<Eylem> SonUygulananlar { get; private set; } = [];

    public List<Eylem> Hatalilar { get; private set; } = [];

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    [TempData]
    public string? Hata { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        Bekleyenler = await servis.ListeAsync(EylemDurumu.Bekliyor, ct);
        SonUygulananlar = (await servis.ListeAsync(EylemDurumu.Uygulandi, ct)).Take(SonUygulananSayisi).ToList();
        Hatalilar = await servis.ListeAsync(EylemDurumu.Hatali, ct);
    }

    public async Task<IActionResult> OnPostUygulaAsync(Guid id, CancellationToken ct) =>
        Don(await servis.UygulaAsync(id, null, EylemEndpoints.KullaniciId(User), ct), "Uygulandı");

    public async Task<IActionResult> OnPostReddetAsync(Guid id, bool birDahaOnerme, CancellationToken ct) =>
        Don(await servis.ReddetAsync(id, birDahaOnerme, EylemEndpoints.KullaniciId(User), ct),
            birDahaOnerme ? "Reddedildi, bu tür bir daha önerilmeyecek" : "Reddedildi");

    public async Task<IActionResult> OnPostGeriAlAsync(Guid id, CancellationToken ct) =>
        Don(await servis.GeriAlAsync(id, EylemEndpoints.KullaniciId(User), ct), "Geri alındı");

    private IActionResult Don(EylemSonucu sonuc, string basari)
    {
        if (sonuc.Basarili)
            Bildirim = basari;
        else
            Hata = sonuc.Tur == EylemSonucuTuru.Bulunamadi ? "Eylem bulunamadı; silinmiş olabilir." : sonuc.Mesaj;

        return RedirectToPage();
    }
}
