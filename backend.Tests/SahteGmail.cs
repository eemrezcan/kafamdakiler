using Kafamdakiler.Gmail;
using Kafamdakiler.Takvim;

namespace Kafamdakiler.Tests;

// A fake Gmail: the same contract as the real client (IGmailIstemcisi), kept in memory. It does not read the search query (the real Gmail
// does); a test that cares about the query looks at `Sorgular`. No call in the tests goes to Google.
public sealed class SahteGmail : IGmailIstemcisi
{
    private readonly Lock _kilit = new();
    private readonly List<GmailPosta> _postalar = [];

    // What was asked of Gmail, in order.
    public List<string> Sorgular { get; } = [];
    public List<string> Getirilenler { get; } = [];
    public List<string> KullanilanErisimTokenleri { get; } = [];

    // How the fake fails.
    public bool ListeYetkiHatasi { get; set; }
    public HashSet<string> OkunamayanlarKimlik { get; } = [];

    // A mail to the inbox; the newest is added last and listed first, like Gmail does.
    public GmailPosta Ekle(
        string kimlik, string konu = "Konu", string govde = "Gövde", string gonderenAdres = "hoca@okul.edu.tr", string? gonderenAd = "Hoca",
        DateTimeOffset? tarih = null, params string[] etiketler)
    {
        var posta = new GmailPosta(kimlik, konu, gonderenAd, gonderenAdres, tarih ?? new DateTimeOffset(2026, 11, 6, 14, 30, 0, TimeSpan.FromHours(3)), govde, etiketler.Length > 0 ? etiketler : ["INBOX"]);
        lock (_kilit)
        {
            _postalar.Add(posta);
        }

        return posta;
    }

    public Task<IReadOnlyList<string>> KimlikleriListeleAsync(string sorgu, int enCok, string erisimToken, CancellationToken ct)
    {
        lock (_kilit)
        {
            Sorgular.Add(sorgu);
            KullanilanErisimTokenleri.Add(erisimToken);
            if (ListeYetkiHatasi)
                throw new GoogleYetkiGecersizException("fake: 401");

            return Task.FromResult<IReadOnlyList<string>>(_postalar.AsEnumerable().Reverse().Take(enCok).Select(p => p.Kimlik).ToList());
        }
    }

    public Task<GmailPosta?> PostaGetirAsync(string kimlik, string erisimToken, CancellationToken ct)
    {
        lock (_kilit)
        {
            Getirilenler.Add(kimlik);
            if (OkunamayanlarKimlik.Contains(kimlik))
                throw new HttpRequestException("fake: network error");

            return Task.FromResult(_postalar.FirstOrDefault(p => p.Kimlik == kimlik));
        }
    }
}
