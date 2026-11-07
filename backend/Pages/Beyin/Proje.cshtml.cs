using Kafamdakiler.Beyin;

namespace Kafamdakiler.Pages.Beyin;

// One project: status, next step, open tasks, last journal lines.
public class ProjeModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk) : BeyinSayfasi(beyin, gunluk)
{
    public ProjeDto? Proje { get; private set; }

    public async Task OnGetAsync(string kimlik, CancellationToken ct) =>
        Proje = Al(await BeyinOkuma.ProjeAl(kimlik, Istemci, Gunluk, ct));
}
