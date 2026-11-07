using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Html;

namespace Kafamdakiler.Pages.Beyin;

// A note from the brain, its Markdown shown as closed HTML (NotGovdesi): raw HTML or script in a note is text on this page.
public class NotModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk) : BeyinSayfasi(beyin, gunluk)
{
    public NotDto? Not { get; private set; }

    public IHtmlContent Govde { get; private set; } = HtmlString.Empty;

    public async Task OnGetAsync(string? yol, CancellationToken ct)
    {
        Not = Al(await BeyinOkuma.NotAl(yol, Istemci, Gunluk, ct));
        if (Not is not null)
            Govde = NotGovdesi.Html(Not.Govde);
    }
}
