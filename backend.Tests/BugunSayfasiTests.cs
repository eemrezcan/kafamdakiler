using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The menu and the home page "Bugün" of the web (simplification wave 2, G), in a browser's shoes: cookies and no automatic
// redirects. The fixture has no brain, so the day plan says so; everything else on the page must stand without it.
public sealed class BugunSayfasiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private Task<HttpClient> SahipAsync() => WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);

    private async Task<string> HamAsync(HttpClient tarayici, string yol)
    {
        var yanit = await tarayici.GetAsync(yol, Ct);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return await WebOturumu.HamAsync(yanit, Ct);
    }

    // The text a person reads (Razor writes Ş as &#x15E;); never used to look for markup.
    private static string Metin(string ham) => WebUtility.HtmlDecode(ham);

    // The visible texts of the top bar's links, in order.
    private static List<string> UstMenu(string ham)
    {
        var bar = Regex.Match(ham, "<div (?:b-[a-z0-9]+ )?class=\"kd-nav-links\"[^>]*>(.*?)<a class=\"kd-icon-btn kd-search-btn", RegexOptions.Singleline).Groups[1].Value;
        var metinler = Regex.Matches(bar, "<(?:a|button) (?:b-[a-z0-9]+ )?class=\"(?:kd-nav-link|dropdown-item)[^\"]*\"[^>]*>(.*?)</(?:a|button)>", RegexOptions.Singleline);
        return metinler.Select(m => Regex.Replace(Regex.Replace(m.Groups[1].Value, "<[^>]+>", " "), "\\s+", " ").Trim()).ToList();
    }

    private async Task BekleyenEylemAsync(string baslik)
    {
        using var kapsam = uygulama.Services.CreateScope();
        var servis = kapsam.ServiceProvider.GetRequiredService<EylemServisi>();
        await using (var db = uygulama.YeniDb())
            await db.EylemIzinleri.Where(i => i.Tur == "hatirlatici-kur").ExecuteDeleteAsync(Ct);
        var sonuc = await servis.OnerAsync(new EylemOnerisi("hatirlatici-kur",
            JsonSerializer.SerializeToElement(new { baslik, gun = "2030-01-01" }), baslik, "gelen", false, "Mailde yazıyor", null), Ct);
        Assert.Equal(EylemDurumu.Bekliyor, sonuc.Eylem!.Durum);
    }

    [Fact]
    public async Task TheTopMenu_HasTheFiveEntriesInOrder_WithTheRestUnderDahaFazla()
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, "/");

        Assert.Equal(["Bugün", "Alışkanlıklar", "Gelen", "Hatırlatıcılar", "Projeler", "Daha fazla", "Asistan işleri", "Yönetim"], UstMenu(ham));
        // The magnifier opens the search page.
        Assert.Matches("<a class=\"kd-icon-btn kd-search-btn[^\"]*\"[^>]*href=\"/Beyin/Ara\"|href=\"/Beyin/Ara\"[^>]*class=\"kd-icon-btn kd-search-btn", ham);
        // The approval queue and the old brain sub-menu have no entry any more.
        Assert.DoesNotContain("Beyin bölümleri", ham);
        Assert.DoesNotContain("Gelen kutusu</a>", ham);
    }

    [Fact]
    public async Task PasswordAndSignOut_AreOnlyInTheSettingsDrawer_NotInTheTopBar()
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, "/");

        Assert.DoesNotContain("class=\"kd-account\"", ham);
        var ustBar = ham[..ham.IndexOf("id=\"kd-settings\"", StringComparison.Ordinal)];
        Assert.DoesNotContain("Şifremi değiştir", ustBar);
        Assert.DoesNotContain("/Hesap/Cikis", ustBar);
        var cekmece = ham[ham.IndexOf("id=\"kd-settings\"", StringComparison.Ordinal)..];
        Assert.Contains("Şifremi değiştir", cekmece);
        Assert.Contains("Çıkış yap", cekmece);
    }

    [Fact]
    public async Task TheDrawerMenu_FollowsTheSameOrder()
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, "/Hatirlaticilar");

        var cekmece = ham[ham.IndexOf("kd-drawer-pages", StringComparison.Ordinal)..];
        cekmece = cekmece[..cekmece.IndexOf("</section>", StringComparison.Ordinal)];
        var adlar = Regex.Matches(cekmece, "<a (?:b-[a-z0-9]+ )?class=\"kd-drawer-link[^\"]*\"[^>]*>(.*?)</a>", RegexOptions.Singleline)
            .Select(m => Regex.Replace(Regex.Replace(m.Groups[1].Value, "<[^>]+>", " "), "\\s+", " ").Trim()).ToList();
        Assert.Equal(["Bugün", "Alışkanlıklar", "Gelen", "Hatırlatıcılar", "Projeler", "Asistan işleri", "Yönetim"], adlar);
    }

    [Theory]
    [InlineData("/", "Bugün")]
    [InlineData("/2026-11-03", "Bugün")]
    [InlineData("/Gelen", "Gelen")]
    [InlineData("/Eylemler", "Gelen")]
    [InlineData("/Yakalamalar/Duzenle", "Gelen")]
    [InlineData("/Beyin", "Projeler")]
    [InlineData("/Hatirlaticilar", "Hatırlatıcılar")]
    [InlineData("/Aliskanliklar", "Alışkanlıklar")]
    [InlineData("/Yonetim", "Daha fazla")]
    public async Task TheEntryOfThePageYouAreOn_IsTheActiveOne(string yol, string beklenen)
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, yol);

        var etkin = Regex.Match(ham, "class=\"kd-nav-link active\"[^>]*>(.*?)</(?:a|button)>", RegexOptions.Singleline).Groups[1].Value;
        Assert.Equal(beklenen, Regex.Replace(Regex.Replace(etkin, "<[^>]+>", " "), "\\s+", " ").Trim());
    }

    [Fact]
    public async Task Home_IsTodaysPage_WithTheBriefingStrip_AndSaysTheBrainIsOffInsteadOfFailing()
    {
        var tarayici = await SahipAsync();

        var yanit = await tarayici.GetAsync("/", Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);
        Assert.Contains("<title>Bugün - Kafamdakiler", metin);
        Assert.Contains("Bugünün brifingi", metin);
        // An empty timeline takes no room on Bugün.
        Assert.DoesNotContain("Bu gün için bir şey yok", metin);
    }

    [Fact]
    public async Task Home_ShowsTheApprovalCard_OnlyWhileSomethingWaits_AndTheInboxShowsItToo()
    {
        var tarayici = await SahipAsync();
        await using (var db = uygulama.YeniDb())
            await db.Eylemler.Where(e => e.Durum == EylemDurumu.Bekliyor).ExecuteDeleteAsync(Ct);

        Assert.DoesNotContain("kd-onay-karti", await HamAsync(tarayici, "/"));
        Assert.DoesNotContain("kd-onay-karti", await HamAsync(tarayici, "/Gelen"));

        await BekleyenEylemAsync("Onay kartı " + Guid.NewGuid().ToString("N"));

        foreach (var yol in new[] { "/", "/Gelen" })
        {
            var ham = await HamAsync(tarayici, yol);
            Assert.Contains("kd-onay-karti", ham);
            Assert.Contains("Onay bekleyen 1", Metin(ham));
            Assert.Contains("href=\"/Eylemler\"", ham);
        }

        // Another day's page is only that day's plan.
        Assert.DoesNotContain("kd-onay-karti", await HamAsync(tarayici, "/2026-11-03"));
    }

    [Fact]
    public async Task Home_ListsTheComingReminders_AndTodaysHabits_ButAnotherDayDoesNot()
    {
        var tarayici = await SahipAsync();
        var hatirlatici = "Yaklaşan " + Guid.NewGuid().ToString("N");
        var aliskanlik = "Bugünkü " + Guid.NewGuid().ToString("N");
        await using (var db = uygulama.YeniDb())
        {
            db.Hatirlaticilar.Add(new Hatirlatici
            {
                Baslik = hatirlatici, Tur = HatirlaticiTuru.Gorev, Tekrar = Tekrar.Yok, Durum = HatirlaticiDurumu.Acik,
                Gun = DateOnly.FromDateTime(DateTime.UtcNow), SonrakiAn = DateTimeOffset.UtcNow.AddHours(3),
            });
            db.Aliskanliklar.Add(new Aliskanlik
            {
                Ad = aliskanlik, Tur = AliskanlikTuru.Sayac, Ikon = "book", Renk = "blue",
                Olcu = Olcu.Sayili, HedefYonu = HedefYonu.EnAz, GunlukHedef = 8, Siklik = Siklik.HerGun,
            });
            await db.SaveChangesAsync(Ct);
        }

        var ham = await HamAsync(tarayici, "/");
        var metin = Metin(ham);

        Assert.Contains("Yaklaşan hatırlatıcılar", metin);
        Assert.Contains(hatirlatici, metin);
        Assert.Contains("Bugünün alışkanlıkları", metin);
        Assert.Contains(aliskanlik, metin);
        // The habit is the full card, usable here: its forms post to the habits page and come back to Bugün.
        Assert.Contains("class=\"kd-habit ", ham);
        Assert.Contains("name=\"donus\" value=\"bugun\"", ham);

        var baskaGun = Metin(await HamAsync(tarayici, "/2026-11-03"));
        Assert.DoesNotContain("Yaklaşan hatırlatıcılar", baskaGun);
        Assert.DoesNotContain(aliskanlik, baskaGun);
        Assert.DoesNotContain("Bugünün brifingi", baskaGun);
    }

    [Fact]
    public async Task TheHabitsPage_IsOnlyHabits_TheBriefingAndTheTimelineAreGone()
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, "/Aliskanliklar");

        Assert.DoesNotContain("id=\"brifing\"", ham);
        Assert.DoesNotContain("Bugünün brifingi", ham);
        Assert.DoesNotContain("zaman-cizelgesi", ham);
        // The briefing's handlers moved with it.
        var yanit = await tarayici.PostAsync("/Aliskanliklar?handler=BrifingYenile", new FormUrlEncodedContent(new Dictionary<string, string>()), Ct);
        Assert.NotEqual(HttpStatusCode.Redirect, yanit.StatusCode);
    }

    [Fact]
    public async Task AHabitCard_OnBugun_TicksThroughTheHabitsPage_AndComesBackToBugun()
    {
        var tarayici = await SahipAsync();
        var ad = "Tik " + Guid.NewGuid().ToString("N");
        Guid id;
        await using (var db = uygulama.YeniDb())
        {
            var a = new Aliskanlik
            {
                Ad = ad, Tur = AliskanlikTuru.Sayac, Ikon = "book", Renk = "blue",
                Olcu = Olcu.EvetHayir, HedefYonu = HedefYonu.EnAz, GunlukHedef = 1, Siklik = Siklik.HerGun,
            };
            db.Aliskanliklar.Add(a);
            await db.SaveChangesAsync(Ct);
            id = a.Id;
        }

        var ham = await HamAsync(tarayici, "/");
        var token = Regex.Match(ham, "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"").Groups[1].Value;
        var yanit = await tarayici.PostAsync($"/Aliskanliklar?handler=Tik&id={id}", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["__RequestVerificationToken"] = token,
            ["donus"] = "bugun",
        }), Ct);

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal($"/#h-{id}", yanit.Headers.Location!.ToString());
        await using (var db = uygulama.YeniDb())
            Assert.True(await db.AliskanlikKayitlari.AnyAsync(k => k.AliskanlikId == id && k.Miktar > 0, Ct));

        // Any other "donus" is ignored: the habits page decides where to go back to.
        var baska = await tarayici.PostAsync($"/Aliskanliklar?handler=Tik&id={id}", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["__RequestVerificationToken"] = token,
            ["donus"] = "https://kotu.example",
        }), Ct);
        Assert.Equal($"/Aliskanliklar#h-{id}", baska.Headers.Location!.ToString());
    }

    [Fact]
    public async Task AShelfHabit_WithABookInProgress_RendersOnBugun_AndItsProgressFormComesBack()
    {
        var tarayici = await SahipAsync();
        var kitap = "Kitap " + Guid.NewGuid().ToString("N");
        await using (var db = uygulama.YeniDb())
        {
            var a = new Aliskanlik
            {
                Ad = "Okuma " + Guid.NewGuid().ToString("N"), Tur = AliskanlikTuru.Raf, Ikon = "book-open", Renk = "violet",
                Olcu = Olcu.Sayili, HedefYonu = HedefYonu.EnAz, GunlukHedef = 20, Birim = "sayfa", OgeEtiketi = "Kitap", Siklik = Siklik.HerGun,
            };
            a.Ogeler.Add(new Oge { Ad = kitap, Toplam = 300, Durum = OgeDurumu.Devam });
            db.Aliskanliklar.Add(a);
            await db.SaveChangesAsync(Ct);
        }

        var yanit = await tarayici.GetAsync("/", Ct);

        // The card's own parts (cover, progress form) are found from Bugün too, not only from the habits page.
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var ham = await WebOturumu.HamAsync(yanit, Ct);
        Assert.Contains(kitap, ham);
        Assert.Contains("handler=Ilerleme", ham);
        Assert.Contains("name=\"donus\" value=\"bugun\"", ham);
    }

    [Theory]
    [InlineData("/Beyin/Gun", "/")]
    [InlineData("/Beyin/Gun/2026-11-03", "/2026-11-03")]
    public async Task TheOldDayPlanAddresses_RedirectToTheHomePage(string eski, string yeni)
    {
        var tarayici = await SahipAsync();

        var yanit = await tarayici.GetAsync(eski, Ct);

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(yeni, yanit.Headers.Location!.OriginalString);
    }

    [Theory]
    [InlineData("/Beyin/Gun/bugun")]
    [InlineData("/bugun")]
    [InlineData("/2026-11")]
    public async Task ADayAddressThatIsNotADate_IsNotFound(string yol)
    {
        var tarayici = await SahipAsync();

        Assert.Equal(HttpStatusCode.NotFound, (await tarayici.GetAsync(yol, Ct)).StatusCode);
    }

    [Fact]
    public async Task TheBrainSubMenu_IsGone_FromEveryBrainPage()
    {
        var tarayici = await SahipAsync();

        foreach (var yol in new[] { "/Beyin", "/Beyin/Ara" })
            Assert.DoesNotContain("Beyin bölümleri", await HamAsync(tarayici, yol));
    }
}
