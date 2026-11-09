using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// The whole app (real pipeline, bearer tokens, the database) with a fake beyin.py and, where a test needs it, a fake claude:
// who may read, suggest, place and delete, and that a hidden or unknown card, a closed path or a wrong tag stops before the brain.
public sealed class GelenApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private readonly string _kart = "2026-11-03-1840-" + Guid.NewGuid().ToString("N")[..10];

    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahteClaude _claude = new();
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        _beyin.Dispose();
        _claude.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    // The round of the background service never runs here (the interval is long): the tests ask by hand.
    private WebApplicationFactory<Program> Fabrika(bool claude = false, Action<IWebHostBuilder>? ek = null)
    {
        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            b.UseSetting("Beyin:Komut", _beyin.Komut)
             .UseSetting("Beyin:Vault", _beyin.Vault)
             .UseSetting("Beyin:GonderimAraligiSaniye", "3600")
             .UseSetting("Gelen:OneriAraligiDakika", "600");
            if (claude)
                b.UseSetting("Claude:Komut", _claude.Komut);
            ek?.Invoke(b);
        });
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    private WebApplicationFactory<Program>? _acik;

    private WebApplicationFactory<Program> Acik => _acik ??= Fabrika();

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

    private async Task IzinAsync(string sahip, string izin, bool acik, WebApplicationFactory<Program> fabrika)
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, fabrika, new { acik });
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
    }

    private static async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    private int Cagri(string komut, string alt) =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Count(a => a[0] == komut && a[1] == alt);

    private const string Sozluk = "# Etiketler\n\n## ogrenme\n- okul: sınav\n- kaynak: kitap\n- özet: çıkarım\n";

    private const string Projeler = """[{"kimlik": "kitap-kulubu", "yol": "projects/kitap-kulubu/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false}]""";

    private void BeyniKur(string? hedef = null)
    {
        _beyin.Cikti("gelen liste", JsonSerializer.Serialize(new[]
        {
            new { yol = $"gelen/{_kart}.md", baslik = "Kitap önerisi: Simyacı", yakalandi = "2026-11-03T18:40", hedef, gorsel = (string?)null },
        }));
        _beyin.Cikti("proje liste", Projeler);
        _beyin.CiktiKonumsal("not oku", "etiketler.md", NotJson("etiketler.md", Sozluk));
        _beyin.CiktiKonumsal("not oku", $"gelen/{_kart}.md", NotJson($"gelen/{_kart}.md", "Ayşe Simyacı'yı önerdi.\n"));
        _beyin.Cikti("gelen isle", $$"""{"yol": "ogrenme/simyaci.md", "kart": "gelen/{{_kart}}.md", "gorsel": null}""");
        _beyin.Cikti("gelen sil", $$"""{"silinen": ["gelen/{{_kart}}.md"]}""");
    }

    private static string NotJson(string yol, string govde) => JsonSerializer.Serialize(new
    {
        yol, baslik = "x", ustbilgi = new Dictionary<string, object> { ["tur"] = "gelen" }, govde, ustbilgi_hatalari = Array.Empty<string>(),
    });

    private static object Girdi(string yol = "ogrenme/simyaci.md", string[]? etiketler = null) =>
        new { yol, baslik = "Simyacı", etiketler = etiketler ?? ["kaynak", "okul"] };

    // Who may do what

    [Fact]
    public async Task Inbox_NeedsLogin_AndTheMatchingPermission()
    {
        BeyniKur();
        var fabrika = Acik;
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinAsync(sahip, "gelen.oku", false, fabrika);
        await IzinAsync(sahip, "gelen.yaz", false, fabrika);

        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, "/api/gelen", null, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/gelen", asistan, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/isle", asistan, fabrika, Girdi())).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/oneri", asistan, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Delete, $"/api/gelen/{_kart}", asistan, fabrika)).StatusCode);

        await IzinAsync(sahip, "gelen.oku", true, fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/gelen", asistan, fabrika)).StatusCode);
        // Reading is not writing.
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/isle", asistan, fabrika, Girdi())).StatusCode);

        // The write permission opens suggesting and placing, but deleting stays with the Sahip.
        await IzinAsync(sahip, "gelen.yaz", true, fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/isle", asistan, fabrika, Girdi())).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Delete, $"/api/gelen/{_kart}", asistan, fabrika)).StatusCode);
        Assert.Equal(0, Cagri("gelen", "sil"));
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Delete, $"/api/gelen/{_kart}", sahip, fabrika)).StatusCode);
        Assert.Equal(1, Cagri("gelen", "sil"));

        await IzinAsync(sahip, "gelen.oku", false, fabrika);
        await IzinAsync(sahip, "gelen.yaz", false, fabrika);
    }

    [Fact]
    public void ThePermissions_AreOnTheListTheSahipGivesOut()
    {
        Assert.True(Izinler.Gecerli("gelen.oku"));
        Assert.True(Izinler.Gecerli("gelen.yaz"));
    }

    // Reading

    [Fact]
    public async Task List_HasTheCard_WithoutASuggestion()
    {
        BeyniKur("projects/kitap-kulubu");
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, Acik);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/gelen", sahip, Acik);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var kart = (await OkuAsync(yanit)).EnumerateArray().Single();
        Assert.Equal(_kart, kart.GetProperty("kimlik").GetString());
        Assert.Equal("Kitap önerisi: Simyacı", kart.GetProperty("ozet").GetString());
        Assert.False(kart.GetProperty("gorselVar").GetBoolean());
        Assert.Equal("projects/kitap-kulubu", kart.GetProperty("hedef").GetString());
        Assert.Equal("2026-11-03T18:40", kart.GetProperty("yakalandi").GetString());
        Assert.False(kart.GetProperty("laptoptaIslenecek").GetBoolean());
        Assert.Equal(JsonValueKind.Null, kart.GetProperty("oneri").ValueKind);
        // Hidden cards are never asked for.
        Assert.DoesNotContain(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a.Contains("--gizli-dahil"));
    }

    [Fact]
    public async Task List_WithTheBrainOff_Is503()
    {
        var kapali = uygulama.WithWebHostBuilder(b => b.UseSetting("Gelen:OneriAraligiDakika", "600"));
        _fabrikalar.Add(kapali);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, kapali);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await GonderAsync(HttpMethod.Get, "/api/gelen", sahip, kapali)).StatusCode);
    }

    // Placing by hand

    [Fact]
    public async Task Place_SendsTheRightArgumentsToTheBrain()
    {
        BeyniKur();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, Acik);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/isle", sahip, Acik, Girdi("ogrenme/simyaci.md", ["Kaynak", "okul"]));

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        Assert.Equal("ogrenme/simyaci.md", govde.GetProperty("yol").GetString());
        Assert.Equal(_kart, govde.GetProperty("kart").GetString());
        var isle = Assert.Single(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a[0] == "gelen" && a[1] == "isle");
        Assert.Equal(
            ["gelen", "isle", "--yol=ogrenme/simyaci.md", "--baslik=Simyacı", "--tags=kaynak,okul", "--json", "--vault", _beyin.Vault, "--", $"gelen/{_kart}.md"],
            isle);
    }

    public static TheoryData<string, string[], string> KotuYerlestirmeler => new()
    {
        { "finans/abonelik.md", ["kaynak"], "yol" },
        { "kisisel/plan.md", ["kaynak"], "yol" },
        { "../finans/x.md", ["kaynak"], "yol" },
        { "/etc/x.md", ["kaynak"], "yol" },
        { ".beyin/x.md", ["kaynak"], "yol" },
        { "gelen/x.md", ["kaynak"], "yol" },
        { "projects/gizli-proje/notlar/x.md", ["kaynak"], "yol" },
        { "projects/kitap-kulubu/gorevler/x.md", ["kaynak"], "yol" },
        { "ogrenme/x.md", ["yeni-etiket"], "etiketler" },
        { "ogrenme/x.md", [], "etiketler" },
        { "ogrenme/x.md", ["iki kelime"], "etiketler" },
    };

    [Theory]
    [MemberData(nameof(KotuYerlestirmeler))]
    public async Task Place_WithAClosedPathOrAWrongTag_IsRefused_BeforeTheBrainIsAskedToWrite(string yol, string[] etiketler, string alan)
    {
        BeyniKur();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, Acik);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/isle", sahip, Acik, Girdi(yol, etiketler));

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.True((await OkuAsync(yanit)).GetProperty("errors").TryGetProperty(alan, out _));
        Assert.Equal(0, Cagri("gelen", "isle"));
    }

    [Fact]
    public async Task Place_ACardThatIsNotInTheList_Is404_AndNothingIsWritten()
    {
        // What a hidden card looks like: `gelen liste` does not have it.
        BeyniKur();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, Acik);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/gelen/2026-11-03-0001-gizli-kart/isle", sahip, Acik, Girdi());

        Assert.Equal(HttpStatusCode.NotFound, yanit.StatusCode);
        Assert.Equal(0, Cagri("gelen", "isle"));
    }

    [Theory]
    [InlineData("..%2Fkisisel%2Fx")]
    [InlineData("a.b")]
    [InlineData("-x")]
    public async Task Place_WithACardNameThatIsNotAFileName_IsRefused(string kart)
    {
        BeyniKur();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, Acik);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gelen/{kart}/isle", sahip, Acik, Girdi());

        Assert.True(yanit.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.NotFound, yanit.StatusCode.ToString());
        Assert.Equal(0, Cagri("gelen", "isle"));
    }

    // Deleting

    [Fact]
    public async Task Delete_NeedsOnayAndTheSahip_AndAnUnknownCardIs404()
    {
        BeyniKur();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, Acik);

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Delete, "/api/gelen/2026-11-03-0001-yok", sahip, Acik)).StatusCode);
        Assert.Equal(0, Cagri("gelen", "sil"));

        var yanit = await GonderAsync(HttpMethod.Delete, $"/api/gelen/{_kart}", sahip, Acik);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var sil = Assert.Single(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a[0] == "gelen" && a[1] == "sil");
        Assert.Equal(["gelen", "sil", "--onay", "--json", "--vault", _beyin.Vault, "--", $"gelen/{_kart}.md"], sil);
    }

    // Suggesting by hand

    private static ClaudeJson Cevap(string yol = "ogrenme/simyaci.md") => new(yol);

    private sealed record ClaudeJson(string Yol)
    {
        public override string ToString() => JsonSerializer.Serialize(new
        {
            yol = Yol, baslik = "Simyacı", etiketler = new[] { "kaynak", "okul", "özet" }, gerekce = "Kitap.", guven = 0.8, yeniEtiket = (object?)null,
        });
    }

    [Fact]
    public async Task SuggestAgain_PutsTheSuggestionInTheQueue_AndTheListShowsIt()
    {
        BeyniKur();
        _claude.YapiliYanit(Cevap().ToString());
        var fabrika = Fabrika(claude: true);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/oneri", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        Assert.Equal("olustu", govde.GetProperty("durum").GetString());
        var eylem = govde.GetProperty("eylem");
        Assert.Equal("yerlestir", eylem.GetProperty("tur").GetString());
        Assert.Equal("bekliyor", eylem.GetProperty("durum").GetString());
        Assert.False(eylem.GetProperty("geriAlinabilir").GetBoolean());
        Assert.Equal(_kart, eylem.GetProperty("yuk").GetProperty("kart").GetString());
        Assert.Single(_claude.Cagrilar());
        Assert.Equal(0, Cagri("gelen", "isle"));

        // The list shows it under the card.
        var kart = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gelen", sahip, fabrika))).EnumerateArray().Single();
        Assert.Equal(eylem.GetProperty("id").GetString(), kart.GetProperty("oneri").GetProperty("eylemId").GetString());
        Assert.Equal("ogrenme/simyaci.md", kart.GetProperty("oneri").GetProperty("yol").GetString());

        // A second ask while one is waiting is a conflict, and does not call Claude again.
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/oneri", sahip, fabrika)).StatusCode);
        Assert.Single(_claude.Cagrilar());

        // Approving it in the queue places the card; the undo is a 409.
        var uygula = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{eylem.GetProperty("id").GetString()}/uygula", sahip, fabrika);
        Assert.Equal(HttpStatusCode.OK, uygula.StatusCode);
        Assert.Equal(1, Cagri("gelen", "isle"));
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{eylem.GetProperty("id").GetString()}/geri-al", sahip, fabrika)).StatusCode);
    }

    [Fact]
    public async Task SuggestAgain_ForAHiddenOrUnknownCard_Is404_AndClaudeIsNotAsked()
    {
        BeyniKur();
        _claude.YapiliYanit(Cevap().ToString());
        var fabrika = Fabrika(claude: true);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/gelen/2026-11-03-0001-gizli-kart/oneri", sahip, fabrika);

        Assert.Equal(HttpStatusCode.NotFound, yanit.StatusCode);
        Assert.Empty(_claude.Cagrilar());
    }

    [Fact]
    public async Task SuggestAgain_ForACardAimedAtAClosedFolder_IsRefused_AndClaudeIsNotAsked()
    {
        BeyniKur(hedef: "finans");
        _claude.YapiliYanit(Cevap().ToString());
        var fabrika = Fabrika(claude: true);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/oneri", sahip, fabrika);

        Assert.Equal(HttpStatusCode.UnprocessableEntity, yanit.StatusCode);
        Assert.Empty(_claude.Cagrilar());
    }

    [Fact]
    public async Task SuggestAgain_WithClaudeOff_Is503()
    {
        BeyniKur();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, Acik);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/oneri", sahip, Acik)).StatusCode);
    }

    [Fact]
    public async Task SuggestAgain_PastTheDailyCap_Is429()
    {
        BeyniKur();
        _claude.YapiliYanit(Cevap().ToString());
        var fabrika = Fabrika(claude: true, b => b.UseSetting("Claude:GunlukEnCokCagri", "0"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/oneri", sahip, fabrika);

        Assert.Equal(HttpStatusCode.TooManyRequests, yanit.StatusCode);
        Assert.Empty(_claude.Cagrilar());
    }

    [Fact]
    public async Task SuggestAgain_WithAnAnswerThatBreaksARule_Is502_AndNothingIsQueued()
    {
        BeyniKur();
        _claude.YapiliYanit(Cevap("finans/abonelik.md").ToString());
        var fabrika = Fabrika(claude: true);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gelen/{_kart}/oneri", sahip, fabrika);

        Assert.Equal(HttpStatusCode.BadGateway, yanit.StatusCode);
        var kart = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gelen", sahip, fabrika))).EnumerateArray().Single();
        Assert.Equal(JsonValueKind.Null, kart.GetProperty("oneri").ValueKind);
    }
}
