using System.Globalization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Pages.Beyin;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages;

// The home page, "Bugün": the brain's plan for a day (the mobile day-plan card) with the writes on it (K2.3a: add, tick,
// carry over, note, add and finish a task, split a task over days). No date means today by the brain's own day-turn rule
// (05:00). Every write goes through BeyinYazma, the same code and checks as /api/beyin (no Idempotency-Key: a form is not
// resent by a queue), and each one names the date explicitly.
// On today's page the briefing (K2.7), the approval card, the coming reminders and today's habits are shown as well;
// another day is just that day's plan. None of the extras depends on the brain, and a failing one only drops its own part.
public class IndexModel(
    BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, GunAyari ayar, TimeProvider saat, ZamanCizelgesiServisi cizelgeler,
    BrifingHazirlayici brifingler, AppDbContext db)
    : BeyinSayfasi(beyin, gunluk)
{
    // The morning card remembers what was let go in this browser only: letting go writes nothing to the brain.
    private const string SabahCerezi = "kd-sabah";
    private const int EnCokBirakilan = 40;

    // How far ahead the reminder list looks, and how many it shows.
    private const int YaklasanGun = 7;
    private const int EnCokYaklasan = 5;

    public BeyinGunDto? Gun { get; private set; }

    // The day asked for, as written (yyyy-MM-dd) when it is a real date, else null.
    public DateOnly? Tarih { get; private set; }

    // Today by the day-turn rule, not by the calendar: at 02:00 it is still yesterday's plan.
    public DateOnly Bugun { get; } = GunSiniri.Bugun(saat.GetUtcNow());

    // True on today's page: the extras below belong there only.
    public bool BugunSayfasi => Tarih == Bugun;

    // What yesterday left open, on today's page only.
    public SabahKartiDto? Sabah { get; private set; }

    // The pick lists of the forms. Empty when the brain would not answer: the forms are then left out.
    public List<ProjeOzetDto> Projeler { get; private set; } = [];

    public List<AcikGorevDto> Gorevler { get; private set; } = [];

    // The open tasks as one list: late ones first (most days late first), then by due date with undated last.
    public IReadOnlyList<GorevSatiri> GorevListesi
    {
        get
        {
            var geciken = Gun?.Geciken.ToDictionary(g => g.Kimlik, StringComparer.Ordinal) ?? [];
            var acik = Gorevler.Select(g => new GorevSatiri(
                g.Kimlik, g.Baslik, g.Proje, g.Bitis, geciken.TryGetValue(g.Kimlik, out var late) ? late.Gun ?? 0 : null));
            // A late task the open-task list did not carry is still shown.
            var eksik = geciken.Values.Where(g => Gorevler.All(a => a.Kimlik != g.Kimlik))
                .Select(g => new GorevSatiri(g.Kimlik, g.Baslik, g.Proje, g.Bitis, g.Gun ?? 0));
            return acik.Concat(eksik)
                .Where(g => !SabahtaVar(g.Kimlik, g.Baslik))
                .OrderBy(g => g.GecikenGun is null)
                .ThenByDescending(g => g.GecikenGun ?? 0)
                .ThenBy(g => g.Bitis ?? DateOnly.MaxValue)
                .ThenBy(g => g.Baslik, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
        }
    }

    // The one timeline of the day (K2.3c); null when it could not be had.
    public ZamanCizelgesiDto? Cizelge { get; private set; }

    // Today's briefing; null when it could not be had or this is another day.
    public BrifingPaneli? Brifing { get; private set; }

    // Open reminders due within the coming week (overdue ones first) and the moment they were judged at.
    public List<HatirlaticiDto> Yaklasanlar { get; private set; } = [];

    public DateTimeOffset Simdi { get; private set; }

    // The habits planned for today, as the same cards as the habits page (tick, −/+, "Nereye kadar geldin?" work here too).
    public List<Aliskanliklar.IndexModel.Kart> BugunkuAliskanliklar { get; private set; } = [];

    // The project's title for a task line ("Staj Hazırlığı", not "staj-hazirligi"); the id when the brain did not name it.
    public string ProjeAdi(string kimlik) => Projeler.FirstOrDefault(p => p.Kimlik == kimlik)?.Baslik ?? kimlik;

    // The overdue task a leftover line stands for: the line is linked to it, or carries its title. Shown under the line,
    // and the task is then left out of the task list below (one job, one place).
    public GecikenGorevDto? SabahGorevi(SabahMaddesiDto madde) =>
        Gun?.Geciken.FirstOrDefault(g => AyniIs(madde.Gorev, madde.Baslik, g.Kimlik, g.Baslik));

    private bool SabahtaVar(string kimlik, string baslik) =>
        Sabah?.Maddeler.Any(m => AyniIs(m.Gorev, m.Baslik, kimlik, baslik)) ?? false;

    private static bool AyniIs(string? maddeGorevi, string maddeBasligi, string gorevKimligi, string gorevBasligi) =>
        (maddeGorevi is not null && (maddeGorevi == gorevKimligi || maddeGorevi.EndsWith("/" + gorevKimligi, StringComparison.Ordinal)
            || gorevKimligi.EndsWith("/" + maddeGorevi, StringComparison.Ordinal)))
        || string.Equals(maddeBasligi.Trim(), gorevBasligi.Trim(), StringComparison.CurrentCultureIgnoreCase);

    public async Task OnGetAsync(string? tarih, CancellationToken ct)
    {
        var istenen = string.IsNullOrWhiteSpace(tarih) ? Bugun.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : tarih;
        if (DateOnly.TryParseExact(istenen, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun))
            Tarih = gun;

        Gun = Al(await BeyinOkuma.GunAl(istenen, Istemci, Gunluk, ct, ayar));
        if (Gun is not null)
            await PlanYukleAsync(ct);

        // The timeline holds the calendar and the reminders too, so it does not wait for the brain; it says itself when the plan is missing.
        await CizelgeYukleAsync(ct);

        if (BugunSayfasi)
        {
            await BrifingYukleAsync(ct);
            await YaklasanlariYukleAsync(ct);
            await AliskanliklariYukleAsync(ct);
        }
    }

    // The extras never turn a good page into an error page: if one fails, its part is simply not shown.
    private async Task PlanYukleAsync(CancellationToken ct)
    {
        Projeler = (await BeyinOkuma.ProjelerAl(Istemci, Gunluk, ct)).Veri ?? [];
        Gorevler = (await BeyinOkuma.AcikGorevlerAl(Istemci, Gunluk, ct)).Veri ?? [];

        if (Tarih == Bugun && (await BeyinOkuma.SabahAl(Istemci, Gunluk, saat, ct)).Veri is { } kart)
        {
            var birakilan = Birakilanlar(kart.Dun);
            Sabah = kart with { Maddeler = kart.Maddeler.Where(m => !birakilan.Contains(m.Id)).ToList() };
        }
    }

    private async Task CizelgeYukleAsync(CancellationToken ct)
    {
        if (Tarih is not { } cizelgeGunu)
            return;

        try
        {
            Cizelge = await cizelgeler.GetirAsync(cizelgeGunu, ct, Gun);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The timeline of the day page failed.");
        }
    }

    private async Task BrifingYukleAsync(CancellationToken ct)
    {
        try
        {
            var sonuc = await brifingler.BugunAsync(ct);
            Brifing = sonuc.Basarili
                ? KalanKartsiz(await brifingler.DtoYapAsync(sonuc.Brifing!, ct))
                : new BrifingPaneli(null, sonuc.Durum == BrifingDurumu.HenuzHazirDegil ? sonuc.Mesaj : "Bugünün brifingi şu an hazırlanamadı.");
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The briefing panel of the home page failed.");
            Brifing = new BrifingPaneli(null, "Bugünün brifingi şu an hazırlanamadı.");
        }
    }

    // The "kalan" card (what yesterday left open) repeats the "Dünden kalanlar" section just below, so the strip leaves it out;
    // the card order numbers (votes) stay as they are. With no card left there is no strip at all.
    public static BrifingPaneli? KalanKartsiz(BrifingDto brifing)
    {
        var kartlar = brifing.Kartlar.Where(k => k.Tur != "kalan").ToList();
        return kartlar.Count == 0 ? null : new BrifingPaneli(brifing with { Kartlar = kartlar }, null);
    }

    // The same window as GET /api/hatirlaticilar?yaklasan=N: open ones due before the end of the Nth day (Istanbul).
    private async Task YaklasanlariYukleAsync(CancellationToken ct)
    {
        try
        {
            Simdi = saat.GetUtcNow();
            var sinir = HatirlaticiHesap.An(HatirlaticiHesap.IstanbulGunu(Simdi).AddDays(YaklasanGun + 1), TimeOnly.MinValue);
            var liste = await db.Hatirlaticilar
                .Where(h => h.Durum == HatirlaticiDurumu.Acik && (h.ErteleAn ?? h.SonrakiAn) < sinir)
                .OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id)
                .Take(EnCokYaklasan)
                .ToListAsync(ct);
            Yaklasanlar = liste.Select(h => HatirlaticiIslemleri.DtoYap(h, Simdi)).ToList();
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The coming reminders of the home page failed.");
        }
    }

    private async Task AliskanliklariYukleAsync(CancellationToken ct)
    {
        try
        {
            var liste = await db.Aliskanliklar.Where(a => !a.Arsivlendi).OrderBy(a => a.Sira).ThenBy(a => a.CreatedAt).ToListAsync(ct);
            var dtolar = await AliskanlikEndpoints.DtoYapAsync(db, liste, ct);
            var bugun = AliskanlikIslemleri.Bugun();
            for (var i = 0; i < liste.Count; i++)
            {
                if (!dtolar[i].Bugun.Planli)
                    continue;
                var gunler = await AliskanlikEndpoints.GunleriHesaplaAsync(db, liste[i], bugun.AddDays(-6), bugun, ct);
                BugunkuAliskanliklar.Add(new Aliskanliklar.IndexModel.Kart(dtolar[i], gunler));
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The habits of the home page failed.");
        }
    }

    // The sections the day already has, offered as suggestions in the add form.
    public IEnumerable<string> Bolumler => Gun?.Bolumler.Select(b => b.Ad) ?? [];

    // Forms are offered for a real date on an open day only.
    public bool Yazilabilir => Tarih is not null && Gun is { Kapandi: false };

    private string HedefTarih(string? tarih) =>
        string.IsNullOrWhiteSpace(tarih) ? Bugun.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : tarih;

    // Writes: not tied to the request, a closed tab must not leave one half done (like the API).

    // The page's one "Ekle": a line on the day's plan, or (hedef = "proje:<id>") a task in that project with an optional due day.
    public async Task<IActionResult> OnPostEkleAsync(string? tarih, string? metin, string? bolum, string? hedef, string? bitis)
    {
        if (hedef is not null && hedef.StartsWith("proje:", StringComparison.Ordinal))
            return Don(await BeyinYazma.GorevEkle(new(metin, hedef["proje:".Length..], null, string.IsNullOrWhiteSpace(bitis) ? null : bitis, null, null),
                Istemci, Gunluk, CancellationToken.None), "Görev eklendi");

        return Don(await BeyinYazma.MaddeEkle(HedefTarih(tarih), new(metin, bolum, null), Istemci, Gunluk, CancellationToken.None), "Plana eklendi");
    }

    public async Task<IActionResult> OnPostIsaretleAsync(string? tarih, string? madde, bool geri) =>
        Don(await BeyinYazma.MaddeIsaretle(HedefTarih(tarih), new(madde, geri), Istemci, Gunluk, CancellationToken.None),
            geri ? "Madde yeniden açıldı" : "Madde yapıldı");

    public async Task<IActionResult> OnPostDevretAsync(string? tarih, string? madde) =>
        Don(await BeyinYazma.MaddeDevret(HedefTarih(tarih), new(madde), Istemci, Gunluk, CancellationToken.None), "Ertesi güne devredildi");

    public async Task<IActionResult> OnPostNotAsync(string? tarih, string? madde, string? metin) =>
        Don(await BeyinYazma.MaddeNotu(HedefTarih(tarih), new(madde, metin), Istemci, Gunluk, CancellationToken.None), "Not eklendi");

    public async Task<IActionResult> OnPostGorevEkleAsync(string? baslik, string? proje, string? bitis) =>
        Don(await BeyinYazma.GorevEkle(new(baslik, proje, null, bitis, null, null), Istemci, Gunluk, CancellationToken.None), "Görev eklendi");

    public async Task<IActionResult> OnPostGorevBitirAsync(string? kimlik) =>
        Don(await BeyinYazma.GorevBitir(kimlik ?? "", Istemci, Gunluk, saat, CancellationToken.None), "Görev bitti");

    public async Task<IActionResult> OnPostBolAsync(string? kimlik, int gunSayisi, string? baslangic) =>
        Don(await BeyinYazma.GunlereBol(kimlik ?? "", new(gunSayisi, baslangic, null, null), Istemci, Gunluk, saat, CancellationToken.None),
            "Görev günlere bölündü");

    // A vote on a card of today's briefing: 1, -1, or 0 to take it back.
    public async Task<IActionResult> OnPostBrifingOyAsync(int sira, int oy, CancellationToken ct)
    {
        var sonuc = await brifingler.OyVerAsync(brifingler.Bugun, sira, oy, ct);
        if (!sonuc.Basarili)
            YazmaHatasi = sonuc.Mesaj;

        return RedirectToPage("/Index", null, null, "brifing");
    }

    // The Sahip asks for a new briefing (at most three times a day).
    public async Task<IActionResult> OnPostBrifingYenileAsync(CancellationToken ct)
    {
        var sonuc = await brifingler.YenileAsync(ct);
        if (sonuc.Basarili)
            Bildirim = "Brifing yenilendi";
        else
            YazmaHatasi = sonuc.Mesaj;

        return RedirectToPage("/Index", null, null, "brifing");
    }

    // Morning card: "Taşı" carries the item from yesterday to today in the brain; "Bırak" only closes the card entry.
    public async Task<IActionResult> OnPostSabahTasiAsync(string? madde) =>
        Don(await BeyinYazma.MaddeDevret($"{GunSiniri.Dun(saat.GetUtcNow()):yyyy-MM-dd}", new(madde), Istemci, Gunluk, CancellationToken.None),
            "Bugüne taşındı");

    public IActionResult OnPostSabahBirak(string? madde)
    {
        var dun = GunSiniri.Dun(saat.GetUtcNow());
        if (BeyinYazma.MaddeKimligiGecerli(madde))
        {
            var liste = Birakilanlar(dun).Append(madde!.Trim()).Distinct().TakeLast(EnCokBirakilan);
            Response.Cookies.Append(SabahCerezi, $"{dun:yyyy-MM-dd}|{string.Join(',', liste)}", new CookieOptions
            {
                HttpOnly = true,
                SameSite = SameSiteMode.Lax,
                Secure = Request.IsHttps,
                Expires = saat.GetUtcNow().AddDays(2),
            });
        }

        return RedirectToPage();
    }

    // "2026-11-06|a3f09c,b4e1d2": the day the let-go items belong to, then their ids. Another day's list is ignored.
    private HashSet<string> Birakilanlar(DateOnly dun)
    {
        var ham = Request.Cookies[SabahCerezi];
        var parca = ham?.Split('|', 2);
        if (parca is not { Length: 2 } || parca[0] != dun.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture))
            return [];
        return parca[1].Split(',', StringSplitOptions.RemoveEmptyEntries).Where(BeyinYazma.MaddeKimligiGecerli).ToHashSet();
    }
}

// A task row of the day page; GecikenGun is null when the task is not late (0 when it is late but the days are unknown).
public record GorevSatiri(string Kimlik, string Baslik, string? Proje, DateOnly? Bitis, int? GecikenGun);
