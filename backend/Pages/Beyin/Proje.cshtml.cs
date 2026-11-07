using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Mvc;

namespace Kafamdakiler.Pages.Beyin;

// One project: status, next step, open tasks, last journal lines, and adding or finishing a task (K2.3a).
public class ProjeModel(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, TimeProvider saat) : BeyinSayfasi(beyin, gunluk)
{
    public ProjeDto? Proje { get; private set; }

    public async Task OnGetAsync(string kimlik, CancellationToken ct) =>
        Proje = Al(await BeyinOkuma.ProjeAl(kimlik, Istemci, Gunluk, ct));

    // The task is added to the project in the address, never to one named in the form.
    public async Task<IActionResult> OnPostGorevEkleAsync(string kimlik, string? baslik, string? bitis) =>
        Don(await BeyinYazma.GorevEkle(new(baslik, kimlik, null, bitis, null, null), Istemci, Gunluk, CancellationToken.None), "Görev eklendi");

    public async Task<IActionResult> OnPostGorevBitirAsync(string? gorev) =>
        Don(await BeyinYazma.GorevBitir(gorev ?? "", Istemci, Gunluk, saat, CancellationToken.None), "Görev bitti");
}
