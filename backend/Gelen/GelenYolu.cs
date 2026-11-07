using Kafamdakiler.Beyin;

namespace Kafamdakiler.Gelen;

// Where an inbox card may be placed. The same check holds for a suggestion of Claude, a corrected one and a path a person
// typed: nothing arrives in the brain by a path this refuses. The brain itself only checks that the folder exists, it would
// happily write into finans/.
public static class GelenYolu
{
    // Top folders a card may go to besides projects/<project>/notlar/. finans/ and kisisel/ stay closed: the API puts
    // nothing there, as for tasks (BeyinYazma) and reads (NotYolu).
    private static readonly string[] AcikKokler = ["ogrenme", "spor", "aliskanliklar"];

    public const string KokMesaji = "Yol projects/<proje>/notlar/<ad>.md, ogrenme/, spor/ ya da aliskanliklar/ altında olmalı.";

    // Null when the path is fine, else the reason. `gorunurProjeler` are the ids of the projects that exist and are not
    // hidden; with null only the shape of a project path is checked (the check that needs the brain comes later).
    public static string? Denetle(string? yol, IReadOnlySet<string>? gorunurProjeler)
    {
        // Relative, ends in .md, no "..", no dot-folders (.beyin), not finans/ or kisisel/.
        if (!NotYolu.Gecerli(yol))
            return "Yol vault'a göreli, .md ile biten ve izinli bir not yolu olmalı.";

        var parcalar = yol!.Split('/');
        if (parcalar[0] == "projects")
        {
            if (parcalar.Length != 4 || parcalar[2] != "notlar" || !BeyinOkuma.KimlikKalibi().IsMatch(parcalar[1]))
                return KokMesaji;
            if (gorunurProjeler is not null && !gorunurProjeler.Contains(parcalar[1]))
                return "Böyle bir proje yok.";
            return null;
        }

        return AcikKokler.Contains(parcalar[0], StringComparer.Ordinal) && parcalar.Length >= 2 ? null : KokMesaji;
    }
}
