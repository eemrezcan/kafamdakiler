using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Kafamdakiler.Pages.Beyin;

// What the Beyin pages share (the Sahip reads the second brain on the web). Every read goes through BeyinOkuma's typed
// reads: the same input checks, the same error table and the same hidden-record and closed-folder locks as /api/beyin,
// and never `--gizli-dahil`. A failure becomes a message on the page; with the brain off the pages say so and nothing throws.
public abstract class BeyinSayfasi(BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk) : PageModel
{
    protected BeyinIstemcisi Istemci => beyin;

    protected ILogger Gunluk => gunluk;

    // The brain is not set up on this machine (503).
    public bool BeyinKapali { get; private set; }

    public string? HataBasligi { get; private set; }

    public List<string> HataMesajlari { get; } = [];

    public bool Hatali => HataBasligi is not null;

    // The data of a successful read, or null after writing the reason into the page. A missing or hidden record keeps
    // its 404 and a bad input its 400; any other trouble of the brain is a message on a normal page.
    protected T? Al<T>(BeyinYaniti<T> yanit)
    {
        if (yanit.Basarili)
            return yanit.Veri;

        BeyinKapali = yanit.BagliDegil;
        if (yanit.Alanlar is not null)
        {
            HataBasligi = "Geçersiz istek";
            HataMesajlari.AddRange(yanit.Alanlar.Values.SelectMany(m => m));
        }
        else
        {
            HataBasligi = yanit.Baslik ?? "Beyin okunamadı";
            if (yanit.Ayrinti is not null)
                HataMesajlari.Add(yanit.Ayrinti);
        }

        if (yanit.Durum is StatusCodes.Status400BadRequest or StatusCodes.Status404NotFound)
            Response.StatusCode = yanit.Durum;

        return default;
    }
}
