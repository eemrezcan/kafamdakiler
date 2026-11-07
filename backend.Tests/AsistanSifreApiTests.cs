using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Kafamdakiler.Tests;

// PUT /api/yonetim/asistan/sifre: the Sahip sets a new password for the Asistan. These tests change the Asistan's
// password, so they have their own fixture (their own database) and every test puts the old password back.
public class AsistanSifreApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private const string Uc = "/api/yonetim/asistan/sifre";
    private const string YeniParola = "Yeni-Parola-2!";

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private Task<HttpResponseMessage> GirisDeneAsync(string eposta, string parola) =>
        uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = parola }, Ct);

    private async Task<JsonElement> GirisAsync(string eposta, string parola = UygulamaFabrikasi.Parola)
    {
        var yanit = await GirisDeneAsync(eposta, parola);
        yanit.EnsureSuccessStatusCode();
        return JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct)).RootElement.Clone();
    }

    private async Task<HttpResponseMessage> SifreYazAsync(string? token, object govde)
    {
        using var istek = new HttpRequestMessage(HttpMethod.Put, Uc) { Content = JsonContent.Create(govde) };
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await uygulama.CreateClient().SendAsync(istek, Ct);
    }

    [Fact]
    public async Task OnlyTheSahipMaySetIt_AnonymousIs401_TheAsistanIs403_AndNothingChanges()
    {
        var asistan = (await GirisAsync(UygulamaFabrikasi.AsistanEposta)).GetProperty("accessToken").GetString();

        Assert.Equal(HttpStatusCode.Unauthorized, (await SifreYazAsync(null, new { yeniSifre = YeniParola })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await SifreYazAsync(asistan, new { yeniSifre = YeniParola })).StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await GirisDeneAsync(UygulamaFabrikasi.AsistanEposta, UygulamaFabrikasi.Parola)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await GirisDeneAsync(UygulamaFabrikasi.AsistanEposta, YeniParola)).StatusCode);
    }

    [Fact]
    public async Task APasswordThatBreaksTheRules_Is400WithTurkishMessages_AndTheOldPasswordStillWorks()
    {
        var sahip = (await GirisAsync(UygulamaFabrikasi.SahipEposta)).GetProperty("accessToken").GetString();

        var yanit = await SifreYazAsync(sahip, new { yeniSifre = "kisa" });

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        var mesajlar = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct)).RootElement
            .GetProperty("errors").GetProperty("yeniSifre").EnumerateArray().Select(m => m.GetString()).ToList();
        Assert.Contains("Şifre en az 6 karakter olmalı.", mesajlar);
        Assert.Contains("Şifre en az bir rakam içermeli (0-9).", mesajlar);
        Assert.All(mesajlar, m => Assert.DoesNotContain("Passwords must", m));

        Assert.Equal(HttpStatusCode.OK, (await GirisDeneAsync(UygulamaFabrikasi.AsistanEposta, UygulamaFabrikasi.Parola)).StatusCode);
    }

    [Fact]
    public async Task AMissingPassword_Is400()
    {
        var sahip = (await GirisAsync(UygulamaFabrikasi.SahipEposta)).GetProperty("accessToken").GetString();

        Assert.Equal(HttpStatusCode.BadRequest, (await SifreYazAsync(sahip, new { })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await SifreYazAsync(sahip, new { yeniSifre = "   " })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GirisDeneAsync(UygulamaFabrikasi.AsistanEposta, UygulamaFabrikasi.Parola)).StatusCode);
    }

    // The two promises of the endpoint: the new password logs in (the old one does not), and the Asistan's
    // refresh token from before stops working.
    [Fact]
    public async Task ANewPassword_LogsIn_TheOldOneDoesNot_AndTheOldRefreshTokenIsRefused()
    {
        var sahip = (await GirisAsync(UygulamaFabrikasi.SahipEposta)).GetProperty("accessToken").GetString();
        var eskiYenileme = (await GirisAsync(UygulamaFabrikasi.AsistanEposta)).GetProperty("refreshToken").GetString();

        try
        {
            Assert.Equal(HttpStatusCode.NoContent, (await SifreYazAsync(sahip, new { yeniSifre = YeniParola })).StatusCode);

            Assert.Equal(HttpStatusCode.OK, (await GirisDeneAsync(UygulamaFabrikasi.AsistanEposta, YeniParola)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await GirisDeneAsync(UygulamaFabrikasi.AsistanEposta, UygulamaFabrikasi.Parola)).StatusCode);

            var yenileme = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/refresh", new { refreshToken = eskiYenileme }, Ct);
            Assert.Equal(HttpStatusCode.Unauthorized, yenileme.StatusCode);
        }
        finally
        {
            Assert.Equal(HttpStatusCode.NoContent, (await SifreYazAsync(sahip, new { yeniSifre = UygulamaFabrikasi.Parola })).StatusCode);
        }
    }

    // The Sahip's own account is not touched.
    [Fact]
    public async Task TheSahipsOwnPassword_StaysTheSame()
    {
        var sahip = (await GirisAsync(UygulamaFabrikasi.SahipEposta)).GetProperty("accessToken").GetString();

        try
        {
            await SifreYazAsync(sahip, new { yeniSifre = YeniParola });
            Assert.Equal(HttpStatusCode.OK, (await GirisDeneAsync(UygulamaFabrikasi.SahipEposta, UygulamaFabrikasi.Parola)).StatusCode);
        }
        finally
        {
            await SifreYazAsync(sahip, new { yeniSifre = UygulamaFabrikasi.Parola });
        }
    }
}
