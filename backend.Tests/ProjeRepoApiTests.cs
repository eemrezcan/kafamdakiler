using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Data;
using Kafamdakiler.ProjeRepolari;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The whole app (real pipeline, bearer tokens, the database) with a fake beyin.py and a fake GitHub: the Sahip maps a project to a
// repository, `beyin.oku` reads the card, and nothing reaches GitHub.
public sealed class ProjeRepoApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Proje = "kitap-kulubu";

    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahteGitHub _github = new();
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        _beyin.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private WebApplicationFactory<Program> Fabrika(string? token = "gizli-token")
    {
        _beyin.Cikti("proje liste", $$"""
            [{"kimlik": "{{Proje}}", "yol": "projects/{{Proje}}/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false},
             {"kimlik": "gizli-proje", "yol": "projects/gizli-proje/index.md", "baslik": "Gizli", "gizli": true}]
            """);
        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            b.UseSetting("Beyin:Komut", _beyin.Komut)
             .UseSetting("Beyin:Vault", _beyin.Vault)
             .UseSetting("Beyin:GonderimAraligiSaniye", "3600")
             .UseSetting("Gelen:OneriAraligiDakika", "600");
            if (token is not null)
                b.UseSetting("GitHub:Token", token);
            b.ConfigureTestServices(s => s.AddSingleton<IGitHubIstemcisi>(_github));
        });
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    private async Task<string> GirisAsync(string eposta, WebApplicationFactory<Program> fabrika)
    {
        var yanit = await fabrika.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string? token, WebApplicationFactory<Program> fabrika, object? govde = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await fabrika.CreateClient().SendAsync(istek, Ct);
    }

    private static async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    private async Task IzinAsync(string sahip, string izin, bool acik, WebApplicationFactory<Program> fabrika)
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, fabrika, new { acik });
        Assert.True(yanit.IsSuccessStatusCode, await yanit.Content.ReadAsStringAsync(Ct));
    }

    // The table is shared by the tests of this class: every test starts with no mapping.
    private async Task TemizleAsync()
    {
        await using var db = uygulama.YeniDb();
        await db.ProjeRepolari.ExecuteDeleteAsync(Ct);
    }

    private async Task<string> EslestirAsync(string sahip, WebApplicationFactory<Program> fabrika, string depo = "emre/kafamdakiler")
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{Proje}", sahip, fabrika, new { depo });
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return depo;
    }

    [Fact]
    public async Task TheMapping_IsForTheSahitOnly_EvenWhenTheAsistanHasEveryPermission()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinAsync(sahip, "beyin.oku", true, fabrika);

        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, "/api/yonetim/proje-repolari", null, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/yonetim/proje-repolari", asistan, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{Proje}", asistan, fabrika, new { depo = "emre/kafamdakiler" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Delete, $"/api/yonetim/proje-repolari/{Proje}", asistan, fabrika)).StatusCode);

        await using var db = uygulama.YeniDb();
        Assert.Empty(await db.ProjeRepolari.ToListAsync(Ct));
    }

    [Fact]
    public async Task TheSahip_SetsListsReplacesAndDeletesTheMapping()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        Assert.Empty((await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/yonetim/proje-repolari", sahip, fabrika))).EnumerateArray());

        var koy = await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{Proje}", sahip, fabrika, new { depo = " emre/kafamdakiler " });
        Assert.Equal(HttpStatusCode.OK, koy.StatusCode);
        var satir = await OkuAsync(koy);
        Assert.Equal(Proje, satir.GetProperty("proje").GetString());
        Assert.Equal("emre/kafamdakiler", satir.GetProperty("depo").GetString());
        Assert.Equal("https://github.com/emre/kafamdakiler", satir.GetProperty("baglanti").GetString());

        await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{Proje}", sahip, fabrika, new { depo = "emre/baska" });
        var liste = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/yonetim/proje-repolari", sahip, fabrika))).EnumerateArray().ToList();
        var tek = Assert.Single(liste);
        Assert.Equal("emre/baska", tek.GetProperty("depo").GetString());

        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Delete, $"/api/yonetim/proje-repolari/{Proje}", sahip, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Delete, $"/api/yonetim/proje-repolari/{Proje}", sahip, fabrika)).StatusCode);
        Assert.Empty((await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/yonetim/proje-repolari", sahip, fabrika))).EnumerateArray());
    }

    [Theory]
    [InlineData("emre")]
    [InlineData("https://github.com/emre/kafamdakiler")]
    [InlineData("emre/..")]
    [InlineData("emre/repo?x=1")]
    public async Task ABadRepositoryName_Is400_AndNothingIsStored(string depo)
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{Proje}", sahip, fabrika, new { depo });

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.True((await OkuAsync(yanit)).GetProperty("errors").TryGetProperty("depo", out _));
        await using var db = uygulama.YeniDb();
        Assert.Empty(await db.ProjeRepolari.ToListAsync(Ct));
    }

    [Fact]
    public async Task AMissingDepo_Is400()
    {
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{Proje}", sahip, fabrika, new { });

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
    }

    [Theory]
    [InlineData("yok-boyle-proje", HttpStatusCode.NotFound)]
    [InlineData("gizli-proje", HttpStatusCode.NotFound)] // a hidden project looks like one that does not exist
    [InlineData("Buyuk_Harf", HttpStatusCode.BadRequest)]
    public async Task OnlyAVisibleProject_CanGetARepository(string kimlik, HttpStatusCode beklenen)
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{kimlik}", sahip, fabrika, new { depo = "emre/kafamdakiler" });

        Assert.Equal(beklenen, yanit.StatusCode);
        await using var db = uygulama.YeniDb();
        Assert.Empty(await db.ProjeRepolari.ToListAsync(Ct));
    }

    [Fact]
    public async Task WithoutTheBrain_TheMappingCannotBeChecked_Is503()
    {
        await TemizleAsync();
        var sahipFabrika = uygulama.WithWebHostBuilder(b => b.ConfigureTestServices(s => s.AddSingleton<IGitHubIstemcisi>(_github)));
        _fabrikalar.Add(sahipFabrika);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, sahipFabrika);

        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/proje-repolari/{Proje}", sahip, sahipFabrika, new { depo = "emre/kafamdakiler" });

        Assert.Equal(HttpStatusCode.ServiceUnavailable, yanit.StatusCode);
    }

    [Fact]
    public async Task TheCard_NeedsLogin_AndTheBeyinOkuPermission()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await EslestirAsync(sahip, fabrika);
        await IzinAsync(sahip, "beyin.oku", false, fabrika);

        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", null, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", asistan, fabrika)).StatusCode);
        Assert.Equal(0, _github.CagriSayisi);

        await IzinAsync(sahip, "beyin.oku", true, fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", asistan, fabrika)).StatusCode);
        await IzinAsync(sahip, "beyin.oku", false, fabrika);
    }

    [Fact]
    public async Task TheCard_HasTheLink_TheLastCommits_AndTheOpenPullRequestCount()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        await EslestirAsync(sahip, fabrika);

        var yanit = await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var kart = await OkuAsync(yanit);
        Assert.Equal("tamam", kart.GetProperty("durum").GetString());
        Assert.Equal("emre/kafamdakiler", kart.GetProperty("depo").GetString());
        Assert.Equal("https://github.com/emre/kafamdakiler", kart.GetProperty("baglanti").GetString());
        Assert.Equal(3, kart.GetProperty("acikPrSayisi").GetInt32());
        var commitler = kart.GetProperty("commitler").EnumerateArray().ToList();
        Assert.Equal(2, commitler.Count);
        Assert.Equal("0123456", commitler[0].GetProperty("hash").GetString());
        Assert.Equal("feat: add the repo card", commitler[0].GetProperty("mesaj").GetString());
        Assert.Equal("Ayşe", commitler[0].GetProperty("yazar").GetString());

        // The token goes to GitHub, never back to the client; a second ask comes from the cache.
        var ikinci = await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", sahip, fabrika);
        Assert.DoesNotContain("gizli-token", await ikinci.Content.ReadAsStringAsync(Ct));
        Assert.Equal("gizli-token", Assert.Single(_github.Istekler).Token);
    }

    [Fact]
    public async Task TheCard_WithNoToken_ShowsOnlyTheLink()
    {
        await TemizleAsync();
        var fabrika = Fabrika(token: null);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        await EslestirAsync(sahip, fabrika);

        var kart = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", sahip, fabrika));

        Assert.Equal("tokenYok", kart.GetProperty("durum").GetString());
        Assert.Equal("https://github.com/emre/kafamdakiler", kart.GetProperty("baglanti").GetString());
        Assert.Equal(JsonValueKind.Null, kart.GetProperty("commitler").ValueKind);
        Assert.Equal(JsonValueKind.Null, kart.GetProperty("acikPrSayisi").ValueKind);
        Assert.Equal(0, _github.CagriSayisi);
    }

    [Fact]
    public async Task TheCard_OfAProjectWithNoRepository_Is404()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", sahip, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, "/api/beyin/projeler/Buyuk_Harf/repo", sahip, fabrika)).StatusCode);
        Assert.Equal(0, _github.CagriSayisi);
    }

    [Fact]
    public async Task TheCard_OfARepositoryGitHubDoesNotHave_SaysDepoYok_WithTheLinkStillThere()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        await EslestirAsync(sahip, fabrika, "emre/yok-boyle-depo");
        _github.Hata = new GitHubDepoBulunamadiException();

        var yanit = await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var kart = await OkuAsync(yanit);
        Assert.Equal("depoYok", kart.GetProperty("durum").GetString());
        Assert.Equal("https://github.com/emre/yok-boyle-depo", kart.GetProperty("baglanti").GetString());
    }

    [Fact]
    public async Task TheCard_WhenTheRateLimitIsReached_SaysOranSiniri()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        await EslestirAsync(sahip, fabrika, "emre/sinirli-depo");
        _github.Hata = new GitHubOranSiniriException(null);

        var kart = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/beyin/projeler/{Proje}/repo", sahip, fabrika));

        Assert.Equal("oranSiniri", kart.GetProperty("durum").GetString());
        Assert.Equal(JsonValueKind.Null, kart.GetProperty("commitler").ValueKind);
    }
}
