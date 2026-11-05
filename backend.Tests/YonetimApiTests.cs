using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Yakalamalar;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The whole app: the Asistan's permissions are read from the database on every request (K-0009 eki), /api/yonetim is
// Sahip only, and the retry of a capture's sending (T07, T08).
public class YonetimApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private async Task<string> GirisAsync(string eposta)
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string? token, object? govde = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await uygulama.CreateClient().SendAsync(istek, Ct);
    }

    private Task<HttpResponseMessage> IzinAyarlaAsync(string sahipToken, string izin, bool acik) =>
        GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahipToken, new { acik });

    // The T07 scenario: the same Asistan token is refused, allowed, then refused again.
    [Fact]
    public async Task Permission_OpenedAndClosed_TakesEffectOnTheNextRequest_WithTheSameToken()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);

        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/beyin/durum", asistan)).StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await IzinAyarlaAsync(sahip, "beyin.oku", true)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/beyin/durum", asistan)).StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await IzinAyarlaAsync(sahip, "beyin.oku", false)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/beyin/durum", asistan)).StatusCode);
    }

    [Fact]
    public async Task Permission_OfAnotherModule_DoesNotOpenThisOne()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);

        await IzinAyarlaAsync(sahip, "yakalama.oku", true);
        try
        {
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/yakalamalar", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/beyin/durum", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/aliskanliklar", asistan)).StatusCode);
        }
        finally
        {
            await IzinAyarlaAsync(sahip, "yakalama.oku", false);
        }
    }

    [Fact]
    public async Task Permission_OpenedTwice_IsStoredOnce()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        await IzinAyarlaAsync(sahip, "aliskanlik.oku", true);
        await IzinAyarlaAsync(sahip, "aliskanlik.oku", true);
        try
        {
            await using var db = uygulama.YeniDb();
            Assert.Equal(1, db.UserClaims.Count(c => c.ClaimType == "izin" && c.ClaimValue == "aliskanlik.oku"));
        }
        finally
        {
            await IzinAyarlaAsync(sahip, "aliskanlik.oku", false);
        }
    }

    [Fact]
    public async Task Management_IsForTheSahipOnly()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        var yollar = new[] { "/api/yonetim/izinler", "/api/yonetim/beyin", "/api/yonetim/gonderim" };

        foreach (var yol in yollar)
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, yol, null)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, yol, asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, yol, sahip)).StatusCode);
        }

        // Even with every permission open, the Asistan cannot change permissions.
        foreach (var izin in Izinler.Tumu)
            await IzinAyarlaAsync(sahip, izin.Ad, true);
        try
        {
            Assert.Equal(HttpStatusCode.Forbidden, (await IzinAyarlaAsync(asistan, "beyin.oku", false)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/yonetim/gonderim/{Guid.NewGuid()}/yeniden-dene", asistan)).StatusCode);
        }
        finally
        {
            foreach (var izin in Izinler.Tumu)
                await IzinAyarlaAsync(sahip, izin.Ad, false);
        }
    }

    [Fact]
    public async Task PermissionList_ShowsEveryKnownPermission_AndRejectsUnknownOnes()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var liste = await (await GonderAsync(HttpMethod.Get, "/api/yonetim/izinler", sahip)).Content.ReadFromJsonAsync<List<IzinDto>>(Ct);
        Assert.NotNull(liste);
        Assert.Equal(Izinler.Tumu.Select(i => i.Ad), liste.Select(i => i.Izin));
        Assert.All(liste, i => Assert.False(i.Acik));

        Assert.Equal(HttpStatusCode.NotFound, (await IzinAyarlaAsync(sahip, "sahip.hersey", true)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/beyin.oku", sahip, new { })).StatusCode);
    }

    // The refresh token stops working; that is the whole promise of the button.
    [Fact]
    public async Task ClosingSessions_RefusesTheRefreshToken()
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = UygulamaFabrikasi.AsistanEposta, password = UygulamaFabrikasi.Parola }, Ct);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        var yenileme = json.RootElement.GetProperty("refreshToken").GetString();

        var once = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/refresh", new { refreshToken = yenileme }, Ct);
        Assert.Equal(HttpStatusCode.OK, once.StatusCode);
        using var yeni = JsonDocument.Parse(await once.Content.ReadAsStringAsync(Ct));
        yenileme = yeni.RootElement.GetProperty("refreshToken").GetString();

        using (var kapsam = uygulama.Services.CreateScope())
            await YonetimIslemleri.AsistaninOturumlariniKapatAsync(kapsam.ServiceProvider.GetRequiredService<UserManager<IdentityUser<Guid>>>());

        var sonra = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/refresh", new { refreshToken = yenileme }, Ct);
        Assert.Equal(HttpStatusCode.Unauthorized, sonra.StatusCode);
    }

    // The sending queue

    private async Task<Guid> YakalamaEkleAsync(Action<Yakalama> ayarla)
    {
        var y = new Yakalama { Metin = "deneme", YakalandiAt = DateTimeOffset.UtcNow.AddHours(-2), GuncellendiAt = DateTimeOffset.UtcNow.AddHours(-2) };
        ayarla(y);
        await using var db = uygulama.YeniDb();
        db.Yakalamalar.Add(y);
        await db.SaveChangesAsync(Ct);
        return y.Id;
    }

    private async Task<List<GonderimDto>> KuyrukAsync(string sahip) =>
        (await (await GonderAsync(HttpMethod.Get, "/api/yonetim/gonderim", sahip)).Content.ReadFromJsonAsync<List<GonderimDto>>(JsonSeceneklari, Ct))!;

    private static readonly JsonSerializerOptions JsonSeceneklari = new(JsonSerializerDefaults.Web)
    {
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    [Fact]
    public async Task Queue_ListsEveryStatus_FailedAndStuckFirst()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var gitti = await YakalamaEkleAsync(y => { y.Durum = YakalamaDurumu.BeyneGitti; y.YakalandiAt = DateTimeOffset.UtcNow; });
        var bekliyor = await YakalamaEkleAsync(y => y.YakalandiAt = DateTimeOffset.UtcNow.AddMinutes(-1));
        var hatali = await YakalamaEkleAsync(y => { y.SonHata = "beyin yok"; y.DenemeSayisi = 2; y.YakalandiAt = DateTimeOffset.UtcNow.AddDays(-3); });
        var takili = await YakalamaEkleAsync(y => { y.GonderimBasladiAt = DateTimeOffset.UtcNow.AddHours(-1); y.YakalandiAt = DateTimeOffset.UtcNow.AddDays(-4); });
        var gonderiliyor = await YakalamaEkleAsync(y => y.GonderimBasladiAt = DateTimeOffset.UtcNow);

        var kuyruk = await KuyrukAsync(sahip);

        // The ones that need a look form the front of the list; nothing like them comes after.
        var onde = kuyruk.TakeWhile(k => k.Gonderim is GonderimDurumu.Hatali or GonderimDurumu.Takili).Select(k => k.Id).ToList();
        Assert.Contains(hatali, onde);
        Assert.Contains(takili, onde);
        Assert.DoesNotContain(kuyruk.Skip(onde.Count), k => k.Gonderim is GonderimDurumu.Hatali or GonderimDurumu.Takili);
        Assert.All(new[] { gitti, bekliyor, gonderiliyor }, id => Assert.Contains(kuyruk, k => k.Id == id));
        Assert.Equal(GonderimDurumu.Hatali, kuyruk.Single(k => k.Id == hatali).Gonderim);
        Assert.Equal(GonderimDurumu.Takili, kuyruk.Single(k => k.Id == takili).Gonderim);
        Assert.Equal(GonderimDurumu.Gonderiliyor, kuyruk.Single(k => k.Id == gonderiliyor).Gonderim);
        Assert.Equal(GonderimDurumu.Bekliyor, kuyruk.Single(k => k.Id == bekliyor).Gonderim);
        Assert.Equal(GonderimDurumu.Tamam, kuyruk.Single(k => k.Id == gitti).Gonderim);
    }

    [Fact]
    public async Task Retry_ClearsTheClaimAndTheError_OfAFailedOrStuckCapture()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var hatali = await YakalamaEkleAsync(y => { y.SonHata = "beyin yok"; y.DenemeSayisi = 3; y.SonDenemeAt = DateTimeOffset.UtcNow; });
        var takili = await YakalamaEkleAsync(y => { y.GonderimBasladiAt = DateTimeOffset.UtcNow.AddHours(-1); y.SonHata = "belirsiz"; y.DenemeSayisi = 1; });

        foreach (var id in new[] { hatali, takili })
        {
            var yanit = await GonderAsync(HttpMethod.Post, $"/api/yonetim/gonderim/{id}/yeniden-dene", sahip);
            Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);

            await using var db = uygulama.YeniDb();
            var y = await db.Yakalamalar.FindAsync([id], Ct);
            Assert.Null(y!.GonderimBasladiAt);
            Assert.Null(y.SonHata);
            Assert.Null(y.SonDenemeAt);
            Assert.Equal(0, y.DenemeSayisi);
            Assert.Equal(YakalamaDurumu.Bekliyor, y.Durum);
        }
    }

    [Fact]
    public async Task Retry_IsRefused_WhileSending_AndAfterTheCaptureLeftBekliyor_AndForAnUnknownId()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var gonderiliyor = await YakalamaEkleAsync(y => y.GonderimBasladiAt = DateTimeOffset.UtcNow);
        var gitti = await YakalamaEkleAsync(y => y.Durum = YakalamaDurumu.BeyneGitti);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/yonetim/gonderim/{gonderiliyor}/yeniden-dene", sahip);
        Assert.Equal(HttpStatusCode.Conflict, yanit.StatusCode);
        // The mobile queue tells this 409 from the permanent ones by the word.
        Assert.Contains("gönderiliyor", await yanit.Content.ReadAsStringAsync(Ct));
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/yonetim/gonderim/{gitti}/yeniden-dene", sahip)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/yonetim/gonderim/{Guid.NewGuid()}/yeniden-dene", sahip)).StatusCode);

        await using var db = uygulama.YeniDb();
        Assert.NotNull((await db.Yakalamalar.FindAsync([gonderiliyor], Ct))!.GonderimBasladiAt);
    }

    // The mobile queue keeps an edit or a delete whose answer is this 409 and sends it again later (it reads the word).
    [Fact]
    public async Task EditingACaptureThatIsBeingSent_Is409_WithTheWordTheMobileAppReads()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var id = await YakalamaEkleAsync(y => y.GonderimBasladiAt = DateTimeOffset.UtcNow);

        var degistir = await GonderAsync(HttpMethod.Put, $"/api/yakalamalar/{id}", sahip, new { metin = "yeni", yakalandiAt = DateTimeOffset.UtcNow });
        var sil = await GonderAsync(HttpMethod.Delete, $"/api/yakalamalar/{id}", sahip);

        foreach (var yanit in new[] { degistir, sil })
        {
            Assert.Equal(HttpStatusCode.Conflict, yanit.StatusCode);
            Assert.Contains("gönderiliyor", await yanit.Content.ReadAsStringAsync(Ct));
        }
    }

    [Fact]
    public async Task BrainStatus_CountsStuckCapturesToo()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await YakalamaEkleAsync(y => y.GonderimBasladiAt = DateTimeOffset.UtcNow.AddHours(-1));

        var yanit = await GonderAsync(HttpMethod.Get, "/api/yonetim/beyin", sahip);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));

        Assert.False(json.RootElement.GetProperty("bagli").GetBoolean());
        Assert.True(json.RootElement.GetProperty("hataliYakalama").GetInt32() >= 1);
    }
}
