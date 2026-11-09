using Kafamdakiler.Beyin;
using Kafamdakiler.Isler;
using Kafamdakiler.Pages.Beyin;

namespace Kafamdakiler.Pages.Isler;

// One work card, read only: the request, the plan, the questions with their answers, the history.
public class DetayModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk) : BeyinSayfasi(beyin, gunluk)
{
    public IsAyrintiDto? Kart { get; private set; }

    public async Task OnGetAsync(string kimlik, CancellationToken ct) =>
        Kart = Al(await IsKartlari.Al(kimlik, Istemci, Gunluk, ct));
}
