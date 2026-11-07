using System.Net;
using System.Net.Http.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The two password pages in a browser's shoes: cookies, antiforgery tokens, no automatic redirects.
// They change passwords, so this class has its own fixture (its own database) and every test puts the old password back.
public partial class SifreSayfalariTests : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string YeniParola = "Yeni-Parola-2!";

    private readonly WebApplicationFactory<Program> _fabrika;
    private readonly UygulamaFabrikasi _uygulama;

    public SifreSayfalariTests(UygulamaFabrikasi uygulama)
    {
        _uygulama = uygulama;
        // The sign-in cookie is normally checked against the security stamp every 30 minutes. Checking it on every
        // request is what makes "the user stays signed in after the change" a real test.
        _fabrika = uygulama.WithWebHostBuilder(b => b.ConfigureTestServices(services =>
            services.Configure<SecurityStampValidatorOptions>(o => o.ValidationInterval = TimeSpan.Zero)));
    }

    public void Dispose() => _fabrika.Dispose();

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    // A browser: its own cookie jar, and redirects are left to the test to read.
    private HttpClient Tarayici() => _fabrika.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false, HandleCookies = true });

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    // Opens the page, reads the antiforgery token out of its form and posts the fields with it.
    private async Task<HttpResponseMessage> FormGonderAsync(HttpClient tarayici, string tokenSayfasi, string yol, Dictionary<string, string> alanlar)
    {
        var sayfa = await tarayici.GetStringAsync(tokenSayfasi, Ct);
        var token = TokenDeseni().Match(sayfa).Groups[1].Value;
        Assert.NotEmpty(token);
        alanlar["__RequestVerificationToken"] = token;
        return await tarayici.PostAsync(yol, new FormUrlEncodedContent(alanlar), Ct);
    }

    private async Task<HttpClient> GirisliTarayiciAsync(string eposta, string parola = UygulamaFabrikasi.Parola)
    {
        var tarayici = Tarayici();
        var yanit = await FormGonderAsync(tarayici, "/Hesap/Giris", "/Hesap/Giris",
            new() { ["Input.Email"] = eposta, ["Input.Sifre"] = parola });
        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        return tarayici;
    }

    // Razor HTML-encodes non-ASCII text (Ş becomes &#x15E;); decode it so the tests can read the Turkish words.
    private async Task<string> GovdeAsync(HttpResponseMessage yanit) => WebUtility.HtmlDecode(await yanit.Content.ReadAsStringAsync(Ct));

    private async Task<HttpStatusCode> ApiGirisiAsync(string eposta, string parola) =>
        (await _uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = parola }, Ct)).StatusCode;

    // Own password (/Hesap/Sifre)

    [Fact]
    public async Task OwnPasswordPage_AsksAnonymousVisitorsToSignIn_AndChangesNothing()
    {
        var tarayici = Tarayici();

        var acma = await tarayici.GetAsync("/Hesap/Sifre", Ct);
        Assert.Equal(HttpStatusCode.Redirect, acma.StatusCode);
        Assert.Equal("/Hesap/Giris", acma.Headers.Location!.AbsolutePath);

        // A token from the (open) sign-in page is valid for the post, so the sign-in check is what has to stop it.
        var gonder = await FormGonderAsync(tarayici, "/Hesap/Giris", "/Hesap/Sifre", new()
        {
            ["Input.MevcutSifre"] = UygulamaFabrikasi.Parola,
            ["Input.YeniSifre"] = YeniParola,
            ["Input.YeniSifreTekrar"] = YeniParola,
        });
        Assert.Equal(HttpStatusCode.Redirect, gonder.StatusCode);
        Assert.Equal("/Hesap/Giris", gonder.Headers.Location!.AbsolutePath);
        Assert.Equal(HttpStatusCode.OK, await ApiGirisiAsync(UygulamaFabrikasi.SahipEposta, UygulamaFabrikasi.Parola));
    }

    [Fact]
    public async Task OwnPassword_Changed_KeepsTheUserSignedIn_AndTheNewPasswordWorks()
    {
        var tarayici = await GirisliTarayiciAsync(UygulamaFabrikasi.SahipEposta);
        Assert.Equal(HttpStatusCode.OK, (await tarayici.GetAsync("/Hesap/Sifre", Ct)).StatusCode);

        try
        {
            var yanit = await FormGonderAsync(tarayici, "/Hesap/Sifre", "/Hesap/Sifre", new()
            {
                ["Input.MevcutSifre"] = UygulamaFabrikasi.Parola,
                ["Input.YeniSifre"] = YeniParola,
                ["Input.YeniSifreTekrar"] = YeniParola,
            });
            Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);

            // Still in: a protected page opens instead of sending the browser to the sign-in page. The stamp is
            // checked on every request here, so this fails if the cookie was not renewed after the change.
            // The toast is read first: any page that renders the layout uses it up.
            var sifreSayfasi = await tarayici.GetAsync("/Hesap/Sifre", Ct);
            Assert.Equal(HttpStatusCode.OK, sifreSayfasi.StatusCode);
            Assert.Contains("Şifren değişti", await GovdeAsync(sifreSayfasi));
            Assert.Equal(HttpStatusCode.OK, (await tarayici.GetAsync("/Yonetim", Ct)).StatusCode);

            Assert.Equal(HttpStatusCode.OK, await ApiGirisiAsync(UygulamaFabrikasi.SahipEposta, YeniParola));
            Assert.Equal(HttpStatusCode.Unauthorized, await ApiGirisiAsync(UygulamaFabrikasi.SahipEposta, UygulamaFabrikasi.Parola));
        }
        finally
        {
            await EskiParolayaDonAsync(UygulamaFabrikasi.SahipEposta);
        }
    }

    [Fact]
    public async Task OwnPassword_WrongCurrentPassword_ShowsTheErrorAndChangesNothing()
    {
        var tarayici = await GirisliTarayiciAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await FormGonderAsync(tarayici, "/Hesap/Sifre", "/Hesap/Sifre", new()
        {
            ["Input.MevcutSifre"] = "Yanlis-Parola-9!",
            ["Input.YeniSifre"] = YeniParola,
            ["Input.YeniSifreTekrar"] = YeniParola,
        });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Contains("Mevcut şifre yanlış.", await GovdeAsync(yanit));
        Assert.Equal(HttpStatusCode.OK, await ApiGirisiAsync(UygulamaFabrikasi.SahipEposta, UygulamaFabrikasi.Parola));
    }

    [Fact]
    public async Task OwnPassword_RuleBreakingAndMismatchedPasswords_ShowTurkishErrors()
    {
        var tarayici = await GirisliTarayiciAsync(UygulamaFabrikasi.SahipEposta);

        var zayif = await FormGonderAsync(tarayici, "/Hesap/Sifre", "/Hesap/Sifre", new()
        {
            ["Input.MevcutSifre"] = UygulamaFabrikasi.Parola,
            ["Input.YeniSifre"] = "kisa",
            ["Input.YeniSifreTekrar"] = "kisa",
        });
        Assert.Equal(HttpStatusCode.OK, zayif.StatusCode);
        Assert.Contains("Şifre en az 6 karakter olmalı.", await GovdeAsync(zayif));

        var farkli = await FormGonderAsync(tarayici, "/Hesap/Sifre", "/Hesap/Sifre", new()
        {
            ["Input.MevcutSifre"] = UygulamaFabrikasi.Parola,
            ["Input.YeniSifre"] = YeniParola,
            ["Input.YeniSifreTekrar"] = "Baska-Parola-3!",
        });
        Assert.Equal(HttpStatusCode.OK, farkli.StatusCode);
        Assert.Contains("Şifreler aynı değil.", await GovdeAsync(farkli));

        Assert.Equal(HttpStatusCode.OK, await ApiGirisiAsync(UygulamaFabrikasi.SahipEposta, UygulamaFabrikasi.Parola));
    }

    [Fact]
    public async Task OwnPassword_PostWithoutAntiforgeryToken_IsRefused()
    {
        var tarayici = await GirisliTarayiciAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await tarayici.PostAsync("/Hesap/Sifre", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Input.MevcutSifre"] = UygulamaFabrikasi.Parola,
            ["Input.YeniSifre"] = YeniParola,
            ["Input.YeniSifreTekrar"] = YeniParola,
        }), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.Equal(HttpStatusCode.OK, await ApiGirisiAsync(UygulamaFabrikasi.SahipEposta, UygulamaFabrikasi.Parola));
    }

    // The Asistan's password (/Yonetim)

    [Fact]
    public async Task ManagementPage_SetsTheAsistansPassword_AndTheOldRefreshTokenIsRefused()
    {
        var tarayici = await GirisliTarayiciAsync(UygulamaFabrikasi.SahipEposta);
        var eskiYenileme = (await (await _uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login",
            new { email = UygulamaFabrikasi.AsistanEposta, password = UygulamaFabrikasi.Parola }, Ct)).Content.ReadFromJsonAsync<Dictionary<string, object>>(Ct))!["refreshToken"];

        try
        {
            var yanit = await FormGonderAsync(tarayici, "/Yonetim", "/Yonetim?handler=AsistanSifre", new()
            {
                ["Sifre.YeniSifre"] = YeniParola,
                ["Sifre.YeniSifreTekrar"] = YeniParola,
            });
            Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);

            // The toast shows once on the page the redirect lands on.
            Assert.Contains("Asistan'ın şifresi değişti, oturumları kapatıldı", await GovdeAsync(await tarayici.GetAsync("/Yonetim", Ct)));

            Assert.Equal(HttpStatusCode.OK, await ApiGirisiAsync(UygulamaFabrikasi.AsistanEposta, YeniParola));
            Assert.Equal(HttpStatusCode.Unauthorized, await ApiGirisiAsync(UygulamaFabrikasi.AsistanEposta, UygulamaFabrikasi.Parola));
            var yenileme = await _uygulama.CreateClient().PostAsJsonAsync("/api/hesap/refresh", new { refreshToken = eskiYenileme?.ToString() }, Ct);
            Assert.Equal(HttpStatusCode.Unauthorized, yenileme.StatusCode);
        }
        finally
        {
            await EskiParolayaDonAsync(UygulamaFabrikasi.AsistanEposta);
        }
    }

    [Fact]
    public async Task ManagementPage_MismatchedOrRuleBreakingPasswords_ShowTurkishErrors_AndChangeNothing()
    {
        var tarayici = await GirisliTarayiciAsync(UygulamaFabrikasi.SahipEposta);

        var farkli = await FormGonderAsync(tarayici, "/Yonetim", "/Yonetim?handler=AsistanSifre", new()
        {
            ["Sifre.YeniSifre"] = YeniParola,
            ["Sifre.YeniSifreTekrar"] = "Baska-Parola-3!",
        });
        Assert.Equal(HttpStatusCode.OK, farkli.StatusCode);
        Assert.Contains("Şifreler aynı değil.", await GovdeAsync(farkli));

        var zayif = await FormGonderAsync(tarayici, "/Yonetim", "/Yonetim?handler=AsistanSifre", new()
        {
            ["Sifre.YeniSifre"] = "kisa",
            ["Sifre.YeniSifreTekrar"] = "kisa",
        });
        Assert.Equal(HttpStatusCode.OK, zayif.StatusCode);
        Assert.Contains("Şifre en az 6 karakter olmalı.", await GovdeAsync(zayif));

        Assert.Equal(HttpStatusCode.OK, await ApiGirisiAsync(UygulamaFabrikasi.AsistanEposta, UygulamaFabrikasi.Parola));
    }

    // Puts the test password back through Identity itself, so a failed assertion above cannot leave a changed password behind.
    private async Task EskiParolayaDonAsync(string eposta)
    {
        using var kapsam = _uygulama.Services.CreateScope();
        var kullanicilar = kapsam.ServiceProvider.GetRequiredService<UserManager<IdentityUser<Guid>>>();
        var kullanici = (await kullanicilar.FindByEmailAsync(eposta))!;
        var sonuc = await kullanicilar.ResetPasswordAsync(kullanici, await kullanicilar.GeneratePasswordResetTokenAsync(kullanici), UygulamaFabrikasi.Parola);
        Assert.True(sonuc.Succeeded);
    }
}
