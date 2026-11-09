using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Bildirimler;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The push channel (FCM) on the whole app with a fake sender: device registration, who may read a notification, the test send, and
// what a dead token does. The default app has no key file, so push is off there; the "push on" tests point
// Firebase:AnahtarDosyasi at an empty temp file (only its existence matters, the fake sender never opens it).
public sealed class BildirimApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private readonly SahtePushGondericisi _push = new();
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];
    private readonly string _anahtar = Path.Combine(Path.GetTempPath(), "kd-test-anahtar-" + Guid.NewGuid().ToString("N") + ".json");

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        if (File.Exists(_anahtar))
            File.Delete(_anahtar);
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private WebApplicationFactory<Program> Fabrika(bool pushAcik)
    {
        if (pushAcik)
            File.WriteAllText(_anahtar, "{}");

        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            if (pushAcik)
                b.UseSetting("Firebase:AnahtarDosyasi", _anahtar);
            b.ConfigureTestServices(s => s.AddSingleton<IPushGondericisi>(_push));
        });
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    private static async Task<string> GirisAsync(WebApplicationFactory<Program> fabrika, string eposta)
    {
        var yanit = await fabrika.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private static async Task<HttpResponseMessage> GonderAsync(WebApplicationFactory<Program> fabrika, HttpMethod yontem, string yol, string? token, object? govde = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await fabrika.CreateClient().SendAsync(istek, Ct);
    }

    private static string YeniToken() => "fcm-" + Guid.NewGuid().ToString("N");

    private async Task<Guid> BildirimEkleAsync(Guid kullaniciId, string baslik = "Başlık", string metin = "Metin")
    {
        await using var db = uygulama.YeniDb();
        var b = new Bildirim { KullaniciId = kullaniciId, Baslik = baslik, Metin = metin, KaynakTuru = "test", Rota = "/hatirlaticilar", HedefKimligi = "42", OlusmaAni = DateTimeOffset.UtcNow };
        db.Bildirimler.Add(b);
        await db.SaveChangesAsync(Ct);
        return b.Id;
    }

    // The app and its database are shared by the tests of this class: a test that counts devices starts from none.
    private async Task CihazlariTemizleAsync(Guid kullaniciId)
    {
        await using var db = uygulama.YeniDb();
        await db.BildirimCihazlari.Where(c => c.KullaniciId == kullaniciId).ExecuteDeleteAsync(Ct);
    }

    private async Task<Guid> KullaniciIdAsync(WebApplicationFactory<Program> fabrika, string token)
    {
        var yanit = await GonderAsync(fabrika, HttpMethod.Get, "/api/ben", token);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("id").GetGuid();
    }

    // Device registration

    [Fact]
    public async Task Device_NewToken_IsStoredForTheUser()
    {
        var fabrika = Fabrika(pushAcik: false);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        var kullanici = await KullaniciIdAsync(fabrika, token);
        var fcm = YeniToken();

        var yanit = await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = fcm, cihazAdi = "Pixel 8" });

        Assert.Equal(HttpStatusCode.NoContent, yanit.StatusCode);
        await using var db = uygulama.YeniDb();
        var cihaz = await db.BildirimCihazlari.SingleAsync(c => c.Token == fcm, Ct);
        Assert.Equal(kullanici, cihaz.KullaniciId);
        Assert.Equal("Pixel 8", cihaz.CihazAdi);
    }

    [Fact]
    public async Task Device_SameTokenAgain_UpdatesTheRowInsteadOfAddingOne()
    {
        var fabrika = Fabrika(pushAcik: false);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        var fcm = YeniToken();

        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = fcm, cihazAdi = "Eski ad" });
        var ilk = await Satir(fcm);
        var yanit = await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = fcm, cihazAdi = "Yeni ad" });

        Assert.Equal(HttpStatusCode.NoContent, yanit.StatusCode);
        await using var db = uygulama.YeniDb();
        var cihaz = await db.BildirimCihazlari.SingleAsync(c => c.Token == fcm, Ct);
        Assert.Equal(ilk.Id, cihaz.Id);
        Assert.Equal("Yeni ad", cihaz.CihazAdi);
        Assert.True(cihaz.GuncellemeAni >= ilk.GuncellemeAni);
    }

    [Fact]
    public async Task Device_SameTokenFromAnotherUser_MovesToThatUser()
    {
        // A phone that signs in as someone else must wake that user's notifications, not the previous user's.
        var fabrika = Fabrika(pushAcik: false);
        var sahip = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(fabrika, UygulamaFabrikasi.AsistanEposta);
        var fcm = YeniToken();

        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", sahip, new { token = fcm });
        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", asistan, new { token = fcm });

        Assert.Equal(await KullaniciIdAsync(fabrika, asistan), (await Satir(fcm)).KullaniciId);
    }

    [Fact]
    public async Task Device_Delete_RemovesTheRow_AndAnUnknownTokenIsNotAnError()
    {
        var fabrika = Fabrika(pushAcik: false);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        var fcm = YeniToken();
        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = fcm });

        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(fabrika, HttpMethod.Delete, "/api/bildirim/cihaz", token, new { token = fcm })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(fabrika, HttpMethod.Delete, "/api/bildirim/cihaz", token, new { token = fcm })).StatusCode);

        await using var db = uygulama.YeniDb();
        Assert.False(await db.BildirimCihazlari.AnyAsync(c => c.Token == fcm, Ct));
    }

    [Fact]
    public async Task Device_Delete_DoesNotRemoveAnotherUsersRow()
    {
        var fabrika = Fabrika(pushAcik: false);
        var sahip = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(fabrika, UygulamaFabrikasi.AsistanEposta);
        var fcm = YeniToken();
        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", sahip, new { token = fcm });

        await GonderAsync(fabrika, HttpMethod.Delete, "/api/bildirim/cihaz", asistan, new { token = fcm });

        await using var db = uygulama.YeniDb();
        Assert.True(await db.BildirimCihazlari.AnyAsync(c => c.Token == fcm, Ct));
    }

    [Fact]
    public async Task Device_WithoutToken_IsRejected_AndWithoutSignInIs401()
    {
        var fabrika = Fabrika(pushAcik: false);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { cihazAdi = "x" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", null, new { token = YeniToken() })).StatusCode);
    }

    private async Task<BildirimCihazi> Satir(string fcm)
    {
        await using var db = uygulama.YeniDb();
        return await db.BildirimCihazlari.AsNoTracking().SingleAsync(c => c.Token == fcm, Ct);
    }

    // Reading a notification

    [Fact]
    public async Task Notification_Owner_ReadsIt_AnotherUserGets404_NoSignInGets401()
    {
        var fabrika = Fabrika(pushAcik: false);
        var sahip = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(fabrika, UygulamaFabrikasi.AsistanEposta);
        var id = await BildirimEkleAsync(await KullaniciIdAsync(fabrika, sahip), "Su iç", "Bir bardak su");

        var sahibi = await GonderAsync(fabrika, HttpMethod.Get, $"/api/bildirimler/{id}", sahip);
        Assert.Equal(HttpStatusCode.OK, sahibi.StatusCode);
        using var json = JsonDocument.Parse(await sahibi.Content.ReadAsStringAsync(Ct));
        Assert.Equal("Su iç", json.RootElement.GetProperty("baslik").GetString());
        Assert.Equal("Bir bardak su", json.RootElement.GetProperty("metin").GetString());
        Assert.Equal("/hatirlaticilar", json.RootElement.GetProperty("rota").GetString());
        Assert.Equal("42", json.RootElement.GetProperty("hedefKimligi").GetString());

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(fabrika, HttpMethod.Get, $"/api/bildirimler/{id}", asistan)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(fabrika, HttpMethod.Get, $"/api/bildirimler/{Guid.NewGuid()}", sahip)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(fabrika, HttpMethod.Get, $"/api/bildirimler/{id}", null)).StatusCode);
    }

    // The sender

    [Fact]
    public void RealMessage_CarriesOnlyTheNotificationId_AtHighPriority()
    {
        var id = Guid.NewGuid();

        var mesaj = FirebasePushGondericisi.MesajYap("fcm-token", id);

        var veri = Assert.Single(mesaj.Data);
        Assert.Equal("bildirimId", veri.Key);
        Assert.Equal(id.ToString(), veri.Value);
        Assert.Null(mesaj.Notification);
        Assert.Equal(FirebaseAdmin.Messaging.Priority.High, mesaj.Android.Priority);
    }

    [Fact]
    public async Task TestSend_PushOn_SendsOnlyTheIdToTheUsersDevices()
    {
        var fabrika = Fabrika(pushAcik: true);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        await CihazlariTemizleAsync(await KullaniciIdAsync(fabrika, token));
        var telefon = YeniToken();
        var tablet = YeniToken();
        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = telefon });
        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = tablet });

        var yanit = await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/test", token);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        var bildirimId = json.RootElement.GetProperty("bildirimId").GetGuid();
        Assert.Equal(2, json.RootElement.GetProperty("giden").GetInt32());
        Assert.Equal(new[] { telefon, tablet }.Order(), _push.Gonderilenler.Where(g => g.BildirimId == bildirimId).Select(g => g.Token).Order());

        // The text exists only in the row the phone reads, and that row belongs to the user.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(fabrika, HttpMethod.Get, $"/api/bildirimler/{bildirimId}", token)).StatusCode);
    }

    [Fact]
    public async Task TestSend_DeadToken_DeletesThatDevice_KeepsTheOthers_AndShowsInTheStatus()
    {
        var fabrika = Fabrika(pushAcik: true);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        await CihazlariTemizleAsync(await KullaniciIdAsync(fabrika, token));
        var canli = YeniToken();
        var olu = YeniToken();
        var gecici = YeniToken();
        foreach (var t in new[] { canli, olu, gecici })
            await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = t });
        _push.Sonuclar[olu] = PushSonucu.GecersizToken;
        _push.Sonuclar[gecici] = PushSonucu.Hata;

        var yanit = await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/test", token);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        Assert.Equal(1, json.RootElement.GetProperty("silinen").GetInt32());
        Assert.Equal(1, json.RootElement.GetProperty("hatali").GetInt32());
        await using var db = uygulama.YeniDb();
        Assert.False(await db.BildirimCihazlari.AnyAsync(c => c.Token == olu, Ct));
        Assert.True(await db.BildirimCihazlari.AnyAsync(c => c.Token == canli, Ct));
        // A failed send (network) keeps the device: the next send tries again.
        Assert.True(await db.BildirimCihazlari.AnyAsync(c => c.Token == gecici, Ct));

        var durum = await GonderAsync(fabrika, HttpMethod.Get, "/api/bildirim/durum", token);
        using var durumJson = JsonDocument.Parse(await durum.Content.ReadAsStringAsync(Ct));
        Assert.True(durumJson.RootElement.GetProperty("acik").GetBoolean());
        Assert.Equal(1, durumJson.RootElement.GetProperty("sonGonderim").GetProperty("silinen").GetInt32());
    }

    [Fact]
    public async Task TestSend_NoKeyFile_PushIsOff_AndSaysSoInsteadOfFailing()
    {
        var fabrika = Fabrika(pushAcik: false);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/cihaz", token, new { token = YeniToken() });
        var onceki = _push.Gonderilenler.Count;

        var yanit = await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/test", token);

        Assert.Equal(HttpStatusCode.Conflict, yanit.StatusCode);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        Assert.Contains("Firebase:AnahtarDosyasi", json.RootElement.GetProperty("detail").GetString());
        Assert.Equal(onceki, _push.Gonderilenler.Count);

        var durum = await GonderAsync(fabrika, HttpMethod.Get, "/api/bildirim/durum", token);
        using var durumJson = JsonDocument.Parse(await durum.Content.ReadAsStringAsync(Ct));
        Assert.False(durumJson.RootElement.GetProperty("acik").GetBoolean());
    }

    [Fact]
    public async Task TestSend_ConfiguredPathButNoFile_PushIsOff()
    {
        // Compose always sets the path; before the key is put on the server the file is missing and the app must still run.
        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            b.UseSetting("Firebase:AnahtarDosyasi", Path.Combine(Path.GetTempPath(), "kd-yok-" + Guid.NewGuid().ToString("N") + ".json"));
            b.ConfigureTestServices(s => s.AddSingleton<IPushGondericisi>(_push));
        });
        _fabrikalar.Add(fabrika);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/test", token)).StatusCode);
    }

    [Fact]
    public async Task TestSend_NoDevice_SaysSo()
    {
        var fabrika = Fabrika(pushAcik: true);
        var token = await GirisAsync(fabrika, UygulamaFabrikasi.SahipEposta);
        await CihazlariTemizleAsync(await KullaniciIdAsync(fabrika, token));

        var yanit = await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/test", token);

        Assert.Equal(HttpStatusCode.Conflict, yanit.StatusCode);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        Assert.Contains("cihaz", json.RootElement.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task TestSend_AndStatus_AreForTheSahipOnly()
    {
        var fabrika = Fabrika(pushAcik: true);
        var asistan = await GirisAsync(fabrika, UygulamaFabrikasi.AsistanEposta);

        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/test", asistan)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(fabrika, HttpMethod.Get, "/api/bildirim/durum", asistan)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(fabrika, HttpMethod.Post, "/api/bildirim/test", null)).StatusCode);
    }
}
