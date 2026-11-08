using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Claude;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Kafamdakiler.Data;
using Kafamdakiler.Pages.Beyin;
using Kafamdakiler.Ses;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Gelen;

// The inbox (K2.2): the cards waiting in the brain, the suggestion of Claude under each, and the hand-made placement.
// Reads and writes go through GelenIslemleri (the same checks as /api/gelen); approving or rejecting a suggestion goes through
// EylemServisi (the same rules as the approval queue). A hidden card never shows up: the brain's list leaves it out.
public class IndexModel(
    BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, AppDbContext db, EylemServisi eylemler, GelenOnerici onerici, ClaudeAyari claude,
    IsCikarServisi isCikar)
    : BeyinSayfasi(beyin, gunluk)
{
    private static readonly JsonSerializerOptions JsonAyari = new(JsonSerializerDefaults.Web);

    // The "suggest again" and "İşe çevir" buttons are shown only while Claude is connected.
    public bool ClaudeBagli => claude.Acik;

    // "Gönderiliyor": the captures that wait to go to the brain, newest first. Read from the database, so they show even when
    // the brain is off.
    public List<YakalamaDto> Gonderiliyor { get; private set; } = [];

    public List<GelenKartDto> Kartlar { get; private set; } = [];

    // For the hand-made form: where a card can go and which tags exist. Empty when the brain did not answer.
    public List<ProjeOzetDto> Projeler { get; private set; } = [];

    public IReadOnlyList<string> Etiketler { get; private set; } = [];

    // The preview of "İşe çevir": what Claude suggested out of the text, to be ticked and applied. Null when none was asked.
    public IsCikarYaniti? Onizleme { get; private set; }

    // The text the preview came from; it goes back into the capture box.
    public string? IsMetni { get; private set; }

    public async Task OnGetAsync(CancellationToken ct) => await YukleAsync(ct);

    private async Task YukleAsync(CancellationToken ct)
    {
        var bekleyenler = await db.Yakalamalar.Where(y => y.Durum == YakalamaDurumu.Bekliyor)
            .OrderByDescending(y => y.YakalandiAt).ThenByDescending(y => y.Id).ToListAsync(ct);
        Gonderiliyor = bekleyenler.Select(YakalamaEndpoints.DtoYap).ToList();

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

    // "İşe çevir": asks Claude what the capture box holds (reminders, plan items, tasks, events). Nothing is saved; the preview is
    // the answer of this very request, so a reload asks again. The text is the only untrusted thing in the call (IsCikarServisi).
    public async Task<IActionResult> OnPostIsCikarAsync([FromForm(Name = "Input.Metin")] string? metin, CancellationToken ct)
    {
        IsMetni = metin;
        var sonuc = await isCikar.CikarAsync(new IsCikarGirdi(metin), ct);
        if (sonuc.Hata is not null)
        {
            YazmaHatasi = HataMetni(sonuc.Hata);
            return RedirectToPage();
        }

        Onizleme = sonuc.Veri;
        await YukleAsync(ct);
        return Page();
    }

    // "Uygula" under the preview: the ticked suggestions go through the same path as the phone's (IsCikarServisi.UygulaAsync):
    // each is checked again, needs the permission of its kind, and lands in the approval queue as applied (action modes and the
    // queue's rules hold).
    public async Task<IActionResult> OnPostIsUygulaAsync(List<string>? secilen, CancellationToken ct)
    {
        var oneriler = new List<IsOnerisi>();
        foreach (var json in secilen ?? [])
        {
            if (OneriOku(json) is not { } oneri)
            {
                YazmaHatasi = "Seçilen öneri okunamadı; işe çevirmeyi yeniden dene.";
                return RedirectToPage();
            }

            oneriler.Add(oneri);
        }

        var sonuc = await isCikar.UygulaAsync(new IsCikarUygulaGirdi(oneriler), User, ct);
        if (sonuc.Hata is not null)
        {
            YazmaHatasi = HataMetni(sonuc.Hata);
            return RedirectToPage();
        }

        var yanit = sonuc.Veri!;
        if (yanit.Basarisiz == 0)
        {
            Bildirim = yanit.Uygulanan == 1 ? "1 öneri uygulandı" : $"{yanit.Uygulanan} öneri uygulandı";
            return RedirectToPage();
        }

        // Some did not go through; the ones that did stay applied, and the page says which failed and why.
        var nedenler = yanit.Sonuclar.Where(s => s.Durum != "uygulandi").Select(s => s.Mesaj ?? "Uygulanamadı.").Distinct();
        YazmaHatasi = $"{yanit.Uygulanan} öneri uygulandı, {yanit.Basarisiz} uygulanamadı: {string.Join(" ", nedenler)}";
        return RedirectToPage();
    }

    // A ticked box carries its suggestion as JSON; whatever comes back is checked again by the service.
    private static IsOnerisi? OneriOku(string json)
    {
        try
        {
            return JsonSerializer.Deserialize<IsOnerisi>(json, JsonAyari);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    // The API's refusal (a ProblemDetails or a validation problem) as a sentence for the page.
    private static string HataMetni(IResult hata) => hata is ProblemHttpResult { ProblemDetails: { } sorun }
        ? (sorun is HttpValidationProblemDetails dogrulama ? string.Join(" ", dogrulama.Errors.Values.SelectMany(m => m)) : sorun.Detail ?? sorun.Title)
            ?? "İşlem yapılamadı."
        : "İşlem yapılamadı.";

    // A ticked box carries its suggestion as JSON, the shape the API takes.
    public static string OneriJson(IsOnerisi oneri) => JsonSerializer.Serialize(oneri, JsonAyari);

    public static string TurAdi(string? tur) => tur switch
    {
        "hatirlatici-kur" => "Hatırlatıcı",
        "plan-ekle" => "Gün planı",
        "gorev-ekle" => "Görev",
        "takvim-ekle" => "Takvim",
        _ => "Öneri",
    };

    // The suggestion in one line for the preview: when, and where it goes.
    public static string OneriAyrintisi(IsOnerisi o)
    {
        var parcalar = new List<string>();
        if (o.Gun is not null)
            parcalar.Add(o.Gun + (o.Saat is not null ? " " + o.Saat : ""));
        else if (o.Bitis is not null)
            parcalar.Add("Bitiş " + o.Bitis);
        if (o.Tekrar is not null and not "yok")
            parcalar.Add("Tekrar: " + o.Tekrar);
        if (o.Proje is not null)
            parcalar.Add("Proje: " + o.Proje);
        else if (o.Alan is not null)
            parcalar.Add("Alan: " + o.Alan);
        if (o.Bolum is not null)
            parcalar.Add("Bölüm: " + o.Bolum);
        if (o.Yer is not null)
            parcalar.Add("Yer: " + o.Yer);
        return string.Join(" · ", parcalar);
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
