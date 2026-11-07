using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Eylemler;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The inbox page of the web (the Sahip decides), in a browser's shoes, with a fake beyin.py and, where needed, a fake claude.
// What must not pass silently: markup from a card, a closed folder reaching the brain, a placement that "can be undone".
public sealed partial class GelenSayfalariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Kotu = "<script>alert('xss')</script>";

    private const string Sozluk = "# Etiketler\n\n## ogrenme\n- okul: sınav\n- kaynak: kitap\n- özet: çıkarım\n";

    private const string Projeler = """[{"kimlik": "kitap-kulubu", "yol": "projects/kitap-kulubu/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false}]""";

    private readonly string _kart = "2026-11-03-1840-" + Guid.NewGuid().ToString("N")[..10];
    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahteClaude _claude = new();
    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
        _beyin.Dispose();
        _claude.Dispose();
    }

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    private WebApplicationFactory<Program> Fabrika(bool claude = false)
    {
        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            b.UseSetting("Beyin:Komut", _beyin.Komut)
             .UseSetting("Beyin:Vault", _beyin.Vault)
             .UseSetting("Beyin:GonderimAraligiSaniye", "3600")
             .UseSetting("Gelen:OneriAraligiDakika", "600");
            if (claude)
                b.UseSetting("Claude:Komut", _claude.Komut);
        });
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    private void BeyniKur(string baslik = "Kitap önerisi: Simyacı", string? hedef = null, bool gorsel = false)
    {
        _beyin.Cikti("gelen liste", JsonSerializer.Serialize(new[]
        {
            new { yol = $"gelen/{_kart}.md", baslik, yakalandi = "2026-11-03T18:40", hedef, gorsel = gorsel ? $"gelen/ekler/{_kart}.jpg" : null },
        }));
        _beyin.Cikti("proje liste", Projeler);
        _beyin.CiktiKonumsal("not oku", "etiketler.md", NotJson("etiketler.md", Sozluk));
        _beyin.CiktiKonumsal("not oku", $"gelen/{_kart}.md", NotJson($"gelen/{_kart}.md", "Ayşe Simyacı'yı önerdi.\n"));
        _beyin.Cikti("gelen isle", $$"""{"yol": "ogrenme/simyaci.md", "kart": "gelen/{{_kart}}.md", "gorsel": null}""");
        _beyin.Cikti("gelen sil", $$"""{"silinen": ["gelen/{{_kart}}.md"]}""");
    }

    private static string NotJson(string yol, string govde) => JsonSerializer.Serialize(new
    {
        yol, baslik = "x", ustbilgi = new Dictionary<string, object> { ["tur"] = "gelen" }, govde, ustbilgi_hatalari = Array.Empty<string>(),
    });

    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string yol, Dictionary<string, string> alanlar, params (string, string)[] ek)
    {
        var sayfa = await tarayici.GetStringAsync("/Gelen", Ct);
        var token = TokenDeseni().Match(sayfa).Groups[1].Value;
        Assert.NotEmpty(token);
        var govde = alanlar.Select(a => KeyValuePair.Create(a.Key, a.Value)).Concat(ek.Select(e => KeyValuePair.Create(e.Item1, e.Item2)))
            .Append(KeyValuePair.Create("__RequestVerificationToken", token));
        return await tarayici.PostAsync(yol, new FormUrlEncodedContent(govde), Ct);
    }

    // A suggestion in the queue for the card, made the way the Onerici makes it.
    private async Task<Guid> OneriAsync(WebApplicationFactory<Program> fabrika, bool disKaynak = false, double guven = 0.9, string yol = "ogrenme/simyaci.md")
    {
        using var kapsam = fabrika.Services.CreateScope();
        var servis = kapsam.ServiceProvider.GetRequiredService<EylemServisi>();
        var yuk = JsonSerializer.SerializeToElement(new { kart = _kart, yol, baslik = "Simyacı önerisi", etiketler = new[] { "kaynak", "okul" } });
        var sonuc = await servis.OnerAsync(new EylemOnerisi("yerlestir", yuk, "Simyacı → " + yol, "gelen", disKaynak, "Kitap önerisi.", guven), Ct);
        Assert.Equal(EylemSonucuTuru.Tamam, sonuc.Tur);
        Assert.Equal(EylemDurumu.Bekliyor, sonuc.Eylem!.Durum);
        return sonuc.Eylem.Id;
    }

    private int Cagri(string komut, string alt) =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Count(a => a[0] == komut && a[1] == alt);

    private async Task<Eylem> EylemAsync(Guid id)
    {
        using var db = uygulama.YeniDb();
        return await db.Eylemler.AsNoTracking().SingleAsync(e => e.Id == id, Ct);
    }

    [Fact]
    public async Task Page_IsForTheSahipOnly()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var anonim = fabrika.CreateClient(new() { AllowAutoRedirect = false });

        var yanit = await anonim.GetAsync("/Gelen", Ct);

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Contains("/Hesap/Giris", yanit.Headers.Location!.OriginalString);
        var asistan = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.AsistanEposta, Ct);
        Assert.NotEqual(HttpStatusCode.OK, (await asistan.GetAsync("/Gelen", Ct)).StatusCode);
    }

    [Fact]
    public async Task List_ShowsTheCardAndItsSuggestion_AndNeverAsMarkup()
    {
        BeyniKur(baslik: "Kitap " + Kotu, hedef: "projects/kitap-kulubu");
        var fabrika = Fabrika();
        await OneriAsync(fabrika, disKaynak: true, guven: 0.3);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await tarayici.GetAsync("/Gelen", Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var ham = await WebOturumu.HamAsync(yanit, Ct);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);
        Assert.DoesNotContain("<script>alert", ham);
        Assert.Contains("Kitap <script>alert", metin);
        Assert.Contains("Hedef: projects/kitap-kulubu", metin);
        Assert.Contains("2026-11-03 18:40", metin);
        Assert.Contains("ogrenme/simyaci.md", metin);
        Assert.Contains("Simyacı önerisi", metin);
        Assert.Contains("kaynak, okul", metin);
        Assert.Contains("Kitap önerisi.", metin);
        Assert.Contains("%30", metin);
        Assert.Contains("Emin değil", metin);
        Assert.Contains("Dış kaynak", metin);
        Assert.Contains("Uygula", metin);
        Assert.Contains("Düzelt", metin);
        Assert.Contains("Reddet", metin);
        // The form offers the projects and the tags of the brain, and nothing closed.
        Assert.Contains("Kitap Kulübü Sitesi", metin);
        Assert.Contains("value=\"projects/kitap-kulubu/notlar/\"", ham);
        Assert.Contains("name=\"etiketler\" value=\"okul\"", ham);
        Assert.DoesNotContain("finans", ham);
        Assert.DoesNotContain("kisisel", ham);
        // The menu entry and its badge (the waiting placement suggestions).
        Assert.Contains("Gelen kutusu", metin);
        using var db = uygulama.YeniDb();
        var bekleyen = (await db.Eylemler.ToListAsync(Ct)).Count(e => e.Tur == "yerlestir" && e.Durum == EylemDurumu.Bekliyor);
        var rozet = Regex.Match(ham, "<span [^>]*class=\"kd-badge\"[^>]*aria-label=\"[0-9]+ bekleyen öneri\"[^>]*>[^<]*</span>");
        Assert.True(rozet.Success);
        Assert.Contains($">{bekleyen}</span>", rozet.Value);
    }

    [Fact]
    public async Task ACardWithoutASuggestion_MarkedForTheLaptop_SaysSo()
    {
        BeyniKur(gorsel: true);
        var fabrika = Fabrika();
        using (var db = uygulama.YeniDb())
        {
            db.GelenKartlari.Add(new Kafamdakiler.Gelen.GelenKartDurumu { Kart = _kart, LaptoptaIslenecek = true, LaptopNotu = "Sözlükte 'mimari-karar' yok." });
            await db.SaveChangesAsync(Ct);
        }

        var metin = await WebOturumu.MetinAsync(await (await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct)).GetAsync("/Gelen", Ct), Ct);

        Assert.Contains("Laptopta işlenecek", metin);
        Assert.Contains("Sözlükte 'mimari-karar' yok.", metin);
        Assert.Contains("Görselli", metin);
        Assert.DoesNotContain("Güven:", metin);
    }

    [Fact]
    public async Task Approve_PlacesTheCard_AndTheQueueHasNoUndoForIt()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var id = await OneriAsync(fabrika);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, $"/Gelen?handler=Uygula&id={id}", []);

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAsync(id)).Durum);
        var isle = Assert.Single(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a[0] == "gelen" && a[1] == "isle");
        Assert.Contains("--yol=ogrenme/simyaci.md", isle);
        Assert.Contains("--tags=kaynak,okul", isle);
        // Applied, and a placement cannot be put back: the queue page offers no "Geri al" for it.
        var kuyruk = await WebOturumu.HamAsync(await tarayici.GetAsync("/Eylemler", Ct), Ct);
        Assert.Contains($"id=\"e-{id}\"", kuyruk);
        var kart = Regex.Match(kuyruk, $"<article[^>]*id=\"e-{id}\".*?</article>", RegexOptions.Singleline).Value;
        Assert.NotEmpty(kart);
        Assert.DoesNotContain("Geri al", kart);
    }

    [Fact]
    public async Task Reject_KeepsTheCard_AndTheBrainIsNotAsked()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var id = await OneriAsync(fabrika);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, $"/Gelen?handler=Reddet&id={id}", []);

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(EylemDurumu.Reddedildi, (await EylemAsync(id)).Durum);
        Assert.Equal(0, Cagri("gelen", "isle"));
        var metin = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);
        Assert.Contains("Kitap önerisi: Simyacı", metin);
        Assert.DoesNotContain("Güven:", metin);
        using var db = uygulama.YeniDb();
        await db.EylemIzinleri.Where(i => i.Tur == "yerlestir").ExecuteDeleteAsync(Ct);
    }

    [Fact]
    public async Task HandPlacement_SendsTheRightArguments()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, "/Gelen?handler=Isle", new()
        {
            ["kart"] = _kart, ["klasor"] = "ogrenme/", ["dosya"] = "simyaci", ["baslik"] = "Simyacı",
        }, ("etiketler", "kaynak"), ("etiketler", "okul"));

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        var isle = Assert.Single(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a[0] == "gelen" && a[1] == "isle");
        Assert.Equal(
            ["gelen", "isle", "--yol=ogrenme/simyaci.md", "--baslik=Simyacı", "--tags=kaynak,okul", "--json", "--vault", _beyin.Vault, "--", $"gelen/{_kart}.md"],
            isle);
    }

    [Theory]
    [InlineData("finans/", "x", "kaynak")]
    [InlineData("kisisel/", "x", "kaynak")]
    [InlineData("ogrenme/../finans/", "x", "kaynak")]
    [InlineData("projects/gizli-proje/notlar/", "x", "kaynak")]
    [InlineData("ogrenme/", "x", "yeni-etiket")]
    public async Task HandPlacement_IntoAClosedPlaceOrWithAWrongTag_ShowsTheReason_AndTheBrainIsNotAskedToWrite(string klasor, string dosya, string etiket)
    {
        BeyniKur();
        var fabrika = Fabrika();
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, "/Gelen?handler=Isle", new()
        {
            ["kart"] = _kart, ["klasor"] = klasor, ["dosya"] = dosya, ["baslik"] = "B",
        }, ("etiketler", etiket));

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(0, Cagri("gelen", "isle"));
        // The reason is shown once above the page, and the card stays.
        var ham = await WebOturumu.HamAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);
        Assert.Contains("class=\"kd-alert\" role=\"alert\"", ham);
        Assert.Contains("Kitap önerisi: Simyacı", WebUtility.HtmlDecode(ham));
    }

    [Fact]
    public async Task Delete_RemovesTheCard_WithTheOnayFlag()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var sayfa = await WebOturumu.HamAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);
        Assert.Contains("onsubmit=\"return confirm(", sayfa);
        var yanit = await PostAsync(tarayici, "/Gelen?handler=Sil", new() { ["kart"] = _kart });

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        var sil = Assert.Single(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a[0] == "gelen" && a[1] == "sil");
        Assert.Equal(["gelen", "sil", "--onay", "--json", "--vault", _beyin.Vault, "--", $"gelen/{_kart}.md"], sil);
    }

    [Fact]
    public async Task SuggestAgain_PutsASuggestionUnderTheCard()
    {
        BeyniKur();
        _claude.YapiliYanit(JsonSerializer.Serialize(new
        {
            yol = "ogrenme/simyaci.md", baslik = "Simyacı", etiketler = new[] { "kaynak" }, gerekce = "Kitap.", guven = 0.8, yeniEtiketGerekir = false,
        }));
        var fabrika = Fabrika(claude: true);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, "/Gelen?handler=Oneri", new() { ["kart"] = _kart });

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Single(_claude.Cagrilar());
        var ham = await WebOturumu.HamAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);
        var metin = WebUtility.HtmlDecode(ham);
        Assert.Contains("<strong>Yol:</strong> ogrenme/simyaci.md", ham);
        Assert.Contains("%80", metin);
        Assert.Equal(0, Cagri("gelen", "isle"));
    }

    [Fact]
    public async Task SuggestAgain_WithClaudeOff_SaysSo()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        await PostAsync(tarayici, "/Gelen?handler=Oneri", new() { ["kart"] = _kart });

        Assert.Contains("bağlı değil", await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct));
    }

    [Fact]
    public async Task WithTheBrainOff_ThePageSaysSo_AndNothingBreaks()
    {
        var kapali = uygulama.WithWebHostBuilder(b => b.UseSetting("Gelen:OneriAraligiDakika", "600"));
        _fabrikalar.Add(kapali);
        var tarayici = await WebOturumu.GirisliAsync(kapali, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await tarayici.GetAsync("/Gelen", Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Contains("Beyin bağlı değil", await WebOturumu.MetinAsync(yanit, Ct));
    }
}
