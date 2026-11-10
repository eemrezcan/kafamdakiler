using System.Globalization;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Yapilacaklar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Takvim;

// "Takvim" (K-0024): a month grid with what each day holds, the list of the chosen day (the same rows and writes as Bugün) and what is
// coming. The grid and the coming list are the range view of GET /api/takvim (TakvimAraligiServisi), the day is the day view. The new-item
// form lives here, with its reminder options. Reminders have no tab of their own any more: a reminder shows on its day, and the old
// reminder pages stay reachable from here.
public class IndexModel(
    BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, GunGorunumuServisi gunServisi, GunIslemleri islemler, AppDbContext db,
    HatirlaticiAyari hatirlaticiAyari, TimeProvider saat, TakvimAraligiServisi araliklar)
    : GunSayfasi(beyin, gunluk, gunServisi, islemler, db, hatirlaticiAyari, saat)
{
    // The first day of the month on show, and the chosen day inside it.
    public DateOnly AyBasi { get; private set; }

    public DateOnly Secili { get; private set; }

    // The grid's days (whole weeks, Monday first) and the counts the range view gave for them; null when it could not be built.
    public DateOnly IlkGun { get; private set; }

    public List<TakvimGunuDto> Gunler { get; private set; } = [];

    public bool AralikVar { get; private set; }

    public List<YapilacakDto> Yaklasan { get; private set; } = [];

    // The day of a coming row, where the database knows it (reminders and events). A task's due day is not in the row.
    public Dictionary<string, DateOnly> YaklasanGunleri { get; private set; } = [];

    public GunGorunumuDto? SeciliGun { get; private set; }

    public Dictionary<string, string> ProjeAdlari { get; private set; } = [];

    public string Adres(DateOnly ay, DateOnly gun) => $"/Takvim?ay={ay:yyyy-MM}&gun={gun:yyyy-MM-dd}";

    public string SeciliAdres => Adres(AyBasi, Secili);

    public async Task<IActionResult> OnGetAsync(string? ay, string? gun, CancellationToken ct)
    {
        // A day names its month; an unreadable month or day falls back to today's, never an error page.
        DateOnly? istenenGun = DateOnly.TryParseExact(gun, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var g) && g.Year is >= 2000 and <= 2100 ? g : null;
        DateOnly? istenenAy = DateOnly.TryParseExact(ay + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var a) && a.Year is >= 2000 and <= 2100 ? a : null;

        AyBasi = istenenAy ?? (istenenGun is { } ig ? new DateOnly(ig.Year, ig.Month, 1) : new DateOnly(Bugun.Year, Bugun.Month, 1));
        Secili = istenenGun is { } sg && sg.Year == AyBasi.Year && sg.Month == AyBasi.Month ? sg
            : Bugun.Year == AyBasi.Year && Bugun.Month == AyBasi.Month ? Bugun
            : AyBasi;

        var kayma = ((int)AyBasi.DayOfWeek + 6) % 7;
        IlkGun = AyBasi.AddDays(-kayma);
        var hafta = (int)Math.Ceiling((kayma + DateTime.DaysInMonth(AyBasi.Year, AyBasi.Month)) / 7.0);
        var sonGun = IlkGun.AddDays(hafta * 7 - 1);

        try
        {
            var aralik = await araliklar.GetirAsync(IlkGun, sonGun, ct);
            Gunler = aralik.Gunler;
            Yaklasan = aralik.Yaklasan;
            AralikVar = true;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The range view of the calendar page failed.");
        }

        try
        {
            SeciliGun = await GunServisi.GetirAsync(Secili, KullaniciId, ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The day view of the calendar page failed.");
        }

        if (SeciliGun?.Kaynaklar.Plan == "tamam")
            ProjeAdlari = ((await BeyinOkuma.ProjelerAl(Istemci, Gunluk, ct)).Veri ?? []).ToDictionary(p => p.Kimlik, p => p.Baslik);

        await YaklasanGunleriniBulAsync(ct);
        return Page();
    }

    private async Task YaklasanGunleriniBulAsync(CancellationToken ct)
    {
        try
        {
            var hatirlaticilar = Yaklasan.Where(o => o.HatirlaticiId is not null && o.Tur == YapilacakTuru.Hatirlatici).Select(o => o.HatirlaticiId!.Value).ToList();
            if (hatirlaticilar.Count > 0)
            {
                var liste = await Db.Hatirlaticilar.AsNoTracking().Where(h => hatirlaticilar.Contains(h.Id)).ToListAsync(ct);
                foreach (var h in liste)
                    YaklasanGunleri[$"h:{h.Id}"] = GunSiniri.Bugun(h.ErteleAn ?? h.SonrakiAn);
            }

            var etkinlikler = Yaklasan.Where(o => o.EtkinlikId is not null).Select(o => o.EtkinlikId!.Value).ToList();
            if (etkinlikler.Count > 0)
            {
                var liste = await Db.TakvimEtkinlikleri.AsNoTracking().Where(e => etkinlikler.Contains(e.Id)).Select(e => new { e.Id, e.BaslangicGunu }).ToListAsync(ct);
                foreach (var e in liste)
                    YaklasanGunleri[$"e:{e.Id}"] = e.BaslangicGunu;
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The days of the coming rows could not be read.");
        }
    }

    // A form's way back: the month and the day it was on.
    protected override IActionResult DonusSonucu() =>
        Donus is { Length: > 0 } adres && Url.IsLocalUrl(adres) ? LocalRedirect(adres) : RedirectToPage(null, new { ay = $"{Bugun:yyyy-MM}", gun = $"{Bugun:yyyy-MM-dd}" });
}
