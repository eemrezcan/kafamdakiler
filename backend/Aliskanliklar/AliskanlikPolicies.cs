namespace Kafamdakiler.Aliskanliklar;

public static class AliskanlikPolicies
{
    // The `izin` claim values double as policy names (K-0009).
    public const string IzinClaim = "izin";
    public const string Oku = "aliskanlik.oku";
    public const string Yaz = "aliskanlik.yaz";

    // Files are read by <img> tags (cookie) and by the mobile app (bearer).
    // Habits and captures share the files, so either module's permission is enough.
    public const string DosyaOku = "dosya.oku";
    public const string DosyaYaz = "dosya.yaz";
}
