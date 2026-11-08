using System.Net;
using System.Text.RegularExpressions;
using Kafamdakiler.ProjeRepolari;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The web pages of the Kat 2 modules, in a browser's shoes (cookies, antiforgery tokens, no automatic redirects): the repository card
// and its link form, the Google Calendar part of Yönetim, the briefing and the timeline. Fakes stand in for the brain, GitHub and Google.
public sealed partial class KatIkiWebSayfalariTests(UygulamaFabrikasi uygulama) : TakvimTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Proje = "kitap-kulubu";

    private readonly SahteGitHub _github = new();
    private readonly List<SahteBeyin> _beyinler = [];

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    public new void Dispose()
    {
        foreach (var b in _beyinler)
            b.Dispose();
        base.Dispose();
    }

    private const string ProjeListesi = """
        [{"kimlik": "kitap-kulubu", "yol": "projects/kitap-kulubu/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false}]
        """;

    private const string ProjeAyrintisi = """
        {"kimlik": "kitap-kulubu", "baslik": "Kitap Kulübü Sitesi", "yol": "projects/kitap-kulubu/index.md",
         "durum": "Okuma listesi sayfası bitti.", "siradaki_adim": "Buluşma takvimi sayfası.", "acik_gorevler": [], "son_gunluk": []}
        """;

    private const string GunPlani = """
        {"tarih": "2026-11-07", "gun_adi": "7 Kasım 2026", "hafta_gunu": "Cumartesi", "bugun": true, "plan_var": true, "kapandi": false,
         "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{"no": 1, "id": "a1", "baslik": "Benzersiz plan işi", "durum": "acik", "tahmin_dk": 30}]}]}
        """;

    // The app with the fake brain (when given), the fake GitHub, and the Google settings (the base class's).
    private WebApplicationFactory<Program> WebFabrika(SahteBeyin? beyin = null, string? githubToken = "gizli-token", bool google = true, DateTimeOffset? an = null) =>
        Fabrika(an, google, ek: b =>
        {
            if (beyin is not null)
                b.UseSetting("Beyin:Komut", beyin.Komut).UseSetting("Beyin:Vault", beyin.Vault);
            if (githubToken is not null)
                b.UseSetting("GitHub:Token", githubToken);
            b.ConfigureTestServices(s => s.AddSingleton<Kafamdakiler.ProjeRepolari.IGitHubIstemcisi>(_github));
        });

    private SahteBeyin Beyin(Action<SahteBeyin> kur)
    {
        var beyin = new SahteBeyin("ok");
        kur(beyin);
        _beyinler.Add(beyin);
        return beyin;
    }

    private async Task<HttpClient> SahipAsync(WebApplicationFactory<Program> fabrika) =>
        await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string tokenSayfasi, string yol, Dictionary<string, string>? alanlar = null)
    {
        var sayfa = await tarayici.GetStringAsync(tokenSayfasi, Ct);
        var token = TokenDeseni().Match(sayfa).Groups[1].Value;
        Assert.NotEmpty(token);
        var govde = new Dictionary<string, string>(alanlar ?? []) { ["__RequestVerificationToken"] = token };
        return await tarayici.PostAsync(yol, new FormUrlEncodedContent(govde), Ct);
    }

    private async Task<string> MetinAsync(HttpClient tarayici, string yol)
    {
        var yanit = await tarayici.GetAsync(yol, Ct);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return await WebOturumu.MetinAsync(yanit, Ct);
    }

    private async Task RepoTemizleAsync()
    {
        await using var db = YeniDb();
        await db.ProjeRepolari.ExecuteDeleteAsync(Ct);
    }

    // The repository card (project page)

    [Fact]
    public async Task ProjectPage_ShowsTheRepoCard_WithTheLink_TheCommitsAndThePullRequests()
    {
        await RepoTemizleAsync();
        await using (var db = YeniDb())
        {
            db.ProjeRepolari.Add(new ProjeRepo { ProjeKimligi = Proje, Depo = "emre/kitap" });
            await db.SaveChangesAsync(Ct);
        }

        var beyin = Beyin(b => b.Cikti(ProjeAyrintisi));
        var tarayici = await SahipAsync(WebFabrika(beyin));

        var sayfa = await MetinAsync(tarayici, $"/Beyin/Proje/{Proje}");

        Assert.Contains("href=\"https://github.com/emre/kitap\"", sayfa);
        Assert.Contains("feat: add the repo card", sayfa);
        Assert.DoesNotContain("A long body that the card does not show", sayfa);
        Assert.Contains("0123456", sayfa);
        Assert.Contains("Açık PR: 3", sayfa);
        Assert.Equal("emre/kitap", Assert.Single(_github.Istekler).Depo);
    }

    [Fact]
    public async Task ProjectPage_WithoutAToken_ShowsOnlyTheLink_AndWithoutALink_NoCard()
    {
        await RepoTemizleAsync();
        var beyin = Beyin(b => b.Cikti(ProjeAyrintisi));
        var tarayici = await SahipAsync(WebFabrika(beyin, githubToken: null));

        var kartsiz = await MetinAsync(tarayici, $"/Beyin/Proje/{Proje}");
        Assert.DoesNotContain("repo-baslik", kartsiz);

        await using (var db = YeniDb())
        {
            db.ProjeRepolari.Add(new ProjeRepo { ProjeKimligi = Proje, Depo = "emre/kitap" });
            await db.SaveChangesAsync(Ct);
        }

        var sayfa = await MetinAsync(tarayici, $"/Beyin/Proje/{Proje}");
        Assert.Contains("href=\"https://github.com/emre/kitap\"", sayfa);
        Assert.Contains("token'ı ayarlı değil", sayfa);
        Assert.DoesNotContain("feat: add the repo card", sayfa);
        Assert.Equal(0, _github.CagriSayisi);
    }

    // The link form (Yönetim)

    [Fact]
    public async Task Yonetim_LinksAProjectToARepo_RefusesABadOneAndAnUnknownProject_AndRemovesTheLink()
    {
        await RepoTemizleAsync();
        var beyin = Beyin(b => b.Cikti("proje liste", ProjeListesi));
        var tarayici = await SahipAsync(WebFabrika(beyin));

        var form = await MetinAsync(tarayici, "/Yonetim");
        Assert.Contains("<option value=\"kitap-kulubu\">Kitap Kulübü Sitesi</option>", form);

        var kotu = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=RepoAyarla", new() { ["proje"] = Proje, ["depo"] = "owner/repo/fazla" });
        Assert.Equal(HttpStatusCode.Redirect, kotu.StatusCode);
        Assert.Contains(DepoAdi.Mesaj, await MetinAsync(tarayici, "/Yonetim"));

        var yok = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=RepoAyarla", new() { ["proje"] = "olmayan-proje", ["depo"] = "emre/kitap" });
        Assert.Equal(HttpStatusCode.Redirect, yok.StatusCode);
        Assert.Contains("Böyle bir proje yok.", await MetinAsync(tarayici, "/Yonetim"));
        await using (var db = YeniDb())
            Assert.Empty(await db.ProjeRepolari.ToListAsync(Ct));

        var iyi = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=RepoAyarla", new() { ["proje"] = Proje, ["depo"] = " emre/kitap " });
        Assert.Equal(HttpStatusCode.Redirect, iyi.StatusCode);
        await using (var db = YeniDb())
            Assert.Equal("emre/kitap", Assert.Single(await db.ProjeRepolari.ToListAsync(Ct)).Depo);
        Assert.Contains("href=\"https://github.com/emre/kitap\"", await MetinAsync(tarayici, "/Yonetim"));

        var sil = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=RepoSil", new() { ["proje"] = Proje });
        Assert.Equal(HttpStatusCode.Redirect, sil.StatusCode);
        await using (var db = YeniDb())
            Assert.Empty(await db.ProjeRepolari.ToListAsync(Ct));
    }

    // Google Calendar (Yönetim)

    [Fact]
    public async Task Yonetim_GoogleSettingsMissing_SaysTheCalendarIsOff()
    {
        await TemizleAsync();
        var tarayici = await SahipAsync(WebFabrika(google: false));

        var sayfa = await MetinAsync(tarayici, "/Yonetim");

        Assert.Contains("takvim kapalı", sayfa);
        Assert.DoesNotContain("Google Takvim'i bağla", sayfa);
    }

    [Fact]
    public async Task Yonetim_ConnectsThroughTheCallback_ShowsTheStatus_AndCutsTheConnection()
    {
        await TemizleAsync();
        var fabrika = WebFabrika();
        var tarayici = await SahipAsync(fabrika);

        var onceki = await MetinAsync(tarayici, "/Yonetim");
        Assert.Contains("Google Takvim'i bağla", onceki);
        Assert.DoesNotContain("Bağlantıyı kes", onceki);

        // To Google's consent screen; its state ties the return to this connect.
        var baslat = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=GoogleBagla");
        Assert.Equal(HttpStatusCode.Redirect, baslat.StatusCode);
        var adres = baslat.Headers.Location!.OriginalString;
        Assert.StartsWith("https://accounts.google.com/", adres);
        var state = QueryDegeri(adres, "state");

        var donus = await tarayici.GetAsync($"/google/donus?state={Uri.EscapeDataString(state)}&code=kod-1", Ct);
        Assert.Equal(HttpStatusCode.Redirect, donus.StatusCode);
        var yonetim = await MetinAsync(tarayici, donus.Headers.Location!.OriginalString);
        Assert.Contains("Google Takvim bağlandı.", yonetim);
        Assert.Contains("Bağlantıyı kes", yonetim);
        Assert.DoesNotContain("Google Takvim'i bağla", yonetim);

        var kes = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=GoogleKes");
        Assert.Equal(HttpStatusCode.Redirect, kes.StatusCode);
        await using (var db = YeniDb())
            Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
        var sonra = await MetinAsync(tarayici, "/Yonetim");
        Assert.Contains("Google Takvim'i bağla", sonra);
        Assert.Contains("Google Takvim bağlantısı kesildi", sonra);
    }

    [Fact]
    public async Task Yonetim_GoogleConnected_ShowsTheLastSyncAndSyncsNow_NotConnected_ShowsOnlyTheConnectRow()
    {
        await TemizleAsync();
        var tarayici = await SahipAsync(WebFabrika());

        var bagliDegil = await MetinAsync(tarayici, "/Yonetim");
        Assert.Contains("Google Takvim'i bağla", bagliDegil);
        Assert.DoesNotContain("Şimdi eşitle", bagliDegil);
        Assert.DoesNotContain("Son eşitleme", bagliDegil);

        var baslat = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=GoogleBagla");
        var state = QueryDegeri(baslat.Headers.Location!.OriginalString, "state");
        await tarayici.GetAsync($"/google/donus?state={Uri.EscapeDataString(state)}&code=kod-1", Ct);

        var bagli = await MetinAsync(tarayici, "/Yonetim");
        Assert.Contains("Son eşitleme", bagli);
        Assert.Contains("Şimdi eşitle", bagli);
        Assert.DoesNotContain("Google Takvim'i bağla", bagli);

        var esitle = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=GoogleEsitle");
        Assert.Equal(HttpStatusCode.Redirect, esitle.StatusCode);
        Assert.Contains("Takvim eşitlendi", await MetinAsync(tarayici, "/Yonetim"));
    }

    [Fact]
    public async Task Yonetim_SyncNowWithoutAConnection_SaysSoAndChangesNothing()
    {
        await TemizleAsync();
        var tarayici = await SahipAsync(WebFabrika());

        var esitle = await PostAsync(tarayici, "/Yonetim", "/Yonetim?handler=GoogleEsitle");

        Assert.Equal(HttpStatusCode.Redirect, esitle.StatusCode);
        Assert.Contains("Google bağlı değil.", await MetinAsync(tarayici, "/Yonetim"));
    }

    [Theory]
    [InlineData("reddedildi", "Google'da izin verilmedi.")]
    [InlineData("sureDoldu", "süresi doldu")]
    [InlineData("<script>alert(1)</script>", "Google bağlantıyı tamamlayamadı")]
    public async Task Yonetim_ACallbackThatFailed_SaysWhy_WithFixedTextsOnly(string neden, string beklenen)
    {
        await TemizleAsync();
        var tarayici = await SahipAsync(WebFabrika());

        var yanit = await tarayici.GetAsync($"/Yonetim?google=hata&neden={Uri.EscapeDataString(neden)}", Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Contains(beklenen, await WebOturumu.MetinAsync(yanit, Ct));
        Assert.DoesNotContain("<script>alert(1)", await WebOturumu.HamAsync(yanit, Ct));
    }

    // The briefing (home page)

    [Fact]
    public async Task Home_ShowsTodaysBriefing_AVoteIsStored_AndItCanBeMadeAgain()
    {
        await TemizleAsync();
        var tarayici = await SahipAsync(WebFabrika());

        var sayfa = await MetinAsync(tarayici, "/Aliskanliklar");
        Assert.Contains("Bugünün brifingi", sayfa);
        Assert.Contains("Bugün sakin bir gün", sayfa);
        Assert.Contains("kurallarla hazırlandı", sayfa);
        Assert.DoesNotContain("aria-pressed=\"true\"", sayfa);

        var oy = await PostAsync(tarayici, "/Aliskanliklar", "/Aliskanliklar?handler=BrifingOy", new() { ["sira"] = "0", ["oy"] = "1" });
        Assert.Equal(HttpStatusCode.Redirect, oy.StatusCode);
        await using (var db = YeniDb())
            Assert.Equal(1, Assert.Single(await db.BrifingOylari.ToListAsync(Ct)).Oy);
        Assert.Contains("aria-pressed=\"true\"", await MetinAsync(tarayici, "/Aliskanliklar"));

        // Pressing the same thumb again sends 0 and takes the vote back.
        var geri = await PostAsync(tarayici, "/Aliskanliklar", "/Aliskanliklar?handler=BrifingOy", new() { ["sira"] = "0", ["oy"] = "0" });
        Assert.Equal(HttpStatusCode.Redirect, geri.StatusCode);
        await using (var db = YeniDb())
            Assert.Empty(await db.BrifingOylari.ToListAsync(Ct));

        var yenile = await PostAsync(tarayici, "/Aliskanliklar", "/Aliskanliklar?handler=BrifingYenile");
        Assert.Equal(HttpStatusCode.Redirect, yenile.StatusCode);
        await using (var db = YeniDb())
            Assert.Equal(1, Assert.Single(await db.Brifingler.ToListAsync(Ct)).YenilemeSayisi);
        Assert.Contains("Bugün 2 yenileme hakkı kaldı.", await MetinAsync(tarayici, "/Aliskanliklar"));
    }

    [Fact]
    public async Task Home_BeforeTheBriefingHour_SaysWhenItComes_AndTheHabitPanelStillShows()
    {
        await TemizleAsync();
        var tarayici = await SahipAsync(WebFabrika(an: IstAn(2026, 11, 7, 5, 30)));

        var sayfa = await MetinAsync(tarayici, "/Aliskanliklar");

        Assert.Contains("Bugünün brifingi", sayfa);
        Assert.Contains("hazırlanır", sayfa);
        Assert.Contains("Alışkanlıklar", sayfa);
        await using var db = YeniDb();
        Assert.Empty(await db.Brifingler.ToListAsync(Ct));
    }

    // The timeline (home page and day page)

    [Fact]
    public async Task Home_ShowsTheTimeline_InTheOrderOfTheClock_WithTheAllDayEventApart()
    {
        await TemizleAsync();
        await EtkinlikEkleAsync("Dişçi randevusu", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 11), yer: "Kadıköy");
        await EtkinlikEkleAsync("Sabah toplantısı", IstAn(2026, 11, 7, 9), IstAn(2026, 11, 7, 9, 30));
        await TumGunEtkinligiEkleAsync("Tüm gün konferans", Bugun, Bugun);
        var tarayici = await SahipAsync(WebFabrika());

        var sayfa = await MetinAsync(tarayici, "/Aliskanliklar");

        // The briefing above names the same events; the timeline's own section is what is read.
        Assert.Contains("Zaman çizelgesi", sayfa);
        var cizelge = sayfa[sayfa.IndexOf("id=\"zaman-cizelgesi\"", StringComparison.Ordinal)..];
        Assert.Contains("10:00–11:00", cizelge);
        Assert.Contains("Kadıköy", cizelge);
        Assert.True(cizelge.IndexOf("Sabah toplantısı", StringComparison.Ordinal) < cizelge.IndexOf("Dişçi randevusu", StringComparison.Ordinal));
        Assert.True(cizelge.IndexOf("Dişçi randevusu", StringComparison.Ordinal) < cizelge.IndexOf("Tüm gün konferans", StringComparison.Ordinal));
        Assert.Contains("Saati olmayanlar", cizelge);
    }

    [Fact]
    public async Task Home_WithGoogleNotConnected_TellsThatTheEventsAreMissing()
    {
        await TemizleAsync();
        var tarayici = await SahipAsync(WebFabrika());

        var sayfa = await MetinAsync(tarayici, "/Aliskanliklar");

        Assert.Contains("Google Takvim bağlı değil", sayfa);
    }

    [Fact]
    public async Task DayPage_ShowsTheTimeline_ButNotThePlanTwice()
    {
        await TemizleAsync();
        await EtkinlikEkleAsync("Dişçi randevusu", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 11));
        var beyin = Beyin(b => b.Cikti("gun goster", GunPlani));
        var tarayici = await SahipAsync(WebFabrika(beyin));

        var sayfa = await MetinAsync(tarayici, "/Beyin/Gun/2026-11-07");

        Assert.Contains("Zaman çizelgesi", sayfa);
        Assert.Contains("Dişçi randevusu", sayfa);
        // The plan is in its own sections below; the timeline leaves it out. (The fake brain answers yesterday's card with the same plan.)
        var cizelge = sayfa[sayfa.IndexOf("id=\"zaman-cizelgesi\"", StringComparison.Ordinal)..];
        cizelge = cizelge[..cizelge.IndexOf("</section>", StringComparison.Ordinal)];
        Assert.DoesNotContain("Benzersiz plan işi", cizelge);
        Assert.Contains("Benzersiz plan işi", sayfa);
    }

    [Fact]
    public async Task Pages_AreForTheSahipOnly()
    {
        var fabrika = WebFabrika();
        var anonim = fabrika.CreateClient(new() { AllowAutoRedirect = false });
        foreach (var yol in new[] { "/Aliskanliklar", "/Yonetim", $"/Beyin/Proje/{Proje}" })
        {
            var yanit = await anonim.GetAsync(yol, Ct);
            Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
            Assert.Contains("/Hesap/Giris", yanit.Headers.Location!.OriginalString);
        }
    }
}
