using System.ComponentModel.DataAnnotations;
using System.Globalization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Pages.Beyin;
using Kafamdakiler.Yapilacaklar;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

namespace Kafamdakiler.Pages;

// The reminder part of the forms (K-0024): the same words as the reminder itself. Bound from `h.*` fields.
public class HatirlaticiFormu
{
    // The checkbox of "Hatırlatıcı kur" on the new-item form.
    public bool Var { get; set; }

    public string? Saat { get; set; }

    public string? Tekrar { get; set; }

    public List<string>? Gunler { get; set; }

    public int OnceGun { get; set; }

    public bool Acil { get; set; }

    public bool Israrli { get; set; }
}

// The new-item form (K-0024, §4). Bound from `yeni.*` fields.
public class YeniOgeFormu
{
    public string? Baslik { get; set; }

    public string? Saat { get; set; }

    public int? TahminDk { get; set; }

    public string? Bolum { get; set; }
}

// What the two day pages (Bugün and Takvim) share: the writes of one list row (done, carry over, note, split, the reminder of an item)
// and the new-item form. Every write goes to the same code as the API (GunIslemleri, BeyinYazma, HatirlaticiIslemleri), so the chain between
// a task and its reminder (HatirlaticiZinciri) runs from the web as it does from the phone. Writes are not tied to the request: a closed
// tab must not leave one half done. A form says where it came from (`donus`, a local address) and the write goes back there.
public abstract class GunSayfasi(
    BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, GunGorunumuServisi gunServisi, GunIslemleri islemler, AppDbContext db,
    HatirlaticiAyari hatirlaticiAyari, TimeProvider saat)
    : BeyinSayfasi(beyin, gunluk)
{
    private static readonly string[] SaatBicimleri = ["HH:mm", "H:mm", "HH:mm:ss"];

    // Today by the brain's day-turn rule (05:00), not by the calendar.
    public DateOnly Bugun { get; } = GunSiniri.Bugun(saat.GetUtcNow());

    [BindProperty(Name = "donus")]
    public string? Donus { get; set; }

    [BindProperty(Name = "h")]
    public HatirlaticiFormu H { get; set; } = new();

    [BindProperty(Name = "yeni")]
    public YeniOgeFormu Yeni { get; set; } = new();

    protected Guid? KullaniciId => BildirimEndpoints.KullaniciId(User);

    protected GunGorunumuServisi GunServisi => gunServisi;

    protected AppDbContext Db => db;

    protected HatirlaticiAyari HatirlaticiAyari => hatirlaticiAyari;

    protected TimeProvider Saat => saat;

    protected override IActionResult DonusSonucu() =>
        Donus is { Length: > 0 } adres && Url.IsLocalUrl(adres) ? LocalRedirect(adres) : RedirectToPage();

    // The day a form names (`bugun` or an empty value is today). Null with the message set when it is not a date.
    protected DateOnly? GunBul(string? tarih)
    {
        if (GunEndpoints.GunCoz(string.IsNullOrWhiteSpace(tarih) ? "bugun" : tarih.Trim(), saat) is { } gun)
            return gun;

        YazmaHatasi = "Tarih yyyy-MM-dd biçiminde olmalı.";
        return null;
    }

    protected IActionResult Reddet(string mesaj)
    {
        YazmaHatasi = mesaj;
        return DonusSonucu();
    }

    // "Yaptım" on any row (m:, g:, h:); the same call as POST /api/gun/{tarih}/yaptim, chain included.
    public async Task<IActionResult> OnPostYaptimAsync(string? tarih, string? kimlik, bool geri)
    {
        if (GunBul(tarih) is not { } gun)
            return DonusSonucu();
        if (GunEndpoints.Ayir(kimlik?.Trim() ?? "") is not { } parca || parca.Onek == 'e')
            return Reddet("Bu öğe için yaptım yok.");
        if (parca.Onek == 'g' && geri)
            return Reddet("Biten görev buradan yeniden açılamaz.");
        if (parca.Onek == 'h' && !Guid.TryParse(parca.Deger, out _))
            return Reddet("Hatırlatıcı kimliği geçerli değil.");

        var yanit = await islemler.YaptimAsync(gun, parca.Onek, parca.Deger, kimlik!.Trim(), geri, KullaniciId, CancellationToken.None);
        var sonuc = Don(yanit, geri ? "Yeniden açıldı" : "Yapıldı");
        if (yanit.Basarili && yanit.Veri is YaptimYanitiDto { } dto)
        {
            // What was done stays done; a step of the chain that did not go through is said, never hidden.
            if (dto.ZincirHatasi is { } hata)
                YazmaHatasi = hata;
            else if (dto.Zincir.Count > 0)
                Bildirim = $"Yapıldı; bağlı {dto.Zincir.Count} iş de kapandı";
        }

        return sonuc;
    }

    // "Devret": a plan item goes to the next day, a task becomes an item of the next day, a reminder is snoozed to tomorrow.
    public async Task<IActionResult> OnPostDevretAsync(string? tarih, string? kimlik)
    {
        if (GunBul(tarih) is not { } gun)
            return DonusSonucu();
        if (GunEndpoints.Ayir(kimlik?.Trim() ?? "") is not { } parca || parca.Onek == 'e')
            return Reddet("Bu öğe devredilemez.");

        var gunMetni = $"{gun:yyyy-MM-dd}";
        switch (parca.Onek)
        {
            case 'm':
                return Don(await BeyinYazma.MaddeDevret(gunMetni, new MaddeDevretGirdi(parca.Deger), Istemci, Gunluk, CancellationToken.None),
                    "Ertesi güne devredildi");

            case 'g':
            {
                // The task keeps its own file; tomorrow gets an item that points at it.
                var gorunum = await gunServisi.GetirAsync(gun, KullaniciId, CancellationToken.None);
                var baslik = gorunum.Ogeler.FirstOrDefault(o => o.Kimlik == kimlik!.Trim())?.Baslik;
                if (baslik is null)
                    return Reddet("Görev o günün listesinde yok.");

                return Don(await BeyinYazma.MaddeEkle($"{gun.AddDays(1):yyyy-MM-dd}", new MaddeEkleGirdi(baslik, null, parca.Deger), Istemci, Gunluk, CancellationToken.None),
                    "Ertesi güne devredildi");
            }

            default:
            {
                if (!Guid.TryParse(parca.Deger, out var id) || await db.Hatirlaticilar.FindAsync([id]) is not { } h)
                    return Reddet("Hatırlatıcı bulunamadı.");

                var sonuc = HatirlaticiIslemleri.Ertele(db, h, "yarin", hatirlaticiAyari.VarsayilanSaat, saat.GetUtcNow());
                if (!sonuc.Basarili)
                    return Reddet(sonuc.Mesaj ?? "Hatırlatıcı ertelenemedi.");

                await db.SaveChangesAsync();
                Bildirim = "Yarına ertelendi";
                return DonusSonucu();
            }
        }
    }

    public async Task<IActionResult> OnPostNotAsync(string? tarih, string? madde, string? metin)
    {
        if (GunBul(tarih) is not { } gun)
            return DonusSonucu();

        return Don(await BeyinYazma.MaddeNotu($"{gun:yyyy-MM-dd}", new MaddeNotGirdi(madde, metin), Istemci, Gunluk, CancellationToken.None), "Not eklendi");
    }

    // Splits a task over days. `kimlik` is the task's slug.
    public async Task<IActionResult> OnPostBolAsync(string? kimlik, int gunSayisi, string? baslangic) =>
        Don(await BeyinYazma.GunlereBol(kimlik ?? "", new GunlereBolGirdi(gunSayisi, baslangic, null, null), Istemci, Gunluk, saat, CancellationToken.None),
            "Görev günlere bölündü");

    public async Task<IActionResult> OnPostHatirlaticiKurAsync(string? tarih, string? kimlik)
    {
        if (GunBul(tarih) is not { } gun)
            return DonusSonucu();
        if (GunEndpoints.OgeKimligi(kimlik?.Trim() ?? "") is not { } parca)
            return Reddet("Hatırlatıcı yalnız plan maddesine ya da göreve kurulur.");
        if (HatirlaticiDto() is not { } dto)
            return DonusSonucu();

        return Sonuc(await islemler.HatirlaticiKurAsync(gun, kimlik!.Trim(), parca, dto, KullaniciId, CancellationToken.None), "Hatırlatıcı kuruldu");
    }

    public async Task<IActionResult> OnPostHatirlaticiDegistirAsync(string? tarih, string? kimlik)
    {
        if (GunBul(tarih) is not { } gun)
            return DonusSonucu();
        if (GunEndpoints.OgeKimligi(kimlik?.Trim() ?? "") is not { } parca)
            return Reddet("Hatırlatıcı yalnız plan maddesine ya da göreve kurulur.");
        if (HatirlaticiDto() is not { } dto)
            return DonusSonucu();

        return Sonuc(await islemler.HatirlaticiDegistirAsync(gun, parca, dto, CancellationToken.None), "Hatırlatıcı güncellendi");
    }

    public async Task<IActionResult> OnPostHatirlaticiKaldirAsync(string? tarih, string? kimlik)
    {
        if (GunBul(tarih) is not { } gun)
            return DonusSonucu();
        if (GunEndpoints.OgeKimligi(kimlik?.Trim() ?? "") is not { } parca)
            return Reddet("Hatırlatıcı yalnız plan maddesine ya da göreve kurulur.");

        return Sonuc(await islemler.HatirlaticiKaldirAsync(gun, parca, CancellationToken.None), "Hatırlatıcı kaldırıldı");
    }

    // The new-item form: a line on the day's plan and, when asked, its reminder.
    public async Task<IActionResult> OnPostEkleAsync(string? tarih)
    {
        if (GunBul(tarih) is not { } gun)
            return DonusSonucu();

        TimeOnly? saatDegeri = null;
        if (!string.IsNullOrWhiteSpace(Yeni.Saat))
        {
            if (!TimeOnly.TryParseExact(Yeni.Saat.Trim(), SaatBicimleri, CultureInfo.InvariantCulture, DateTimeStyles.None, out var s))
                return Reddet("Saat SS:DD biçiminde olmalı.");
            saatDegeri = s;
        }

        var girdi = new YeniOgeGirdisi
        {
            Baslik = Yeni.Baslik,
            Saat = saatDegeri,
            TahminDk = Yeni.TahminDk,
            Bolum = string.IsNullOrWhiteSpace(Yeni.Bolum) ? null : Yeni.Bolum.Trim(),
        };
        if (H.Var)
        {
            if (HatirlaticiDto() is not { } dto)
                return DonusSonucu();
            girdi.Hatirlatici = dto;
        }

        if (Dogrula(girdi) is { } hata)
            return Reddet(hata);

        return Don(await islemler.OgeEkleAsync(gun, girdi, KullaniciId, CancellationToken.None), "Eklendi");
    }

    // The reminder fields as the API's own body, checked by the same rules. Null with the message set when they do not hold.
    private OgeHatirlaticiDto? HatirlaticiDto()
    {
        TimeOnly? saatDegeri = null;
        if (!string.IsNullOrWhiteSpace(H.Saat))
        {
            if (!TimeOnly.TryParseExact(H.Saat.Trim(), SaatBicimleri, CultureInfo.InvariantCulture, DateTimeStyles.None, out var s))
            {
                YazmaHatasi = "Hatırlatıcı saati SS:DD biçiminde olmalı.";
                return null;
            }

            saatDegeri = s;
        }

        var tekrar = Tekrar.Yok;
        if (!string.IsNullOrWhiteSpace(H.Tekrar) && (!Enum.TryParse(H.Tekrar, true, out tekrar) || !Enum.IsDefined(tekrar)))
        {
            YazmaHatasi = "Tekrar yok, gunluk, haftalik, aylik ya da yillik olmalı.";
            return null;
        }

        List<Gunler>? gunler = null;
        if (tekrar == Tekrar.Haftalik && H.Gunler is { Count: > 0 } secilen)
        {
            gunler = [];
            foreach (var ad in secilen)
            {
                if (!Enum.TryParse<Gunler>(ad, true, out var gun) || gun == Gunler.Yok || !Enum.IsDefined(gun))
                {
                    YazmaHatasi = "Gün listesi yalnız pzt, sal, car, per, cum, cmt, paz içerebilir.";
                    return null;
                }

                if (!gunler.Contains(gun))
                    gunler.Add(gun);
            }
        }

        var dto = new OgeHatirlaticiDto
        {
            Saat = saatDegeri, Tekrar = tekrar, Gunler = gunler, Acil = H.Acil, Israrli = H.Israrli, OnceGun = H.OnceGun,
        };
        if (Dogrula(dto) is { } hata)
        {
            YazmaHatasi = hata;
            return null;
        }

        return dto;
    }

    private static string? Dogrula(object nesne)
    {
        var sonuclar = new List<ValidationResult>();
        return Validator.TryValidateObject(nesne, new ValidationContext(nesne), sonuclar, validateAllProperties: true)
            ? null
            : string.Join(" ", sonuclar.Select(s => s.ErrorMessage));
    }

    // What the reminder shortcuts of the day service answer (they are minimal-API results), as a message and a redirect.
    private IActionResult Sonuc(IResult sonuc, string basari)
    {
        if (sonuc is IStatusCodeHttpResult { StatusCode: >= 200 and < 300 })
        {
            Bildirim = basari;
            return DonusSonucu();
        }

        YazmaHatasi = sonuc switch
        {
            ProblemHttpResult { ProblemDetails: HttpValidationProblemDetails dogrulama } => string.Join(" ", dogrulama.Errors.Values.SelectMany(m => m)),
            ProblemHttpResult sorun => sorun.ProblemDetails.Detail ?? sorun.ProblemDetails.Title ?? "İşlem yapılamadı.",
            IStatusCodeHttpResult { StatusCode: StatusCodes.Status404NotFound } => "Bu öğenin açık bir hatırlatıcısı yok.",
            _ => "İşlem yapılamadı.",
        };
        return DonusSonucu();
    }
}
