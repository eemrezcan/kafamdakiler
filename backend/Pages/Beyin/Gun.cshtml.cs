using System.Globalization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Pages.Beyin;

// The brain's plan for a day (the mobile day-plan card). No date means today (the habit day, like the rest of the app).
public class GunModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk) : BeyinSayfasi(beyin, gunluk)
{
    public BeyinGunDto? Gun { get; private set; }

    // The day asked for, as written (yyyy-MM-dd) when it is a real date, else null.
    public DateOnly? Tarih { get; private set; }

    public DateOnly Bugun { get; } = AliskanlikIslemleri.Bugun();

    public async Task OnGetAsync(string? tarih, CancellationToken ct)
    {
        var istenen = string.IsNullOrWhiteSpace(tarih) ? Bugun.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : tarih;
        if (DateOnly.TryParseExact(istenen, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun))
            Tarih = gun;

        Gun = Al(await BeyinOkuma.GunAl(istenen, Istemci, Gunluk, ct));
    }
}
