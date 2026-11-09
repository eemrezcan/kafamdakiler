using Kafamdakiler.Beyin;
using Kafamdakiler.Isler;
using Kafamdakiler.Pages.Beyin;

namespace Kafamdakiler.Pages.Isler;

// The open work cards of the brain and the ones finished this week, read only (the Sahip). The phone is where they are answered and
// approved; the reads go through IsKartlari, so the hidden-card and closed-folder locks are the API's.
public class IndexModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, TimeProvider saat) : BeyinSayfasi(beyin, gunluk)
{
    public List<IsKartiDto> Acik { get; private set; } = [];

    public List<IsKartiDto> BuHaftaBiten { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        var kartlar = Al(await IsKartlari.ListeAl(null, null, kapali: true, Istemci, Gunluk, saat, ct)) ?? [];
        Acik = kartlar.Where(k => k.Acik).ToList();
        BuHaftaBiten = kartlar.Where(k => !k.Acik).ToList();
    }
}
