using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The whole app (real pipeline, bearer tokens, the database) with a fake beyin.py behind it: who may write, and that a
// request sent twice under one Idempotency-Key is applied once. The repeat guard is the part that must not pass silently,
// so most tests here count the calls the brain really received.
public sealed class BeyinYazmaApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Tarih = "2026-11-03";

    private readonly SahteBeyin _beyin = new("ok");
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        _beyin.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private WebApplicationFactory<Program> Fabrika(Action<IWebHostBuilder>? ek = null)
    {
        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            b.UseSetting("Beyin:Komut", _beyin.Komut)
             .UseSetting("Beyin:Vault", _beyin.Vault)
             .UseSetting("Beyin:GonderimAraligiSaniye", "3600");
            ek?.Invoke(b);
        });
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    private WebApplicationFactory<Program>? _acik;

    private WebApplicationFactory<Program> Acik => _acik ??= Fabrika();

    private async Task<string> GirisAsync(string eposta, WebApplicationFactory<Program>? fabrika = null)
    {
        var yanit = await (fabrika ?? Acik).CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string? token, object? govde = null, string? anahtar = null, WebApplicationFactory<Program>? fabrika = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (anahtar is not null)
            istek.Headers.Add("Idempotency-Key", anahtar);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await (fabrika ?? Acik).CreateClient().SendAsync(istek, Ct);
    }

    private async Task IzinAsync(string sahip, string izin, bool acik, WebApplicationFactory<Program>? fabrika = null)
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, new { acik }, fabrika: fabrika);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
    }

    private static string Anahtar() => "k-" + Guid.NewGuid().ToString("N");

    private int Cagri(string komut, string alt) =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Count(a => a[0] == komut && a[1] == alt);

    private const string MaddeJson = """{"no": 4, "id": "a3f09c", "baslik": "Yeni iş", "bolum": "Yapılacaklar", "durum": "acik", "tahmin_dk": 45, "sure_dk": 0}""";

    private const string Gorevler = """[{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "gizli": false}]""";

    private void BeyniHazirla()
    {
        _beyin.Cikti("gun ekle", """{"tarih": "2026-11-03", "madde": """ + MaddeJson + ", \"tahmin_onerisi\": null}");
        _beyin.Cikti("gun isaretle", """{"tarih": "2026-11-03", "madde": """ + MaddeJson + ", \"gorev_kapandi\": false}");
        _beyin.Cikti("gun devret", """{"tarih": "2026-11-03", "devredilen_gun": "2026-11-04", "madde": """ + MaddeJson + "}");
        _beyin.Cikti("gun not", """{"tarih": "2026-11-03", "madde": """ + MaddeJson + "}");
        _beyin.Cikti("gorev ekle", """{"yol": "projects/kitap-kulubu/gorevler/yeni.md", "kimlik": "yeni"}""");
        _beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");
        _beyin.Cikti("gorev liste", Gorevler);
    }

    private static readonly (HttpMethod Yontem, string Yol, object Govde, bool PlanIzni)[] Yazmalar =
    [
        (HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", new { metin = "iş" }, true),
        (HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/isaretle", new { madde = "a3f09c" }, true),
        (HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/devret", new { madde = "a3f09c" }, true),
        (HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/not", new { madde = "a3f09c", metin = "n" }, true),
        (HttpMethod.Post, "/api/beyin/gorevler/uye-girisi/gunlere-bol", new { gunSayisi = 1, baslangic = Tarih }, true),
        (HttpMethod.Post, "/api/beyin/gorevler", new { baslik = "Yeni", proje = "kitap-kulubu" }, false),
        (HttpMethod.Post, "/api/beyin/gorevler/uye-girisi/bitir", new { }, false),
    ];

    // Who may write

    [Fact]
    public async Task Writes_NeedASignIn_AndTheAsistanNeedsThePermission_AndTheBrainIsNeverCalledWithout()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        await IzinAsync(sahip, BeyinPolicies.PlanYaz, false);
        await IzinAsync(sahip, BeyinPolicies.GorevYaz, false);

        foreach (var (yontem, yol, govde, _) in Yazmalar)
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(yontem, yol, null, govde)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(yontem, yol, asistan, govde)).StatusCode);
        }

        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task ThePlanPermission_OpensThePlanWrites_AndTheTaskPermission_TheTaskWrites_NotEachOther()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        await IzinAsync(sahip, BeyinPolicies.PlanYaz, true);
        await IzinAsync(sahip, BeyinPolicies.GorevYaz, false);
        foreach (var (yontem, yol, govde, planIzni) in Yazmalar)
            Assert.Equal(planIzni ? HttpStatusCode.OK : HttpStatusCode.Forbidden, (await GonderAsync(yontem, yol, asistan, govde)).StatusCode);

        await IzinAsync(sahip, BeyinPolicies.PlanYaz, false);
        await IzinAsync(sahip, BeyinPolicies.GorevYaz, true);
        foreach (var (yontem, yol, govde, planIzni) in Yazmalar)
            Assert.Equal(planIzni ? HttpStatusCode.Forbidden : HttpStatusCode.OK, (await GonderAsync(yontem, yol, asistan, govde)).StatusCode);

        await IzinAsync(sahip, BeyinPolicies.GorevYaz, false);
    }

    [Fact]
    public async Task TheSahip_NeedsNoPermission()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        foreach (var (yontem, yol, govde, _) in Yazmalar)
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(yontem, yol, sahip, govde)).StatusCode);
    }

    [Fact]
    public void TheNewPermissions_AreInTheOneList() =>
        Assert.Contains(Kafamdakiler.Yonetim.Izinler.Tumu, i => i.Ad == "plan.yaz");

    [Fact]
    public async Task TheTaskPermissionsList_HasBoth()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var liste = await (await GonderAsync(HttpMethod.Get, "/api/yonetim/izinler", sahip)).Content.ReadAsStringAsync(Ct);

        Assert.Contains("plan.yaz", liste);
        Assert.Contains("gorev.yaz", liste);
    }

    // The repeat guard

    [Fact]
    public async Task SameKeyTwice_IsAppliedOnce_AndTheSecondGetsTheFirstAnswer()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = Anahtar();
        var govde = new { metin = "iş" };

        var birinci = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, govde, anahtar);
        var ikinci = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, govde, anahtar);

        Assert.Equal(HttpStatusCode.OK, birinci.StatusCode);
        Assert.Equal(HttpStatusCode.OK, ikinci.StatusCode);
        Assert.Equal(1, Cagri("gun", "ekle"));
        Assert.Equal(await birinci.Content.ReadAsStringAsync(Ct), await ikinci.Content.ReadAsStringAsync(Ct));
        Assert.False(birinci.Headers.Contains("Idempotent-Replayed"));
        Assert.Equal("true", ikinci.Headers.GetValues("Idempotent-Replayed").Single());
    }

    [Fact]
    public async Task SameKeyTwice_OnEveryWrite_AppliesEachOnce()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        foreach (var (yontem, yol, govde, _) in Yazmalar)
        {
            var anahtar = Anahtar();
            var birinci = await GonderAsync(yontem, yol, sahip, govde, anahtar);
            var ikinci = await GonderAsync(yontem, yol, sahip, govde, anahtar);

            Assert.Equal(HttpStatusCode.OK, birinci.StatusCode);
            Assert.Equal(await birinci.Content.ReadAsStringAsync(Ct), await ikinci.Content.ReadAsStringAsync(Ct));
            Assert.Equal("true", ikinci.Headers.GetValues("Idempotent-Replayed").Single());
        }

        // Once each: gun ekle (maddeler + gunlere-bol), isaretle, devret, not, gorev ekle, gorev bitir.
        Assert.Equal(2, Cagri("gun", "ekle"));
        Assert.Equal(1, Cagri("gun", "isaretle"));
        Assert.Equal(1, Cagri("gun", "devret"));
        Assert.Equal(1, Cagri("gun", "not"));
        Assert.Equal(1, Cagri("gorev", "ekle"));
        Assert.Equal(1, Cagri("gorev", "bitir"));
    }

    [Fact]
    public async Task WithoutAKey_EveryRequestRuns_LikeTheWebDoes()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        using var db = uygulama.YeniDb();
        var oncekiKayit = await db.BeyinIslemleri.CountAsync(Ct);

        await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "iş" });
        await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "iş" });

        Assert.Equal(2, Cagri("gun", "ekle"));
        Assert.Equal(oncekiKayit, await db.BeyinIslemleri.CountAsync(Ct));
    }

    [Fact]
    public async Task SameKeyWithOtherInput_Is422_AndNothingNewIsWritten()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = Anahtar();
        await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "birinci" }, anahtar);

        var baskaMetin = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "ikinci" }, anahtar);
        var baskaGun = await GonderAsync(HttpMethod.Post, "/api/beyin/gunler/2026-11-04/maddeler", sahip, new { metin = "birinci" }, anahtar);
        var baskaIslem = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/isaretle", sahip, new { madde = "a3f09c" }, anahtar);

        Assert.Equal(HttpStatusCode.UnprocessableEntity, baskaMetin.StatusCode);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, baskaGun.StatusCode);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, baskaIslem.StatusCode);
        Assert.Equal(1, Cagri("gun", "ekle"));
        Assert.Equal(0, Cagri("gun", "isaretle"));
    }

    [Fact]
    public async Task TheKeyBelongsToTheUser_TwoUsersMayUseTheSameString()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        await IzinAsync(sahip, BeyinPolicies.PlanYaz, true);
        var anahtar = Anahtar();

        var a = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "iş" }, anahtar);
        var b = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", asistan, new { metin = "iş" }, anahtar);

        Assert.Equal(HttpStatusCode.OK, a.StatusCode);
        Assert.Equal(HttpStatusCode.OK, b.StatusCode);
        Assert.False(b.Headers.Contains("Idempotent-Replayed"));
        Assert.Equal(2, Cagri("gun", "ekle"));
        await IzinAsync(sahip, BeyinPolicies.PlanYaz, false);
    }

    [Theory]
    [InlineData("a b")]
    [InlineData("a/b")]
    [InlineData("-baslayamaz")]
    public async Task ABadKey_Is400_AndNothingRuns(string anahtar)
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "iş" }, anahtar);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task ATooLongKey_Is400()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "iş" }, new string('k', 101));

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
    }

    [Fact]
    public async Task ARefusedWrite_IsNotKept_SoTheSameKeyCanBeTriedAgain()
    {
        BeyniHazirla();
        _beyin.Cikti("gun ekle", """{"hata": {"kod": "gun-kapali", "mesaj": "kapandı"}}""", cikis: 1);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = Anahtar();
        var yol = $"/api/beyin/gunler/{Tarih}/maddeler";

        var red = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar);
        using (var db = uygulama.YeniDb())
            Assert.DoesNotContain(await db.BeyinIslemleri.ToListAsync(Ct), i => i.Anahtar == anahtar);

        // The day is open again (or the brain is back): the same key now writes, and writes once.
        BeyniHazirla();
        var tekrar = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar);
        var yineTekrar = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar);

        Assert.Equal(HttpStatusCode.Conflict, red.StatusCode);
        Assert.Equal(HttpStatusCode.OK, tekrar.StatusCode);
        Assert.False(tekrar.Headers.Contains("Idempotent-Replayed"));
        Assert.Equal("true", yineTekrar.Headers.GetValues("Idempotent-Replayed").Single());
        Assert.Equal(2, Cagri("gun", "ekle"));
    }

    [Fact]
    public async Task AnUncertainWrite_IsKept_AndNeverRunAgainByTheSameKey()
    {
        BeyniHazirla();
        _beyin.Cikti("gun ekle", "???");
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = Anahtar();
        var yol = $"/api/beyin/gunler/{Tarih}/maddeler";

        var birinci = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar);
        // The brain is fine now, but the first attempt may have written: the key is not run again.
        BeyniHazirla();
        var ikinci = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar);

        Assert.Equal(HttpStatusCode.Accepted, birinci.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, ikinci.StatusCode);
        Assert.Equal("true", ikinci.Headers.GetValues("Idempotent-Replayed").Single());
        Assert.True(JsonDocument.Parse(await ikinci.Content.ReadAsStringAsync(Ct)).RootElement.GetProperty("yazilmisOlabilir").GetBoolean());
        Assert.Equal(1, Cagri("gun", "ekle"));
        using var db = uygulama.YeniDb();
        Assert.Equal(BeyinIslemiDurumu.Belirsiz, (await db.BeyinIslemleri.SingleAsync(i => i.Anahtar == anahtar, Ct)).Durum);
    }

    [Fact]
    public async Task APartialSplit_IsKept_SoARepeatDoesNotWriteTheFirstDaysAgain()
    {
        BeyniHazirla();
        _beyin.Sirali("gun ekle",
            ("""{"tarih": "2026-11-10", "madde": """ + MaddeJson + "}", 0),
            ("""{"hata": {"kod": "gun-kapali", "mesaj": "kapandı"}}""", 1));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = Anahtar();
        var govde = new { gunSayisi = 3, baslangic = "2026-11-10" };
        var yol = "/api/beyin/gorevler/uye-girisi/gunlere-bol";

        var birinci = await GonderAsync(HttpMethod.Post, yol, sahip, govde, anahtar);
        var ikinci = await GonderAsync(HttpMethod.Post, yol, sahip, govde, anahtar);

        Assert.Equal((HttpStatusCode)207, birinci.StatusCode);
        Assert.Equal((HttpStatusCode)207, ikinci.StatusCode);
        Assert.Equal(2, Cagri("gun", "ekle"));
        Assert.Equal(await birinci.Content.ReadAsStringAsync(Ct), await ikinci.Content.ReadAsStringAsync(Ct));
    }

    [Fact]
    public async Task TwoRequestsAtOnce_UnderOneKey_RunTheBrainOnce()
    {
        BeyniHazirla();
        _beyin.Gecikme(1.5);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = Anahtar();
        var yol = $"/api/beyin/gunler/{Tarih}/maddeler";

        var yanitlar = await Task.WhenAll(
            GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar),
            GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar));

        // One ran. The other either met the claim while it ran (409) or came after it finished (the same answer).
        Assert.Equal(1, Cagri("gun", "ekle"));
        Assert.Contains(yanitlar, y => y.StatusCode == HttpStatusCode.OK);
        Assert.All(yanitlar, y => Assert.Contains(y.StatusCode, new[] { HttpStatusCode.OK, HttpStatusCode.Conflict }));

        // And once it is done, the key replays.
        var sonra = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, anahtar);
        Assert.Equal(HttpStatusCode.OK, sonra.StatusCode);
        Assert.Equal("true", sonra.Headers.GetValues("Idempotent-Replayed").Single());
        Assert.Equal(1, Cagri("gun", "ekle"));
    }

    [Fact]
    public async Task AClaimThatNeverFinished_IsUncertain_NotRunAgain_OnceItIsOldEnough()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var kullanici = await KullaniciIdAsync(UygulamaFabrikasi.SahipEposta);
        var girdi = new MaddeEkleGirdi("iş", null, null);
        var parmakizi = TekrarGuvenligi.Parmakizi("madde-ekle", new { tarih = Tarih, girdi });
        var eski = Anahtar();
        var taze = Anahtar();
        using (var db = uygulama.YeniDb())
        {
            db.BeyinIslemleri.Add(new BeyinIslemi { KullaniciId = kullanici, Anahtar = eski, Parmakizi = parmakizi, CreatedAt = DateTimeOffset.UtcNow - TekrarGuvenligi.TakilmaSuresi - TimeSpan.FromMinutes(1) });
            db.BeyinIslemleri.Add(new BeyinIslemi { KullaniciId = kullanici, Anahtar = taze, Parmakizi = parmakizi, CreatedAt = DateTimeOffset.UtcNow - TimeSpan.FromMinutes(1) });
            await db.SaveChangesAsync(Ct);
        }

        var yol = $"/api/beyin/gunler/{Tarih}/maddeler";
        var eskiYanit = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, eski);
        var tazeYanit = await GonderAsync(HttpMethod.Post, yol, sahip, new { metin = "iş" }, taze);

        Assert.Equal(HttpStatusCode.Accepted, eskiYanit.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, tazeYanit.StatusCode);
        Assert.Empty(_beyin.Cagrilar());
        using var kontrol = uygulama.YeniDb();
        Assert.Equal(BeyinIslemiDurumu.Belirsiz, (await kontrol.BeyinIslemleri.SingleAsync(i => i.Anahtar == eski, Ct)).Durum);
        Assert.Equal(BeyinIslemiDurumu.Calisiyor, (await kontrol.BeyinIslemleri.SingleAsync(i => i.Anahtar == taze, Ct)).Durum);
    }

    [Fact]
    public async Task Records_OlderThanTheKeepingTime_AreRemovedOnTheNextKeyedWrite()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var kullanici = await KullaniciIdAsync(UygulamaFabrikasi.SahipEposta);
        var eski = Anahtar();
        using (var db = uygulama.YeniDb())
        {
            db.BeyinIslemleri.Add(new BeyinIslemi { KullaniciId = kullanici, Anahtar = eski, Parmakizi = "x", Durum = BeyinIslemiDurumu.Tamam, DurumKodu = 200, Cevap = "{}", CreatedAt = DateTimeOffset.UtcNow - TekrarGuvenligi.SaklamSuresi - TimeSpan.FromHours(1) });
            await db.SaveChangesAsync(Ct);
        }

        await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "iş" }, Anahtar());

        using var kontrol = uygulama.YeniDb();
        Assert.DoesNotContain(await kontrol.BeyinIslemleri.ToListAsync(Ct), i => i.Anahtar == eski);
    }

    private async Task<Guid> KullaniciIdAsync(string eposta)
    {
        using var db = uygulama.YeniDb();
        return (await db.Users.SingleAsync(u => u.Email == eposta, Ct)).Id;
    }

    // Validation reaches the client as a ProblemDetails

    [Fact]
    public async Task BadInput_Is400WithTheFieldName_AndNothingIsKeptUnderTheKey()
    {
        BeyniHazirla();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = Anahtar();

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/isaretle", sahip, new { madde = "3" }, anahtar);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.True(JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct)).RootElement.GetProperty("errors").TryGetProperty("madde", out _));
        using var db = uygulama.YeniDb();
        Assert.DoesNotContain(await db.BeyinIslemleri.ToListAsync(Ct), i => i.Anahtar == anahtar);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task BrainOff_WritesAre503()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, uygulama);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{Tarih}/maddeler", sahip, new { metin = "iş" }, Anahtar(), uygulama);

        Assert.Equal(HttpStatusCode.ServiceUnavailable, yanit.StatusCode);
    }

    // Reads: the capacity setting reaches the day, the morning card follows the day-turn rule

    [Fact]
    public async Task TheDay_CarriesTheCapacityWarning_FromTheSetting()
    {
        _beyin.Cikti("""
            {"tarih": "2026-11-03", "plan_var": true, "kapandi": false, "geciken": [],
             "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{"id": "a3f09c", "baslik": "Uzun iş", "durum": "acik", "tahmin_dk": 90}]}]}
            """);
        var kucuk = Fabrika(b => b.UseSetting("Gun:KapasiteSaat", "1"));
        var kucukSahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, kucuk);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var kucukYanit = await GonderAsync(HttpMethod.Get, $"/api/beyin/gunler/{Tarih}", kucukSahip, fabrika: kucuk);
        var varsayilanYanit = await GonderAsync(HttpMethod.Get, $"/api/beyin/gunler/{Tarih}", sahip);

        var uyari = JsonDocument.Parse(await kucukYanit.Content.ReadAsStringAsync(Ct)).RootElement.GetProperty("kapasiteUyarisi");
        Assert.Equal(30, uyari.GetProperty("asimDk").GetInt32());
        Assert.Equal(JsonValueKind.Null, JsonDocument.Parse(await varsayilanYanit.Content.ReadAsStringAsync(Ct)).RootElement.GetProperty("kapasiteUyarisi").ValueKind);
    }

    [Fact]
    public async Task TheMorningCard_AsksForYesterdayOfTheBrainsDay_AndNeedsBeyinOku()
    {
        _beyin.Cikti("""
            {"tarih": "2026-11-05", "plan_var": true, "kapandi": false, "geciken": [],
             "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{"id": "a3f09c", "baslik": "Kalan iş", "durum": "acik"}]}]}
            """);
        var saat = new ElleSaat(new DateTimeOffset(2026, 11, 7, 4, 59, 0, TimeSpan.FromHours(3)));
        var fabrika = Fabrika(b => b.ConfigureTestServices(s => s.AddSingleton<TimeProvider>(saat)));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinAsync(sahip, BeyinPolicies.Oku, false, fabrika);

        var yasak = await GonderAsync(HttpMethod.Get, "/api/beyin/sabah", asistan, fabrika: fabrika);
        var yanit = await GonderAsync(HttpMethod.Get, "/api/beyin/sabah", sahip, fabrika: fabrika);

        Assert.Equal(HttpStatusCode.Forbidden, yasak.StatusCode);
        var kart = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct)).RootElement;
        Assert.Equal("2026-11-05", kart.GetProperty("dun").GetString());
        Assert.Equal("2026-11-06", kart.GetProperty("bugun").GetString());
        Assert.Equal("a3f09c", kart.GetProperty("maddeler")[0].GetProperty("id").GetString());
        // The day (yesterday) is asked once; the list of tasks the card may show is asked beside it (E9).
        Assert.Equal("--tarih=2026-11-05", SahteBeyin.Argumanlar(_beyin.Cagrilar().Single(c => SahteBeyin.Argumanlar(c)[0] == "gun"))[2]);
    }
}
