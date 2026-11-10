namespace Kafamdakiler.OpenApi;

public static class HataAnahtarlari
{
    // A revision of a work card (back to "plan") needs a short note on what should change. The key of the 400's `errors` entry, in the brain's own word.
    public const string NotGerekli = "not-gerekli";

    public const string NotGerekliMetni = "Revizyon için kısa bir not yaz.";

    // Validation errors are keyed by the C# property name ("BitisKonum"); the API speaks camelCase JSON ("bitisKonum").
    public static void CamelCaseYap(HttpValidationProblemDetails sorun)
    {
        var yeni = sorun.Errors.ToDictionary(e => CamelCase(e.Key), e => e.Value);
        sorun.Errors.Clear();
        foreach (var (anahtar, mesajlar) in yeni)
            sorun.Errors[anahtar] = mesajlar;
    }

    // "Gunler[0].Ad" -> "gunler[0].ad"
    private static string CamelCase(string anahtar) =>
        string.Join('.', anahtar.Split('.').Select(parca => parca.Length == 0 ? parca : char.ToLowerInvariant(parca[0]) + parca[1..]));
}
