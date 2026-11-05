using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Microsoft.Extensions.Configuration;

namespace Kafamdakiler.Tests;

// Test settings that are not in the repository: the app's own user-secrets, or KAFAMDAKILER_* environment variables.
public static class TestAyari
{
    // Settings for the real beyin.py and a vault folder that does not exist yet (OrnekBeyinKopyasi fills it from
    // ornek-beyin/). The command path is Beyin:Komut in user-secrets or KAFAMDAKILER_BEYIN_KOMUT.
    // Skips the test when beyin.py is not on this machine; the template folder itself is never used as the vault.
    public static BeyinAyari GercekBeyin(string vault)
    {
        var ayar = new ConfigurationBuilder()
            .AddUserSecrets(typeof(AppDbContext).Assembly)
            .AddEnvironmentVariables("KAFAMDAKILER_")
            .Build();
        var komut = ayar["BEYIN_KOMUT"] ?? ayar["Beyin:Komut"];
        Assert.SkipUnless(!string.IsNullOrWhiteSpace(komut) && File.Exists(komut), "beyin.py is not on this machine (Beyin:Komut).");

        var kok = AppContext.BaseDirectory;
        while (kok is not null && !Directory.Exists(Path.Combine(kok, "ornek-beyin")))
            kok = Path.GetDirectoryName(kok);
        Assert.SkipWhen(kok is null, "ornek-beyin/ not found.");

        return new BeyinAyari { Komut = komut!, Vault = vault, Sablon = Path.Combine(kok!, "ornek-beyin") };
    }
}
