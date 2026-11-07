namespace Kafamdakiler.Ses;

public static class SesPolicies
{
    // The `izin` claim value doubles as the policy name (K-0009): extracting work from text and rewriting text call Claude.
    public const string AsistanKullan = "asistan.kullan";

    // Applying the chosen suggestions. Not a permission of its own (it is not in Izinler): a person who holds none of the three
    // write permissions has nothing to apply. Each suggestion is then checked against the permission of its own kind.
    public const string Uygula = "is-cikar.uygula";
}
