using Kafamdakiler.Beyin;
using Kafamdakiler.Isler;
using Kafamdakiler.OpenApi;
using Kafamdakiler.Pages.Beyin;
using Microsoft.AspNetCore.Mvc;

namespace Kafamdakiler.Pages.Isler;

// One work card: the request, the plan, the questions with their answers, the history. An open question can be answered here, with one of its
// options or with the person's own words (E6), and a card that is past its plan can be sent back to it, with the note the plan session reads.
// Both go through IsKartlari, the same code and checks as /api/isler.
public class DetayModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, TimeProvider saat) : BeyinSayfasi(beyin, gunluk)
{
    public IsAyrintiDto? Kart { get; private set; }

    public async Task OnGetAsync(string kimlik, CancellationToken ct) =>
        Kart = Al(await IsKartlari.Al(kimlik, Istemci, Gunluk, ct));

    // Not tied to the request: a closed tab must not leave the answer half written.
    public async Task<IActionResult> OnPostCevapAsync(string kimlik, int soruNo, string? cevap)
    {
        if (string.IsNullOrWhiteSpace(cevap))
        {
            YazmaHatasi = "Cevap boş olamaz.";
            return RedirectToPage();
        }

        return Don(await IsKartlari.Cevapla(kimlik, new IsCevapGirdi(soruNo, cevap), Istemci, Gunluk, CancellationToken.None), "Cevap yazıldı");
    }

    // "Plana geri gönder": a revision needs a note. An empty one is refused here, before the brain, with the API's own sentence;
    // should the brain still answer "not-gerekli", Don says the same sentence.
    public async Task<IActionResult> OnPostPlanaGeriAsync(string kimlik, string? not)
    {
        if (string.IsNullOrWhiteSpace(not))
        {
            YazmaHatasi = HataAnahtarlari.NotGerekliMetni;
            return RedirectToPage();
        }

        return Don(await IsKartlari.AsamaDegistir(kimlik, new IsAsamaGirdi("plan", null, not.Trim()), Istemci, Gunluk, saat, CancellationToken.None),
            "Plana geri gönderildi");
    }
}
