using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The whole app (real pipeline, bearer tokens, the database) with a fake claude: the briefing endpoints (K2.7).
// What matters most here: who may read, vote and ask for a new one; no briefing before its hour; a day gets one; and every
// answer says whether Claude or the rules made it.
public sealed class BrifingApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private static readonly DateTimeOffset Sabah = new(2026, 11, 7, 7, 0, 0, TimeSpan.FromHours(3));

    private readonly SahteClaude _claude = new();
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        _claude.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private WebApplicationFactory<Program> Fabrika(DateTimeOffset? an = null, bool claude = true)
    {
        var saat = new ElleSaat((an ?? Sabah).ToUniversalTime());
        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            b.UseSetting("Beyin:GonderimAraligiSaniye", "3600").UseSetting("Gelen:OneriAraligiDakika", "600");
            if (claude)
                b.UseSetting("Claude:Komut", _claude.Komut);
            b.ConfigureTestServices(s => s.AddSingleton<TimeProvider>(saat));
        });
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    // The shared database holds the rows of the tests before this one: each test starts from a clean briefing and reminder state.
    private async Task TemizleAsync()
    {
        await using var db = uygulama.YeniDb();
        await db.BrifingOylari.ExecuteDeleteAsync(Ct);
        await db.Brifingler.ExecuteDeleteAsync(Ct);
        await db.Hatirlaticilar.ExecuteDeleteAsync(Ct);
    }

    private async Task<Guid> HatirlaticiEkleAsync(string baslik, DateTimeOffset an)
    {
        var utc = an.ToUniversalTime();
        var h = new Hatirlatici
        {
            Baslik = baslik, Tur = HatirlaticiTuru.Gorev, Gun = HatirlaticiHesap.IstanbulGunu(utc), Saat = HatirlaticiHesap.IstanbulSaati(utc),
            Tekrar = Tekrar.Yok, Durum = HatirlaticiDurumu.Acik, SonrakiAn = utc,
        };
        await using var db = uygulama.YeniDb();
        db.Hatirlaticilar.Add(h);
        await db.SaveChangesAsync(Ct);
        return h.Id;
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

    private async Task IzinAsync(string sahip, bool acik, WebApplicationFactory<Program> fabrika)
    {
        var yanit = await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/brifing.oku", sahip, fabrika, new { acik });
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
    }

    private static async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    private void ClaudeCevabi(params object[] kartlar) => _claude.YapiliYanit(JsonSerializer.Serialize(new { kartlar }));

    private static object Kart(string tur, string baslik, string metin, params string[] kimlikler) => new { tur, baslik, metin, bagliKimlikler = kimlikler };

    // Who may do what

    [Fact]
    public async Task Reading_NeedsTheBrifingPermission_TheSahipAlwaysHasIt()
    {
        await TemizleAsync();
        var acik = Fabrika(claude: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, acik);

        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", null, acik)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", asistan, acik)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/brifing/2026-11-07", asistan, acik)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, "/api/brifing/2026-11-07/kartlar/0/oy", asistan, acik, new { oy = 1 })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik)).StatusCode);

        await IzinAsync(sahip, true, acik);
        try
        {
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", asistan, acik)).StatusCode);
        }
        finally
        {
            await IzinAsync(sahip, false, acik);
        }
    }

    [Fact]
    public async Task Refresh_IsTheSahipsAlone_EvenWithThePermission()
    {
        await TemizleAsync();
        var acik = Fabrika(claude: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, acik);
        await IzinAsync(sahip, true, acik);
        try
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/yenile", asistan, acik)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/yenile", null, acik)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/yenile", sahip, acik)).StatusCode);
        }
        finally
        {
            await IzinAsync(sahip, false, acik);
        }
    }

    [Fact]
    public async Task ThePermission_IsInTheListTheSahipHandsOut()
    {
        var acik = Fabrika(claude: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);

        Assert.True(Izinler.Gecerli("brifing.oku"));
        var liste = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/yonetim/izinler", sahip, acik));
        Assert.Contains(liste.EnumerateArray(), i => i.GetProperty("izin").GetString() == "brifing.oku");
    }

    // Today's briefing

    [Fact]
    public async Task Today_AfterTheHour_IsMadeByClaude_AndServedAgainWithoutAnotherCall()
    {
        await TemizleAsync();
        var kimlik = await HatirlaticiEkleAsync("Diş randevusu", new DateTimeOffset(2026, 11, 7, 14, 0, 0, TimeSpan.FromHours(3)));
        ClaudeCevabi(Kart("hatirlatici", "Diş randevusu", "Bugün 14:00.", kimlik.ToString()), Kart("kapasite", "Uydurma kapasite", "Sığmıyor."));
        var acik = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        Assert.Equal("2026-11-07", govde.GetProperty("gun").GetString());
        Assert.Equal("claude", govde.GetProperty("yontem").GetString());
        Assert.Equal(3, govde.GetProperty("kalanYenileme").GetInt32());
        var kart = Assert.Single(govde.GetProperty("kartlar").EnumerateArray());
        Assert.Equal((0, "hatirlatici", "Diş randevusu", 0), (kart.GetProperty("sira").GetInt32(), kart.GetProperty("tur").GetString(), kart.GetProperty("baslik").GetString(), kart.GetProperty("oy").GetInt32()));
        Assert.Equal([kimlik.ToString()], kart.GetProperty("bagliKimlikler").EnumerateArray().Select(x => x.GetString()));

        var tekrar = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik));
        Assert.Equal(govde.GetProperty("uretimAni").GetString(), tekrar.GetProperty("uretimAni").GetString());
        Assert.Single(_claude.Cagrilar());
    }

    [Fact]
    public async Task Today_BeforeTheHour_IsNotThereYet()
    {
        await TemizleAsync();
        var acik = Fabrika(new DateTimeOffset(2026, 11, 7, 5, 30, 0, TimeSpan.FromHours(3)));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik);

        Assert.Equal(HttpStatusCode.NotFound, yanit.StatusCode);
        Assert.Equal("Brifing henüz hazır değil", (await OkuAsync(yanit)).GetProperty("title").GetString());
        Assert.Empty(_claude.Cagrilar());
        await using var db = uygulama.YeniDb();
        Assert.Empty(await db.Brifingler.ToListAsync(Ct));
    }

    [Fact]
    public async Task Today_WithoutClaude_IsMadeByRules_AndSaysSo()
    {
        await TemizleAsync();
        await HatirlaticiEkleAsync("Diş randevusu", new DateTimeOffset(2026, 11, 7, 14, 0, 0, TimeSpan.FromHours(3)));
        var acik = Fabrika(claude: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        Assert.Equal("hesap", govde.GetProperty("yontem").GetString());
        Assert.Equal(["hatirlatici"], govde.GetProperty("kartlar").EnumerateArray().Select(k => k.GetProperty("tur").GetString()));
    }

    [Fact]
    public async Task ADay_ByDate_IsOnlyEverRead_NeverMade()
    {
        await TemizleAsync();
        var acik = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);

        var yok = await GonderAsync(HttpMethod.Get, "/api/brifing/2026-11-07", sahip, acik);
        Assert.Equal(HttpStatusCode.NotFound, yok.StatusCode);
        Assert.Empty(_claude.Cagrilar());
        await using (var db = uygulama.YeniDb())
            Assert.Empty(await db.Brifingler.ToListAsync(Ct));

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/brifing/2026-11-07", sahip, acik)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Get, "/api/brifing/2026-11-06", sahip, acik)).StatusCode);
    }

    [Theory]
    [InlineData("dun")]
    [InlineData("2026-13-45")]
    [InlineData("07.11.2026")]
    [InlineData("2026-11-7")]
    public async Task ADay_ThatIsNotADate_IsABadRequest(string gun)
    {
        var acik = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);

        var yanit = await GonderAsync(HttpMethod.Get, $"/api/brifing/{gun}", sahip, acik);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.True((await OkuAsync(yanit)).GetProperty("errors").TryGetProperty("gun", out _));
    }

    // Votes

    [Fact]
    public async Task Vote_IsKept_ShownOnTheCard_AndCanBeChangedOrTakenBack()
    {
        await TemizleAsync();
        var kimlik = await HatirlaticiEkleAsync("Diş randevusu", new DateTimeOffset(2026, 11, 7, 14, 0, 0, TimeSpan.FromHours(3)));
        ClaudeCevabi(Kart("hatirlatici", "Diş randevusu", "Bugün 14:00.", kimlik.ToString()));
        var acik = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);
        await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik);

        var yukari = await GonderAsync(HttpMethod.Post, "/api/brifing/2026-11-07/kartlar/0/oy", sahip, acik, new { oy = 1 });
        Assert.Equal(HttpStatusCode.OK, yukari.StatusCode);
        Assert.Equal(1, (await OkuAsync(yukari)).GetProperty("kartlar")[0].GetProperty("oy").GetInt32());

        var asagi = await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/kartlar/0/oy", sahip, acik, new { oy = -1 });
        Assert.Equal(-1, (await OkuAsync(asagi)).GetProperty("kartlar")[0].GetProperty("oy").GetInt32());
        Assert.Equal(-1, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik))).GetProperty("kartlar")[0].GetProperty("oy").GetInt32());

        var geri = await GonderAsync(HttpMethod.Post, "/api/brifing/2026-11-07/kartlar/0/oy", sahip, acik, new { oy = 0 });
        Assert.Equal(0, (await OkuAsync(geri)).GetProperty("kartlar")[0].GetProperty("oy").GetInt32());
        await using var db = uygulama.YeniDb();
        Assert.Empty(await db.BrifingOylari.ToListAsync(Ct));
    }

    [Fact]
    public async Task Vote_ThatIsNotAThumb_OrOnNoCard_OrOnNoDay_IsRefused()
    {
        await TemizleAsync();
        var kimlik = await HatirlaticiEkleAsync("Diş randevusu", new DateTimeOffset(2026, 11, 7, 14, 0, 0, TimeSpan.FromHours(3)));
        ClaudeCevabi(Kart("hatirlatici", "Diş randevusu", "Bugün 14:00.", kimlik.ToString()));
        var acik = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);
        await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik);

        var besOy = await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/kartlar/0/oy", sahip, acik, new { oy = 5 });
        Assert.Equal(HttpStatusCode.BadRequest, besOy.StatusCode);
        Assert.True((await OkuAsync(besOy)).GetProperty("errors").TryGetProperty("oy", out _));
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/kartlar/0/oy", sahip, acik, new { })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/kartlar/3/oy", sahip, acik, new { oy = 1 })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/kartlar/-1/oy", sahip, acik, new { oy = 1 })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, "/api/brifing/2026-11-01/kartlar/0/oy", sahip, acik, new { oy = 1 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, "/api/brifing/dun/kartlar/0/oy", sahip, acik, new { oy = 1 })).StatusCode);
        await using var db = uygulama.YeniDb();
        Assert.Empty(await db.BrifingOylari.ToListAsync(Ct));
    }

    // A new briefing on request

    [Fact]
    public async Task Refresh_WorksThreeTimesADay_ThenIsRefused()
    {
        await TemizleAsync();
        var kimlik = await HatirlaticiEkleAsync("Diş randevusu", new DateTimeOffset(2026, 11, 7, 14, 0, 0, TimeSpan.FromHours(3)));
        ClaudeCevabi(Kart("hatirlatici", "Diş randevusu", "Bugün 14:00.", kimlik.ToString()));
        var acik = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, acik);
        await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, acik);

        var kalanlar = new List<int>();
        for (var i = 0; i < 3; i++)
        {
            var yanit = await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/yenile", sahip, acik);
            Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
            kalanlar.Add((await OkuAsync(yanit)).GetProperty("kalanYenileme").GetInt32());
        }

        Assert.Equal([2, 1, 0], kalanlar);
        var dorduncu = await GonderAsync(HttpMethod.Post, "/api/brifing/bugun/yenile", sahip, acik);
        Assert.Equal(HttpStatusCode.TooManyRequests, dorduncu.StatusCode);
        Assert.Equal(4, _claude.Cagrilar().Count);
    }
}
