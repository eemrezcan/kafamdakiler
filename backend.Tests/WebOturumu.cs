using System.Net;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// A browser's shoes for the page tests: its own cookie jar, no automatic redirects, a real sign-in with the antiforgery token.
internal static partial class WebOturumu
{
    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    public static async Task<HttpClient> GirisliAsync(WebApplicationFactory<Program> fabrika, string eposta, CancellationToken ct)
    {
        var tarayici = fabrika.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false, HandleCookies = true });
        var sayfa = await tarayici.GetStringAsync("/Hesap/Giris", ct);
        var token = TokenDeseni().Match(sayfa).Groups[1].Value;
        Assert.NotEmpty(token);

        var yanit = await tarayici.PostAsync("/Hesap/Giris", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["Input.Email"] = eposta,
            ["Input.Sifre"] = UygulamaFabrikasi.Parola,
            ["__RequestVerificationToken"] = token,
        }), ct);
        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        return tarayici;
    }

    // The page exactly as the server sent it: what a browser parses. Security checks read this one.
    public static Task<string> HamAsync(HttpResponseMessage yanit, CancellationToken ct) => yanit.Content.ReadAsStringAsync(ct);

    // The text a person reads (Razor writes Ş as &#x15E;). Never use it to look for markup: it turns &lt; back into <.
    public static async Task<string> MetinAsync(HttpResponseMessage yanit, CancellationToken ct) =>
        WebUtility.HtmlDecode(await HamAsync(yanit, ct));
}
