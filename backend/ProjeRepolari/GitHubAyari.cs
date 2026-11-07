namespace Kafamdakiler.ProjeRepolari;

// The "GitHub" settings (K2.5). With no `GitHub:Token` the module only shows the repository link: the commits and the pull request
// count say there is no token. The token (read only) lives in the server's .env, never in the repo, and is never logged.
public class GitHubAyari
{
    public const int SonCommitSayisi = 5;

    // A result is kept this long (the rate limit of GitHub: 60 an hour without a token, 5000 with one).
    public TimeSpan Onbellek { get; init; } = TimeSpan.FromMinutes(5);

    // A "not found" or a "rate limit" answer is kept shorter, so a broken link is not asked again on every screen open.
    public TimeSpan HataOnbellegi { get; init; } = TimeSpan.FromMinutes(1);

    public string Token { get; init; } = "";

    public bool TokenVar => Token.Length > 0;

    public static GitHubAyari Oku(IConfiguration config)
    {
        var bolum = config.GetSection("GitHub");
        var dakika = Math.Clamp(bolum.GetValue("OnbellekDakika", 5.0), 0.0, 1440.0);
        return new GitHubAyari
        {
            Token = bolum["Token"]?.Trim() ?? "",
            Onbellek = TimeSpan.FromMinutes(dakika),
            HataOnbellegi = TimeSpan.FromMinutes(Math.Min(dakika, 1.0)),
        };
    }
}
