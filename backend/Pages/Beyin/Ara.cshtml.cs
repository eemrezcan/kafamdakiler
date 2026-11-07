using Kafamdakiler.Beyin;

namespace Kafamdakiler.Pages.Beyin;

// Search the brain (the mobile "Ara" tab). Nothing is asked of the brain until there is a query.
public class AraModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk) : BeyinSayfasi(beyin, gunluk)
{
    public string? Sorgu { get; private set; }

    // Null: no search yet. Empty: searched, nothing found.
    public List<AramaSonucuDto>? Sonuclar { get; private set; }

    public async Task OnGetAsync(string? q, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(q))
            return;

        Sorgu = q.Trim();
        Sonuclar = Al(await BeyinOkuma.AraAl(Sorgu, null, null, Istemci, Gunluk, ct));
    }
}
