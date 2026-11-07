using System.Globalization;
using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Mvc;

namespace Kafamdakiler.Pages.Beyin;

// The brain's plan for a day (the mobile day-plan card), and the writes on it (K2.3a): add, tick, carry over, note,
// add and finish a task, split a task over days. No date means today by the brain's own day-turn rule (05:00).
// Every write goes through BeyinYazma, the same code and checks as /api/beyin (no Idempotency-Key: a form is not
// resent by a queue), and each one names the date explicitly.
public class GunModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, GunAyari ayar, TimeProvider saat) : BeyinSayfasi(beyin, gunluk)
{
    // The morning card remembers what was let go in this browser only: letting go writes nothing to the brain.
    private const string SabahCerezi = "kd-sabah";
    private const int EnCokBirakilan = 40;

    public BeyinGunDto? Gun { get; private set; }

    // The day asked for, as written (yyyy-MM-dd) when it is a real date, else null.
    public DateOnly? Tarih { get; private set; }

    // Today by the day-turn rule, not by the calendar: at 02:00 it is still yesterday's plan.
    public DateOnly Bugun { get; } = GunSiniri.Bugun(saat.GetUtcNow());

    // What yesterday left open, on today's page only.
    public SabahKartiDto? Sabah { get; private set; }

    // The pick lists of the forms. Empty when the brain would not answer: the forms are then left out.
    public List<ProjeOzetDto> Projeler { get; private set; } = [];

    public List<AcikGorevDto> Gorevler { get; private set; } = [];

    public async Task OnGetAsync(string? tarih, CancellationToken ct)
    {
        var istenen = string.IsNullOrWhiteSpace(tarih) ? Bugun.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : tarih;
        if (DateOnly.TryParseExact(istenen, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun))
            Tarih = gun;

        Gun = Al(await BeyinOkuma.GunAl(istenen, Istemci, Gunluk, ct, ayar));
        if (Gun is null)
            return;

        // The extras never turn a good page into an error page: if one fails, its part is simply not shown.
        Projeler = (await BeyinOkuma.ProjelerAl(Istemci, Gunluk, ct)).Veri ?? [];
        Gorevler = (await BeyinOkuma.AcikGorevlerAl(Istemci, Gunluk, ct)).Veri ?? [];

        if (Tarih == Bugun && (await BeyinOkuma.SabahAl(Istemci, Gunluk, saat, ct)).Veri is { } kart)
        {
            var birakilan = Birakilanlar(kart.Dun);
            Sabah = kart with { Maddeler = kart.Maddeler.Where(m => !birakilan.Contains(m.Id)).ToList() };
        }
    }

    // The sections the day already has, offered as suggestions in the add form.
    public IEnumerable<string> Bolumler => Gun?.Bolumler.Select(b => b.Ad) ?? [];

    // Forms are offered for a real date on an open day only.
    public bool Yazilabilir => Tarih is not null && Gun is { Kapandi: false };

    private string HedefTarih(string? tarih) =>
        string.IsNullOrWhiteSpace(tarih) ? Bugun.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : tarih;

    // Writes: not tied to the request, a closed tab must not leave one half done (like the API).

    public async Task<IActionResult> OnPostEkleAsync(string? tarih, string? metin, string? bolum) =>
        Don(await BeyinYazma.MaddeEkle(HedefTarih(tarih), new(metin, bolum, null), Istemci, Gunluk, CancellationToken.None), "Madde eklendi");

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
