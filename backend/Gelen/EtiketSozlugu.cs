using System.Text;
using System.Text.RegularExpressions;

namespace Kafamdakiler.Gelen;

// The tag dictionary of the brain (etiketler.md): lines like `- ana: es1, es2` under `## alan` headings. The brain accepts
// a main name or a synonym as a tag and refuses anything else, whatever the area; a suggestion of Claude uses main names only.
public sealed partial class EtiketSozlugu
{
    private readonly HashSet<string> _gecerli;

    private EtiketSozlugu(List<string> anaAdlar, Dictionary<string, List<string>> esler, HashSet<string> gecerli)
    {
        AnaAdlar = anaAdlar;
        Esler = esler;
        _gecerli = gecerli;
    }

    public IReadOnlyList<string> AnaAdlar { get; }

    // The synonyms of each main name, in the order written. A synonym that is a main name itself is not listed.
    public IReadOnlyDictionary<string, List<string>> Esler { get; }

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
        var esler = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        var gecerli = new HashSet<string>(StringComparer.Ordinal);
        foreach (var satir in govde.Split('\n'))
        {
            if (Satir().Match(satir) is not { Success: true } m)
                continue;

            var ad = Temizle(m.Groups[1].Value);
            if (ad.Length == 0 || !gecerli.Add(ad))
                continue;

            ana.Add(ad);
            var bunlar = esler[ad] = [];
            foreach (var es in m.Groups[2].Value.Split(','))
            {
                if (Temizle(es) is { Length: > 0 } temiz && temiz != ad && !bunlar.Contains(temiz))
                {
                    gecerli.Add(temiz);
                    bunlar.Add(temiz);
                }
            }
        }

        // A synonym that is also a main name (written further down) is not a synonym.
        foreach (var liste in esler.Values)
            liste.RemoveAll(e => ana.Contains(e));

        return new EtiketSozlugu(ana, esler, gecerli);
    }

    private static string Temizle(string? etiket) => (etiket ?? "").Normalize(NormalizationForm.FormC).Trim().TrimStart('#').ToLowerInvariant();

    [GeneratedRegex(@"^\s*[-*]\s+([^\s:]+)\s*:\s*(.*)$", RegexOptions.CultureInvariant)]
    private static partial Regex Satir();
}
