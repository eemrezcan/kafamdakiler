using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Gelen;

namespace Kafamdakiler.ProjeRepolari;

public enum RepoEslemeTuru
{
    Tamam,
    GecersizKimlik,
    GecersizDepo,
    // The brain has no such (visible) project.
    ProjeYok,
    // The brain could not be asked: `BeyinYaniti` says why.
    BeyinHatasi,
}

public record RepoEslemeSonucu(RepoEslemeTuru Tur, ProjeRepo? Satir = null, string? Mesaj = null, BeyinYaniti<HashSet<string>>? BeyinYaniti = null)
{
    public bool Basarili => Tur == RepoEslemeTuru.Tamam;
}

// The write rule of the project ↔ repository link. The endpoint and the web page both call it, so the rule lives in one place.
public static class ProjeRepoIslemleri
{
    public static bool KimlikGecerli(string kimlik) => kimlik.Length <= 100 && BeyinOkuma.KimlikKalibi().IsMatch(kimlik);

    // Sets or replaces the repository of a project. The project must exist in the brain (hidden ones do not count as existing).
    public static async Task<RepoEslemeSonucu> AyarlaAsync(
        AppDbContext db, BeyinIstemcisi beyin, TimeProvider saat, ILogger log, string kimlik, string? depo, CancellationToken ct)
    {
        if (!KimlikGecerli(kimlik))
            return new RepoEslemeSonucu(RepoEslemeTuru.GecersizKimlik, Mesaj: "Proje kimliği küçük harf, rakam ve tire olmalı.");

        depo = depo?.Trim();
        if (!DepoAdi.Gecerli(depo))
            return new RepoEslemeSonucu(RepoEslemeTuru.GecersizDepo, Mesaj: DepoAdi.Mesaj);

        var projeler = await GelenBeyin.ProjeleriAlAsync(beyin, log, ct);
        if (!projeler.Basarili)
            return new RepoEslemeSonucu(RepoEslemeTuru.BeyinHatasi, BeyinYaniti: projeler);
        if (!projeler.Veri!.Contains(kimlik))
            return new RepoEslemeSonucu(RepoEslemeTuru.ProjeYok, Mesaj: "Böyle bir proje yok.");

        var satir = await db.ProjeRepolari.FindAsync([kimlik], ct);
        if (satir is null)
            db.ProjeRepolari.Add(satir = new ProjeRepo { ProjeKimligi = kimlik });
        satir.Depo = depo!;
        satir.GuncellendiAt = saat.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return new RepoEslemeSonucu(RepoEslemeTuru.Tamam, satir);
    }
}
