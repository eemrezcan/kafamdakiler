using System.Net;
using System.Text.RegularExpressions;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The Yönetim cards (K-0009 permissions grouped by area): the table covers every permission once, the choices set the
// right claims, and the page posts them in one go.
public sealed partial class IzinGruplariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    [Fact]
    public void EveryPermission_FallsInExactlyOneCard_OrIsTheAssistantSwitch()
    {
        var gruptakiler = IzinGruplari.Tumu.SelectMany(g => g.Hepsi).ToList();

        Assert.Equal(gruptakiler.Count, gruptakiler.Distinct().Count());
        Assert.DoesNotContain(IzinGruplari.AsistanAnahtari, gruptakiler);
        Assert.Equal(
            Izinler.Tumu.Select(i => i.Ad).Order(),
            gruptakiler.Append(IzinGruplari.AsistanAnahtari).Order());
        Assert.Equal(7, IzinGruplari.Tumu.Count);
    }

    [Fact]
    public void Cards_HaveTheReadAndWritePermissionsOfTheDecision()
    {
        string Izinleri(string anahtar) => string.Join(",", IzinGruplari.Bul(anahtar)!.Okur) + "|" + string.Join(",", IzinGruplari.Bul(anahtar)!.Yazar);

        Assert.Equal("aliskanlik.oku|aliskanlik.yaz", Izinleri("aliskanlik"));
        Assert.Equal("hatirlatici.oku|hatirlatici.yaz", Izinleri("hatirlatici"));
        Assert.Equal("yakalama.oku,gelen.oku|yakalama.yaz,gelen.yaz", Izinleri("gelen"));
        Assert.Equal("beyin.oku|plan.yaz,gorev.yaz", Izinleri("beyin"));
        Assert.Equal("takvim.oku,brifing.oku|takvim.yaz", Izinleri("takvim"));
        Assert.Equal("eylem.oku|eylem.onayla", Izinleri("eylem"));
        Assert.Equal("asistan.kullan", IzinGruplari.AsistanAnahtari);
    }

    [Fact]
    public void KipBul_ReadsTheStateOfACard_AndCallsAMixSpecial()
    {
        var gelen = IzinGruplari.Bul("gelen")!;

        Assert.Equal(GrupKipi.Kapali, IzinGruplari.KipBul(gelen, new HashSet<string>()));
        Assert.Equal(GrupKipi.Okur, IzinGruplari.KipBul(gelen, new HashSet<string> { "yakalama.oku", "gelen.oku" }));
        Assert.Equal(GrupKipi.OkurVeYazar, IzinGruplari.KipBul(gelen, new HashSet<string> { "yakalama.oku", "gelen.oku", "yakalama.yaz", "gelen.yaz" }));
        Assert.Equal(GrupKipi.Ozel, IzinGruplari.KipBul(gelen, new HashSet<string> { "yakalama.oku" }));
        Assert.Equal(GrupKipi.Ozel, IzinGruplari.KipBul(gelen, new HashSet<string> { "yakalama.oku", "gelen.oku", "gelen.yaz" }));
        Assert.Equal(GrupKipi.Ozel, IzinGruplari.KipBul(gelen, new HashSet<string> { "gelen.yaz" }));
    }

    [Fact]
    public async Task GrupAyarla_SetsAndClearsTheCardsPermissions_AndLeavesTheOthers()
    {
        using var kapsam = uygulama.Services.CreateScope();
        var kullanicilar = kapsam.ServiceProvider.GetRequiredService<UserManager<IdentityUser<Guid>>>();
        var beyin = IzinGruplari.Bul("beyin")!;
        var takvim = IzinGruplari.Bul("takvim")!;
        try
        {
            await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, takvim, GrupKipi.Okur);
            await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, beyin, GrupKipi.OkurVeYazar);
            Assert.Equal(GrupKipi.OkurVeYazar, await KipAsync(kullanicilar, beyin));

            await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, beyin, GrupKipi.Okur);
            Assert.Equal(GrupKipi.Okur, await KipAsync(kullanicilar, beyin));

            await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, beyin, GrupKipi.Kapali);
            Assert.Equal(GrupKipi.Kapali, await KipAsync(kullanicilar, beyin));
            Assert.Equal(GrupKipi.Okur, await KipAsync(kullanicilar, takvim));
            await Assert.ThrowsAsync<ArgumentException>(() => YonetimIslemleri.GrupAyarlaAsync(kullanicilar, beyin, GrupKipi.Ozel));
        }
        finally
        {
            await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, beyin, GrupKipi.Kapali);
            await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, takvim, GrupKipi.Kapali);
        }
    }

    private static async Task<GrupKipi> KipAsync(UserManager<IdentityUser<Guid>> kullanicilar, IzinGruplari.Grup grup)
    {
        var acik = (await YonetimIslemleri.IzinleriGetirAsync(kullanicilar)).Where(i => i.Acik).Select(i => i.Izin).ToHashSet();
        return IzinGruplari.KipBul(grup, acik);
    }

    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string yol, Dictionary<string, string> alanlar)
    {
        var sayfa = await tarayici.GetStringAsync("/Yonetim", Ct);
        alanlar["__RequestVerificationToken"] = TokenDeseni().Match(sayfa).Groups[1].Value;
        return await tarayici.PostAsync(yol, new FormUrlEncodedContent(alanlar), Ct);
    }

    [Fact]
    public async Task Page_ShowsTheCards_PostsAChoiceInOneGo_AndKeepsTheRawListInAdvanced()
    {
        var tarayici = await WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);
        using var kapsam = uygulama.Services.CreateScope();
        var kullanicilar = kapsam.ServiceProvider.GetRequiredService<UserManager<IdentityUser<Guid>>>();
        var gelen = IzinGruplari.Bul("gelen")!;
        try
        {
            var sayfa = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Yonetim", Ct), Ct);
            Assert.Contains("Gelen ve yakalamalar", sayfa);
            Assert.Contains(">Yazar<", sayfa);
            Assert.Contains("Yazar, okumayı da kapsar", sayfa);
            Assert.Contains("Asistan Claude'u çağırabilsin", sayfa);
            Assert.Contains("Gelişmiş", sayfa);
            Assert.DoesNotContain("403 alır", sayfa);
            Assert.DoesNotContain("(refresh)", sayfa);

            var yanit = await PostAsync(tarayici, "/Yonetim?handler=Grup", new() { ["grup"] = "gelen", ["kip"] = "OkurVeYazar" });
            Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
            Assert.Equal(GrupKipi.OkurVeYazar, await KipAsync(kullanicilar, gelen));

            // One permission changed by hand: the card says so and shows no pressed choice.
            await YonetimIslemleri.IzinAyarlaAsync(kullanicilar, "gelen.yaz", false);
            var ozel = await WebOturumu.HamAsync(await tarayici.GetAsync("/Yonetim", Ct), Ct);
            Assert.Contains("Özel: izinler tek tek ayarlanmış", ozel);

            // Wrong values change nothing.
            foreach (var (grup, kip) in new[] { ("olmayan", "Okur"), ("gelen", "Ozel"), ("gelen", "belki"), ("gelen", "1"), ("gelen", "") })
                Assert.Equal(HttpStatusCode.BadRequest, (await PostAsync(tarayici, "/Yonetim?handler=Grup", new() { ["grup"] = grup, ["kip"] = kip })).StatusCode);
            Assert.Equal(GrupKipi.Ozel, await KipAsync(kullanicilar, gelen));
        }
        finally
        {
            await YonetimIslemleri.GrupAyarlaAsync(kullanicilar, gelen, GrupKipi.Kapali);
        }
    }
}
