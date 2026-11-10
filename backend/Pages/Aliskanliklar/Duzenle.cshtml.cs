using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

public class DuzenleModel(AppDbContext db, DosyaDeposu depo) : PageModel
{
    [BindProperty]
    public AliskanlikYazDto Input { get; set; } = new();

    public Guid? AliskanlikId { get; private set; }

    public bool Yeni => AliskanlikId is null;

    // Short success message, shown once as a toast by the layout.
    [TempData]
    public string? Bildirim { get; set; }

    public async Task<IActionResult> OnGetAsync(Guid? id, AliskanlikTuru? tur, CancellationToken ct)
    {
        AliskanlikId = id;
        if (id is null)
        {
            if (tur is null)
                return RedirectToPage("Index");

            Input = Varsayilan(tur.Value);
            return Page();
        }

        var a = await db.Aliskanliklar.FindAsync([id.Value], ct);
        if (a is null)
            return NotFound();

        Input = new AliskanlikYazDto
        {
            Ad = a.Ad, Tur = a.Tur, Ikon = a.Ikon, Renk = a.Renk, Olcu = a.Olcu, HedefYonu = a.HedefYonu,
            GunlukHedef = AliskanlikIslemleri.Sade(a.GunlukHedef), Birim = a.Birim, OgeEtiketi = a.OgeEtiketi,
            AltBaslikEtiketi = a.AltBaslikEtiketi, Siklik = a.Siklik, HaftalikSayi = a.HaftalikSayi,
            Gunler = Gorunum.Haftanin.Where(g => a.Gunler is { } secili && secili.HasFlag(g)).ToList(),
            Sira = a.Sira, Arsivlendi = a.Arsivlendi,
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(Guid? id, CancellationToken ct)
    {
        AliskanlikId = id;
        if (!ModelState.IsValid)
            return Page();

        if (id is null)
        {
            var a = new Aliskanlik();
            AliskanlikIslemleri.AliskanlikUygula(a, Input);
            a.Sira = await db.Aliskanliklar.AnyAsync(ct) ? await db.Aliskanliklar.MaxAsync(x => x.Sira, ct) + 1 : 0;
            db.Aliskanliklar.Add(a);
            await db.SaveChangesAsync(ct);
            Bildirim = "Alışkanlık eklendi";

            // A new shelf habit starts with an empty shelf: go and fill it.
            return a.Tur == AliskanlikTuru.Raf
                ? RedirectToPage("Detay", null, new { id = a.Id }, "raf")
                : RedirectToPage("Index", null, null, "h-" + a.Id);
        }

        var mevcut = await db.Aliskanliklar.FindAsync([id.Value], ct);
        if (mevcut is null)
            return NotFound();
        if (AliskanlikIslemleri.AliskanlikKontrol(mevcut, Input) is { Basarili: false } sonuc)
        {
            ModelState.AddModelError(string.Empty, sonuc.Mesaj!);
            return Page();
        }

        Input.Sira = mevcut.Sira;
        Input.Arsivlendi = mevcut.Arsivlendi;
        AliskanlikIslemleri.AliskanlikUygula(mevcut, Input);
        await db.SaveChangesAsync(ct);
        Bildirim = "Kaydedildi";
        return RedirectToPage("Index", null, null, "h-" + mevcut.Id);
    }

    public async Task<IActionResult> OnPostArsivleAsync(Guid id, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([id], ct);
        if (a is null)
            return NotFound();

        a.Arsivlendi = !a.Arsivlendi;
        await db.SaveChangesAsync(ct);
        Bildirim = a.Arsivlendi ? "Arşivlendi" : "Arşivden çıkarıldı";
        return a.Arsivlendi ? RedirectToPage("Index") : RedirectToPage("Index", null, null, "h-" + a.Id);
    }

    public async Task<IActionResult> OnPostSilAsync(Guid id, CancellationToken ct)
    {
        var a = await db.Aliskanliklar.FindAsync([id], ct);
        if (a is null)
            return NotFound();

        await AliskanlikIslemleri.AliskanlikSilAsync(db, depo, a, ct);
        Bildirim = "Alışkanlık silindi";
        return RedirectToPage("Index");
    }

    // Suggested starting values, so a new habit is one name away from being saved.
    private static AliskanlikYazDto Varsayilan(AliskanlikTuru tur) => tur == AliskanlikTuru.Raf
        ? new AliskanlikYazDto
        {
            Tur = tur, Ikon = "book-open", Renk = "violet", Olcu = Olcu.Sayili, HedefYonu = HedefYonu.EnAz,
            GunlukHedef = 30, Birim = "sayfa", OgeEtiketi = "Kitap", AltBaslikEtiketi = "Yazar",
        }
        : new AliskanlikYazDto
        {
            Tur = tur, Ikon = "glass-water", Renk = "blue", Olcu = Olcu.Sayili, HedefYonu = HedefYonu.EnAz,
            GunlukHedef = 8, Birim = "bardak",
        };
}
