using System.Globalization;
using System.Text.RegularExpressions;

namespace Kafamdakiler.Bildirimler;

public enum KanitDuzeyi { Yok, Zayif, Guclu }

// What the search found. `Kanit` is the proof to write on the task (`commit:<hash>` / `onay:dogrulama-<date>`), null unless strong.
// `Neden` is one line for the log and the action's reason.
public record KanitSonucu(KanitDuzeyi Duzey, string? Kanit, string Neden)
{
    public static readonly KanitSonucu Yok = new(KanitDuzeyi.Yok, null, "Kanıt yok.");
}

public record GitKomiti(string Hash, string Mesaj);

public record GunlukKaydi(string? Baslik, string? Metin);

// Does the evidence say a task is done? Plain text matching on what is already on the server's side: the project's last handover
// card, its journal and the last commits of its clone. No Claude, no guessing from meaning: a wrong "done" closes work nobody
// finished, so the strong rules are narrow and the weak one only ever asks.
//   strong: a commit message names the task id; or a line of the last card names the task id and says it is done.
//   weak:   every significant word of the title shows up in the last card or in one journal entry.
public static partial class GorevKaniti
{
    // A short id ("test", "api") appears in ordinary sentences; below this length a mention counts as nothing strong.
    public const int EnKisaGucluKimlik = 10;

    // Words of a title that carry meaning: shorter ones ("ve", "bir", "yaz") are left out; at least this many must be left.
    public const int EnKisaSozcuk = 4;
    public const int EnAzSozcuk = 2;

    private static readonly CultureInfo Tr = new("tr-TR");

    [GeneratedRegex(@"\b(bitti|bitirildi|kapandı|kapatıldı|tamamlandı)\b", RegexOptions.CultureInvariant)]
    private static partial Regex BittiKalibi();

    [GeneratedRegex(@"[\p{L}\p{N}]+", RegexOptions.CultureInvariant)]
    private static partial Regex SozcukKalibi();

    // The card is written by sessions; its "next step" line names work still to do, so it never counts for the weak rule.
    [GeneratedRegex(@"^\s*sıradaki adım", RegexOptions.CultureInvariant)]
    private static partial Regex SiradakiKalibi();

    public static KanitSonucu Ara(
        string kimlik, string baslik, IReadOnlyList<GitKomiti> komitler, string? sonKart, IReadOnlyList<GunlukKaydi> gunluk, DateOnly bugun)
    {
        if (kimlik.Length >= EnKisaGucluKimlik)
        {
            var kimlikKalibi = KimlikKalibi(kimlik);
            if (komitler.FirstOrDefault(k => kimlikKalibi.IsMatch(k.Mesaj.ToLowerInvariant())) is { } komit)
                return new KanitSonucu(KanitDuzeyi.Guclu, $"commit:{komit.Hash.ToLowerInvariant()[..Math.Min(12, komit.Hash.Length)]}",
                    $"Bir commit görev kimliğini anıyor ({komit.Hash[..Math.Min(7, komit.Hash.Length)]}).");

            if (sonKart is not null && sonKart.Split('\n').Any(satir =>
                {
                    // A question ("bitti mi?") is not a statement. The id is ASCII (a file name), the done-word is Turkish: each is
                    // lower-cased by its own rules ("I" must not become "ı" inside an id).
                    return !satir.Contains('?') && kimlikKalibi.IsMatch(satir.ToLowerInvariant()) && BittiKalibi().IsMatch(satir.ToLower(Tr));
                }))
            {
                return new KanitSonucu(KanitDuzeyi.Guclu, $"onay:dogrulama-{bugun:yyyy-MM-dd}", "Son devir kartı görevin bittiğini söylüyor.");
            }
        }

        var sozcukler = AnlamliSozcukler(baslik);
        if (sozcukler.Count >= EnAzSozcuk)
        {
            var kartMetni = sonKart is null
                ? null
                : string.Join('\n', sonKart.Split('\n').Where(s => !SiradakiKalibi().IsMatch(s.ToLower(Tr))));
            if (kartMetni is not null && HepsiGeciyor(sozcukler, kartMetni))
                return new KanitSonucu(KanitDuzeyi.Zayif, null, "Başlığın sözcükleri son devir kartında geçiyor.");

            if (gunluk.Any(g => HepsiGeciyor(sozcukler, $"{g.Baslik} {g.Metin}")))
                return new KanitSonucu(KanitDuzeyi.Zayif, null, "Başlığın sözcükleri iş günlüğünde geçiyor.");
        }

        return KanitSonucu.Yok;
    }

    // The task id as a whole word: "a-b" is not found inside "a-b-c" or "xa-b".
    private static Regex KimlikKalibi(string kimlik) =>
        new($@"(?<![\p{{L}}\p{{N}}-]){Regex.Escape(kimlik.ToLowerInvariant())}(?![\p{{L}}\p{{N}}-])", RegexOptions.CultureInvariant);

    private static List<string> AnlamliSozcukler(string baslik) =>
        SozcukKalibi().Matches(baslik.ToLower(Tr)).Select(m => m.Value).Where(s => s.Length >= EnKisaSozcuk).Distinct().ToList();

    // Turkish adds endings to words ("düzeltmeleri", "düzeltme"), so a word counts when the text has a word that starts with
    // its first six letters.
    private static bool HepsiGeciyor(List<string> sozcukler, string metin)
    {
        var kelimeler = SozcukKalibi().Matches(metin.ToLower(Tr)).Select(m => m.Value).ToList();
        return sozcukler.All(s =>
        {
            var kok = s[..Math.Min(6, s.Length)];
            return kelimeler.Any(k => k.StartsWith(kok, StringComparison.Ordinal));
        });
    }

    // The newest card of a project's `oturumlar.md`: blocks start with `## YYYY-MM-DD HH:mm · ...`. Null when there is none.
    public static string? SonKart(string? govde)
    {
        if (string.IsNullOrWhiteSpace(govde))
            return null;

        string? enYeni = null;
        string? enYeniAn = null;
        foreach (var blok in KartBasligi().Split(govde).Skip(1).Chunk(2))
        {
            // Split with a capture group gives: text, heading-time, text, heading-time... so a chunk is (time, body).
            if (blok.Length < 2)
                continue;

            if (enYeniAn is null || string.CompareOrdinal(blok[0], enYeniAn) > 0)
            {
                enYeniAn = blok[0];
                enYeni = blok[1];
            }
        }

        return enYeni;
    }

    [GeneratedRegex(@"^##\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2})[^\n]*$", RegexOptions.Multiline | RegexOptions.CultureInvariant)]
    private static partial Regex KartBasligi();
}
