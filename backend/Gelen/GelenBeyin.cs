using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Gelen;

// The reads of the inbox side from the brain, through BeyinIstemcisi like every other module. A failure comes back as
// a BeyinYaniti, so the endpoints and the background round turn it into a status the same way the brain reads do.
public static partial class GelenBeyin
{
    // The card name as the routes take it: a file name without ".md". No slash, no dot, no leading dash.
    public const int EnUzunKimlik = 150;

    [GeneratedRegex(@"^[\p{L}\p{N}][\p{L}\p{N}_-]*\z", RegexOptions.CultureInvariant)]
    private static partial Regex KimlikKalibi();

    public static bool KartKimligiGecerli(string? kimlik) =>
        kimlik is { Length: > 0 and <= EnUzunKimlik } && KimlikKalibi().IsMatch(kimlik);

    public static string KartYolu(string kimlik) => $"gelen/{kimlik}.md";

    // `gelen liste` without `--gizli-dahil`: the brain leaves hidden cards out, and this never asks for them.
    public static async Task<BeyinYaniti<List<BeyinKarti>>> KartlariAlAsync(BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var sonuc = await beyin.CalistirAsync(["gelen", "liste"], ct);
        if (!sonuc.Basarili)
            return BeyinOkuma.Hata<List<BeyinKarti>>(sonuc, log);

        try
        {
            var kartlar = BeyinOkuma.Dizi(sonuc.Veri!.Value).Where(BeyinOkuma.Gorunur).Select(Kart).OfType<BeyinKarti>().ToList();
            return new BeyinYaniti<List<BeyinKarti>>(StatusCodes.Status200OK, kartlar);
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException)
        {
            return BeyinOkuma.Hata<List<BeyinKarti>>(new BeyinSonucu(BeyinDurumu.BozukCikti, Mesaj: "Beklenmeyen biçim: " + e.Message), log);
        }
    }

    // A card with a name the routes cannot carry is left out: it is placed on the laptop.
    private static BeyinKarti? Kart(JsonElement e)
    {
        var yol = BeyinOkuma.Gerekli(e, "yol");
        if (!yol.StartsWith("gelen/", StringComparison.Ordinal) || !yol.EndsWith(".md", StringComparison.Ordinal))
            return null;

        var kimlik = yol["gelen/".Length..^".md".Length];
        if (!KartKimligiGecerli(kimlik))
            return null;

        return new BeyinKarti(kimlik, BeyinOkuma.Metin(e, "baslik") ?? kimlik, BeyinOkuma.Metin(e, "yakalandi"), BeyinOkuma.Metin(e, "hedef"),
            BeyinOkuma.Metin(e, "gorsel") is { Length: > 0 });
    }

    // The ids of the projects that exist and are not hidden (BeyinOkuma.ProjelerAl leaves hidden ones out).
    public static async Task<BeyinYaniti<HashSet<string>>> ProjeleriAlAsync(BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var yanit = await BeyinOkuma.ProjelerAl(beyin, log, ct);
        return yanit.Basarili
            ? new BeyinYaniti<HashSet<string>>(StatusCodes.Status200OK, yanit.Veri!.Select(p => p.Kimlik).ToHashSet(StringComparer.Ordinal))
            : new BeyinYaniti<HashSet<string>>(yanit.Durum, Baslik: yanit.Baslik, Ayrinti: yanit.Ayrinti, Alanlar: yanit.Alanlar);
    }

    public static async Task<BeyinYaniti<EtiketSozlugu>> SozluguAlAsync(BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var yanit = await BeyinOkuma.NotAl("etiketler.md", beyin, log, ct);
        return yanit.Basarili
            ? new BeyinYaniti<EtiketSozlugu>(StatusCodes.Status200OK, EtiketSozlugu.Oku(yanit.Veri!.Govde))
            : new BeyinYaniti<EtiketSozlugu>(yanit.Durum, Baslik: yanit.Baslik, Ayrinti: yanit.Ayrinti, Alanlar: yanit.Alanlar);
    }

    // The body of a card. `not oku` refuses a hidden card (404), which is the third lock before a card goes to Claude.
    public static Task<BeyinYaniti<NotDto>> KartMetniAlAsync(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct) =>
        BeyinOkuma.NotAl(KartYolu(kimlik), beyin, log, ct);
}
