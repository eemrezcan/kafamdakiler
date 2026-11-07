using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Eylemler;

internal static class EylemDogrulama
{
    // A refusal of the brain write checks (a 400 naming one field) as the Sonuc a kind returns. Null when there was no refusal.
    public static Sonuc? Sonuca(YazmaYaniti? red)
    {
        if (red is null)
            return null;

        if (red.Alanlar is { Count: > 0 } alanlar)
        {
            var (alan, mesajlar) = alanlar.First();
            return Sonuc.Gecersiz(alan, mesajlar.FirstOrDefault() ?? "Geçersiz değer.");
        }

        return Sonuc.Gecersiz("yuk", red.Ayrinti ?? "Geçersiz değer.");
    }
}
