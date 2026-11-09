using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Isler;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// /api/isler against the whole app (real pipeline, bearer tokens, database) with a fake beyin.py behind it. What must not pass silently:
// who may read and write, what the brain is really asked (the writer's name, the gate approval the server adds, no stray option),
// a refusal of the brain turning into words that do not carry a path, and the notification buttons.
public sealed class IsApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private readonly SahteBeyin _beyin = new("ok");
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];
    private WebApplicationFactory<Program>? _acik;

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        _beyin.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private WebApplicationFactory<Program> Acik => _acik ??= Fabrika();

    private WebApplicationFactory<Program> Fabrika()
    {
        var fabrika = uygulama.WithWebHostBuilder(b => b
            .UseSetting("Beyin:Komut", _beyin.Komut)
            .UseSetting("Beyin:Vault", _beyin.Vault)
            .UseSetting("Beyin:GonderimAraligiSaniye", "3600"));
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    private async Task<string> GirisAsync(string eposta)
    {
        var yanit = await Acik.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string? token, object? govde = null, string? anahtar = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (anahtar is not null)
            istek.Headers.Add("Idempotency-Key", anahtar);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await Acik.CreateClient().SendAsync(istek, Ct);
    }

    private async Task<(HttpStatusCode Durum, JsonElement Govde, string Ham)> OkuAsync(HttpResponseMessage yanit)
    {
        var ham = await yanit.Content.ReadAsStringAsync(Ct);
        return (yanit.StatusCode, ham.Length == 0 ? default : JsonDocument.Parse(ham).RootElement.Clone(), ham);
    }

    private async Task IzinAsync(string sahip, string izin, bool acik)
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, new { acik });
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
    }

    private static string Bugun() => GunSiniri.Bugun(DateTimeOffset.UtcNow).ToString("yyyy-MM-dd");

    // The calls the brain got for `is <alt>`: their arguments.
    private List<string[]> Cagrilar(string alt) =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(a => a[0] == "is" && a[1] == alt).ToList();

    // Who may read and write

    [Fact]
    public async Task TheCards_NeedASignIn_AndTheAsistanNeedsTheReadAndWritePermissions_AndTheBrainIsNeverCalledWithout()
    {
        _beyin.Cikti("is liste", SahteIsKarti.Liste());
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir"));
        _beyin.Cikti("is not", SahteIsKarti.Kart("kart-bir"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        await IzinAsync(sahip, IsPolicies.Oku, false);
        await IzinAsync(sahip, IsPolicies.Yaz, false);

        (HttpMethod, string, object?)[] hepsi =
        [
            (HttpMethod.Get, "/api/isler", null),
            (HttpMethod.Get, "/api/isler/kart-bir", null),
            (HttpMethod.Post, "/api/isler", new { baslik = "x", proje = "kitap-kulubu" }),
            (HttpMethod.Post, "/api/isler/kart-bir/cevap", new { soruNo = 1, cevap = "a" }),
            (HttpMethod.Post, "/api/isler/kart-bir/asama", new { asama = "plan" }),
            (HttpMethod.Post, "/api/isler/kart-bir/not", new { metin = "n" }),
        ];
        foreach (var (yontem, yol, govde) in hepsi)
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(yontem, yol, null, govde)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(yontem, yol, asistan, govde)).StatusCode);
        }

        Assert.Empty(_beyin.Cagrilar());

        // Reading does not open writing, and writing does not open reading.
        await IzinAsync(sahip, IsPolicies.Oku, true);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/isler", asistan)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/not", asistan, new { metin = "n" })).StatusCode);
        await IzinAsync(sahip, IsPolicies.Oku, false);
        await IzinAsync(sahip, IsPolicies.Yaz, true);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/isler", asistan)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/not", asistan, new { metin = "n" })).StatusCode);
        await IzinAsync(sahip, IsPolicies.Yaz, false);
    }

    [Fact]
    public async Task TheSahip_NeedsNoPermission()
    {
        _beyin.Cikti("is liste", SahteIsKarti.Liste(SahteIsKarti.Kart("kart-bir")));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, govde, _) = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/isler", sahip));

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Equal("kart-bir", govde[0].GetProperty("kimlik").GetString());
    }

    // Reading

    [Fact]
    public async Task TheList_ShowsOpenVisibleCards_WithoutThePathOrHiddenOnes_AndAsksTheBrainForOpenOnly()
    {
        _beyin.Cikti("is liste", SahteIsKarti.Liste(
            SahteIsKarti.Kart("acik-bir", asama: "karar", bekleyenSoru: 2),
            SahteIsKarti.Kart("gizli-kart", gizli: true),
            SahteIsKarti.Kart("finans-kart", proje: null, alan: "finans"),
            SahteIsKarti.Kart("bozuk-kart", hata: "üst bilgi okunamadı"),
            SahteIsKarti.Kart("genel-alan", proje: null, alan: "ogrenme", tip: "genel")));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, govde, ham) = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/isler?asama=karar&proje=kitap-kulubu", sahip));

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Equal(["acik-bir", "genel-alan"], govde.EnumerateArray().Select(k => k.GetProperty("kimlik").GetString()));
        Assert.DoesNotContain("projects/", ham);
        Assert.DoesNotContain("yol", ham);
        var ilk = govde[0];
        Assert.Equal(("karar", "kod", 2, true), (ilk.GetProperty("asama").GetString(), ilk.GetProperty("tip").GetString(), ilk.GetProperty("bekleyenSoru").GetInt32(), ilk.GetProperty("acik").GetBoolean()));
        var a = Assert.Single(Cagrilar("liste"));
        Assert.Contains("--acik", a);
        Assert.Contains("--asama=karar", a);
        Assert.Contains("--proje=kitap-kulubu", a);
        Assert.DoesNotContain("--gizli-dahil", a);
    }

    [Fact]
    public async Task TheClosedFlag_AddsOnlyTheCardsFinishedThisWeek()
    {
        var bugun = Bugun();
        var eski = GunSiniri.Bugun(DateTimeOffset.UtcNow).AddDays(-30).ToString("yyyy-MM-dd");
        _beyin.Cikti("is liste", SahteIsKarti.Liste(
            SahteIsKarti.Kart("acik-bir", asama: "yapim"),
            SahteIsKarti.Kart("bu-hafta-bitti", asama: "bitti", guncelleme: bugun + "T10:00"),
            SahteIsKarti.Kart("eski-bitti", asama: "bitti", guncelleme: eski + "T10:00"),
            SahteIsKarti.Kart("iptal-kart", asama: "iptal", guncelleme: bugun + "T10:00")));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (_, govde, _) = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/isler?kapali=true", sahip));

        Assert.Equal(["acik-bir", "bu-hafta-bitti"], govde.EnumerateArray().Select(k => k.GetProperty("kimlik").GetString()));
        Assert.DoesNotContain("--acik", Assert.Single(Cagrilar("liste")));
    }

    [Theory]
    [InlineData("/api/isler?asama=uydurma")]
    [InlineData("/api/isler?proje=../etc")]
    [InlineData("/api/isler/Bu_Bir_Yol")]
    public async Task AnInvalidFilterOrId_IsA400_AndTheBrainIsNotCalled(string yol)
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, yol, sahip)).StatusCode);

        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task TheDetail_ShowsRequestPlanQuestionsAndHistory()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular:
        [
            new(1, "Hangi kütüphane?", ["a", "b"], "a", "Daha hafif"),
            new(2, "Ne zaman?", Cevap: "Bu hafta"),
        ], gecmis: ["kullanici: oluşturuldu", "vps: plan yazıldı"]));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, k, ham) = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/isler/kart-bir", sahip));

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Equal(("Talep metni", "## Adımlar\n- bir"), (k.GetProperty("talep").GetString(), k.GetProperty("plan").GetString()));
        var s1 = k.GetProperty("sorular")[0];
        Assert.Equal(("Hangi kütüphane?", "a", "Daha hafif", JsonValueKind.Null), (s1.GetProperty("soru").GetString(), s1.GetProperty("onerilen").GetString(), s1.GetProperty("neden").GetString(), s1.GetProperty("cevap").ValueKind));
        Assert.Equal(["a", "b"], s1.GetProperty("secenekler").EnumerateArray().Select(e => e.GetString()));
        Assert.Equal("Bu hafta", k.GetProperty("sorular")[1].GetProperty("cevap").GetString());
        Assert.Equal(["oluşturuldu", "plan yazıldı"], k.GetProperty("gecmis").EnumerateArray().Select(g => g.GetProperty("olay").GetString()));
        Assert.DoesNotContain("projects/", ham);
    }

    [Theory]
    [InlineData("bulunamadi")]
    [InlineData("gizli")]
    public async Task ACardThatDoesNotExistOrIsHidden_IsA404_WithoutThePath(string kod)
    {
        _beyin.Cikti("is goster", SahteIsKarti.Hata(kod), cikis: 1);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, _, ham) = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/isler/kart-bir", sahip));

        Assert.Equal(HttpStatusCode.NotFound, durum);
        Assert.DoesNotContain("/home/", ham);
    }

    [Fact]
    public async Task ACardInAClosedFolder_LooksLikeOneThatDoesNotExist()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir").Replace("projects/kitap-kulubu/isler/kart-bir.md", "kisisel/isler/kart-bir.md"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Get, "/api/isler/kart-bir", sahip)).StatusCode);
    }

    // Opening a card

    [Fact]
    public async Task OpeningACard_AsksTheBrain_AsThePersonAtThePhone_WithTheRequestInAFile()
    {
        _beyin.Cikti("is ekle", SahteIsKarti.Kart("takvim-sayfasi", asama: "talep", sahip: "vps"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, k, _) = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/isler", sahip,
            new { baslik = "Takvim sayfası", talep = "Satır bir\n- satır iki", proje = "kitap-kulubu", tip = "genel" }));

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Equal(("takvim-sayfasi", "talep", "vps"), (k.GetProperty("kimlik").GetString(), k.GetProperty("asama").GetString(), k.GetProperty("sahip").GetString()));
        var cagri = Assert.Single(_beyin.Cagrilar());
        var a = SahteBeyin.Argumanlar(cagri);
        Assert.Equal(["is", "ekle"], a[..2]);
        Assert.Contains("--kim=kullanici", a);
        Assert.Contains("--baslik=Takvim sayfası", a);
        Assert.Contains("--tip=genel", a);
        Assert.Contains("--kaynak=telefon", a);
        Assert.Contains("--sahip=vps", a);
        Assert.Contains("--proje=kitap-kulubu", a);
        Assert.Equal("Satır bir\n- satır iki", cagri.GetProperty("metin").GetString());
        Assert.DoesNotContain(a, x => x.Contains("Satır bir"));
    }

    [Fact]
    public async Task OpeningACard_InAnArea_DefaultsToCodeType()
    {
        _beyin.Cikti("is ekle", SahteIsKarti.Kart("kitap-listesi", asama: "talep", sahip: "vps", proje: null, alan: "ogrenme"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/isler", sahip, new { baslik = "Kitap listesi", alan = "ogrenme" })).StatusCode);

        var a = SahteBeyin.Argumanlar(Assert.Single(_beyin.Cagrilar()));
        Assert.Contains("--alan=ogrenme", a);
        Assert.Contains("--tip=kod", a);
    }

    [Theory]
    [InlineData("{\"baslik\":\"\",\"proje\":\"kitap-kulubu\"}")]
    [InlineData("{\"proje\":\"kitap-kulubu\"}")]
    [InlineData("{\"baslik\":\"x\"}")]
    [InlineData("{\"baslik\":\"x\",\"proje\":\"kitap-kulubu\",\"alan\":\"ogrenme\"}")]
    [InlineData("{\"baslik\":\"x\",\"alan\":\"finans\"}")]
    [InlineData("{\"baslik\":\"x\",\"alan\":\"projects\"}")]
    [InlineData("{\"baslik\":\"x\",\"proje\":\"Büyük Harf\"}")]
    [InlineData("{\"baslik\":\"x\",\"proje\":\"kitap-kulubu\",\"tip\":\"uydurma\"}")]
    [InlineData("{\"baslik\":\"satır\\nsonu\",\"proje\":\"kitap-kulubu\"}")]
    public async Task AnInvalidNewCard_Is400_AndNothingIsWritten(string govde)
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        using var icerik = new StringContent(govde, System.Text.Encoding.UTF8, "application/json");
        using var istek = new HttpRequestMessage(HttpMethod.Post, "/api/isler") { Content = icerik };
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", sahip);

        Assert.Equal(HttpStatusCode.BadRequest, (await Acik.CreateClient().SendAsync(istek, Ct)).StatusCode);

        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task AProjectTheBrainDoesNotKnow_IsRefusedInWords_WithoutThePath()
    {
        _beyin.Cikti("is ekle", SahteIsKarti.Hata("hata", "proje klasörü yok: projects/olmayan/ (önce `projects/_sablon` kopyalanır)"), cikis: 1);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, govde, ham) = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/isler", sahip, new { baslik = "x", proje = "olmayan" }));

        Assert.Equal(HttpStatusCode.Conflict, durum);
        Assert.Equal("İşlem uygulanamadı", govde.GetProperty("title").GetString());
        Assert.DoesNotContain("projects/", ham);
    }

    // Answering

    [Fact]
    public async Task AnAnswer_IsWrittenAsThePerson_WithTheValueAfterTheSeparator()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(1, "Hangi?", ["-x", "b"])]));
        _beyin.Cikti("is cevapla", SahteIsKarti.Kart("kart-bir"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/cevap", sahip, new { soruNo = 1, cevap = "-x" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var a = Assert.Single(Cagrilar("cevapla"));
        Assert.Contains("--kim=kullanici", a);
        Assert.Equal(["kart-bir", "1", "-x"], a[(Array.IndexOf(a, "--") + 1)..]);
    }

    [Fact]
    public async Task AQuestionThatIsAlreadyAnswered_IsLocked_ButTheSameAnswerAgainIsFine()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(1, "Hangi?", ["a", "b"], Cevap: "a")]));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, _, _) = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/cevap", sahip, new { soruNo = 1, cevap = "b" }));
        var ayni = await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/cevap", sahip, new { soruNo = 1, cevap = "a" });

        Assert.Equal(HttpStatusCode.Conflict, durum);
        Assert.Equal(HttpStatusCode.OK, ayni.StatusCode);
        Assert.Empty(Cagrilar("cevapla"));
    }

    [Fact]
    public async Task AnAnswerToAQuestionThatIsNotThere_IsA404()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(1, "Hangi?")]));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/cevap", sahip, new { soruNo = 7, cevap = "a" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/cevap", sahip, new { soruNo = 0, cevap = "a" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/cevap", sahip, new { soruNo = 1, cevap = " " })).StatusCode);
        Assert.Empty(Cagrilar("cevapla"));
    }

    // Stages

    [Fact]
    public async Task LeavingTheCodeGateForward_CarriesTheApprovalOfThePhone_AndGoingBackOrCancellingDoesNot()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "kod-onayi"));
        _beyin.Cikti("is asama", SahteIsKarti.Kart("kart-bir", asama: "yapim"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/asama", sahip, new { asama = "yapim" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/asama", sahip, new { asama = "plan", not = "Kapsam dar" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/asama", sahip, new { asama = "iptal", gerekce = "Vazgeçtim" })).StatusCode);

        var cagrilar = Cagrilar("asama");
        Assert.Equal(3, cagrilar.Count);
        Assert.Contains($"--onay=onay:telefon-{Bugun()}", cagrilar[0]);
        Assert.All(cagrilar, a => Assert.Contains("--kim=kullanici", a));
        Assert.Equal(["kart-bir", "yapim"], cagrilar[0][(Array.IndexOf(cagrilar[0], "--") + 1)..]);
        Assert.DoesNotContain(cagrilar[1], a => a.StartsWith("--onay"));
        Assert.Contains("--not=Kapsam dar", cagrilar[1]);
        Assert.DoesNotContain(cagrilar[2], a => a.StartsWith("--onay"));
        Assert.Contains("--gerekce=Vazgeçtim", cagrilar[2]);
    }

    [Fact]
    public async Task AnApproval_IsNeverTakenFromTheRequest_AndOtherStagesCarryNone()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "plan"));
        _beyin.Cikti("is asama", SahteIsKarti.Kart("kart-bir", asama: "karar"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        // A body that tries to bring its own approval: the field is simply not read.
        var yanit = await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/asama", sahip, new { asama = "karar", onay = "onay:ben" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.DoesNotContain(Assert.Single(Cagrilar("asama")), a => a.StartsWith("--onay"));
    }

    [Theory]
    [InlineData("{\"asama\":\"iptal\"}")]
    [InlineData("{\"asama\":\"plan\",\"gerekce\":\"neden\"}")]
    [InlineData("{\"asama\":\"talep\"}")]
    [InlineData("{\"asama\":\"uydurma\"}")]
    [InlineData("{}")]
    public async Task AnInvalidStageRequest_Is400_AndNothingIsWritten(string govde)
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "plan"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        using var icerik = new StringContent(govde, System.Text.Encoding.UTF8, "application/json");
        using var istek = new HttpRequestMessage(HttpMethod.Post, "/api/isler/kart-bir/asama") { Content = icerik };
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", sahip);

        Assert.Equal(HttpStatusCode.BadRequest, (await Acik.CreateClient().SendAsync(istek, Ct)).StatusCode);

        Assert.Empty(Cagrilar("asama"));
    }

    [Theory]
    [InlineData("cevapsiz-soru", HttpStatusCode.Conflict, "Cevapsız soru var", "soruları cevapla")]
    [InlineData("gecersiz-gecis", HttpStatusCode.Conflict, "Aşama değiştirilemedi", "geçemez")]
    [InlineData("kilitli", HttpStatusCode.Conflict, "Kart kilitli", "oturumda")]
    [InlineData("kapali", HttpStatusCode.Conflict, "Kart kapalı", "iptal edilmiş")]
    [InlineData("onay-gerekli", HttpStatusCode.Conflict, "Onay gerekli", "onay")]
    [InlineData("bozuk-kart", HttpStatusCode.Conflict, "Kart bozuk", "okunamıyor")]
    [InlineData("bulunamadi", HttpStatusCode.NotFound, "Bulunamadı", "bulunamadı")]
    [InlineData("gerekce-gerekli", HttpStatusCode.BadRequest, "Gerekçe gerekli", "gerekçe")]
    public async Task ARefusalOfTheBrain_BecomesAReadableMessage_WithoutThePath(string kod, HttpStatusCode beklenen, string baslik, string ayrintiParcasi)
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "karar"));
        _beyin.Cikti("is asama", SahteIsKarti.Hata(kod), cikis: 1);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, govde, ham) = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/asama", sahip, new { asama = "kod-onayi" }));

        Assert.Equal(beklenen, durum);
        Assert.Equal(baslik, govde.GetProperty("title").GetString());
        Assert.Contains(ayrintiParcasi, govde.GetProperty("detail").GetString());
        Assert.DoesNotContain("/home/", ham);
        Assert.DoesNotContain("projects/", ham);
    }

    [Fact]
    public async Task ABrainThatDoesNotAnswerInTime_IsAnUncertainWrite_NotAFailure()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "plan"));
        _beyin.Cikti("is asama", "???", cikis: 0);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var (durum, govde, _) = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/asama", sahip, new { asama = "karar" }));

        Assert.Equal(HttpStatusCode.Accepted, durum);
        Assert.True(govde.GetProperty("yazilmisOlabilir").GetBoolean());
    }

    // Notes and repeats

    [Fact]
    public async Task ANote_IsWrittenAsThePerson()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir"));
        _beyin.Cikti("is not", SahteIsKarti.Kart("kart-bir"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/not", sahip, new { metin = "--acele" })).StatusCode);

        var a = Assert.Single(Cagrilar("not"));
        Assert.Contains("--kim=kullanici", a);
        Assert.Equal(["kart-bir", "--acele"], a[(Array.IndexOf(a, "--") + 1)..]);
    }

    [Fact]
    public async Task AWriteSentTwiceUnderOneKey_IsAppliedOnce()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir"));
        _beyin.Cikti("is not", SahteIsKarti.Kart("kart-bir"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var anahtar = "k-" + Guid.NewGuid().ToString("N");

        var bir = await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/not", sahip, new { metin = "bir" }, anahtar);
        var iki = await GonderAsync(HttpMethod.Post, "/api/isler/kart-bir/not", sahip, new { metin = "bir" }, anahtar);

        Assert.Equal((HttpStatusCode.OK, HttpStatusCode.OK), (bir.StatusCode, iki.StatusCode));
        Assert.Single(Cagrilar("not"));
    }

    // Notification buttons

    private async Task<Guid> BildirimEkleAsync(string eposta, string kimlik, string kaynak = "is")
    {
        await using var db = uygulama.YeniDb();
        var kullanici = await db.Users.AsNoTracking().FirstAsync(u => u.Email == eposta, Ct);
        var b = new Bildirim
        {
            KullaniciId = kullanici.Id, Baslik = "Kart", Metin = "Karar bekliyor", KaynakTuru = kaynak, Rota = IsBildirimci.Rota, HedefKimligi = kimlik,
            Anahtar = "is:" + Guid.NewGuid().ToString("N"), OlusmaAni = DateTimeOffset.UtcNow,
        };
        db.Bildirimler.Add(b);
        await db.SaveChangesAsync(Ct);
        return b.Id;
    }

    private async Task<JsonElement> SecenekleriAlAsync(string token, Guid id)
    {
        var (durum, govde, _) = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/bildirimler/{id}", token));
        Assert.Equal(HttpStatusCode.OK, durum);
        return govde.TryGetProperty("secenekler", out var s) ? s : default;
    }

    [Fact]
    public async Task TheNotificationOfACodeGate_OffersApproveAndBackToPlan()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "kod-onayi"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var id = await BildirimEkleAsync(UygulamaFabrikasi.SahipEposta, "kart-bir");

        var s = await SecenekleriAlAsync(sahip, id);

        Assert.Equal(["Onayla", "Plana dön"], s.EnumerateArray().Select(e => e.GetProperty("etiket").GetString()));
        Assert.Equal([("asama", "yapim"), ("asama", "plan")], s.EnumerateArray().Select(e => (e.GetProperty("eylem").GetString()!, e.GetProperty("asama").GetString()!)));
    }

    [Fact]
    public async Task TheNotificationOfADecision_OffersTheOptionsOfTheOnlyOpenQuestion_UpToThree()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var id = await BildirimEkleAsync(UygulamaFabrikasi.SahipEposta, "kart-bir");

        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(1, "Eski", ["x"], Cevap: "x"), new(2, "Hangi?", ["a", "b"], "a")]));
        var iki = await SecenekleriAlAsync(sahip, id);
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(1, "Hangi?", ["a", "b", "c", "d"])]));
        var dort = await SecenekleriAlAsync(sahip, id);
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(1, "Bir", ["a", "b"]), new(2, "İki", ["a", "b"])]));
        var ikiSoru = await SecenekleriAlAsync(sahip, id);
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(1, "Serbest")]));
        var seceneksiz = await SecenekleriAlAsync(sahip, id);

        Assert.Equal([("cevap", 2, "a"), ("cevap", 2, "b")], iki.EnumerateArray().Select(e => (e.GetProperty("eylem").GetString()!, e.GetProperty("soruNo").GetInt32(), e.GetProperty("cevap").GetString()!)));
        Assert.True(dort.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || dort.GetArrayLength() == 0);
        Assert.True(ikiSoru.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || ikiSoru.GetArrayLength() == 0);
        Assert.True(seceneksiz.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || seceneksiz.GetArrayLength() == 0);
    }

    [Theory]
    [InlineData("push-onayi")]
    [InlineData("deploy-onayi")]
    [InlineData("yapim")]
    public async Task ThePushAndDeployGates_HaveNoButtons_AndNeitherDoesACardThatHasMovedOn(string asama)
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: asama));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var id = await BildirimEkleAsync(UygulamaFabrikasi.SahipEposta, "kart-bir");

        var s = await SecenekleriAlAsync(sahip, id);

        Assert.True(s.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || s.GetArrayLength() == 0);
    }

    [Fact]
    public async Task APersonWhoMayNotWriteTheCards_GetsNoButtons_AndOtherNotificationsNeverAskTheBrain()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "kod-onayi"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        await IzinAsync(sahip, IsPolicies.Yaz, false);
        var asistanId = await BildirimEkleAsync(UygulamaFabrikasi.AsistanEposta, "kart-bir");
        var baskasi = await BildirimEkleAsync(UygulamaFabrikasi.SahipEposta, "kart-bir", kaynak: "hatirlatici");

        var s = await SecenekleriAlAsync(asistan, asistanId);
        var b = await SecenekleriAlAsync(sahip, baskasi);

        Assert.True(s.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || s.GetArrayLength() == 0);
        Assert.True(b.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null || b.GetArrayLength() == 0);
        Assert.Empty(Cagrilar("goster"));
    }
}
