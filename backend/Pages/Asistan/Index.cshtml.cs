using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;
using Kafamdakiler.Asistan;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Asistan;

// "Asistan" (K-0024): one stream for what the person said and what the assistant did, asked and found. Everything it shows and does is the same
// service as /api/asistan (AsistanServisi for an input and an answer, AsistanAkisi for the stream), with the queue's own undo, approve and refuse
// (EylemServisi) and the capture's own removal. The old pages (inbox, approval queue, captures, work cards) stay; this one links to them.
public partial class IndexModel(
    AsistanServisi servis, AsistanAkisi akis, EylemServisi eylemler, AppDbContext db, DosyaDeposu depo, BrifingHazirlayici brifingler, TimeProvider saat)
    : PageModel
{
    public const int SayfaBoyu = 40;
    private const int SayimSiniri = AsistanAkisi.EnCokSatir;

    // The stream, newest first, and the moment to continue from when there may be older items.
    public List<AkisOgesiDto> Ogeler { get; private set; } = [];

    public DateTimeOffset? Sonraki { get; private set; }

    // The filter chips: what waits, the open cards, the notes (100 is "100 or more").
    public int Bekleyen { get; private set; }

    public int Isler { get; private set; }

    public int Notlar { get; private set; }

    // The id of the next input, made when the page is made: pressing "Gönder" twice is the same input, so it runs once.
    public Guid GirdiId { get; } = Guid.NewGuid();

    [BindProperty(SupportsGet = true)]
    public string Suzgec { get; set; } = "hepsi";

    [TempData]
    public string? Hata { get; set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    private Guid? KullaniciId => EylemEndpoints.KullaniciId(User);

    public async Task<IActionResult> OnGetAsync(DateTimeOffset? once, CancellationToken ct)
    {
        if (KullaniciId is not { } kullanici)
            return Challenge();
        if (!AsistanAkisi.Suzgecler.Contains(Suzgec))
            Suzgec = "hepsi";

        Ogeler = await akis.AkisAsync(User, kullanici, once, SayfaBoyu, Suzgec, ct);
        if (Ogeler.Count == SayfaBoyu)
            Sonraki = Ogeler[^1].Zaman;

        Bekleyen = await akis.BekleyenSayisiAsync(User, kullanici, ct);
        Isler = (await akis.AkisAsync(User, kullanici, null, SayimSiniri, "isler", ct)).Count;
        Notlar = (await akis.AkisAsync(User, kullanici, null, SayimSiniri, "notlar", ct)).Count;
        return Page();
    }

    public static string SayiMetni(int sayi) => sayi >= SayimSiniri ? $"{SayimSiniri}+" : sayi.ToString();

    // Where a tap on a result goes on the web. The result's route is the app's (E8): a day, a work card, the stream.
    public string? HedefAdresi(AsistanHedefiDto hedef)
    {
        if (hedef.Rota is not { } rota)
            return null;

        if (GunRotasi().Match(rota) is { Success: true } gun && DateOnly.TryParseExact(gun.Groups[1].Value, "yyyy-MM-dd", null, System.Globalization.DateTimeStyles.None, out var tarih))
            return Url.Page("/Takvim/Index", new { ay = $"{tarih:yyyy-MM}", gun = $"{tarih:yyyy-MM-dd}" });
        if (IsRotasi().Match(rota) is { Success: true } is_)
            return Url.Page("/Isler/Detay", new { kimlik = is_.Groups[1].Value });
        if (rota == "/asistan")
            return Url.Page("/Asistan/Index");
        return null;
    }

    [GeneratedRegex(@"^/gun/(\d{4}-\d{2}-\d{2})$")]
    private static partial Regex GunRotasi();

    [GeneratedRegex(@"^/isler/([a-z0-9][a-z0-9-]*)$")]
    private static partial Regex IsRotasi();

    private IActionResult Don()
    {
        return RedirectToPage(null, new { suzgec = Suzgec is not ("hepsi" or null) && AsistanAkisi.Suzgecler.Contains(Suzgec) ? Suzgec : null });
    }

    private IActionResult Reddet(string mesaj)
    {
        Hata = mesaj;
        return Don();
    }

    // The input box: the same entry as POST /api/asistan/girdi, typed text.
    public async Task<IActionResult> OnPostGirdiAsync(Guid girdiId, string? metin)
    {
        var girdi = new AsistanGirdisiDto { Id = girdiId, Metin = metin, Kaynak = AsistanKaynagi.Yazi };
        var dogrulama = new List<ValidationResult>();
        if (!Validator.TryValidateObject(girdi, new ValidationContext(girdi), dogrulama, validateAllProperties: true))
            return Reddet(string.Join(" ", dogrulama.Select(d => d.ErrorMessage)));

        // From here on the work is not tied to the request: a closed tab must not leave an input half known (the service does the same).
        var sonuc = await servis.GirdiAsync(girdi, User, CancellationToken.None);
        if (sonuc.Hata is { } hata)
            return Reddet(SonucMetni.Hata(hata) ?? "Gönderilemedi.");

        var yanit = sonuc.Veri!;
        Bildirim = yanit.Soru is not null ? "Bir sorum var" : yanit.Sonuclar.Count == 0 ? "Gönderildi" : $"{yanit.Sonuclar.Count} sonuç";
        return Don();
    }

    // The answer to the open question: one of its options, or the person's own words.
    public async Task<IActionResult> OnPostCevapAsync(Guid id, string? cevap)
    {
        var dogrulama = new AsistanCevabiDto { Cevap = cevap };
        var sonuclar = new List<ValidationResult>();
        if (!Validator.TryValidateObject(dogrulama, new ValidationContext(dogrulama), sonuclar, validateAllProperties: true) || string.IsNullOrWhiteSpace(cevap))
            return Reddet(sonuclar.Count > 0 ? string.Join(" ", sonuclar.Select(d => d.ErrorMessage)) : "Cevap zorunlu.");

        var sonuc = await servis.CevapAsync(id, cevap.Trim(), User, CancellationToken.None);
        if (sonuc.Hata is { } hata)
            return Reddet(SonucMetni.Hata(hata) ?? "Cevap gönderilemedi.");

        Bildirim = "Cevap gönderildi";
        return Don();
    }

    // The approval card: "Ekle" applies the suggestion, "Geç" refuses it (and keeps the kind coming).
    public async Task<IActionResult> OnPostUygulaAsync(Guid id) =>
        EylemDon(await eylemler.UygulaAsync(id, null, KullaniciId, CancellationToken.None), "Eklendi");

    public async Task<IActionResult> OnPostReddetAsync(Guid id) =>
        EylemDon(await eylemler.ReddetAsync(id, false, KullaniciId, CancellationToken.None), "Geçildi");

    // "Geri al" on a result made by a queue action.
    public async Task<IActionResult> OnPostGeriAlAsync(Guid id) =>
        EylemDon(await eylemler.GeriAlAsync(id, KullaniciId, CancellationToken.None), "Geri alındı");

    private IActionResult EylemDon(EylemSonucu sonuc, string basari)
    {
        if (sonuc.Basarili)
            Bildirim = basari;
        else
            Hata = sonuc.Tur == EylemSonucuTuru.Bulunamadi ? "Eylem bulunamadı; silinmiş olabilir." : sonuc.Mesaj;

        return Don();
    }

    // "Geri al" on a note: the capture is deleted while it still waits (once it is on its way to the brain, or sent, it cannot be taken back).
    public async Task<IActionResult> OnPostNotuGeriAlAsync(Guid id)
    {
        var y = await db.Yakalamalar.FindAsync([id]);
        if (y is null)
            return Reddet("Not bulunamadı; zaten silinmiş olabilir.");
        if (y.Durum != YakalamaDurumu.Bekliyor || YakalamaGonderimi.Gonderiliyor(y, saat.GetUtcNow()))
            return Reddet("Not beyne gönderildi ya da gönderiliyor; artık geri alınamaz.");

        var sonuc = await YakalamaIslemleri.SilAsync(db, depo, y, CancellationToken.None);
        if (!sonuc.Basarili)
            return Reddet(sonuc.Mesaj ?? "Not silinemedi.");

        Bildirim = "Not geri alındı";
        return Don();
    }

    // A vote on a card of today's briefing: 1, -1, or 0 to take it back.
    public async Task<IActionResult> OnPostBrifingOyAsync(int sira, int oy)
    {
        var sonuc = await brifingler.OyVerAsync(brifingler.Bugun, sira, oy, CancellationToken.None);
        if (!sonuc.Basarili)
            return Reddet(sonuc.Mesaj ?? "Oy verilemedi.");

        return Don();
    }
}
