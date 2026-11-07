using System.Buffers.Text;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// Connecting the Google account (K2.3c), end to end on a fake Google. What matters most: `state` and PKCE are really checked, the refresh
// token is in the database only sealed, a wrong or replayed or foreign callback connects nothing, only the Sahip can start or cut the
// connection, and cutting it revokes at Google and deletes what was synced.
public sealed class GoogleBaglantiTests(UygulamaFabrikasi uygulama) : TakvimTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private async Task<string> AdresAlAsync(WebApplicationFactory<Program> fabrika)
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var yanit = await GonderAsync(HttpMethod.Post, "/api/google/baglan", sahip, fabrika);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return (await OkuAsync(yanit)).GetProperty("adres").GetString()!;
    }

    private async Task<HttpResponseMessage> DonusAsync(WebApplicationFactory<Program> fabrika, string sorgu, string eposta = UygulamaFabrikasi.SahipEposta)
    {
        var tarayici = await WebOturumu.GirisliAsync(fabrika, eposta, Ct);
        return await tarayici.GetAsync("/google/donus" + sorgu, Ct);
    }

    private static string Yonlendirme(HttpResponseMessage yanit) => yanit.Headers.Location?.OriginalString ?? "";

    // Who may do what

    [Fact]
    public async Task OnlyTheSahip_StartsCutsAndReadsTheConnection()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);

        foreach (var (yontem, yol) in new[] { (HttpMethod.Get, "/api/google/durum"), (HttpMethod.Post, "/api/google/baglan"), (HttpMethod.Delete, "/api/google/baglanti"), (HttpMethod.Post, "/api/google/esitle") })
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(yontem, yol, null, fabrika)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(yontem, yol, asistan, fabrika)).StatusCode);
        }

        // Not even a permission with a calendar name opens them.
        await IzinAsync(sahip, "takvim.oku", fabrika);
        await IzinAsync(sahip, "takvim.yaz", fabrika);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, "/api/google/baglan", asistan, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/google/durum", sahip, fabrika)).StatusCode);
    }

    [Fact]
    public async Task WithTheGoogleSettingsMissing_TheModuleIsOff_AndSaysSo()
    {
        await TemizleAsync();
        var fabrika = Fabrika(google: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var durum = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/google/durum", sahip, fabrika));
        Assert.False(durum.GetProperty("acik").GetBoolean());
        Assert.Equal("kapali", durum.GetProperty("durum").GetString());

        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await GonderAsync(HttpMethod.Post, "/api/google/baglan", sahip, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await GonderAsync(HttpMethod.Post, "/api/google/esitle", sahip, fabrika)).StatusCode);

        // A callback that arrives anyway connects nothing and exchanges nothing.
        var donus = await DonusAsync(fabrika, "?state=x&code=y");
        Assert.Contains("neden=kapali", Yonlendirme(donus));
        Assert.Empty(Google.KodCagrilari);
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
    }

    // The consent address

    [Fact]
    public async Task TheConsentAddress_CarriesStateAndAPkceChallenge_AndOnlyTheNarrowScopes()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var adres = await AdresAlAsync(fabrika);

        var uri = new Uri(adres);
        Assert.Equal("accounts.google.com", uri.Host);
        Assert.Equal("code", QueryDegeri(adres, "response_type"));
        Assert.Equal("test-istemci", QueryDegeri(adres, "client_id"));
        Assert.Equal(DonusAdresi, QueryDegeri(adres, "redirect_uri"));
        Assert.Equal("offline", QueryDegeri(adres, "access_type"));
        Assert.Equal("S256", QueryDegeri(adres, "code_challenge_method"));
        Assert.Equal(43, QueryDegeri(adres, "code_challenge").Length);
        Assert.True(QueryDegeri(adres, "state").Length >= 43);
        Assert.Equal(
            ["https://www.googleapis.com/auth/calendar.events", "https://www.googleapis.com/auth/calendar.readonly"],
            QueryDegeri(adres, "scope").Split(' ').Order().ToArray());
        // The secret never goes into an address a browser holds.
        Assert.DoesNotContain("test-gizli", adres);
        Assert.DoesNotContain("client_secret", adres);
    }

    [Fact]
    public async Task TheState_IsKeptOnlyAsAHash_AndTheVerifierSealed()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var adres = await AdresAlAsync(fabrika);
        var state = QueryDegeri(adres, "state");

        await using var db = YeniDb();
        var satir = Assert.Single(await db.GoogleYetkilendirmeleri.ToListAsync(Ct));
        Assert.Equal(Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(state))), satir.StateOzeti);
        Assert.DoesNotContain(state, satir.StateOzeti);

        // The verifier opens only with the key of its own purpose, and is not the challenge in the address.
        var koruma = fabrika.Services.GetRequiredService<IDataProtectionProvider>();
        var dogrulayici = koruma.CreateProtector(GoogleErisimi.DogrulayiciAmaci).Unprotect(satir.KodDogrulayici);
        Assert.NotEqual(QueryDegeri(adres, "code_challenge"), dogrulayici);
        Assert.Equal(QueryDegeri(adres, "code_challenge"), Base64Url.EncodeToString(SHA256.HashData(Encoding.ASCII.GetBytes(dogrulayici))));
        Assert.Throws<CryptographicException>(() => koruma.CreateProtector(GoogleErisimi.TokenAmaci).Unprotect(satir.KodDogrulayici));
        Assert.DoesNotContain(dogrulayici, satir.KodDogrulayici);
    }

    [Fact]
    public async Task StartingAgain_ReplacesTheEarlierUnfinishedConnect()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var ilk = QueryDegeri(await AdresAlAsync(fabrika), "state");
        var ikinci = QueryDegeri(await AdresAlAsync(fabrika), "state");

        await using var db = YeniDb();
        Assert.Single(await db.GoogleYetkilendirmeleri.ToListAsync(Ct));
        // Only the latest link works.
        Assert.Contains("neden=state", Yonlendirme(await DonusAsync(fabrika, $"?state={ilk}&code=kod-1")));
        Assert.Contains("google=bagli", Yonlendirme(await DonusAsync(fabrika, $"?state={ikinci}&code=kod-1")));
    }

    // The callback

    [Fact]
    public async Task TheCallback_ExchangesTheCodeWithTheVerifierOfTheChallenge_AndStoresTheTokenSealed()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var adres = await AdresAlAsync(fabrika);

        var donus = await DonusAsync(fabrika, $"?state={Uri.EscapeDataString(QueryDegeri(adres, "state"))}&code=kod-1");
        Assert.Equal(HttpStatusCode.Redirect, donus.StatusCode);
        Assert.Equal("/Yonetim?google=bagli", Yonlendirme(donus));
        Assert.Equal("no-store", donus.Headers.CacheControl?.ToString());

        // PKCE: the verifier sent to Google hashes to the challenge in the address, and the return address is the configured one.
        var cagri = Assert.Single(Google.KodCagrilari);
        Assert.Equal("kod-1", cagri.Kod);
        Assert.Equal(DonusAdresi, cagri.Donus);
        Assert.Equal(QueryDegeri(adres, "code_challenge"), Base64Url.EncodeToString(SHA256.HashData(Encoding.ASCII.GetBytes(cagri.Dogrulayici))));

        // The token is in the database sealed: not the clear text, not containing it, and it opens only with its own purpose.
        await using var db = YeniDb();
        var baglanti = await db.GoogleBaglantilari.SingleAsync(Ct);
        Assert.Equal(GoogleBaglantiDurumu.Bagli, baglanti.Durum);
        Assert.NotEqual(SahteGoogle.YenilemeTokeni, baglanti.YenilemeTokeni);
        Assert.DoesNotContain(SahteGoogle.YenilemeTokeni, baglanti.YenilemeTokeni);
        var koruma = fabrika.Services.GetRequiredService<IDataProtectionProvider>();
        Assert.Equal(SahteGoogle.YenilemeTokeni, koruma.CreateProtector(GoogleErisimi.TokenAmaci).Unprotect(baglanti.YenilemeTokeni));
        Assert.Throws<CryptographicException>(() => koruma.CreateProtector("baska-amac").Unprotect(baglanti.YenilemeTokeni));

        // The connect is used up, and the first sync ran.
        Assert.Empty(await db.GoogleYetkilendirmeleri.ToListAsync(Ct));
        Assert.Contains("liste", Google.Cagrilar);
    }

    [Theory]
    [InlineData("")]
    [InlineData("?code=kod-1")]
    [InlineData("?state=yanlis-state&code=kod-1")]
    [InlineData("?state=%20&code=kod-1")]
    public async Task TheCallback_WithAWrongOrMissingState_ConnectsNothing(string sorgu)
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await AdresAlAsync(fabrika);

        var donus = await DonusAsync(fabrika, sorgu);
        Assert.Contains("google=hata", Yonlendirme(donus));
        Assert.Contains("neden=state", Yonlendirme(donus));
        Assert.Empty(Google.KodCagrilari);
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
    }

    [Fact]
    public async Task TheCallback_WithAStateAlreadyUsed_ConnectsNothingTheSecondTime()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var state = QueryDegeri(await AdresAlAsync(fabrika), "state");

        Assert.Contains("google=bagli", Yonlendirme(await DonusAsync(fabrika, $"?state={state}&code=kod-1")));
        var tekrar = await DonusAsync(fabrika, $"?state={state}&code=kod-2");

        Assert.Contains("neden=state", Yonlendirme(tekrar));
        Assert.Single(Google.KodCagrilari);
    }

    [Fact]
    public async Task TheCallback_WithAnExpiredState_ConnectsNothing()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var state = QueryDegeri(await AdresAlAsync(fabrika), "state");

        Saat.Simdi += GoogleBaglanti.BaglantiSuresi + TimeSpan.FromSeconds(1);
        var donus = await DonusAsync(fabrika, $"?state={state}&code=kod-1");

        Assert.Contains("neden=sureDoldu", Yonlendirme(donus));
        Assert.Empty(Google.KodCagrilari);
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
        // Used up, even though it failed: it cannot be tried again.
        Assert.Empty(await db.GoogleYetkilendirmeleri.ToListAsync(Ct));
    }

    [Fact]
    public async Task TheCallback_WithAnotherPersonsState_ConnectsNothing_AndBurnsTheState()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahipId = await SahipKimligiAsync(fabrika);
        using var kapsam = fabrika.Services.CreateScope();
        var baglanti = kapsam.ServiceProvider.GetRequiredService<GoogleBaglanti>();
        var state = QueryDegeri((await baglanti.BaslatAsync(sahipId, Ct))!.AbsoluteUri, "state");

        var yabanci = await baglanti.TamamlaAsync(Guid.NewGuid(), state, "kod-1", null, Ct);
        Assert.Equal(BaglantiSonucuTuru.KullaniciUyusmuyor, yabanci.Tur);

        // The rightful owner cannot use it afterwards either.
        Assert.Equal(BaglantiSonucuTuru.StateGecersiz, (await baglanti.TamamlaAsync(sahipId, state, "kod-1", null, Ct)).Tur);
        Assert.Empty(Google.KodCagrilari);
    }

    [Fact]
    public async Task TheCallback_NeedsTheSahipsBrowserSession()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var state = QueryDegeri(await AdresAlAsync(fabrika), "state");

        // No session: sent to sign in.
        var tarayici = fabrika.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        var anonim = await tarayici.GetAsync($"/google/donus?state={state}&code=kod-1", Ct);
        Assert.Equal(HttpStatusCode.Redirect, anonim.StatusCode);
        Assert.Contains("/Hesap/Giris", Yonlendirme(anonim));

        // The Asistan's session: turned away.
        var asistan = await DonusAsync(fabrika, $"?state={state}&code=kod-1", UygulamaFabrikasi.AsistanEposta);
        Assert.DoesNotContain("google=bagli", Yonlendirme(asistan));

        Assert.Empty(Google.KodCagrilari);
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
        // The state is still good for the Sahip.
        Assert.Contains("google=bagli", Yonlendirme(await DonusAsync(fabrika, $"?state={state}&code=kod-1")));
    }

    [Fact]
    public async Task TheCallback_WhenThePersonRefusesAtGoogle_ConnectsNothing()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var state = QueryDegeri(await AdresAlAsync(fabrika), "state");

        var donus = await DonusAsync(fabrika, $"?state={state}&error=access_denied");

        Assert.Contains("neden=reddedildi", Yonlendirme(donus));
        Assert.Empty(Google.KodCagrilari);
    }

    [Fact]
    public async Task TheCallback_WhenGoogleGrantsFewerScopes_ConnectsNothing_AndRevokes()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        Google.TokenSonucu = Google.TokenSonucu with { Kapsamlar = ["https://www.googleapis.com/auth/calendar.events"] };
        var state = QueryDegeri(await AdresAlAsync(fabrika), "state");

        var donus = await DonusAsync(fabrika, $"?state={state}&code=kod-1");

        Assert.Contains("neden=eksikIzin", Yonlendirme(donus));
        Assert.Equal([SahteGoogle.YenilemeTokeni], Google.IptalEdilenler);
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
    }

    [Fact]
    public async Task TheCallback_WhenGoogleSendsNoRefreshToken_ConnectsNothing()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        Google.TokenSonucu = Google.TokenSonucu with { YenilemeTokeni = null };
        var state = QueryDegeri(await AdresAlAsync(fabrika), "state");

        var donus = await DonusAsync(fabrika, $"?state={state}&code=kod-1");

        Assert.Contains("neden=kod", Yonlendirme(donus));
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
    }

    [Fact]
    public async Task TheCallback_WhenGoogleRejectsTheCode_ConnectsNothing()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        Google.KodGecersiz = true;
        var state = QueryDegeri(await AdresAlAsync(fabrika), "state");

        var donus = await DonusAsync(fabrika, $"?state={state}&code=kotu-kod");

        Assert.Contains("neden=kod", Yonlendirme(donus));
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
    }

    // Using and cutting the connection

    [Fact]
    public async Task TheStatus_NeverShowsATokenOrTheSecret()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await BaglaAsync(fabrika);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/google/durum", sahip, fabrika);
        var metin = await yanit.Content.ReadAsStringAsync(Ct);

        var durum = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/google/durum", sahip, fabrika));
        Assert.Equal("bagli", durum.GetProperty("durum").GetString());
        Assert.DoesNotContain(SahteGoogle.YenilemeTokeni, metin);
        Assert.DoesNotContain("test-gizli", metin);
        Assert.DoesNotContain("yenileme", metin, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Cutting_RevokesTheTokenAtGoogle_AndDeletesTheTokenTheEventsAndTheSyncState()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await BaglaAsync(fabrika);
        await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 11));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Delete, "/api/google/baglanti", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        Assert.True(govde.GetProperty("baglantiVardi").GetBoolean());
        Assert.True(govde.GetProperty("googleIptal").GetBoolean());
        // The refresh token itself (in the clear) is what Google is told to revoke.
        Assert.Equal([SahteGoogle.YenilemeTokeni], Google.IptalEdilenler);
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
        Assert.Empty(await db.TakvimEtkinlikleri.ToListAsync(Ct));
        Assert.Empty(await db.TakvimEsitlemeleri.ToListAsync(Ct));

        var durum = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/google/durum", sahip, fabrika));
        Assert.Equal("bagliDegil", durum.GetProperty("durum").GetString());

        // Cutting again is harmless and tells that there was nothing.
        var ikinci = await OkuAsync(await GonderAsync(HttpMethod.Delete, "/api/google/baglanti", sahip, fabrika));
        Assert.False(ikinci.GetProperty("baglantiVardi").GetBoolean());
        Assert.Single(Google.IptalEdilenler);
    }

    [Fact]
    public async Task Cutting_WhenGoogleCannotBeReached_StillDeletesTheLocalCopy_AndSaysItWasNotRevoked()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await BaglaAsync(fabrika);
        Google.IptalHatasi = true;
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var govde = await OkuAsync(await GonderAsync(HttpMethod.Delete, "/api/google/baglanti", sahip, fabrika));

        Assert.True(govde.GetProperty("baglantiVardi").GetBoolean());
        Assert.False(govde.GetProperty("googleIptal").GetBoolean());
        await using var db = YeniDb();
        Assert.Empty(await db.GoogleBaglantilari.ToListAsync(Ct));
    }

    [Fact]
    public async Task AccessTokens_AreKeptUntilTheyExpire_ThenMadeAgain()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await BaglaAsync(fabrika);
        var erisim = fabrika.Services.GetRequiredService<GoogleErisimi>();
        Google.ErisimBitisi = Saat.Simdi.AddHours(1);
        var onceki = Google.Cagrilar.Count(c => c == "erisim");

        var ilk = await erisim.TokenAlAsync(Ct);
        var ikinci = await erisim.TokenAlAsync(Ct);
        Assert.True(ilk.Basarili);
        Assert.Equal(ilk.Token, ikinci.Token);
        Assert.Equal(onceki + 1, Google.Cagrilar.Count(c => c == "erisim"));

        Saat.Simdi += TimeSpan.FromMinutes(59);
        var yeni = await erisim.TokenAlAsync(Ct);
        Assert.NotEqual(ilk.Token, yeni.Token);
    }

    [Fact]
    public async Task ARefusedStoredToken_MarksReconnect_NoMoreCallsAreMade_AndConnectingAgainFixesIt()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await BaglaAsync(fabrika);
        var erisim = fabrika.Services.GetRequiredService<GoogleErisimi>();
        erisim.Unut();
        Google.YenilemeGecersiz = true;

        var sonuc = await erisim.TokenAlAsync(Ct);

        Assert.Equal(ErisimDurumu.YenidenBaglan, sonuc.Durum);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        Assert.Equal("yenidenBaglan", (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/google/durum", sahip, fabrika))).GetProperty("durum").GetString());

        // Marked: it does not ask Google again every round.
        var cagri = Google.Cagrilar.Count(c => c == "erisim");
        Assert.Equal(ErisimDurumu.YenidenBaglan, (await erisim.TokenAlAsync(Ct)).Durum);
        Assert.Equal(cagri, Google.Cagrilar.Count(c => c == "erisim"));

        Google.YenilemeGecersiz = false;
        await BaglaAsync(fabrika);
        Assert.True((await erisim.TokenAlAsync(Ct)).Basarili);
    }

    [Fact]
    public async Task ATokenSealedWithAKeyThatIsGone_MarksReconnect_WithoutCallingGoogle()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await BaglaAsync(fabrika);
        await using (var db = YeniDb())
            await db.GoogleBaglantilari.ExecuteUpdateAsync(s => s.SetProperty(b => b.YenilemeTokeni, "CfDJ8-bu-anahtarla-acilmaz"), Ct);
        var erisim = fabrika.Services.GetRequiredService<GoogleErisimi>();
        erisim.Unut();
        var onceki = Google.Cagrilar.Count(c => c == "erisim");

        var sonuc = await erisim.TokenAlAsync(Ct);

        Assert.Equal(ErisimDurumu.YenidenBaglan, sonuc.Durum);
        Assert.Equal(onceki, Google.Cagrilar.Count(c => c == "erisim"));
    }
}
