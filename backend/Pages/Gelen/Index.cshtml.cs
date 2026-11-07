using Kafamdakiler.Beyin;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Kafamdakiler.Data;
using Kafamdakiler.Pages.Beyin;
using Microsoft.AspNetCore.Mvc;

namespace Kafamdakiler.Pages.Gelen;

// The inbox (K2.2): the cards waiting in the brain, the suggestion of Claude under each, and the hand-made placement.
// Reads and writes go through GelenIslemleri (the same checks as /api/gelen); approving or rejecting a suggestion goes through
// EylemServisi (the same rules as the approval queue). A hidden card never shows up: the brain's list leaves it out.
public class IndexModel(
    BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, AppDbContext db, EylemServisi eylemler, GelenOnerici onerici)
    : BeyinSayfasi(beyin, gunluk)
{
    public List<GelenKartDto> Kartlar { get; private set; } = [];

    // For the hand-made form: where a card can go and which tags exist. Empty when the brain did not answer.
    public List<ProjeOzetDto> Projeler { get; private set; } = [];

    public IReadOnlyList<string> Etiketler { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        if (Al(await GelenIslemleri.ListeAl(Istemci, db, Gunluk, ct)) is not { } kartlar)
            return;

        Kartlar = kartlar;
        if (kartlar.Count == 0)
            return;

        var projeler = await BeyinOkuma.ProjelerAl(Istemci, Gunluk, ct);
        if (projeler.Basarili)
            Projeler = projeler.Veri!;
        var sozluk = await GelenBeyin.SozluguAlAsync(Istemci, Gunluk, ct);
        if (sozluk.Basarili)
            Etiketler = sozluk.Veri!.AnaAdlar;
    }

    // The suggestion's three buttons. "Düzelt" is the link to the action's page, where the payload can be edited.
    public async Task<IActionResult> OnPostUygulaAsync(Guid id, CancellationToken ct) =>
        Don(await eylemler.UygulaAsync(id, null, EylemEndpoints.KullaniciId(User), ct), "Kart yerleştirildi");

    public async Task<IActionResult> OnPostReddetAsync(Guid id, bool birDahaOnerme, CancellationToken ct) =>
        Don(await eylemler.ReddetAsync(id, birDahaOnerme, EylemEndpoints.KullaniciId(User), ct),
            birDahaOnerme ? "Reddedildi, bu tür bir daha önerilmeyecek" : "Reddedildi");

    // The folder comes from a pick list and the file name from a box; GelenIslemleri checks the whole path again.
    public async Task<IActionResult> OnPostIsleAsync(string kart, string? klasor, string? dosya, string? baslik, List<string>? etiketler, CancellationToken ct)
    {
        var ad = (dosya ?? "").Trim();
        if (ad.Length > 0 && !ad.EndsWith(".md", StringComparison.Ordinal))
            ad += ".md";

        return Don(await GelenIslemleri.Isle(kart, new((klasor ?? "") + ad, baslik, etiketler, null), Istemci, Gunluk, ct), "Kart yerleştirildi");
    }

    public async Task<IActionResult> OnPostSilAsync(string kart, CancellationToken ct) =>
        Don(await GelenIslemleri.Sil(kart, Istemci, Gunluk, ct), "Kart silindi");

    // "Suggest again": asks Claude now; this can take a while.
    public async Task<IActionResult> OnPostOneriAsync(string kart, CancellationToken ct)
    {
        var sonuc = await onerici.OnerAsync(kart, ct);
        switch (sonuc.Durum)
        {
            case OneriDurumu.Olustu:
                Bildirim = "Öneri hazır";
                break;
            case OneriDurumu.LaptoptaIslenecek:
                Bildirim = "Yeni etiket gerekiyor: kart laptopta işlenecek olarak işaretlendi";
                break;
            case OneriDurumu.BagliDegil:
                YazmaHatasi = "Claude ya da beyin bu makinede bağlı değil.";
                break;
            case OneriDurumu.Basarisiz:
                // The reason (what the command printed) stays in the log.
                YazmaHatasi = "Claude öneri üretemedi ya da önerisi kurallara uymadı. Kart yerinde duruyor.";
                break;
            default:
                YazmaHatasi = sonuc.Mesaj ?? "Öneri istenemedi.";
                break;
        }

        return RedirectToPage();
    }

    private IActionResult Don(EylemSonucu sonuc, string basari)
    {
        if (sonuc.Basarili)
            Bildirim = basari;
        else
            YazmaHatasi = sonuc.Tur == EylemSonucuTuru.Bulunamadi ? "Öneri bulunamadı; silinmiş olabilir." : sonuc.Mesaj ?? "İşlem yapılamadı.";

        return RedirectToPage();
    }
}
