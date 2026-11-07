using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Gelen;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// The two pick lists the hand placement of the inbox needs (K2.5, from C3): the tag dictionary and the folders.
public class GelenSecenekTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Sozluk = "# Etiketler\n\n## ogrenme\n- okul: sınav, Ders\n- kaynak: kitap\n- özet:\n\n## genel\n- #fikir: kafada, okul\n- okul: tekrar\n";

    private const string Projeler = """
        [{"kimlik": "kitap-kulubu", "yol": "projects/kitap-kulubu/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false},
         {"kimlik": "gizli-proje", "yol": "projects/gizli-proje/index.md", "baslik": "Gizli", "gizli": true},
         {"kimlik": "finans-takip", "yol": "finans/x/index.md", "baslik": "Kapalı klasör", "gizli": false}]
        """;

    private readonly SahteBeyin _beyin = new("ok");
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        _beyin.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private WebApplicationFactory<Program> Fabrika(bool beyinBagli = true)
    {
        if (beyinBagli)
        {
            _beyin.Cikti("proje liste", Projeler);
            _beyin.CiktiKonumsal("not oku", "etiketler.md", JsonSerializer.Serialize(new
            {
                yol = "etiketler.md", baslik = "Etiketler", ustbilgi = new Dictionary<string, object>(), govde = Sozluk, ustbilgi_hatalari = Array.Empty<string>(),
            }));
        }

        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            if (beyinBagli)
                b.UseSetting("Beyin:Komut", _beyin.Komut).UseSetting("Beyin:Vault", _beyin.Vault);
            b.UseSetting("Beyin:GonderimAraligiSaniye", "3600").UseSetting("Gelen:OneriAraligiDakika", "600");
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

    private async Task<HttpResponseMessage> GetAsync(string yol, string? token, WebApplicationFactory<Program> fabrika)
    {
        using var istek = new HttpRequestMessage(HttpMethod.Get, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await fabrika.CreateClient().SendAsync(istek, Ct);
    }

    private async Task IzinAsync(string sahip, bool acik, WebApplicationFactory<Program> fabrika)
    {
        using var istek = new HttpRequestMessage(HttpMethod.Put, "/api/yonetim/izinler/gelen.oku") { Content = JsonContent.Create(new { acik }) };
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", sahip);
        (await fabrika.CreateClient().SendAsync(istek, Ct)).EnsureSuccessStatusCode();
    }

    private static async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    [Theory]
    [InlineData("/api/gelen/etiketler")]
    [InlineData("/api/gelen/klasorler")]
    public async Task TheLists_NeedLogin_AndTheGelenOkuPermission(string yol)
    {
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinAsync(sahip, false, fabrika);

        Assert.Equal(HttpStatusCode.Unauthorized, (await GetAsync(yol, null, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GetAsync(yol, asistan, fabrika)).StatusCode);

        await IzinAsync(sahip, true, fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GetAsync(yol, asistan, fabrika)).StatusCode);
        await IzinAsync(sahip, false, fabrika);
    }

    [Fact]
    public async Task Tags_AreTheMainNames_WithTheirSynonyms_InTheOrderWritten()
    {
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GetAsync("/api/gelen/etiketler", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var liste = (await OkuAsync(yanit)).EnumerateArray().ToList();
        Assert.Equal(["okul", "kaynak", "özet", "fikir"], liste.Select(e => e.GetProperty("ad").GetString()));
        string[] Esler(int i) => liste[i].GetProperty("esler").EnumerateArray().Select(x => x.GetString()!).ToArray();
        Assert.Equal(["sınav", "ders"], Esler(0)); // lower-cased like the brain does
        Assert.Equal(["kitap"], Esler(1));
        Assert.Empty(Esler(2));
        Assert.Equal(["kafada"], Esler(3)); // "okul" is a main name above, so it is not a synonym of fikir
    }

    [Fact]
    public async Task Tags_WithTheBrainOff_Is503()
    {
        var fabrika = Fabrika(beyinBagli: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await GetAsync("/api/gelen/etiketler", sahip, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await GetAsync("/api/gelen/klasorler", sahip, fabrika)).StatusCode);
    }

    [Fact]
    public async Task Folders_AreTheVisibleProjectsNotesFolders_AndTheOpenTopFolders_NeverFinansOrKisisel()
    {
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GetAsync("/api/gelen/klasorler", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var liste = (await OkuAsync(yanit)).EnumerateArray().ToList();
        var yollar = liste.Select(k => k.GetProperty("yol").GetString()!).ToList();

        var proje = liste.Single(k => k.GetProperty("tur").GetString() == "proje");
        Assert.Equal("projects/kitap-kulubu/notlar/", proje.GetProperty("yol").GetString());
        Assert.Equal("Kitap Kulübü Sitesi", proje.GetProperty("ad").GetString());
        Assert.Equal("kitap-kulubu", proje.GetProperty("proje").GetString());

        Assert.Equal(GelenYolu.AcikKokler.Select(k => $"{k}/"), liste.Where(k => k.GetProperty("tur").GetString() == "kok").Select(k => k.GetProperty("yol").GetString()));
        Assert.DoesNotContain(yollar, y => y.Contains("gizli-proje") || y.StartsWith("finans", StringComparison.Ordinal) || y.StartsWith("kisisel", StringComparison.Ordinal));
        Assert.DoesNotContain(yollar, y => y.Contains("finans-takip"));
    }

    [Fact]
    public async Task EveryFolderOffered_PassesTheCheckThePlacementUses()
    {
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var liste = (await OkuAsync(await GetAsync("/api/gelen/klasorler", sahip, fabrika))).EnumerateArray().ToList();
        var gorunur = new HashSet<string>(["kitap-kulubu"], StringComparer.Ordinal);

        Assert.NotEmpty(liste);
        foreach (var k in liste)
            Assert.Null(GelenYolu.Denetle(k.GetProperty("yol").GetString() + "bir-not.md", gorunur));
    }
}
