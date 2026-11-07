using System.Collections.Concurrent;

namespace Kafamdakiler.ProjeRepolari;

// The repository card of a project: the link, the last commits and the open pull request count. Singleton, because it holds the
// cache that keeps the calls under GitHub's rate limit. With no token it never calls GitHub.
public class RepoOzetServisi(IGitHubIstemcisi github, GitHubAyari ayar, TimeProvider saat, ILogger<RepoOzetServisi> log)
{
    private const int EnUzunMesaj = 200;

    private readonly ConcurrentDictionary<string, (DateTimeOffset Bitis, Sonuc Ozet)> _onbellek = new(StringComparer.OrdinalIgnoreCase);

    private record Sonuc(string Durum, string? Mesaj, List<RepoCommitDto>? Commitler, int? AcikPrSayisi);

    public static string Baglanti(string depo) => $"https://github.com/{depo}";

    public async Task<ProjeRepoOzetiDto> OzetAsync(string proje, string depo, CancellationToken ct)
    {
        var s = await SonucAsync(depo, ct);
        return new ProjeRepoOzetiDto(proje, depo, Baglanti(depo), s.Durum, s.Mesaj, s.Commitler, s.AcikPrSayisi);
    }

    private async Task<Sonuc> SonucAsync(string depo, CancellationToken ct)
    {
        if (!ayar.TokenVar)
            return new Sonuc("tokenYok", "GitHub token'ı ayarlı değil; yalnız bağlantı gösterilir.", null, null);

        var simdi = saat.GetUtcNow();
        if (_onbellek.TryGetValue(depo, out var kayit) && kayit.Bitis > simdi)
            return kayit.Ozet;

        Sonuc sonuc;
        TimeSpan sure;
        try
        {
            var ozet = await github.OzetAlAsync(depo, ayar.Token, GitHubAyari.SonCommitSayisi, ct);
            sonuc = new Sonuc("tamam", null, ozet.Commitler.Take(GitHubAyari.SonCommitSayisi).Select(CommitDto).ToList(), ozet.AcikPrSayisi);
            sure = ayar.Onbellek;
        }
        catch (GitHubDepoBulunamadiException)
        {
            sonuc = new Sonuc("depoYok", "Depo bulunamadı ya da token onu göremiyor.", null, null);
            sure = ayar.HataOnbellegi;
        }
        catch (GitHubOranSiniriException e)
        {
            sonuc = new Sonuc("oranSiniri", "GitHub istek sınırına ulaşıldı; biraz sonra tekrar dene.", null, null);
            // Until GitHub says the limit resets, but never longer than the cache of a good answer.
            sure = e.Sifirlanma is { } an && an > simdi ? Min(an - simdi, ayar.Onbellek) : ayar.HataOnbellegi;
        }
        catch (GitHubYetkiException)
        {
            sonuc = new Sonuc("yetkiYok", "GitHub token'ı kabul edilmedi ya da bu depoyu okuyamıyor.", null, null);
            sure = ayar.HataOnbellegi;
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            log.LogWarning(e, "GitHub could not be reached for a repository summary.");
            return new Sonuc("hata", "GitHub'a ulaşılamadı; biraz sonra tekrar dene.", null, null);
        }

        _onbellek[depo] = (simdi + sure, sonuc);
        return sonuc;
    }

    private static TimeSpan Min(TimeSpan a, TimeSpan b) => a < b ? a : b;

    private static RepoCommitDto CommitDto(GitHubCommit c) =>
        new(c.Sha.Length > 7 ? c.Sha[..7] : c.Sha, IlkSatir(c.Mesaj), c.Yazar, c.Tarih);

    private static string IlkSatir(string mesaj)
    {
        var satir = mesaj.Split('\n', 2)[0].Trim();
        return satir.Length > EnUzunMesaj ? satir[..EnUzunMesaj] + "…" : satir;
    }
}
