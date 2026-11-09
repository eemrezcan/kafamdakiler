using System.Net;
using Kafamdakiler.Beyin;
using Kafamdakiler.Isler;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// The read-only work card pages of the web (/Isler), the whole app with a fake beyin.py behind it. Closed to the Asistan and to
// signed-out visitors; with the brain off a message, never a 500; nothing a card contains reaches the page as markup.
public sealed class IsSayfalariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
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
}
