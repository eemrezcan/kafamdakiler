using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Kafamdakiler.ProjeRepolari;

// The real thing: GitHub's REST API over a plain HttpClient (two GET calls; a package would add nothing). The tests never reach this
// class; they run on a fake IGitHubIstemcisi. The repository name was checked by DepoAdi before it got here.
public class GitHubIstemcisi(HttpClient http) : IGitHubIstemcisi
{
    public const string TabanAdres = "https://api.github.com/";

    public async Task<GitHubDepoOzeti> OzetAlAsync(string depo, string token, int commitSayisi, CancellationToken ct)
    {
        using var commitler = await GetAsync($"repos/{depo}/commits?per_page={commitSayisi}", token, ct);
        using var prler = await GetAsync($"search/issues?q={Uri.EscapeDataString($"repo:{depo} type:pr state:open")}&per_page=1", token, ct);

        try
        {
            var liste = commitler.RootElement.EnumerateArray().Take(commitSayisi).Select(Commit).ToList();
            var sayi = prler.RootElement.GetProperty("total_count").GetInt32();
            return new GitHubDepoOzeti(liste, sayi);
        }
        catch (Exception e) when (e is InvalidOperationException or KeyNotFoundException or FormatException)
        {
            throw new HttpRequestException("GitHub answered in an unexpected shape.", e);
        }
    }

    private static GitHubCommit Commit(JsonElement e)
    {
        var sha = e.GetProperty("sha").GetString() ?? "";
        var commit = e.GetProperty("commit");
        var mesaj = commit.TryGetProperty("message", out var m) && m.ValueKind == JsonValueKind.String ? m.GetString() ?? "" : "";
        string? yazar = null;
        DateTimeOffset? tarih = null;
        if (commit.TryGetProperty("author", out var a) && a.ValueKind == JsonValueKind.Object)
        {
            yazar = a.TryGetProperty("name", out var n) && n.ValueKind == JsonValueKind.String ? n.GetString() : null;
            if (a.TryGetProperty("date", out var d) && d.ValueKind == JsonValueKind.String
                && DateTimeOffset.TryParse(d.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.None, out var t))
                tarih = t;
        }

        return new GitHubCommit(sha, mesaj, yazar, tarih);
    }

    private async Task<JsonDocument> GetAsync(string yol, string token, CancellationToken ct)
    {
        using var istek = new HttpRequestMessage(HttpMethod.Get, yol);
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var yanit = await http.SendAsync(istek, ct);

        switch (yanit.StatusCode)
        {
            case HttpStatusCode.NotFound:
                throw new GitHubDepoBulunamadiException();
            case HttpStatusCode.Unauthorized:
                throw new GitHubYetkiException();
            case HttpStatusCode.TooManyRequests:
                throw new GitHubOranSiniriException(Sifirlanma(yanit));
            case HttpStatusCode.Forbidden:
                // 403 is both "limit used up" and "no right to this repository".
                if (OranDolu(yanit))
                    throw new GitHubOranSiniriException(Sifirlanma(yanit));
                throw new GitHubYetkiException();
        }

        yanit.EnsureSuccessStatusCode();
        try
        {
            return await JsonDocument.ParseAsync(await yanit.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
        }
        catch (JsonException e)
        {
            throw new HttpRequestException("GitHub answered with something that is not JSON.", e);
        }
    }

    private static bool OranDolu(HttpResponseMessage yanit) =>
        yanit.Headers.Contains("Retry-After")
        || (yanit.Headers.TryGetValues("X-RateLimit-Remaining", out var kalan) && kalan.FirstOrDefault() == "0");

    private static DateTimeOffset? Sifirlanma(HttpResponseMessage yanit) =>
        yanit.Headers.TryGetValues("X-RateLimit-Reset", out var v) && long.TryParse(v.FirstOrDefault(), CultureInfo.InvariantCulture, out var saniye)
            ? DateTimeOffset.FromUnixTimeSeconds(saniye)
            : null;
}
