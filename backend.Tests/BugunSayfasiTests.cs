using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The menu and the home page "Bugün" of the web (K-0024), in a browser's shoes: cookies and no automatic redirects. The fixture has
// no brain, so the day plan says so; everything else on the page must stand without it. The list, the weight of the day and the
// writes are in GunSayfalariTests (a fake brain and a clock the test owns).
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

    private static string Duz(string html) => Regex.Replace(Regex.Replace(html, "<[^>]+>", " "), "\\s+", " ").Trim();

    // The visible texts of the top bar's five links, in order.
    private static List<string> UstMenu(string ham)
    {
        var bar = Regex.Match(ham, "<div (?:b-[a-z0-9]+ )?class=\"kd-nav-links\"[^>]*>(.*?)</div>", RegexOptions.Singleline).Groups[1].Value;
        return Regex.Matches(bar, "<a (?:b-[a-z0-9]+ )?class=\"kd-nav-link[^\"]*\"[^>]*>(.*?)</a>", RegexOptions.Singleline).Select(m => Regex.Replace(Duz(m.Groups[1].Value), " \\d+$", "")).ToList();
    }

    // The profile menu's entries, in order (the account name line is not an entry).
    private static List<string> ProfilMenusu(string ham)
    {
        var menu = Regex.Match(ham, "class=\"dropdown kd-profil[^\"]*\".*?</ul>", RegexOptions.Singleline).Value;
        return Regex.Matches(menu, "<(?:a|button) [^>]*class=\"dropdown-item[^\"]*\"[^>]*>(.*?)</(?:a|button)>", RegexOptions.Singleline).Select(m => Duz(m.Groups[1].Value)).ToList();
    }

    private async Task<Oge> db_OgeAsync(string ad)
    {
        await using var db = uygulama.YeniDb();
        return await db.Ogeler.AsNoTracking().SingleAsync(o => o.Ad == ad, Ct);
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
    public async Task TheTopMenu_HasTheFiveEntriesInOrder_AndTheProfileMenuTheRest()
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, "/");

        Assert.Equal(["Bugün", "Takvim", "Asistan", "Alışkanlıklar", "Beyin"], UstMenu(ham));
        Assert.Equal(["Yönetim", "Gün kapasitesi", "Şifremi değiştir", "Görünüm", "Çıkış yap"], ProfilMenusu(ham));
        // Search lives in Beyin only; the reminders, the inbox and the old "Daha fazla" menu have no entry any more.
        Assert.DoesNotContain("kd-search-btn", ham);
        Assert.DoesNotContain("Daha fazla", ham);
        Assert.DoesNotContain("Hatırlatıcılar</a>", ham);
        Assert.DoesNotContain("Beyin bölümleri", ham);
    }

    [Fact]
    public async Task PasswordAndSignOut_AreInTheProfileMenuAndTheDrawer_NotLooseInTheTopBar()
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, "/");

        Assert.DoesNotContain("class=\"kd-account\"", ham);
        var ustBar = ham[..ham.IndexOf("id=\"kd-settings\"", StringComparison.Ordinal)];
        // In the bar they are only inside the profile dropdown.
        var profilDisi = Regex.Replace(ustBar, "class=\"dropdown kd-profil.*?</ul>", "", RegexOptions.Singleline);
        Assert.DoesNotContain("Şifremi değiştir", profilDisi);
        Assert.DoesNotContain("/Hesap/Cikis", profilDisi);
        Assert.Contains("Şifremi değiştir", ustBar);
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
            .Select(m => Regex.Replace(Duz(m.Groups[1].Value), " \\d+$", "")).ToList();
        Assert.Equal(["Bugün", "Takvim", "Asistan", "Alışkanlıklar", "Beyin", "Yönetim", "Gün kapasitesi"], adlar);
    }

    [Theory]
    [InlineData("/", "Bugün")]
    [InlineData("/2026-11-03", "Bugün")]
    [InlineData("/Takvim", "Takvim")]
    [InlineData("/Hatirlaticilar", "Takvim")]
    [InlineData("/Gelen", "Asistan")]
    [InlineData("/Eylemler", "Asistan")]
    [InlineData("/Yakalamalar/Duzenle", "Asistan")]
    [InlineData("/Isler", "Asistan")]
    [InlineData("/Aliskanliklar", "Alışkanlıklar")]
    [InlineData("/Beyin", "Beyin")]
    [InlineData("/Beyin/Ara", "Beyin")]
    public async Task TheEntryOfThePageYouAreOn_IsTheActiveOne(string yol, string beklenen)
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, yol);

        var etkin = Regex.Match(ham, "class=\"kd-nav-link active\"[^>]*>(.*?)</(?:a|button)>", RegexOptions.Singleline).Groups[1].Value;
        // Without the badge count: other tests of the class may leave an action waiting, and the menu then says "Asistan 1".
        Assert.Equal(beklenen, Regex.Replace(Duz(etkin), " \\d+$", ""));
    }

    [Theory]
    [InlineData("/Yonetim", "Yönetim")]
    [InlineData("/Ayarlar/Gun", "Gün kapasitesi")]
    public async Task ThePagesOfTheProfileMenu_LightNoTopEntry_ButTheirOwnMenuItem(string yol, string beklenen)
    {
        var tarayici = await SahipAsync();

        var ham = await HamAsync(tarayici, yol);

        Assert.DoesNotContain("class=\"kd-nav-link active\"", ham);
        var menu = Regex.Match(ham, "class=\"dropdown kd-profil[^\"]*\".*?</ul>", RegexOptions.Singleline).Value;
        var etkin = Regex.Match(menu, "class=\"dropdown-item active\"[^>]*>(.*?)</a>", RegexOptions.Singleline).Groups[1].Value;
        Assert.Equal(beklenen, Duz(etkin));
    }

    [Fact]
    public async Task Home_IsTodaysPage_WithTheAssistantsSummary_AndSaysTheBrainIsOffInsteadOfFailing()
    {
        var tarayici = await SahipAsync();

        var yanit = await tarayici.GetAsync("/", Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);
        Assert.Contains("<title>Bugün - Kafamdakiler", metin);
        // The briefing is in the Asistan stream; Bugün has only the assistant's summary and the weight of the day.
        Assert.Contains("Asistanın özeti", metin);
        Assert.DoesNotContain("Bugünün brifingi", metin);
        // No brain on this machine: the page says so and still stands (reminders, events, habits).
        Assert.Contains("Beyin bağlı değil", metin);
    }

    [Fact]
    public async Task TheApprovalPointer_IsOnTheInboxOnlyWhileSomethingWaits_AndNoLongerOnBugun()
    {
        var tarayici = await SahipAsync();
        await using (var db = uygulama.YeniDb())
            await db.Eylemler.Where(e => e.Durum == EylemDurumu.Bekliyor).ExecuteDeleteAsync(Ct);

        Assert.DoesNotContain("kd-onay-karti", await HamAsync(tarayici, "/Gelen"));

        await BekleyenEylemAsync("Onay kartı " + Guid.NewGuid().ToString("N"));

        var ham = await HamAsync(tarayici, "/Gelen");
        Assert.Contains("kd-onay-karti", ham);
        Assert.Contains("Onay bekleyen 1", Metin(ham));
        Assert.Contains("href=\"/Eylemler\"", ham);
        // What waits for approval is in the Asistan stream (and on the menu's badge); Bugün does not repeat it.
        Assert.DoesNotContain("kd-onay-karti", await HamAsync(tarayici, "/"));
        Assert.DoesNotContain("kd-onay-karti", await HamAsync(tarayici, "/2026-11-03"));
    }

    [Fact]
    public async Task Home_ListsALateReminderInTheOneList_AndTodaysHabits_ButAnotherDayDoesNot()
    {
        var tarayici = await SahipAsync();
        var hatirlatici = "Geciken " + Guid.NewGuid().ToString("N");
        var aliskanlik = "Bugünkü " + Guid.NewGuid().ToString("N");
        await using (var db = uygulama.YeniDb())
        {
            db.Hatirlaticilar.Add(new Hatirlatici
            {
                Baslik = hatirlatici, Tur = HatirlaticiTuru.Gorev, Tekrar = Tekrar.Yok, Durum = HatirlaticiDurumu.Acik,
                Gun = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-2)), SonrakiAn = DateTimeOffset.UtcNow.AddDays(-2),
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

        // The reminder is a row of the one list (there is no separate "coming reminders" card any more), marked late.
        Assert.DoesNotContain("Yaklaşan hatırlatıcılar", metin);
        Assert.Contains(hatirlatici, metin);
        Assert.Contains("gün gecikti", metin);
        Assert.Contains("Bugünün alışkanlıkları", metin);
        Assert.Contains(aliskanlik, metin);
        // The habit is a compact strip item here, usable with one tap: its form posts to the habits page and comes back to Bugün.
        // The big card is on the habits page only.
        Assert.Contains("class=\"kd-serit-oge", ham);
        Assert.DoesNotContain("class=\"kd-habit ", ham);
        Assert.Contains("name=\"donus\" value=\"bugun\"", ham);
        Assert.Contains("class=\"kd-habit ", await HamAsync(tarayici, "/Aliskanliklar"));

        var baskaGun = Metin(await HamAsync(tarayici, "/2026-11-03"));
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
    public async Task AShelfHabit_WithABookInProgress_OpensTheReadingLogFromBugun_AndComesBackToBugun()
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

        // The strip item opens the reading log (a modal with the book, the page and the time) and posts it back to Bugün.
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var ham = await WebOturumu.HamAsync(yanit, Ct);
        Assert.Contains(kitap, ham);
        Assert.Contains("data-bs-target=\"#okuma-", ham);
        Assert.Contains("handler=Okuma", ham);
        Assert.Contains("name=\"bitisKonum\"", ham);
        Assert.Contains("name=\"donus\" value=\"bugun\"", ham);

        var oge = await db_OgeAsync(kitap);
        var token = Regex.Match(ham, "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"").Groups[1].Value;
        var kayit = await tarayici.PostAsync($"/Aliskanliklar/Detay/{oge.AliskanlikId}?handler=Okuma", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["__RequestVerificationToken"] = token, ["ogeId"] = oge.Id.ToString(), ["bitisKonum"] = "25", ["dakika"] = "30", ["donus"] = "bugun",
        }), Ct);
        Assert.Equal(HttpStatusCode.Redirect, kayit.StatusCode);
        Assert.StartsWith("/#h-", kayit.Headers.Location!.OriginalString);
        await using var db2 = uygulama.YeniDb();
        Assert.Equal(25m, Assert.Single(await db2.Oturumlar.Where(o => o.OgeId == oge.Id).ToListAsync(Ct)).BitisKonum);
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
