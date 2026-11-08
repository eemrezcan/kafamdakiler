using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

// The habit panel: today's habits as cards, and the archive. (The briefing and the timeline are on the home page.)
public class IndexModel(AppDbContext db) : PageModel
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

    public async Task OnGetAsync(CancellationToken ct)
    {
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

    // Post-redirect-get, back to the same card: on this page, or on Bugün when the card was used there (the form says
    // "donus=bugun"; nothing else is read from it, so it cannot send the browser anywhere else).
    private IActionResult Don(Sonuc sonuc, Guid aliskanlikId, string? bildirim)
    {
        if (!sonuc.Basarili)
            Hata = sonuc.Mesaj;
        else
            Bildirim = bildirim;

        if (Request.HasFormContentType && Request.Form["donus"] == "bugun")
        {
            // Bugün shows its own error line; the message goes there instead of waiting for the habits page.
            if (Hata is { } hata)
            {
                TempData["YazmaHatasi"] = hata;
                Hata = null;
            }

            return RedirectToPage("/Index", null, null, "h-" + aliskanlikId);
        }

        return RedirectToPage("/Aliskanliklar/Index", null, null, "h-" + aliskanlikId);
    }
}
