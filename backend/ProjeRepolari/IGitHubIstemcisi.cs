namespace Kafamdakiler.ProjeRepolari;

// What the app needs from GitHub, read only, and nothing more. The network sits behind this one interface, so the tests run the
// whole module on a fake and never call GitHub. The real one is GitHubIstemcisi.

public record GitHubCommit(string Sha, string Mesaj, string? Yazar, DateTimeOffset? Tarih);

public record GitHubDepoOzeti(IReadOnlyList<GitHubCommit> Commitler, int AcikPrSayisi);

// 404: the repository does not exist, or the token cannot see it (GitHub answers the same for both).
public class GitHubDepoBulunamadiException(Exception? ic = null) : Exception("GitHub repository not found.", ic);

// 403/429 with the limit used up. `Sifirlanma` is when GitHub says the limit resets, if it said.
public class GitHubOranSiniriException(DateTimeOffset? sifirlanma, Exception? ic = null) : Exception("GitHub rate limit reached.", ic)
{
    public DateTimeOffset? Sifirlanma { get; } = sifirlanma;
}

// 401, or a 403 that is not the rate limit: the token is wrong, expired or lacks the right to read the repository.
public class GitHubYetkiException(Exception? ic = null) : Exception("GitHub refused the token.", ic);

public interface IGitHubIstemcisi
{
    // The last `commitSayisi` commits of the default branch and the number of open pull requests. `token` is never empty here.
    Task<GitHubDepoOzeti> OzetAlAsync(string depo, string token, int commitSayisi, CancellationToken ct);
}
