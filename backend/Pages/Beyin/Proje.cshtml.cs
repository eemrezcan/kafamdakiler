using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.ProjeRepolari;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Beyin;

// One project: status, next step, open tasks, last journal lines, and adding or finishing a task (K2.3a), and the repository card (K2.5).
public class ProjeModel(
    BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, TimeProvider saat, AppDbContext db, RepoOzetServisi repolar, HatirlaticiAyari hatirlaticiAyari)
    : BeyinSayfasi(beyin, gunluk)
{
    public ProjeDto? Proje { get; private set; }

    // The repository linked to the project, null when none is (the card is then left out).
    public ProjeRepoOzetiDto? Repo { get; private set; }

    public async Task OnGetAsync(string kimlik, CancellationToken ct)
    {
        Proje = Al(await BeyinOkuma.ProjeAl(kimlik, Istemci, Gunluk, ct));
        if (Proje is null)
            return;

        // The card never turns a good page into an error page: GitHub trouble is a status inside the summary.
        var satir = await db.ProjeRepolari.AsNoTracking().FirstOrDefaultAsync(r => r.ProjeKimligi == Proje.Kimlik, ct);
        if (satir is not null)
            Repo = await repolar.OzetAsync(Proje.Kimlik, satir.Depo, ct);
    }

    // The task is added to the project in the address, never to one named in the form.
    public async Task<IActionResult> OnPostGorevEkleAsync(string kimlik, string? baslik, string? bitis) =>
        Don(await BeyinYazma.GorevEkle(new(baslik, kimlik, null, bitis, null, null), Istemci, Gunluk, CancellationToken.None), "Görev eklendi");

    // Finishing a task closes the reminder tied to it too (HatirlaticiZinciri, the chain of K-0024); a step of it that fails is said, the task stays finished.
    public async Task<IActionResult> OnPostGorevBitirAsync(string? gorev)
    {
        var yanit = await BeyinYazma.GorevBitir(gorev ?? "", Istemci, Gunluk, saat, CancellationToken.None);
        var sonuc = Don(yanit, "Görev bitti");
        if (yanit.Basarili)
        {
            var zincir = await HatirlaticiZinciri.GorevBitirildiAsync(db, gorev!, hatirlaticiAyari.VarsayilanSaat, saat.GetUtcNow(), Gunluk, CancellationToken.None);
            if (zincir.Hata is { } hata)
                YazmaHatasi = hata;
            else if (zincir.Kimlikler.Count > 0)
                Bildirim = "Görev bitti; bağlı hatırlatıcı da kapandı";
        }

        return sonuc;
    }
}
