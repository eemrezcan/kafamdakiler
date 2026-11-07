using Kafamdakiler.ProjeRepolari;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The repository card without the app around it: the service on a fake GitHub and a clock the test moves.
// The cache, the missing token, a 404, the rate limit, a refused token and a network failure.
public class RepoOzetServisiTests
{
    private const string Depo = "emre/kafamdakiler";

    private readonly SahteGitHub _github = new();
    private readonly ElleSaat _saat = new(new DateTimeOffset(2026, 11, 7, 4, 0, 0, TimeSpan.Zero));

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private RepoOzetServisi Servis(string token = "gizli-token", double onbellekDakika = 5) =>
        new(_github, new GitHubAyari { Token = token, Onbellek = TimeSpan.FromMinutes(onbellekDakika), HataOnbellegi = TimeSpan.FromMinutes(Math.Min(onbellekDakika, 1)) },
            _saat, NullLogger<RepoOzetServisi>.Instance);

    [Fact]
    public async Task WithAToken_ReturnsTheLink_TheLastCommits_AndTheOpenPullRequestCount()
    {
        var ozet = await Servis().OzetAsync("kafamdakiler", Depo, Ct);

        Assert.Equal("tamam", ozet.Durum);
        Assert.Equal("https://github.com/emre/kafamdakiler", ozet.Baglanti);
        Assert.Equal(3, ozet.AcikPrSayisi);
        Assert.Equal(2, ozet.Commitler!.Count);
        var ilk = ozet.Commitler[0];
        Assert.Equal("0123456", ilk.Hash);
        Assert.Equal("feat: add the repo card", ilk.Mesaj); // the first line only
        Assert.Equal("Ayşe", ilk.Yazar);
        Assert.Equal(new DateTimeOffset(2026, 11, 7, 12, 0, 0, TimeSpan.Zero), ilk.Tarih);
        Assert.Null(ozet.Commitler[1].Yazar);
        var istek = Assert.Single(_github.Istekler);
        Assert.Equal((Depo, "gizli-token", 5), istek);
    }

    [Fact]
    public async Task OnlyTheFirstFiveCommits_AreKept_AndALongSubjectIsCut()
    {
        _github.Ozet = new GitHubDepoOzeti(
            Enumerable.Range(0, 8).Select(i => new GitHubCommit($"{i}abcdef0123", i == 0 ? new string('x', 500) : $"commit {i}", "A", null)).ToList(), 0);

        var ozet = await Servis().OzetAsync("kafamdakiler", Depo, Ct);

        Assert.Equal(5, ozet.Commitler!.Count);
        Assert.True(ozet.Commitler[0].Mesaj.Length <= 201);
        Assert.EndsWith("…", ozet.Commitler[0].Mesaj);
    }

    [Fact]
    public async Task WithoutAToken_OnlyTheLinkIsShown_AndGitHubIsNeverCalled()
    {
        var ozet = await Servis(token: "").OzetAsync("kafamdakiler", Depo, Ct);

        Assert.Equal("tokenYok", ozet.Durum);
        Assert.Equal("https://github.com/emre/kafamdakiler", ozet.Baglanti);
        Assert.Null(ozet.Commitler);
        Assert.Null(ozet.AcikPrSayisi);
        Assert.NotNull(ozet.Mesaj);
        Assert.Equal(0, _github.CagriSayisi);
    }

    [Fact]
    public async Task ASecondAsk_WithinTheCacheTime_DoesNotCallGitHub_AndAfterItDoes()
    {
        var servis = Servis(onbellekDakika: 5);

        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        _saat.Simdi = _saat.Simdi.AddMinutes(4);
        var ikinci = await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal("tamam", ikinci.Durum);
        Assert.Equal(1, _github.CagriSayisi);

        _saat.Simdi = _saat.Simdi.AddMinutes(2); // 6 minutes after the first call
        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal(2, _github.CagriSayisi);
    }

    [Fact]
    public async Task TheCache_IsPerRepository_AndIgnoresCase()
    {
        var servis = Servis();

        await servis.OzetAsync("a", "emre/bir", Ct);
        await servis.OzetAsync("a", "EMRE/Bir", Ct);
        await servis.OzetAsync("b", "emre/iki", Ct);

        Assert.Equal(2, _github.CagriSayisi);
    }

    [Fact]
    public async Task ARepositoryThatIsNotThere_IsDepoYok_AndIsNotAskedAgainAtOnce()
    {
        _github.Hata = new GitHubDepoBulunamadiException();
        var servis = Servis();

        var ozet = await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal("depoYok", ozet.Durum);
        Assert.Null(ozet.Commitler);
        Assert.Equal("https://github.com/emre/kafamdakiler", ozet.Baglanti);

        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal(1, _github.CagriSayisi);

        // The repository appears (or the token is fixed): after the short error cache it is asked again and works.
        _github.Hata = null;
        _saat.Simdi = _saat.Simdi.AddSeconds(61);
        Assert.Equal("tamam", (await servis.OzetAsync("kafamdakiler", Depo, Ct)).Durum);
        Assert.Equal(2, _github.CagriSayisi);
    }

    [Fact]
    public async Task TheRateLimit_IsOranSiniri_AndHoldsUntilGitHubSaysItResets()
    {
        _github.Hata = new GitHubOranSiniriException(_saat.Simdi.AddMinutes(3));
        var servis = Servis(onbellekDakika: 5);

        var ozet = await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal("oranSiniri", ozet.Durum);
        Assert.Null(ozet.AcikPrSayisi);

        _saat.Simdi = _saat.Simdi.AddMinutes(2);
        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal(1, _github.CagriSayisi); // still inside the reset window: no call

        _github.Hata = null;
        _saat.Simdi = _saat.Simdi.AddMinutes(2); // past the reset
        Assert.Equal("tamam", (await servis.OzetAsync("kafamdakiler", Depo, Ct)).Durum);
        Assert.Equal(2, _github.CagriSayisi);
    }

    [Fact]
    public async Task TheRateLimit_WithNoResetTime_IsHeldForTheShortErrorCache()
    {
        _github.Hata = new GitHubOranSiniriException(null);
        var servis = Servis();

        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal(1, _github.CagriSayisi);

        _saat.Simdi = _saat.Simdi.AddSeconds(61);
        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal(2, _github.CagriSayisi);
    }

    [Fact]
    public async Task ARefusedToken_IsYetkiYok()
    {
        _github.Hata = new GitHubYetkiException();

        var ozet = await Servis().OzetAsync("kafamdakiler", Depo, Ct);

        Assert.Equal("yetkiYok", ozet.Durum);
        Assert.DoesNotContain("gizli-token", ozet.Mesaj);
    }

    [Fact]
    public async Task ANetworkFailure_IsHata_AndIsNotCached()
    {
        _github.Hata = new HttpRequestException("boom");
        var servis = Servis();

        var ozet = await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal("hata", ozet.Durum);
        Assert.DoesNotContain("boom", ozet.Mesaj);

        await servis.OzetAsync("kafamdakiler", Depo, Ct);
        Assert.Equal(2, _github.CagriSayisi);
    }

    [Fact]
    public async Task ACancelledRequest_IsNotTurnedIntoAnAnswer()
    {
        _github.Hata = new OperationCanceledException();
        using var iptal = new CancellationTokenSource();
        await iptal.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Servis().OzetAsync("kafamdakiler", Depo, iptal.Token));
    }

    [Theory]
    [InlineData("emre/kafamdakiler", true)]
    [InlineData("a/b", true)]
    [InlineData("Emre-Ozcan/repo.v2_x", true)]
    [InlineData("emre", false)]
    [InlineData("/repo", false)]
    [InlineData("emre/", false)]
    [InlineData("emre/repo/extra", false)]
    [InlineData("-emre/repo", false)]
    [InlineData("em--re/repo", false)]
    [InlineData("emre-/repo", false)]
    [InlineData("emre/..", false)]
    [InlineData("emre/.", false)]
    [InlineData("emre/re po", false)]
    [InlineData("emre/repo?x=1", false)]
    [InlineData("https://github.com/emre/repo", false)]
    [InlineData("emre/repo\n", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void TheRepositoryName_MustBeOwnerSlashRepo(string? depo, bool gecerli) =>
        Assert.Equal(gecerli, DepoAdi.Gecerli(depo));
}
