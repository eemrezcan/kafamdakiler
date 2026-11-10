using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Isler;
using Kafamdakiler.Yapilacaklar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Bildirimler;

// The notification center (K-0024, §6) on the web: the person's own rows, newest first, 30 to a page ("Daha eski" continues from the oldest row
// shown), unread ones marked, one or all marked read. A reminder's notification offers "Yaptım" and "Ertele" while the reminder is open: they go
// to the same code as everywhere else (GunIslemleri.YaptimAsync with its chain, HatirlaticiIslemleri.Ertele). Reading marks a row, deletes nothing.
public class IndexModel(AppDbContext db, GunIslemleri islemler, HatirlaticiAyari ayar, TimeProvider saat) : PageModel
{
    public const int SayfaBoyu = BildirimEndpoints.VarsayilanSatir;

    public record Satir(BildirimSatiriDto Bildirim, HatirlaticiDurumu? HatirlaticiDurumu, string? Adres);

    public List<Satir> Satirlar { get; private set; } = [];

    public int Okunmamis { get; private set; }

    // The moment to continue from when there are older rows, else null.
    public DateTimeOffset? Sonraki { get; private set; }

    [BindProperty(Name = "donus")]
    public string? Donus { get; set; }

    [TempData]
    public string? Hata { get; set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    private Guid? KullaniciId => BildirimEndpoints.KullaniciId(User);

    public async Task<IActionResult> OnGetAsync(DateTimeOffset? once, CancellationToken ct)
    {
        if (KullaniciId is not { } kullanici)
            return Challenge();

        var sorgu = db.Bildirimler.AsNoTracking().Where(b => b.KullaniciId == kullanici);
        Okunmamis = await sorgu.CountAsync(b => b.OkunmaAni == null, ct);
        if (once is { } sinir)
            sorgu = sorgu.Where(b => b.OlusmaAni < sinir);

        // One more than a page tells whether there is an older page.
        var liste = await sorgu.OrderByDescending(b => b.OlusmaAni).ThenByDescending(b => b.Id).Take(SayfaBoyu + 1)
            .Select(b => new BildirimSatiriDto(b.Id, b.Baslik, b.Metin, b.Rota, b.HedefKimligi, b.KaynakTuru, b.OlusmaAni, b.Anahtar, b.OkunmaAni != null))
            .ToListAsync(ct);
        if (liste.Count > SayfaBoyu)
        {
            liste.RemoveAt(SayfaBoyu);
            Sonraki = liste[^1].OlusmaAni;
        }

        // The state of the reminders the page offers buttons for (one query).
        var hatirlaticilar = liste.Where(b => b.KaynakTuru == "hatirlatici" && Guid.TryParse(b.HedefKimligi, out _))
            .Select(b => Guid.Parse(b.HedefKimligi!)).Distinct().ToList();
        var durumlar = hatirlaticilar.Count == 0
            ? []
            : await db.Hatirlaticilar.AsNoTracking().Where(h => hatirlaticilar.Contains(h.Id)).ToDictionaryAsync(h => h.Id, h => h.Durum, ct);
        Satirlar = liste.Select(b => new Satir(
            b,
            b.KaynakTuru == "hatirlatici" && Guid.TryParse(b.HedefKimligi, out var id) && durumlar.TryGetValue(id, out var d) ? d : null,
            AdresBul(b))).ToList();
        return Page();
    }

    // Where a tap on the row goes on the web: the notification's `Rota` is a route of the phone, so it is translated by what made it.
    private string? AdresBul(BildirimSatiriDto b) => b.KaynakTuru switch
    {
        "hatirlatici" when Guid.TryParse(b.HedefKimligi, out var id) => Url.Page("/Hatirlaticilar/Duzenle", new { id }),
        "is" when !string.IsNullOrWhiteSpace(b.HedefKimligi) => Url.Page("/Isler/Detay", new { kimlik = b.HedefKimligi }),
        "gorev" or "dogrulama" or "asistan" => Url.Page("/Index"),
        _ => null,
    };

    private IActionResult Don() =>
        Donus is { Length: > 0 } adres && Url.IsLocalUrl(adres) ? LocalRedirect(adres) : RedirectToPage();

    private IActionResult Reddet(string mesaj)
    {
        Hata = mesaj;
        return Don();
    }

    public async Task<IActionResult> OnPostOkunduAsync(Guid id)
    {
        if (KullaniciId is not { } kullanici)
            return Challenge();

        await OkunduYapAsync(id, kullanici);
        return Don();
    }

    public async Task<IActionResult> OnPostTumuOkunduAsync()
    {
        if (KullaniciId is not { } kullanici)
            return Challenge();

        var an = saat.GetUtcNow();
        await db.Bildirimler.Where(b => b.KullaniciId == kullanici && b.OkunmaAni == null).ExecuteUpdateAsync(s => s.SetProperty(b => b.OkunmaAni, an));
        Bildirim = "Hepsi okundu";
        return Don();
    }

    // "Yaptım" on a reminder's notification: the reminder is done with its chain, and the notification is read.
    public async Task<IActionResult> OnPostYaptimAsync(Guid id)
    {
        if (KullaniciId is not { } kullanici)
            return Challenge();
        if (await HatirlaticiBulAsync(id, kullanici) is not { } hatirlatici)
            return Reddet("Bu bildirimin hatırlatıcısı artık yok.");

        var yanit = await islemler.YaptimAsync(GunSiniri.Bugun(saat.GetUtcNow()), 'h', hatirlatici.Id.ToString(), $"h:{hatirlatici.Id}", false, kullanici, CancellationToken.None);
        if (!yanit.Basarili)
            return Reddet(yanit.Alanlar is not null ? string.Join(" ", yanit.Alanlar.Values.SelectMany(m => m)) : yanit.Ayrinti ?? yanit.Baslik ?? "İşlem yapılamadı.");

        await OkunduYapAsync(id, kullanici);
        if (yanit.Veri is YaptimYanitiDto { ZincirHatasi: { } zincirHatasi })
            Hata = zincirHatasi;
        else
            Bildirim = "Yapıldı";
        return Don();
    }

    // "Ertele": 1 hour or tomorrow, as the reminder page does it.
    public async Task<IActionResult> OnPostErteleAsync(Guid id, string? sure)
    {
        if (KullaniciId is not { } kullanici)
            return Challenge();
        if (await HatirlaticiBulAsync(id, kullanici) is not { } hatirlatici)
            return Reddet("Bu bildirimin hatırlatıcısı artık yok.");

        var sonuc = HatirlaticiIslemleri.Ertele(db, hatirlatici, sure, ayar.VarsayilanSaat, saat.GetUtcNow());
        if (!sonuc.Basarili)
            return Reddet(sonuc.Mesaj ?? "Ertelenemedi.");

        await db.SaveChangesAsync();
        await OkunduYapAsync(id, kullanici);
        Bildirim = "Ertelendi";
        return Don();
    }

    // The reminder of the notification `id`, only through a notification of this person's own (a guessed reminder id is a 404 in words).
    private async Task<Hatirlatici?> HatirlaticiBulAsync(Guid bildirimId, Guid kullanici)
    {
        var b = await db.Bildirimler.AsNoTracking().FirstOrDefaultAsync(x => x.Id == bildirimId && x.KullaniciId == kullanici && x.KaynakTuru == "hatirlatici");
        return b is not null && Guid.TryParse(b.HedefKimligi, out var id) ? await db.Hatirlaticilar.FindAsync(id) : null;
    }

    private async Task OkunduYapAsync(Guid id, Guid kullanici)
    {
        var an = saat.GetUtcNow();
        await db.Bildirimler.Where(b => b.Id == id && b.KullaniciId == kullanici && b.OkunmaAni == null).ExecuteUpdateAsync(s => s.SetProperty(b => b.OkunmaAni, an));
    }
}
