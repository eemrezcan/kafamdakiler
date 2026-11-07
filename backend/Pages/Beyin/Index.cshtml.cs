using Kafamdakiler.Beyin;

namespace Kafamdakiler.Pages.Beyin;

// The projects of the brain (the mobile "Projeler" tab).
public class IndexModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk) : BeyinSayfasi(beyin, gunluk)
{
    public List<ProjeOzetDto> Projeler { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct) =>
        Projeler = Al(await BeyinOkuma.ProjelerAl(Istemci, Gunluk, ct)) ?? [];
}
