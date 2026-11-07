using System.Text.Json;
using Kafamdakiler.Eylemler;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Eylemler;

// One action in full: the payload can be corrected before it is applied. The payload is shown as JSON, whatever the
// kind is, so a new kind needs no page of its own.
public class DetayModel(EylemServisi servis, EylemTurleri turler) : PageModel
{
    public Eylem Eylem { get; private set; } = null!;

    public string TurAdi => turler.Bul(Eylem.Tur)?.GorunenAd ?? Eylem.Tur;

    // The text of the payload box: the stored payload, or what the person typed when it was refused.
    [BindProperty]
    public string Yuk { get; set; } = "";

    public async Task<IActionResult> OnGetAsync(Guid id, CancellationToken ct)
    {
        if (await servis.GetirAsync(id, ct) is not { } eylem)
            return NotFound();

        Eylem = eylem;
        Yuk = EylemGorunum.YukMetni(eylem.Yuk);
        return Page();
    }

    public async Task<IActionResult> OnPostUygulaAsync(Guid id, CancellationToken ct)
    {
        JsonElement yuk;
        try
        {
            using var belge = JsonDocument.Parse(Yuk ?? "");
            yuk = belge.RootElement.Clone();
        }
        catch (JsonException)
        {
            return await SayfaHatasiAsync(id, "Yük geçerli bir JSON değil.", ct);
        }

        var sonuc = await servis.UygulaAsync(id, yuk, EylemEndpoints.KullaniciId(User), ct);
        if (sonuc.Basarili)
        {
            TempData["Bildirim"] = "Uygulandı";
            return RedirectToPage("Index");
        }

        return sonuc.Tur == EylemSonucuTuru.Bulunamadi ? NotFound() : await SayfaHatasiAsync(id, sonuc.Mesaj!, ct);
    }

    public async Task<IActionResult> OnPostReddetAsync(Guid id, bool birDahaOnerme, CancellationToken ct)
    {
        var sonuc = await servis.ReddetAsync(id, birDahaOnerme, EylemEndpoints.KullaniciId(User), ct);
        if (sonuc.Basarili)
        {
            TempData["Bildirim"] = birDahaOnerme ? "Reddedildi, bu tür bir daha önerilmeyecek" : "Reddedildi";
            return RedirectToPage("Index");
        }

        return sonuc.Tur == EylemSonucuTuru.Bulunamadi ? NotFound() : await SayfaHatasiAsync(id, sonuc.Mesaj!, ct);
    }

    // Shows the page again with the message, keeping what the person typed in the payload box.
    private async Task<IActionResult> SayfaHatasiAsync(Guid id, string mesaj, CancellationToken ct)
    {
        if (await servis.GetirAsync(id, ct) is not { } eylem)
            return NotFound();

        Eylem = eylem;
        // Yuk keeps the posted text, so the box shows what the person typed.
        ModelState.Clear();
        ViewData["SayfaHatasi"] = mesaj;
        return Page();
    }
}
