namespace Kafamdakiler.Beyin;

// Development only: the app works on a Git-ignored copy of ornek-beyin/, never on the template itself (K-0023 eki).
public static class OrnekBeyinKopyasi
{
    // Copies the template when the vault folder does not exist yet. Returns true when it copied.
    public static bool HazirlaGerekirse(BeyinAyari ayar)
    {
        if (!ayar.Acik || string.IsNullOrWhiteSpace(ayar.Sablon) || Directory.Exists(ayar.Vault))
            return false;

        var sablon = Path.TrimEndingDirectorySeparator(ayar.Sablon);
        var vault = Path.TrimEndingDirectorySeparator(ayar.Vault);
        // The two folders must be apart: a vault inside the template (or the template itself) would write into it.
        if (!Directory.Exists(sablon) || vault == sablon || vault.StartsWith(sablon + Path.DirectorySeparatorChar))
            return false;

        Kopyala(sablon, vault);
        return true;
    }

    private static void Kopyala(string kaynak, string hedef)
    {
        Directory.CreateDirectory(hedef);
        foreach (var dosya in Directory.EnumerateFiles(kaynak))
            File.Copy(dosya, Path.Combine(hedef, Path.GetFileName(dosya)));
        foreach (var klasor in Directory.EnumerateDirectories(kaynak))
        {
            if (Path.GetFileName(klasor) == ".git")
                continue;
            Kopyala(klasor, Path.Combine(hedef, Path.GetFileName(klasor)));
        }
    }
}
