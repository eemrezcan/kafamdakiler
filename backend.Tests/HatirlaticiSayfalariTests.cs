using System.Net;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The reminder form of the web (H4): the persistent fields are shown and sent, so editing a reminder and saving it no longer
// puts them back to their defaults. In a browser's shoes: cookies, antiforgery tokens, no automatic redirects.
public sealed partial class HatirlaticiSayfalariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private static string Gun => DateOnly.FromDateTime(DateTime.UtcNow).AddDays(10).ToString("yyyy-MM-dd");

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string yol, Dictionary<string, string> alanlar)
    {
        var sayfa = await tarayici.GetStringAsync(yol, Ct);
        var token = TokenDeseni().Match(sayfa).Groups[1].Value;
        Assert.NotEmpty(token);
        var govde = new Dictionary<string, string>(alanlar) { ["__RequestVerificationToken"] = token };
        return await tarayici.PostAsync(yol, new FormUrlEncodedContent(govde), Ct);
    }

    private static Dictionary<string, string> Form(string baslik, string israrli, string aralik, string enCok, string acil) => new()
    {
        ["Input.Baslik"] = baslik,
        ["Input.Tur"] = "Gorev",
        ["Input.Gun"] = Gun,
        ["Input.Tekrar"] = "Yok",
        ["Input.OnceGun"] = "0",
        ["Input.Durum"] = "Acik",
        ["Input.Israrli"] = israrli,
        ["Input.IsrarAraligiDakika"] = aralik,
        ["Input.IsrarEnCok"] = enCok,
        ["Input.Acil"] = acil,
    };

    private async Task<Kafamdakiler.Hatirlaticilar.Hatirlatici> BulAsync(string baslik)
    {
        await using var db = uygulama.YeniDb();
        return await db.Hatirlaticilar.AsNoTracking().SingleAsync(h => h.Baslik == baslik, Ct);
    }

    [Fact]
    public async Task TheEditForm_ShowsThePersistentFields_AndSavingKeepsThem()
    {
        var tarayici = await WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);
        var baslik = "Israrlı " + Guid.NewGuid().ToString("N");

        var yeni = await PostAsync(tarayici, "/Hatirlaticilar/Duzenle", Form(baslik, "true", "5", "4", "true"));
        Assert.Equal(HttpStatusCode.Redirect, yeni.StatusCode);
        var kayit = await BulAsync(baslik);
        Assert.True(kayit.Israrli);
        Assert.Equal(5, kayit.IsrarAraligiDakika);
        Assert.Equal(4, kayit.IsrarEnCok);
        Assert.True(kayit.Acil);

        // The form shows what is stored, not the defaults.
        var sayfa = await WebOturumu.HamAsync(await tarayici.GetAsync($"/Hatirlaticilar/Duzenle/{kayit.Id}", Ct), Ct);
        Assert.Matches("<input[^>]*type=\"checkbox\"[^>]*name=\"Input.Israrli\"[^>]*checked=\"checked\"|<input[^>]*checked=\"checked\"[^>]*name=\"Input.Israrli\"", sayfa);
        Assert.Matches("<input[^>]*type=\"checkbox\"[^>]*name=\"Input.Acil\"[^>]*checked=\"checked\"|<input[^>]*checked=\"checked\"[^>]*name=\"Input.Acil\"", sayfa);
        Assert.Matches("<option[^>]*value=\"5\"[^>]*selected=\"selected\"|<option[^>]*selected=\"selected\"[^>]*value=\"5\"", sayfa);
        Assert.DoesNotMatch("<option[^>]*value=\"15\"[^>]*selected", sayfa);
        Assert.Matches("name=\"Input.IsrarEnCok\"[^>]*value=\"4\"|value=\"4\"[^>]*name=\"Input.IsrarEnCok\"", sayfa);

        // Saving the form as it was rendered changes nothing; saving with other values changes them.
        var ayni = await PostAsync(tarayici, $"/Hatirlaticilar/Duzenle/{kayit.Id}", Form(baslik, "true", "5", "4", "true"));
        Assert.Equal(HttpStatusCode.Redirect, ayni.StatusCode);
        var sonra = await BulAsync(baslik);
        Assert.True(sonra.Israrli);
        Assert.Equal(5, sonra.IsrarAraligiDakika);
        Assert.Equal(4, sonra.IsrarEnCok);
        Assert.True(sonra.Acil);

        var degisen = await PostAsync(tarayici, $"/Hatirlaticilar/Duzenle/{kayit.Id}", Form(baslik, "false", "60", "1", "false"));
        Assert.Equal(HttpStatusCode.Redirect, degisen.StatusCode);
        var son = await BulAsync(baslik);
        Assert.False(son.Israrli);
        Assert.Equal(60, son.IsrarAraligiDakika);
        Assert.Equal(1, son.IsrarEnCok);
        Assert.False(son.Acil);
    }

    [Fact]
    public async Task ABadInterval_IsRefused_AndNothingIsStored()
    {
        var tarayici = await WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);
        var baslik = "Kötü aralık " + Guid.NewGuid().ToString("N");

        var yanit = await PostAsync(tarayici, "/Hatirlaticilar/Duzenle", Form(baslik, "true", "10", "9", "false"));

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        await using var db = uygulama.YeniDb();
        Assert.DoesNotContain(await db.Hatirlaticilar.AsNoTracking().ToListAsync(Ct), h => h.Baslik == baslik);
    }
}
