using System.Text;
using System.Text.RegularExpressions;

namespace Kafamdakiler.Gelen;

// The tag dictionary of the brain (etiketler.md): lines like `- ana: es1, es2` under `## alan` headings. The brain accepts
// a main name or a synonym as a tag and refuses anything else, whatever the area; a suggestion of Claude uses main names only.
public sealed partial class EtiketSozlugu
{
    private readonly HashSet<string> _gecerli;

    private EtiketSozlugu(List<string> anaAdlar, HashSet<string> gecerli)
    {
        AnaAdlar = anaAdlar;
        _gecerli = gecerli;
    }

    public IReadOnlyList<string> AnaAdlar { get; }

    public bool Bos => AnaAdlar.Count == 0;

    // The tag as the brain would store it, or null when the dictionary does not know it.
    public string? Coz(string? etiket)
    {
        var temiz = Temizle(etiket);
        return temiz.Length > 0 && _gecerli.Contains(temiz) ? temiz : null;
    }

    public bool AnaAdMi(string? etiket) => Temizle(etiket) is { Length: > 0 } temiz && AnaAdlar.Contains(temiz, StringComparer.Ordinal);

    public static EtiketSozlugu Oku(string govde)
    {
        var ana = new List<string>();
        var gecerli = new HashSet<string>(StringComparer.Ordinal);
        foreach (var satir in govde.Split('\n'))
        {
            if (Satir().Match(satir) is not { Success: true } m)
                continue;

            var ad = Temizle(m.Groups[1].Value);
            if (ad.Length == 0 || !gecerli.Add(ad))
                continue;

            ana.Add(ad);
            foreach (var es in m.Groups[2].Value.Split(','))
            {
                if (Temizle(es) is { Length: > 0 } temiz)
                    gecerli.Add(temiz);
            }
        }

        return new EtiketSozlugu(ana, gecerli);
    }

    private static string Temizle(string? etiket) => (etiket ?? "").Normalize(NormalizationForm.FormC).Trim().TrimStart('#').ToLowerInvariant();

    [GeneratedRegex(@"^\s*[-*]\s+([^\s:]+)\s*:\s*(.*)$", RegexOptions.CultureInvariant)]
    private static partial Regex Satir();
}
