using System.Net;
using System.Text.RegularExpressions;
using Kafamdakiler.Beyin;
using Kafamdakiler.Isler;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// The read-only work card pages of the web (/Isler), the whole app with a fake beyin.py behind it. Closed to the Asistan and to
// signed-out visitors; with the brain off a message, never a 500; nothing a card contains reaches the page as markup.
public sealed partial class IsSayfalariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Kotu = "<script>alert('xss')</script>";

    private readonly SahteBeyin _beyin = new("ok");
    private WebApplicationFactory<Program>? _acik;

    private WebApplicationFactory<Program> Acik => _acik ??= uygulama.WithWebHostBuilder(b => b
        .UseSetting("Beyin:Komut", _beyin.Komut)
        .UseSetting("Beyin:Vault", _beyin.Vault)
        .UseSetting("Beyin:GonderimAraligiSaniye", "3600"));

    public void Dispose()
    {
        _acik?.Dispose();
        _beyin.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    [Fact]
    public async Task ThePages_AreClosedToVisitorsAndTheAsistan()
    {
        var anonim = uygulama.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        var asistan = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.AsistanEposta, Ct);

        foreach (var yol in new[] { "/Isler", "/Isler/Detay/kart-bir" })
        {
            var a = await anonim.GetAsync(yol, Ct);
            Assert.Equal(("/Hesap/Giris", HttpStatusCode.Redirect), (a.Headers.Location!.AbsolutePath, a.StatusCode));
            var b = await asistan.GetAsync(yol, Ct);
            Assert.Equal(("/Hesap/Erisim", HttpStatusCode.Redirect), (b.Headers.Location!.AbsolutePath, b.StatusCode));
        }

        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task TheList_ShowsOpenCardsAndThisWeeksFinishedOnes_EscapedAndWithoutHiddenOnes()
    {
        var bugun = GunSiniri.Bugun(DateTimeOffset.UtcNow).ToString("yyyy-MM-dd");
        _beyin.Cikti("is liste", SahteIsKarti.Liste(
            SahteIsKarti.Kart("kart-bir", "karar", baslik: Kotu, bekleyenSoru: 2),
            SahteIsKarti.Kart("kart-iki", "yapim", sahip: "vps", baslik: "Takvim sayfası"),
            SahteIsKarti.Kart("bitti-kart", "bitti", baslik: "Biten iş", guncelleme: bugun + "T09:00"),
            SahteIsKarti.Kart("gizli-kart", baslik: "Gizli iş", gizli: true)));
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await sahip.GetAsync("/Isler", Ct);
        var ham = await WebOturumu.HamAsync(yanit, Ct);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.DoesNotContain("<script>alert", ham);
        Assert.Contains("&lt;script&gt;", ham);
        Assert.Contains("Takvim sayfası", metin);
        Assert.Contains("2 cevapsız soru", metin);
        Assert.Contains("Biten iş", metin);
        Assert.DoesNotContain("Gizli iş", metin);
        Assert.Contains("/Isler/Detay/kart-iki", ham);
    }

    [Fact]
    public async Task TheDetail_ShowsRequestPlanQuestionsAndHistory_Escaped()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", talep: Kotu, plan: "## Plan\n- adım", sorular:
        [
            new(1, "Hangi kütüphane?", ["a", "b"], "a", "Daha hafif"),
            new(2, "Ne zaman?", Cevap: "Bu hafta"),
        ], gecmis: ["kullanici: oluşturuldu", "vps: plan yazıldı"]));
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await sahip.GetAsync("/Isler/Detay/kart-bir", Ct);
        var ham = await WebOturumu.HamAsync(yanit, Ct);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.DoesNotContain("<script>alert", ham);
        Assert.Contains("- adım", metin);
        Assert.Contains("S1: Hangi kütüphane?", metin);
        Assert.Contains("Önerilen: a", metin);
        Assert.Contains("Neden: Daha hafif", metin);
        Assert.Contains("Cevap bekliyor", metin);
        Assert.Contains("Cevap: Bu hafta", metin);
        Assert.Contains("plan yazıldı", metin);
        Assert.DoesNotContain("projects/", ham);
    }

    [Fact]
    public async Task ACardThatIsNotThere_IsA404Page_AndTheBrainBeingOff_IsAMessage()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Hata("bulunamadi"), cikis: 1);
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);
        var kapali = await WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);

        var yok = await sahip.GetAsync("/Isler/Detay/kart-bir", Ct);
        Assert.Equal(HttpStatusCode.NotFound, yok.StatusCode);
        Assert.DoesNotContain("/home/", await WebOturumu.HamAsync(yok, Ct));

        foreach (var yol in new[] { "/Isler", "/Isler/Detay/kart-bir" })
        {
            var yanit = await kapali.GetAsync(yol, Ct);
            Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
            Assert.Contains("Beyin bağlı değil", await WebOturumu.MetinAsync(yanit, Ct));
        }
    }

    // E6: answering a question and sending a card back to its plan

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    private const string Kart = "/Isler/Detay/kart-bir";

    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string islem, Dictionary<string, string> alanlar)
    {
        var token = TokenDeseni().Match(await tarayici.GetStringAsync(Kart, Ct)).Groups[1].Value;
        Assert.NotEmpty(token);
        return await tarayici.PostAsync($"{Kart}?handler={islem}", new FormUrlEncodedContent(new Dictionary<string, string>(alanlar) { ["__RequestVerificationToken"] = token }), Ct);
    }

    private async Task<string> SonrakiAsync(HttpClient tarayici, HttpResponseMessage yonlendirme)
    {
        Assert.Equal(HttpStatusCode.Redirect, yonlendirme.StatusCode);
        return WebUtility.HtmlDecode(await tarayici.GetStringAsync(yonlendirme.Headers.Location, Ct));
    }

    private string[][] BeyinCagrilari(string komut, string alt) =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(c => c[0] == komut && c[1] == alt).ToArray();

    private static SahteIsKarti.Soru[] IkiSoru() =>
    [
        new(1, "Hangi kütüphane?", ["a", "b"], "a", "Daha hafif"),
        new(2, "Ne zaman?", Cevap: "Bu hafta"),
    ];

    [Fact]
    public async Task AnOpenQuestion_OffersItsOptions_AndAlwaysTheOwnAnswerField_AnAnsweredOneOffersNothing()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: IkiSoru()));
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var ham = await sahip.GetStringAsync(Kart, Ct);

        // Question 1 (open): one button per option (two) and the free field. Question 2 (answered): nothing.
        Assert.Equal(3, Regex.Matches(ham, "name=\"soruNo\" value=\"1\"").Count);
        Assert.DoesNotContain("name=\"soruNo\" value=\"2\"", ham);
        Assert.Contains("name=\"cevap\" value=\"a\"", ham);
        Assert.Contains("name=\"cevap\" value=\"b\"", ham);
        Assert.Single(Regex.Matches(ham, "placeholder=\"Kendi cevabım\""));

        // A question with no options still has the free field.
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: [new(3, "Serbest soru?")]));
        var seceneksiz = await sahip.GetStringAsync(Kart, Ct);
        Assert.Single(Regex.Matches(seceneksiz, "placeholder=\"Kendi cevabım\""));
        Assert.DoesNotContain("name=\"cevap\" value=", seceneksiz);

        // A closed card is not answered from here.
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "bitti", sorular: [new(1, "Eski soru?")]));
        Assert.DoesNotContain("Kendi cevabım", await sahip.GetStringAsync(Kart, Ct));
    }

    [Fact]
    public async Task AnOptionAndTheOwnWords_BothGoToTheBrainAsTheAnswerOfThatQuestion()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: IkiSoru()));
        _beyin.Cikti("is cevapla", SahteIsKarti.Kart("kart-bir"));
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var secenek = await SonrakiAsync(sahip, await PostAsync(sahip, "Cevap", new() { ["soruNo"] = "1", ["cevap"] = "b" }));
        var kendi = await SonrakiAsync(sahip, await PostAsync(sahip, "Cevap", new() { ["soruNo"] = "1", ["cevap"] = "-ikisi de değil, kendi yolum" }));

        Assert.Contains("Cevap yazıldı", secenek);
        Assert.Contains("Cevap yazıldı", kendi);
        var cagrilar = BeyinCagrilari("is", "cevapla");
        Assert.Equal(2, cagrilar.Length);
        Assert.Equal(["kart-bir", "1", "b"], cagrilar[0][^3..]);
        Assert.Equal(["kart-bir", "1", "-ikisi de değil, kendi yolum"], cagrilar[1][^3..]);
    }

    [Fact]
    public async Task AnEmptyOwnAnswer_IsRefusedBeforeTheBrain()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: IkiSoru()));
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var sonraki = await SonrakiAsync(sahip, await PostAsync(sahip, "Cevap", new() { ["soruNo"] = "1", ["cevap"] = "   " }));

        Assert.Contains("Cevap boş olamaz.", sonraki);
        Assert.Empty(BeyinCagrilari("is", "cevapla"));
    }

    [Fact]
    public async Task ABrainRefusalOfAnAnswer_IsSaidOnThePage_WithoutAPath()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", sorular: IkiSoru()));
        // The card already holds another answer for question 2 (locked): the API's 409 sentence is what the page says.
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var sonraki = await SonrakiAsync(sahip, await PostAsync(sahip, "Cevap", new() { ["soruNo"] = "2", ["cevap"] = "Başka bir şey" }));

        Assert.Contains("başka bir cevap yazılmış", sonraki);
        Assert.DoesNotContain("projects/", sonraki);
        Assert.Empty(BeyinCagrilari("is", "cevapla"));
    }

    [Fact]
    public async Task SendBackToPlan_NeedsANote_AndAnEmptyOneNeverReachesTheBrain()
    {
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "karar"));
        _beyin.Cikti("is asama", SahteIsKarti.Kart("kart-bir", asama: "plan"));
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var ham = await sahip.GetStringAsync(Kart, Ct);
        Assert.Contains("Plana geri gönder", ham);
        Assert.Contains("name=\"not\"", ham);

        var bos = await SonrakiAsync(sahip, await PostAsync(sahip, "PlanaGeri", new() { ["not"] = "" }));
        var bosluk = await SonrakiAsync(sahip, await PostAsync(sahip, "PlanaGeri", new() { ["not"] = "   " }));
        Assert.Contains("Revizyon için kısa bir not yaz.", bos);
        Assert.Contains("Revizyon için kısa bir not yaz.", bosluk);
        Assert.Empty(BeyinCagrilari("is", "asama"));

        var dolu = await SonrakiAsync(sahip, await PostAsync(sahip, "PlanaGeri", new() { ["not"] = "  Kapsamı daralt  " }));
        Assert.Contains("Plana geri gönderildi", dolu);
        var cagri = Assert.Single(BeyinCagrilari("is", "asama"));
        Assert.Contains("--not=Kapsamı daralt", cagri);
        Assert.Equal(["kart-bir", "plan"], cagri[^2..]);
    }

    [Fact]
    public async Task WhenTheBrainStillAsksForTheNote_ThePageSaysTheSameSentence_NotTheBrainsOwnMessage()
    {
        // The card looks like an early one to the server, so the server lets it through, and the brain still wants the note.
        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "talep"));
        _beyin.Cikti("is asama", SahteIsKarti.Hata("not-gerekli", "revizyonda --not şart: projects/x/isler/kart-bir.md"), cikis: 1);
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        var sonraki = await SonrakiAsync(sahip, await PostAsync(sahip, "PlanaGeri", new() { ["not"] = "Bir not" }));

        Assert.Contains("Revizyon için kısa bir not yaz.", sonraki);
        Assert.DoesNotContain("projects/", sonraki);
        Assert.DoesNotContain("Plana geri gönderildi", sonraki);
    }

    [Fact]
    public async Task TheSendBackSection_IsNotOnAClosedCard()
    {
        var sahip = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

        _beyin.Cikti("is goster", SahteIsKarti.Ayrinti("kart-bir", asama: "bitti"));
        Assert.DoesNotContain("Plana geri gönder", await sahip.GetStringAsync(Kart, Ct));
    }
}
