using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Data;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

// The home page: today's briefing (K2.7) and timeline (K2.3c) on top, then the habit panel.
public class IndexModel(
    AppDbContext db, BrifingHazirlayici brifingler, ZamanCizelgesiServisi cizelgeler, TimeProvider saat, ILogger<IndexModel> gunluk) : PageModel
{
    public record Kart(AliskanlikDto Aliskanlik, List<GunDto> SonGunler);

    // Habits planned for today first; the rest are shown dimmed below.
    public List<Kart> Planli { get; private set; } = [];
    public List<Kart> Diger { get; private set; } = [];
    public DateOnly BugunTarihi { get; private set; }

    // Today's summary: how many of today's planned habits reached their goal (or stayed under the limit).
    public int BugunTamam => Planli.Count(k => k.Aliskanlik.Bugun.Deger >= 1);

    [TempData]
    public string? Hata { get; set; }

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    // /Aliskanliklar?arsiv=true lists the archived habits instead.
    [BindProperty(SupportsGet = true)]
    public bool Arsiv { get; set; }

    // Today's briefing and timeline; null when they could not be had. The extras never turn the habit panel into an error page.
    public BrifingPaneli? Brifing { get; private set; }

    public ZamanCizelgesiDto? Cizelge { get; private set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        if (!Arsiv)
        {
            await BrifingYukleAsync(ct);
            await CizelgeYukleAsync(ct);
        }

        var liste = await db.Aliskanliklar.Where(a => a.Arsivlendi == Arsiv)
            .OrderBy(a => a.Sira).ThenBy(a => a.CreatedAt).ToListAsync(ct);
        var dtolar = await AliskanlikEndpoints.DtoYapAsync(db, liste, ct);

        BugunTarihi = AliskanlikIslemleri.Bugun();
        for (var i = 0; i < liste.Count; i++)
        {
            var gunler = await AliskanlikEndpoints.GunleriHesaplaAsync(db, liste[i], BugunTarihi.AddDays(-6), BugunTarihi, ct);
            (dtolar[i].Bugun.Planli ? Planli : Diger).Add(new Kart(dtolar[i], gunler));
        }
    }

    private async Task BrifingYukleAsync(CancellationToken ct)
    {
        try
        {
            var sonuc = await brifingler.BugunAsync(ct);
            Brifing = sonuc.Basarili
                ? new BrifingPaneli(await brifingler.DtoYapAsync(sonuc.Brifing!, ct), null)
                : new BrifingPaneli(null, sonuc.Durum == BrifingDurumu.HenuzHazirDegil ? sonuc.Mesaj : "Bugünün brifingi şu an hazırlanamadı.");
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            gunluk.LogError(e, "The briefing panel of the home page failed.");
            Brifing = new BrifingPaneli(null, "Bugünün brifingi şu an hazırlanamadı.");
        }
    }

    private async Task CizelgeYukleAsync(CancellationToken ct)
    {
        try
        {
            Cizelge = await cizelgeler.GetirAsync(GunSiniri.Bugun(saat.GetUtcNow()), ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            gunluk.LogError(e, "The timeline of the home page failed.");
        }
    }

    // A vote on a card of today's briefing: 1, -1, or 0 to take it back.
    public async Task<IActionResult> OnPostBrifingOyAsync(int sira, int oy, CancellationToken ct)
    {
        var sonuc = await brifingler.OyVerAsync(brifingler.Bugun, sira, oy, ct);
        if (!sonuc.Basarili)
            Hata = sonuc.Mesaj;

        return RedirectToPage("/Aliskanliklar/Index", null, null, "brifing");
    }

    // The Sahip asks for a new briefing (at most three times a day).
    public async Task<IActionResult> OnPostBrifingYenileAsync(CancellationToken ct)
    {
        var sonuc = await brifingler.YenileAsync(ct);
        if (sonuc.Basarili)
            Bildirim = "Brifing yenilendi";
        else
            Hata = sonuc.Mesaj;

        return RedirectToPage("/Aliskanliklar/Index", null, null, "brifing");
    }

    // Yes/no habit: one tap ticks today, another tap takes it back.
    public async Task<IActionResult> OnPostTikAsync(Guid id, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([id], ct);
        if (a is null)
            return NotFound();

        var bugun = AliskanlikIslemleri.Bugun();
        var yapildi = await db.AliskanlikKayitlari.AnyAsync(k => k.AliskanlikId == id && k.Tarih == bugun && k.Miktar > 0, ct);
        var sonuc = yapildi
            ? await AliskanlikIslemleri.KayitSilAsync(db, a, bugun, ct)
            : await AliskanlikIslemleri.KayitYazAsync(db, a, bugun, 1, null, ct);
        return Don(sonuc, id, yapildi ? "Geri alındı" : "İşaretlendi");
    }

    // Counter habit: −/+ changes today's total by one step.
    public async Task<IActionResult> OnPostSayiAsync(Guid id, decimal delta, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([id], ct);
        if (a is null)
            return NotFound();

        var bugun = AliskanlikIslemleri.Bugun();
        var simdiki = await db.AliskanlikKayitlari.Where(k => k.AliskanlikId == id && k.Tarih == bugun)
            .Select(k => (decimal?)k.Miktar).FirstOrDefaultAsync(ct) ?? 0;
        var yeni = Math.Max(0, simdiki + delta);
        return Don(await AliskanlikIslemleri.KayitYazAsync(db, a, bugun, yeni, null, ct), id, "Kaydedildi");
    }

    // Counter habit: type today's total.
    public async Task<IActionResult> OnPostAyarlaAsync(Guid id, decimal? miktar, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([id], ct);
        if (a is null)
            return NotFound();
        if (miktar is null or < 0)
        {
            Hata = "Bugünkü miktarı 0 ya da daha büyük bir sayı olarak yaz.";
            return Don(Sonuc.Tamam, id, null);
        }

        return Don(await AliskanlikIslemleri.KayitYazAsync(db, a, AliskanlikIslemleri.Bugun(), miktar.Value, null, ct), id, "Kaydedildi");
    }

    // Shelf habit: "I got to page 35".
    public async Task<IActionResult> OnPostIlerlemeAsync(Guid ogeId, decimal? bitisKonum, int? dakika, CancellationToken ct)
    {
        var oge = await AliskanlikIslemleri.OgeSorgu(db).FirstOrDefaultAsync(o => o.Id == ogeId, ct);
        if (oge is null)
            return NotFound();
        if (bitisKonum is null)
        {
            Hata = "Nereye kadar geldiğini yaz.";
            return Don(Sonuc.Tamam, oge.AliskanlikId, null);
        }

        var (sonuc, _) = await AliskanlikIslemleri.OturumEkleAsync(db, oge,
            new OturumEkleDto { BitisKonum = bitisKonum.Value, Dakika = dakika }, ct);
        return Don(sonuc, oge.AliskanlikId, "Oturum kaydedildi");
    }

    // Post-redirect-get, back to the same card.
    private IActionResult Don(Sonuc sonuc, Guid aliskanlikId, string? bildirim)
    {
        if (!sonuc.Basarili)
            Hata = sonuc.Mesaj;
        else
            Bildirim = bildirim;

        return RedirectToPage("/Aliskanliklar/Index", null, null, "h-" + aliskanlikId);
    }
}
