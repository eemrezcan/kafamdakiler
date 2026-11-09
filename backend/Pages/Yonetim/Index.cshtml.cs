using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Claude;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gmail;
using Kafamdakiler.Ozet;
using Kafamdakiler.ProjeRepolari;
using Kafamdakiler.Takvim;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Yonetim;

// The Sahip's panel (T08): the Asistan's permissions, its sessions, the brain, the sending queue, the project ↔ repository links
// (K2.5) and the Google Calendar connection (K2.3c). The rules live in YonetimIslemleri, ProjeRepoIslemleri and GoogleBaglanti,
// shared with /api/yonetim and /api/google.
public class IndexModel(
    AppDbContext db, UserManager<IdentityUser<Guid>> kullanicilar, BeyinIstemcisi beyin, BeyinAyari ayar, EylemServisi eylemler,
    GoogleBaglanti googleBaglanti, TakvimEsitleyici esitleyici, ClaudeIstemcisi claude, GmailTaramaDurumu gmailDurumu, HaftalikOzetYazici haftalikOzet,
    BildirimServisi bildirimler, PushDurumu pushDurumu, TimeProvider saat, ILogger<BeyinIstemcisi> gunluk) : PageModel
{
    public record GrupKarti(IzinGruplari.Grup Grup, GrupKipi Kip);

    // The six cards (Kapalı / Okur / Okur ve yazar) and the assistant switch; the raw list below stays for "Gelişmiş".
    public List<GrupKarti> GrupKartlari { get; private set; } = [];

    public bool AsistanAcik { get; private set; }

    public List<IzinDto> IzinListesi { get; private set; } = [];

    // The mode of every kind of action the Asistan may suggest (K2.6).
    public List<EylemKipiDto> EylemKipleri { get; private set; } = [];

    // One line for outside the "Gelişmiş" fold, like "Sor: 4 tür · Kendin yap: 1 tür".
    public string EylemOzeti => string.Join(" · ", EylemKipleri.GroupBy(k => k.Kip).OrderBy(g => g.Key)
        .Select(g => $"{EylemGorunum.KipAdi(g.Key)}: {g.Count()} tür"));

    public BeyinDurumDto BeyinDurumu { get; private set; } = new(false, null, 0, 0);

    // Only the captures that need a look (a failed send, or one stuck after a crash or a timeout).
    public List<GonderimDto> Kuyruk { get; private set; } = [];

    // The links of projects to repositories, and the projects of the brain to pick from (empty, with `ProjeListesiHatasi`, when the brain
    // would not answer: the form is then left out, the existing links stay listed).
    public List<ProjeRepoDto> RepoEslemeleri { get; private set; } = [];

    public List<ProjeOzetDto> Projeler { get; private set; } = [];

    public string? ProjeListesiHatasi { get; private set; }

    // Today's Claude calls per model against their caps, and what the last Gmail scan did with the mail it met.
    public IReadOnlyList<ClaudeKullanimi> ClaudeKullanimi { get; private set; } = [];

    public GmailTaramaSayilari? GmailSayilari { get; private set; }

    // The last weekly summary note written to the brain (null: none yet).
    public HaftalikOzetKaydi? SonOzet { get; private set; }

    // Push to the phones (FCM): on or off, how many devices are registered, and how the last send went.
    public PushDurumDto PushBilgisi { get; private set; } = new(false, 0, null);

    public GoogleDurumDto GoogleDurumu { get; private set; } = new(false, "kapali", null, [], null, 0);

    // How the Google callback went, from its redirect (?google=bagli, or ?google=hata&neden=...). Only fixed texts reach the page.
    public string? GoogleSonucu { get; private set; }

    public bool GoogleSonucuHata { get; private set; }

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

    public async Task OnGetAsync(string? google, string? neden, CancellationToken ct)
    {
        (GoogleSonucu, GoogleSonucuHata) = google switch
        {
            "bagli" => ("Google Takvim bağlandı.", false),
            "hata" => (GoogleHatasi(neden), true),
            _ => (null, false),
        };
        await YukleAsync(ct);
    }

    private static string GoogleHatasi(string? neden) => neden switch
    {
        "kapali" => "Google ayarları yapılmamış.",
        "state" or "sureDoldu" => "Bağlantı isteğinin süresi doldu ya da geçersiz. Bağla düğmesine yeniden bas.",
        "kullanici" => "Bu bağlantı isteği başka bir oturuma ait. Bağla düğmesine yeniden bas.",
        "reddedildi" => "Google'da izin verilmedi.",
        "eksikIzin" => "Google gereken izinlerin hepsini vermedi. Bağlanırken takvim izinlerini işaretli bırak.",
        _ => "Google bağlantıyı tamamlayamadı. Bağla düğmesine yeniden bas.",
    };

    private async Task YukleAsync(CancellationToken ct)
    {
        var simdi = DateTimeOffset.UtcNow;
        IzinListesi = await YonetimIslemleri.IzinleriGetirAsync(kullanicilar);
        var acik = IzinListesi.Where(i => i.Acik).Select(i => i.Izin).ToHashSet();
        GrupKartlari = IzinGruplari.Tumu.Select(g => new GrupKarti(g, IzinGruplari.KipBul(g, acik))).ToList();
        AsistanAcik = acik.Contains(IzinGruplari.AsistanAnahtari);
        EylemKipleri = await eylemler.KipleriGetirAsync(ct);
        BeyinDurumu = await YonetimIslemleri.BeyinDurumuAsync(db, beyin, ayar, simdi, ct);
        Kuyruk = await YonetimIslemleri.KuyrukAsync(db, simdi, yalnizIlgilenilecek: true, ct);
        GoogleDurumu = await googleBaglanti.DurumAsync(ct);
        ClaudeKullanimi = claude.Kullanim();
        GmailSayilari = gmailDurumu.SonSayilar;
        SonOzet = await haftalikOzet.SonKayitAsync(ct);
        PushBilgisi = new(bildirimler.PushAcik, await bildirimler.CihazSayisiAsync(ct), pushDurumu.Son);

        RepoEslemeleri = (await db.ProjeRepolari.AsNoTracking().OrderBy(r => r.ProjeKimligi).ToListAsync(ct))
            .Select(r => new ProjeRepoDto(r.ProjeKimligi, r.Depo, RepoOzetServisi.Baglanti(r.Depo))).ToList();
        var projeler = await BeyinOkuma.ProjelerAl(beyin, gunluk, ct);
        if (projeler.Basarili)
            Projeler = projeler.Veri!;
        else
            ProjeListesiHatasi = projeler.BagliDegil ? "Beyin bağlı değil; proje listesi alınamadı." : "Beyin okunamadı; proje listesi alınamadı.";
    }

    public async Task<IActionResult> OnPostIzinAsync(string izin, bool acik)
    {
        if (!Izinler.Gecerli(izin))
            return BadRequest();

        await YonetimIslemleri.IzinAyarlaAsync(kullanicilar, izin, acik);
        Bildirim = acik ? "İzin açıldı" : "İzin kapatıldı";
        return RedirectToPage();
    }

    // One card's choice. `kip` is read as text like the action modes below; `Ozel` is a reading, not a choice.
    public async Task<IActionResult> OnPostGrupAsync(string grup, string kip)
    {
        if (IzinGruplari.Bul(grup) is not { } bulunan || string.IsNullOrEmpty(kip) || !char.IsLetter(kip[0])
            || !Enum.TryParse<GrupKipi>(kip, ignoreCase: true, out var yeniKip) || yeniKip == GrupKipi.Ozel || !Enum.IsDefined(yeniKip))
            return BadRequest();

        await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, bulunan, yeniKip);
        Bildirim = "İzinler kaydedildi";
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

    // Writes this week's summary note now, for trying it out. A week already written is left as it is.
    public async Task<IActionResult> OnPostOzetYazAsync(CancellationToken ct)
    {
        var sonuc = await haftalikOzet.SimdiYazAsync(ct);
        switch (sonuc.Durum)
        {
            case OzetDurumu.Yazildi:
                Bildirim = $"Haftalık özet beyne yazıldı ({HaftalikOzetOlusturucu.Kimlik(sonuc.Hafta)})";
                break;
            case OzetDurumu.ZatenVardi:
                Bildirim = $"Bu haftanın özeti zaten yazılmış ({HaftalikOzetOlusturucu.Kimlik(sonuc.Hafta)}); üstüne yazılmaz";
                break;
            case OzetDurumu.BeyinYok:
                Hata = "Beyin bağlı değil; haftalık özet yazılamadı.";
                break;
            default:
                Hata = "Beyin haftalık özeti almadı; sonra yeniden dene.";
                break;
        }

        return RedirectToPage();
    }

    // Sends a test notification to the Sahip's own phones, the same way as POST /api/bildirim/test.
    public async Task<IActionResult> OnPostPushTestAsync(CancellationToken ct)
    {
        if (EylemEndpoints.KullaniciId(User) is not { } id)
            return Forbid();

        if (!bildirimler.PushAcik)
        {
            Hata = "Push kapalı: Firebase:AnahtarDosyasi ayarlı değil.";
            return RedirectToPage();
        }

        var bildirim = await bildirimler.OlusturAsync(id, "Test bildirimi", "Sunucudan telefona anlık bildirim çalışıyor.", "test", rota: null, hedefKimligi: null, ct);
        var sonuc = (await bildirimler.GonderAsync(bildirim, ct))!;
        if (sonuc.Hedef == 0)
            Hata = "Bu hesapta kayıtlı cihaz yok; uygulamayı açıp giriş yap.";
        else if (sonuc.Giden == 0)
            Hata = $"Bildirim gitmedi ({sonuc.Hedef} cihaz denendi); ayrıntı sunucu günlüğünde.";
        else
            Bildirim = $"Test bildirimi {sonuc.Giden} cihaza gönderildi";

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRepoAyarlaAsync(string? proje, string? depo, CancellationToken ct)
    {
        var sonuc = await ProjeRepoIslemleri.AyarlaAsync(db, beyin, saat, gunluk, proje ?? "", depo, ct);
        switch (sonuc.Tur)
        {
            case RepoEslemeTuru.Tamam:
                Bildirim = "Depo bağlandı";
                break;
            case RepoEslemeTuru.BeyinHatasi:
                Hata = sonuc.BeyinYaniti!.BagliDegil ? "Beyin bağlı değil; proje doğrulanamadı." : "Beyin okunamadı; proje doğrulanamadı.";
                break;
            default:
                Hata = sonuc.Mesaj;
                break;
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRepoSilAsync(string? proje, CancellationToken ct)
    {
        var satir = await db.ProjeRepolari.FindAsync([proje ?? ""], ct);
        if (satir is null)
            return NotFound();

        db.ProjeRepolari.Remove(satir);
        await db.SaveChangesAsync(ct);
        Bildirim = "Depo bağlantısı kaldırıldı";
        return RedirectToPage();
    }

    // To Google's consent screen; Google sends the browser back to /google/donus, which ends at this page.
    public async Task<IActionResult> OnPostGoogleBaglaAsync(CancellationToken ct)
    {
        if (EylemEndpoints.KullaniciId(User) is not { } id)
            return Forbid();

        if (await googleBaglanti.BaslatAsync(id, ct) is not { } adres)
        {
            Hata = "Google ayarları yapılmamış.";
            return RedirectToPage();
        }

        return Redirect(adres.AbsoluteUri);
    }

    public async Task<IActionResult> OnPostGoogleKesAsync(CancellationToken ct)
    {
        var sonuc = await googleBaglanti.KesAsync(ct);
        if (!sonuc.BaglantiVardi)
            Bildirim = "Zaten bağlı değildi";
        else if (sonuc.GoogleIptal)
            Bildirim = "Google Takvim bağlantısı kesildi";
        else
            Hata = "Bağlantı bu uygulamada kesildi ama Google'da izin iptal edilemedi. Google hesabının güvenlik sayfasından da kaldır.";

        return RedirectToPage();
    }

    // The same sync as POST /api/google/esitle, run now instead of waiting for the next round.
    public async Task<IActionResult> OnPostGoogleEsitleAsync(CancellationToken ct)
    {
        var ozet = await esitleyici.TurAsync(ct);
        if (ozet.ErisimSorunu is { } sorun)
            Hata = sorun == ErisimDurumu.Kapali ? "Google ayarları yapılmamış." : new ErisimSonucu(sorun).Mesaj;
        else
            Bildirim = $"Takvim eşitlendi: {ozet.Eklenen} yeni, {ozet.Guncellenen} güncellenen, {ozet.Silinen} silinen";

        return RedirectToPage();
    }
}
