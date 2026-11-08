using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The approval queue pages of the web (the Sahip decides), in a browser's shoes: cookies, antiforgery tokens, no automatic redirects.
public sealed partial class EylemSayfalariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private const string Tur = "hatirlatici-kur";
    private const string Kotu = "<script>alert('xss')</script>";

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    private Task<HttpClient> SahipAsync() => WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);

    // Opens a page, takes the antiforgery token from its form and posts the fields with it.
    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string tokenSayfasi, string yol, Dictionary<string, string>? alanlar = null)
    {
        var sayfa = await tarayici.GetStringAsync(tokenSayfasi, Ct);
        var token = TokenDeseni().Match(sayfa).Groups[1].Value;
        Assert.NotEmpty(token);
        var govde = new Dictionary<string, string>(alanlar ?? []) { ["__RequestVerificationToken"] = token };
        return await tarayici.PostAsync(yol, new FormUrlEncodedContent(govde), Ct);
    }

    private async Task KipSifirlaAsync()
    {
        using var db = uygulama.YeniDb();
        await db.EylemIzinleri.Where(i => i.Tur == Tur).ExecuteDeleteAsync(Ct);
    }

    private async Task<Guid> BekleyenAsync(string baslik, bool disKaynak = false, string? ozet = null, double? guven = null, object? yuk = null)
    {
        await KipSifirlaAsync();
        using var kapsam = uygulama.Services.CreateScope();
        var servis = kapsam.ServiceProvider.GetRequiredService<EylemServisi>();
        var sonuc = await servis.OnerAsync(new EylemOnerisi(Tur, JsonSerializer.SerializeToElement(yuk ?? new { baslik, gun = "2030-01-01" }),
            ozet ?? baslik, "gelen", disKaynak, "Mailde yazıyor", guven), Ct);
        Assert.Equal(EylemDurumu.Bekliyor, sonuc.Eylem!.Durum);
        return sonuc.Eylem.Id;
    }

    private static string Baslik() => "Web " + Guid.NewGuid().ToString("N");

    private async Task<Eylem> EylemAsync(Guid id)
    {
        using var db = uygulama.YeniDb();
        return await db.Eylemler.AsNoTracking().SingleAsync(e => e.Id == id, Ct);
    }

    private async Task<Hatirlatici?> HatirlaticiAsync(string baslik)
    {
        using var db = uygulama.YeniDb();
        return await db.Hatirlaticilar.SingleOrDefaultAsync(h => h.Baslik == baslik, Ct);
    }

    [Fact]
    public async Task Pages_AreForTheSahipOnly()
    {
        var id = await BekleyenAsync(Baslik());
        var anonim = uygulama.CreateClient(new() { AllowAutoRedirect = false });
        foreach (var yol in new[] { "/Eylemler", $"/Eylemler/Detay/{id}" })
        {
            var yanit = await anonim.GetAsync(yol, Ct);
            Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
            Assert.Contains("/Hesap/Giris", yanit.Headers.Location!.OriginalString);
        }

        // The Asistan has no web pages, whatever permissions it holds.
        var asistan = await WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.AsistanEposta, Ct);
        Assert.NotEqual(HttpStatusCode.OK, (await asistan.GetAsync("/Eylemler", Ct)).StatusCode);
    }

    [Fact]
    public async Task List_ShowsWhatWaits_WithSourceReasonAndWarnings_AndNeverAsMarkup()
    {
        var baslik = Baslik();
        await BekleyenAsync(baslik, disKaynak: true, ozet: baslik + " " + Kotu, guven: 0.3);
        var tarayici = await SahipAsync();

        var yanit = await tarayici.GetAsync("/Eylemler", Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var ham = await WebOturumu.HamAsync(yanit, Ct);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);
        Assert.Contains(baslik, metin);
        Assert.Contains("Hatırlatıcı kur", metin);
        Assert.Contains("Gelen kutusu", metin);
        Assert.Contains("Mailde yazıyor", metin);
        Assert.Contains("Dış kaynak", metin);
        Assert.Contains("Emin değil", metin);
        Assert.Contains("%30", metin);
        Assert.Contains("Bir daha önerme", metin);
        Assert.DoesNotContain("<script>alert", ham);
        Assert.Contains("Onay kuyruğu", metin);
        // The queue has no menu entry of its own (and so no badge): the inbox entry is the lit one, and the badge on it
        // counts placement suggestions only, which this "reminder" action is not.
        var etkinMenu = Regex.Match(ham, "class=\"kd-nav-link active\"[^>]*>\\s*([^<\\s]+)");
        Assert.True(etkinMenu.Success);
        Assert.Equal("Gelen", etkinMenu.Groups[1].Value);
        Assert.DoesNotContain("href=\"/Eylemler\" class=\"kd-nav-link", ham);
        Assert.DoesNotContain("class=\"kd-badge\"", ham);
    }

    [Fact]
    public async Task Approve_AppliesIt_AndTheUndoButtonArchivesIt()
    {
        var baslik = Baslik();
        var id = await BekleyenAsync(baslik);
        var tarayici = await SahipAsync();

        var uygula = await PostAsync(tarayici, "/Eylemler", $"/Eylemler?handler=Uygula&id={id}");

        Assert.Equal(HttpStatusCode.Redirect, uygula.StatusCode);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAsync(id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiAsync(baslik))!.Durum);
        var liste = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Eylemler", Ct), Ct);
        Assert.Contains("Son uygulananlar", liste);
        Assert.Contains($"id=\"e-{id}\"", await WebOturumu.HamAsync(await tarayici.GetAsync("/Eylemler", Ct), Ct));

        var geriAl = await PostAsync(tarayici, "/Eylemler", $"/Eylemler?handler=GeriAl&id={id}");

        Assert.Equal(HttpStatusCode.Redirect, geriAl.StatusCode);
        Assert.Equal(EylemDurumu.GeriAlindi, (await EylemAsync(id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Arsiv, (await HatirlaticiAsync(baslik))!.Durum);

        // A second approval is refused with a message, not a crash.
        var tekrar = await PostAsync(tarayici, "/Eylemler", $"/Eylemler?handler=Uygula&id={id}");
        Assert.Equal(HttpStatusCode.Redirect, tekrar.StatusCode);
        Assert.Contains("yalnız bekleyen eylem uygulanabilir", await WebOturumu.MetinAsync(await tarayici.GetAsync("/Eylemler", Ct), Ct));
    }

    [Fact]
    public async Task Reject_WithNeverAgain_MakesTheKindYasak()
    {
        var baslik = Baslik();
        var id = await BekleyenAsync(baslik);
        var tarayici = await SahipAsync();

        var yanit = await PostAsync(tarayici, "/Eylemler", $"/Eylemler?handler=Reddet&id={id}", new() { ["birDahaOnerme"] = "true" });

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(EylemDurumu.Reddedildi, (await EylemAsync(id)).Durum);
        Assert.Null(await HatirlaticiAsync(baslik));
        using var db = uygulama.YeniDb();
        Assert.Equal(EylemKipi.Yasak, (await db.EylemIzinleri.SingleAsync(i => i.Tur == Tur, Ct)).Kip);
        await KipSifirlaAsync();
    }

    [Fact]
    public async Task Reject_WithoutTheTick_KeepsTheMode()
    {
        var id = await BekleyenAsync(Baslik());
        var tarayici = await SahipAsync();

        await PostAsync(tarayici, "/Eylemler", $"/Eylemler?handler=Reddet&id={id}");

        Assert.Equal(EylemDurumu.Reddedildi, (await EylemAsync(id)).Durum);
        using var db = uygulama.YeniDb();
        Assert.Equal(EylemKipi.Sor, (await db.EylemIzinleri.SingleAsync(i => i.Tur == Tur, Ct)).Kip);
    }

    [Fact]
    public async Task Detail_ShowsThePayload_AndAppliesACorrectedOne()
    {
        var id = await BekleyenAsync(Baslik());
        var duzeltilmis = Baslik();
        var tarayici = await SahipAsync();

        var sayfa = await tarayici.GetAsync($"/Eylemler/Detay/{id}", Ct);
        Assert.Equal(HttpStatusCode.OK, sayfa.StatusCode);
        var metin = await WebOturumu.MetinAsync(sayfa, Ct);
        Assert.Contains("\"gun\": \"2030-01-01\"", metin);
        Assert.Contains("Mailde yazıyor", metin);

        var yanit = await PostAsync(tarayici, $"/Eylemler/Detay/{id}", $"/Eylemler/Detay/{id}?handler=Uygula",
            new() { ["Yuk"] = $$"""{ "baslik": "{{duzeltilmis}}", "gun": "2031-02-03" }""" });

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAsync(id)).Durum);
        var h = await HatirlaticiAsync(duzeltilmis);
        Assert.Equal(new DateOnly(2031, 2, 3), h!.Gun);
    }

    [Theory]
    [InlineData("{ bu json degil", "geçerli bir JSON değil")]
    [InlineData("""{ "baslik": "", "gun": "2030-01-01" }""", "Başlık zorunlu")]
    [InlineData("""{ "baslik": "x", "gun": "2030-01-01", "uydurma": 1 }""", "Yük hatırlatıcı biçimine uymuyor")]
    public async Task Detail_RefusesABadPayload_KeepsTheTextAndTheAction(string yuk, string mesaj)
    {
        var id = await BekleyenAsync(Baslik());
        var tarayici = await SahipAsync();

        var yanit = await PostAsync(tarayici, $"/Eylemler/Detay/{id}", $"/Eylemler/Detay/{id}?handler=Uygula", new() { ["Yuk"] = yuk });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);
        Assert.Contains(mesaj, metin);
        Assert.Contains(yuk.Split('\n')[0], metin);
        Assert.Equal(EylemDurumu.Bekliyor, (await EylemAsync(id)).Durum);
    }

    [Fact]
    public async Task Detail_Reject_AndUnknownId()
    {
        var id = await BekleyenAsync(Baslik());
        var tarayici = await SahipAsync();

        var yanit = await PostAsync(tarayici, $"/Eylemler/Detay/{id}", $"/Eylemler/Detay/{id}?handler=Reddet");
        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(EylemDurumu.Reddedildi, (await EylemAsync(id)).Durum);

        // Decided already: the page shows the payload read-only.
        var salt = await WebOturumu.MetinAsync(await tarayici.GetAsync($"/Eylemler/Detay/{id}", Ct), Ct);
        Assert.Contains("Reddedildi", salt);
        Assert.DoesNotContain("<textarea", salt);

        Assert.Equal(HttpStatusCode.NotFound, (await tarayici.GetAsync($"/Eylemler/Detay/{Guid.CreateVersion7()}", Ct)).StatusCode);
    }

    [Fact]
    public async Task Yonetim_ListsTheKinds_AndSetsTheirModes()
    {
        await KipSifirlaAsync();
        var tarayici = await SahipAsync();

        var sayfa = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Yonetim", Ct), Ct);
        Assert.Contains("Eylem kipleri", sayfa);
        Assert.Contains("Gelişmiş", sayfa);
        Assert.Contains("Sor: ", sayfa);
        Assert.Contains("Hatırlatıcı kur", sayfa);
        Assert.Contains("Önce onayını bekler.", sayfa);

        var yanit = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=EylemKipi", new() { ["tur"] = Tur, ["kip"] = "KendinYap" });
        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        using (var db = uygulama.YeniDb())
            Assert.Equal(EylemKipi.KendinYap, (await db.EylemIzinleri.SingleAsync(i => i.Tur == Tur, Ct)).Kip);
        var sonra = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Yonetim", Ct), Ct);
        Assert.Contains("Hemen uygular", sonra);
        Assert.Contains("Kendin yap: 1 tür", sonra);

        // Wrong values change nothing.
        Assert.Equal(HttpStatusCode.NotFound, (await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=EylemKipi", new() { ["tur"] = "olmayan", ["kip"] = "Sor" })).StatusCode);
        foreach (var kip in new[] { "belki", "1", "99", "" })
            Assert.Equal(HttpStatusCode.BadRequest, (await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=EylemKipi", new() { ["tur"] = Tur, ["kip"] = kip })).StatusCode);
        using (var db = uygulama.YeniDb())
            Assert.Equal(EylemKipi.KendinYap, (await db.EylemIzinleri.SingleAsync(i => i.Tur == Tur, Ct)).Kip);
        await KipSifirlaAsync();
    }
}
