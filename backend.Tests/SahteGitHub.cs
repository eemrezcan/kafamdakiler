using Kafamdakiler.ProjeRepolari;

namespace Kafamdakiler.Tests;

// A fake GitHub: the same contract as the real client (IGitHubIstemcisi). It answers what the test sets and counts the calls.
// No call in the tests goes to GitHub; this is the only thing that answers.
public sealed class SahteGitHub : IGitHubIstemcisi
{
    private int _cagri;

    public int CagriSayisi => _cagri;

    public List<(string Depo, string Token, int CommitSayisi)> Istekler { get; } = [];

    // Set to make the next calls fail the way GitHub would (a 404, the rate limit, a refused token, a network error).
    public Exception? Hata { get; set; }

    public GitHubDepoOzeti Ozet { get; set; } = new(
    [
        new GitHubCommit("0123456789abcdef0123456789abcdef01234567", "feat: add the repo card\n\nA long body that the card does not show.", "Ayşe", new DateTimeOffset(2026, 11, 7, 12, 0, 0, TimeSpan.Zero)),
        new GitHubCommit("abcdef0123456789abcdef0123456789abcdef01", "fix: a typo", null, null),
    ], 3);

    public Task<GitHubDepoOzeti> OzetAlAsync(string depo, string token, int commitSayisi, CancellationToken ct)
    {
        Interlocked.Increment(ref _cagri);
        lock (Istekler)
            Istekler.Add((depo, token, commitSayisi));
        return Hata is { } hata ? Task.FromException<GitHubDepoOzeti>(hata) : Task.FromResult(Ozet);
    }
}
