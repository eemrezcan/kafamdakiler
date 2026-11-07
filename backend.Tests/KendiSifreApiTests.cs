using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Kafamdakiler.Tests;

// What the mobile app relies on when a user changes their own password: Identity's ready-made
// POST /api/hesap/manage/info. Own fixture (own database); every test puts the old password back.
public class KendiSifreApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private const string YeniParola = "Yeni-Parola-2!";

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private async Task<JsonElement> GirisAsync(string parola)
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = UygulamaFabrikasi.AsistanEposta, password = parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        return JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct)).RootElement.Clone();
    }

    private async Task<HttpResponseMessage> SifreDegistirAsync(string token, string mevcut, string yeni)
    {
        using var istek = new HttpRequestMessage(HttpMethod.Post, "/api/hesap/manage/info")
        {
            Content = JsonContent.Create(new { oldPassword = mevcut, newPassword = yeni }),
        };
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await uygulama.CreateClient().SendAsync(istek, Ct);
    }

    [Fact]
    public async Task WrongCurrentPassword_AndRuleBreakingNewPassword_Are400WithTurkishMessages()
    {
        var token = (await GirisAsync(UygulamaFabrikasi.Parola)).GetProperty("accessToken").GetString()!;

        var yanlis = await SifreDegistirAsync(token, "Yanlis-Parola-9!", YeniParola);
        Assert.Equal(HttpStatusCode.BadRequest, yanlis.StatusCode);
        Assert.Contains("Mevcut şifre yanlış.", await yanlis.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);

        var zayif = await SifreDegistirAsync(token, UygulamaFabrikasi.Parola, "kisa");
        Assert.Equal(HttpStatusCode.BadRequest, zayif.StatusCode);
        Assert.Contains("Şifre en az 6 karakter olmalı.", await zayif.Content.ReadAsStringAsync(Ct), StringComparison.Ordinal);

        Assert.Equal(HttpStatusCode.OK, (await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login",
            new { email = UygulamaFabrikasi.AsistanEposta, password = UygulamaFabrikasi.Parola }, Ct)).StatusCode);
    }

    // The reason the mobile app signs in again after a change: the refresh token it held is refused afterwards.
    [Fact]
    public async Task ChangingYourOwnPassword_RefusesTheOldRefreshToken_ButTheNewPasswordSignsIn()
    {
        var eski = await GirisAsync(UygulamaFabrikasi.Parola);
        var token = eski.GetProperty("accessToken").GetString()!;
        var eskiYenileme = eski.GetProperty("refreshToken").GetString();

        try
        {
            Assert.Equal(HttpStatusCode.OK, (await SifreDegistirAsync(token, UygulamaFabrikasi.Parola, YeniParola)).StatusCode);

            var yenileme = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/refresh", new { refreshToken = eskiYenileme }, Ct);
            Assert.Equal(HttpStatusCode.Unauthorized, yenileme.StatusCode);
            Assert.NotEmpty((await GirisAsync(YeniParola)).GetProperty("refreshToken").GetString()!);
        }
        finally
        {
            var yeni = (await GirisAsync(YeniParola)).GetProperty("accessToken").GetString()!;
            Assert.Equal(HttpStatusCode.OK, (await SifreDegistirAsync(yeni, YeniParola, UygulamaFabrikasi.Parola)).StatusCode);
        }
    }
}
