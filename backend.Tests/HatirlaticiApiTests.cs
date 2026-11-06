using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Kafamdakiler.Tests;

// The whole app: reminder CRUD, validation (400 ProblemDetails), Yaptim, Ertele, and the Asistan's permissions.
public class HatirlaticiApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private async Task<string> GirisAsync(string eposta)
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string token, object? govde = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await uygulama.CreateClient().SendAsync(istek, Ct);
    }

    private async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    [Fact]
    public async Task Crud_HappyPath_AsSahip()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var gun = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(30).ToString("yyyy-MM-dd");

        var olustur = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "  Ali'ye kitabı ver ", tur = "soz", kime = "Ali", gun, saat = "18:30:00", tekrar = "aylik", onceGun = 2 });
        Assert.Equal(HttpStatusCode.Created, olustur.StatusCode);
        var h = await OkuAsync(olustur);
        var id = h.GetProperty("id").GetGuid();
        Assert.Equal("Ali'ye kitabı ver", h.GetProperty("baslik").GetString());
        Assert.Equal("soz", h.GetProperty("tur").GetString());
        Assert.Equal("Ali", h.GetProperty("kime").GetString());
        Assert.Equal("acik", h.GetProperty("durum").GetString());
        Assert.InRange(h.GetProperty("kalanGun").GetInt32(), 29, 31);
        Assert.Equal(h.GetProperty("sonrakiAn").GetDateTimeOffset(), h.GetProperty("etkinAn").GetDateTimeOffset());
        Assert.NotEqual(JsonValueKind.Null, h.GetProperty("onceAn").ValueKind);

        var tek = await GonderAsync(HttpMethod.Get, $"/api/hatirlaticilar/{id}", sahip);
        Assert.Equal(HttpStatusCode.OK, tek.StatusCode);

        var degistir = await GonderAsync(HttpMethod.Put, $"/api/hatirlaticilar/{id}", sahip,
            new { baslik = "Ali'ye kitabı geri ver", tur = "gorev", kime = "Ali", gun, tekrar = "yok" });
        Assert.Equal(HttpStatusCode.OK, degistir.StatusCode);
        var yeni = await OkuAsync(degistir);
        Assert.Equal("Ali'ye kitabı geri ver", yeni.GetProperty("baslik").GetString());
        Assert.Equal(JsonValueKind.Null, yeni.GetProperty("kime").ValueKind); // Kime is kept for Soz only

        var liste = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/hatirlaticilar", sahip));
        Assert.Contains(liste.EnumerateArray(), x => x.GetProperty("id").GetGuid() == id);

        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Delete, $"/api/hatirlaticilar/{id}", sahip)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Get, $"/api/hatirlaticilar/{id}", sahip)).StatusCode);
    }

    [Fact]
    public async Task Post_SameClientId_ReturnsTheExistingRecord()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var id = Guid.CreateVersion7();
        var govde = new { id, baslik = "Tekrar", gun = "2030-01-01" };

        Assert.Equal(HttpStatusCode.Created, (await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, govde)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, govde)).StatusCode);
    }

    [Fact]
    public async Task Post_InvalidBody_IsA400ProblemDetails()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "", gun = "2030-01-01", onceGun = 99 });
        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        var hatalar = (await OkuAsync(yanit)).GetProperty("errors");
        Assert.True(hatalar.TryGetProperty("baslik", out _));
        Assert.True(hatalar.TryGetProperty("onceGun", out _));

        var uzun = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = new string('a', 201), gun = "2030-01-01" });
        Assert.Equal(HttpStatusCode.BadRequest, uzun.StatusCode);

        var gunsuz = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "x" });
        Assert.Equal(HttpStatusCode.BadRequest, gunsuz.StatusCode);

        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, "/api/hatirlaticilar?durum=olmaz", sahip)).StatusCode);
    }

    [Fact]
    public async Task Yaptim_And_Ertele_ChangeTheReminder()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var gunluk = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "Su iç", gun = "2020-01-01", tekrar = "gunluk" }));
        var gunlukId = gunluk.GetProperty("id").GetGuid();
        var once = gunluk.GetProperty("sonrakiAn").GetDateTimeOffset();
        Assert.True(once > DateTimeOffset.UtcNow);

        var ertelendi = await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{gunlukId}/ertele", sahip, new { sure = "1s" }));
        Assert.Equal(once, ertelendi.GetProperty("sonrakiAn").GetDateTimeOffset());
        Assert.NotEqual(JsonValueKind.Null, ertelendi.GetProperty("erteleAn").ValueKind);
        Assert.Equal(ertelendi.GetProperty("erteleAn").GetDateTimeOffset(), ertelendi.GetProperty("etkinAn").GetDateTimeOffset());

        var yapildi = await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{gunlukId}/yaptim", sahip));
        Assert.Equal("acik", yapildi.GetProperty("durum").GetString());
        Assert.Equal(JsonValueKind.Null, yapildi.GetProperty("erteleAn").ValueKind);
        Assert.Equal(once.AddDays(1), yapildi.GetProperty("sonrakiAn").GetDateTimeOffset());

        var tek = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "Bir kez", gun = "2030-05-05" }));
        var tekId = tek.GetProperty("id").GetGuid();
        var tamam = await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{tekId}/yaptim", sahip));
        Assert.Equal("tamam", tamam.GetProperty("durum").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{tekId}/yaptim", sahip)).StatusCode);

        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{gunlukId}/ertele", sahip, new { sure = "2s" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{Guid.NewGuid()}/yaptim", sahip)).StatusCode);
    }

    [Fact]
    public async Task List_Filters_ByStatus_And_Upcoming_SortedByEffectiveMoment()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var bugun = DateOnly.FromDateTime(DateTime.UtcNow);
        string Gun(int n) => bugun.AddDays(n).ToString("yyyy-MM-dd");

        var uzak = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "Uzak-L", gun = Gun(40) }));
        var yakin = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "Yakin-L", gun = Gun(3) }));
        var bitti = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "Bitti-L", gun = Gun(2) }));
        await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{bitti.GetProperty("id").GetGuid()}/yaptim", sahip);

        var yaklasan = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/hatirlaticilar?yaklasan=7", sahip));
        var basliklar = yaklasan.EnumerateArray().Select(x => x.GetProperty("baslik").GetString()).ToList();
        Assert.Contains("Yakin-L", basliklar);
        Assert.DoesNotContain("Uzak-L", basliklar);
        Assert.DoesNotContain("Bitti-L", basliklar); // closed ones are not upcoming
        var anlar = yaklasan.EnumerateArray().Select(x => x.GetProperty("etkinAn").GetDateTimeOffset()).ToList();
        Assert.Equal(anlar.OrderBy(a => a), anlar);

        var tamam = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/hatirlaticilar?durum=tamam", sahip));
        Assert.Contains(tamam.EnumerateArray(), x => x.GetProperty("baslik").GetString() == "Bitti-L");
        Assert.All(tamam.EnumerateArray(), x => Assert.Equal("tamam", x.GetProperty("durum").GetString()));

        Assert.NotEqual(default, uzak.GetProperty("id").GetGuid());
        Assert.NotEqual(default, yakin.GetProperty("id").GetGuid());
    }

    [Fact]
    public async Task Asistan_WithoutPermission_Gets403_WithPermission_Gets200()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);

        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/hatirlaticilar", asistan)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", asistan, new { baslik = "x", gun = "2030-01-01" })).StatusCode);

        await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/hatirlatici.oku", sahip, new { acik = true });
        try
        {
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/hatirlaticilar", asistan)).StatusCode);
            // Reading does not open writing.
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", asistan, new { baslik = "x", gun = "2030-01-01" })).StatusCode);
        }
        finally
        {
            await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/hatirlatici.oku", sahip, new { acik = false });
        }

        await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/hatirlatici.yaz", sahip, new { acik = true });
        try
        {
            var olustur = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", asistan, new { baslik = "Asistan yazdı", gun = "2030-01-01" });
            Assert.Equal(HttpStatusCode.Created, olustur.StatusCode);
        }
        finally
        {
            await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/hatirlatici.yaz", sahip, new { acik = false });
        }
    }
}
