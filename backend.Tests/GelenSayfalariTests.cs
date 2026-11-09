using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Yakalamalar;
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
    private async Task<Guid> OneriAsync(
        WebApplicationFactory<Program> fabrika, bool disKaynak = false, double guven = 0.9, string yol = "ogrenme/simyaci.md", bool yeniEtiket = false)
    {
        using var kapsam = fabrika.Services.CreateScope();
        var servis = kapsam.ServiceProvider.GetRequiredService<EylemServisi>();
        var yuk = yeniEtiket
            ? JsonSerializer.SerializeToElement(new
            {
                kart = _kart, yol, baslik = "Simyacı önerisi", etiketler = new[] { "kaynak", "okul", "kitap-onerisi" },
                yeniEtiket = new { ad = "kitap-onerisi", esler = new[] { "oneri" }, bolum = "ogrenme" },
            })
            : JsonSerializer.SerializeToElement(new { kart = _kart, yol, baslik = "Simyacı önerisi", etiketler = new[] { "kaynak", "okul" } });
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
        Assert.Contains("Önerilen yer: Kitap Kulübü Sitesi", metin);
        Assert.Contains("3 Kas 18:40", metin);
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
        // The page is called "Gelen", like the menu entry, and the entry has its badge (the waiting placement suggestions).
        Assert.Contains("<h1 class=\"kd-page-title\">Gelen</h1>", ham);
        Assert.DoesNotContain("Gelen kutusu</", ham);
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
    public async Task ASuggestionWithANewTag_ShowsTheTagItsSynonymsAndItsSection_AndOffersToDropIt()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var id = await OneriAsync(fabrika, yeniEtiket: true);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await tarayici.GetAsync("/Gelen", Ct);

        var ham = await WebOturumu.HamAsync(yanit, Ct);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);
        Assert.Contains("Yeni etiket", metin);
        Assert.Contains("kitap-onerisi", metin);
        Assert.Contains("eş sözcükler: oneri", metin);
        Assert.Contains("bölüm: ogrenme", metin);
        Assert.Contains("önce etiket sözlüğüne eklenir", metin);
        Assert.Contains("kaynak, okul", metin);
        Assert.Contains("handler=YeniEtiketsiz", ham);
        Assert.Contains(id.ToString(), ham);
        Assert.Contains("Yeni etiketsiz uygula", metin);
        Assert.Contains("Reddet", metin);
    }

    [Fact]
    public async Task ASuggestionWithoutANewTag_ShowsNoNewTagRow_AndNoDropButton()
    {
        BeyniKur();
        var fabrika = Fabrika();
        await OneriAsync(fabrika);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var metin = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);

        Assert.DoesNotContain("Yeni etiket", metin);
        Assert.DoesNotContain("Yeni etiketsiz uygula", metin);
    }

    [Fact]
    public async Task ApprovingANewTag_AddsItFirst_ThenPlacesTheCard()
    {
        BeyniKur();
        _beyin.Cikti("etiket ekle", """{"yol": "etiketler.md", "ana": "kitap-onerisi", "es": ["oneri"], "bolum": "ogrenme", "satir": "- kitap-onerisi: oneri"}""");
        var fabrika = Fabrika();
        var id = await OneriAsync(fabrika, yeniEtiket: true);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, $"/Gelen?handler=Uygula&id={id}", []);

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAsync(id)).Durum);
        var komutlar = _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(a => a[0] == "etiket" || (a[0] == "gelen" && a[1] == "isle")).ToList();
        Assert.Equal(["etiket", "gelen"], komutlar.Select(a => a[0]).ToArray());
        Assert.Contains("--tags=kaynak,okul,kitap-onerisi", komutlar[1]);
    }

    [Fact]
    public async Task ApprovingWithoutTheNewTag_PlacesTheCardAndLeavesTheDictionaryAlone()
    {
        BeyniKur();
        var fabrika = Fabrika();
        var id = await OneriAsync(fabrika, yeniEtiket: true);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, $"/Gelen?handler=YeniEtiketsiz&id={id}", []);

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAsync(id)).Durum);
        Assert.DoesNotContain(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a[0] == "etiket");
        var isle = Assert.Single(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), a => a[0] == "gelen" && a[1] == "isle");
        Assert.Contains("--tags=kaynak,okul", isle);
        // The stored payload is the corrected one: the tag is gone from it.
        using var yuk = JsonDocument.Parse((await EylemAsync(id)).Yuk);
        Assert.False(yuk.RootElement.TryGetProperty("yeniEtiket", out var kalan) && kalan.ValueKind != JsonValueKind.Null);
        Assert.Equal(["kaynak", "okul"], yuk.RootElement.GetProperty("etiketler").EnumerateArray().Select(e => e.GetString()).ToArray());
    }

    [Fact]
    public async Task WhenTheTagCannotBeAdded_TheCardStays_AndThePageShowsTheError()
    {
        BeyniKur();
        _beyin.Cikti("etiket ekle", """{"hata": {"kod": "etiket-var", "mesaj": "sözlükte zaten var"}}""", cikis: 1);
        var fabrika = Fabrika();
        var id = await OneriAsync(fabrika, yeniEtiket: true);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        await PostAsync(tarayici, $"/Gelen?handler=Uygula&id={id}", []);

        Assert.Equal(EylemDurumu.Hatali, (await EylemAsync(id)).Durum);
        Assert.Equal(0, Cagri("gelen", "isle"));
        var ham = await WebOturumu.HamAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);
        Assert.Contains("class=\"kd-alert\" role=\"alert\"", ham);
        Assert.Contains("kart işlenmedi", WebUtility.HtmlDecode(ham));
        Assert.Contains("Kitap önerisi: Simyacı", WebUtility.HtmlDecode(ham));
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
            yol = "ogrenme/simyaci.md", baslik = "Simyacı", etiketler = new[] { "kaynak" }, gerekce = "Kitap.", guven = 0.8, yeniEtiket = (object?)null,
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
    public async Task SuggestAgainButton_ShowsOnlyWhileClaudeIsConnected()
    {
        BeyniKur();
        var kapali = await WebOturumu.GirisliAsync(Fabrika(), UygulamaFabrikasi.SahipEposta, Ct);
        var acik = await WebOturumu.GirisliAsync(Fabrika(claude: true), UygulamaFabrikasi.SahipEposta, Ct);

        Assert.DoesNotContain("Yeniden öner", await WebOturumu.MetinAsync(await kapali.GetAsync("/Gelen", Ct), Ct));
        Assert.Contains("Yeniden öner", await WebOturumu.MetinAsync(await acik.GetAsync("/Gelen", Ct), Ct));
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

    // The merged inbox (Dalga 3): the capture box, "Gönderiliyor" (waiting captures) and "Yerleşmeyi bekliyor" (the brain's cards).

    private static string Benzersiz(string ad) => $"{ad} {Guid.NewGuid().ToString("N")[..8]}";

    private async Task<Guid> YakalamaEkleAsync(string metin, YakalamaDurumu durum = YakalamaDurumu.Bekliyor)
    {
        using var db = uygulama.YeniDb();
        var y = new Yakalama { Metin = metin, Durum = durum, YakalandiAt = DateTimeOffset.UtcNow };
        db.Yakalamalar.Add(y);
        await db.SaveChangesAsync(Ct);
        return y.Id;
    }

    [Fact]
    public async Task Page_HasTheCaptureBox_TheWaitingCaptures_AndTheCards_InThatOrder()
    {
        BeyniKur();
        var bekleyen = Benzersiz("bekleyen yakalama");
        var gitmis = Benzersiz("beyne gitmis yakalama");
        await YakalamaEkleAsync(bekleyen);
        await YakalamaEkleAsync(gitmis, YakalamaDurumu.BeyneGitti);
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(), UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await tarayici.GetAsync("/Gelen", Ct);

        var ham = await WebOturumu.HamAsync(yanit, Ct);
        var metin = await WebOturumu.MetinAsync(yanit, Ct);
        Assert.Contains("<h1 class=\"kd-page-title\">Gelen</h1>", ham);
        Assert.Contains("data-kd-composer", ham);
        Assert.Contains("Gönderiliyor", metin);
        Assert.Contains(bekleyen, metin);
        Assert.DoesNotContain(gitmis, metin);
        Assert.Contains("Yerleşmeyi bekliyor", metin);
        Assert.Contains("yakalamalar.js", ham);
        Assert.True(ham.IndexOf("data-kd-composer", StringComparison.Ordinal) < ham.IndexOf("Gönderiliyor", StringComparison.Ordinal));
        Assert.True(ham.IndexOf("Gönderiliyor", StringComparison.Ordinal) < ham.IndexOf("Yerleşmeyi bekliyor", StringComparison.Ordinal));
        // Each waiting capture can be edited and deleted from here.
        Assert.Matches("href=\"/Yakalamalar/Duzenle/[0-9a-f-]{36}\"", ham);
        Assert.Contains("/Yakalamalar/Duzenle/", ham);
        Assert.Contains("handler=Sil", ham);
    }

    [Fact]
    public async Task WaitingCaptures_ShowEvenWhenTheBrainIsOff()
    {
        var bekleyen = Benzersiz("beyin kapaliyken");
        await YakalamaEkleAsync(bekleyen);
        var kapali = uygulama.WithWebHostBuilder(b => b.UseSetting("Gelen:OneriAraligiDakika", "600"));
        _fabrikalar.Add(kapali);
        var tarayici = await WebOturumu.GirisliAsync(kapali, UygulamaFabrikasi.SahipEposta, Ct);

        var metin = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);

        Assert.Contains(bekleyen, metin);
        Assert.Contains("Beyin bağlı değil", metin);
    }

    [Fact]
    public async Task OldCapturesAddress_RedirectsToTheInbox_AndTheEditPageStays()
    {
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(), UygulamaFabrikasi.SahipEposta, Ct);

        var eski = await tarayici.GetAsync("/Yakalamalar", Ct);
        var duzenle = await tarayici.GetAsync("/Yakalamalar/Duzenle", Ct);

        Assert.Equal(HttpStatusCode.Redirect, eski.StatusCode);
        Assert.Equal("/Gelen", eski.Headers.Location!.OriginalString);
        Assert.Equal(HttpStatusCode.OK, duzenle.StatusCode);
    }

    [Fact]
    public async Task SavingFromTheBox_LandsInTheInbox_UnderWaiting_AndDeletingFromThereWorks()
    {
        BeyniKur();
        var metin = Benzersiz("kutudan yakalama");
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(), UygulamaFabrikasi.SahipEposta, Ct);

        var kayit = await PostAsync(tarayici, "/Yakalamalar/Duzenle", new() { ["Input.Metin"] = metin, ["Input.YakalandiAt"] = DateTimeOffset.UtcNow.ToString("o") });

        Assert.Equal(HttpStatusCode.Redirect, kayit.StatusCode);
        Assert.Equal("/Gelen", kayit.Headers.Location!.OriginalString);
        var sayfa = await WebOturumu.HamAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);
        Assert.Contains(metin, WebUtility.HtmlDecode(sayfa));
        using (var db = uygulama.YeniDb())
        {
            var id = (await db.Yakalamalar.SingleAsync(y => y.Metin == metin, Ct)).Id;
            var silme = await PostAsync(tarayici, $"/Yakalamalar/Duzenle/{id}?handler=Sil", []);
            Assert.Equal(HttpStatusCode.Redirect, silme.StatusCode);
            Assert.Equal("/Gelen", silme.Headers.Location!.OriginalString);
        }

        Assert.DoesNotContain(metin, WebUtility.HtmlDecode(await WebOturumu.HamAsync(await tarayici.GetAsync("/Gelen", Ct), Ct)));
    }

    [Fact]
    public async Task Menu_HasNoCapturesEntryAnyMore_AndTheEditPageLightsTheInbox()
    {
        BeyniKur();
        var id = await YakalamaEkleAsync(Benzersiz("menu"));
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(), UygulamaFabrikasi.SahipEposta, Ct);

        var ham = await WebOturumu.HamAsync(await tarayici.GetAsync($"/Yakalamalar/Duzenle/{id}", Ct), Ct);

        Assert.DoesNotContain("asp-page=\"/Yakalamalar/Index\"", ham);
        Assert.DoesNotContain("href=\"/Yakalamalar\"", ham);
        Assert.Matches("kd-nav-link active\"[^>]*href=\"/Gelen\"", ham);
    }

    // Work out of text on the web

    private void ClaudeCevabi(params object[] oneriler) => _claude.YapiliYanit(JsonSerializer.Serialize(new { oneriler }));

    private static object Hatirlatici(string baslik, string gun) =>
        new { tur = "hatirlatici-kur", baslik, gun, saat = "09:00", kaynakParca = $"{baslik} dedi", guven = 0.9 };

    private static string Gun(int ileri) => DateOnly.FromDateTime(DateTime.UtcNow.AddDays(ileri)).ToString("yyyy-MM-dd");

    [Fact]
    public async Task WorkOutButton_ShowsOnlyWhileClaudeIsConnected()
    {
        BeyniKur();
        var kapali = await WebOturumu.GirisliAsync(Fabrika(), UygulamaFabrikasi.SahipEposta, Ct);
        var acik = await WebOturumu.GirisliAsync(Fabrika(claude: true), UygulamaFabrikasi.SahipEposta, Ct);

        Assert.DoesNotContain("İşe çevir", await WebOturumu.MetinAsync(await kapali.GetAsync("/Gelen", Ct), Ct));
        var ham = await WebOturumu.HamAsync(await acik.GetAsync("/Gelen", Ct), Ct);
        Assert.Contains("İşe çevir", WebUtility.HtmlDecode(ham));
        // The button posts the capture box to this page's handler instead of saving it.
        Assert.Contains("formaction=\"/Gelen?handler=IsCikar\"", ham);
    }

    [Fact]
    public async Task WorkOut_ShowsAPreview_AndSavesNothing()
    {
        BeyniKur();
        var baslik = Benzersiz("Ali'yi ara");
        ClaudeCevabi(Hatirlatici(baslik, Gun(3)));
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(claude: true), UygulamaFabrikasi.SahipEposta, Ct);
        using var oncesi = uygulama.YeniDb();
        var yakalamalar = await oncesi.Yakalamalar.CountAsync(Ct);
        var eylemler = await oncesi.Eylemler.CountAsync(Ct);

        var yanit = await PostAsync(tarayici, "/Gelen?handler=IsCikar", new() { ["Input.Metin"] = "yarın Ali'yi ara" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var ham = await WebOturumu.HamAsync(yanit, Ct);
        var metin = WebUtility.HtmlDecode(ham);
        Assert.Contains(baslik, metin);
        Assert.Contains("Hatırlatıcı", metin);
        Assert.Contains("name=\"secilen\"", ham);
        Assert.Contains("yarın Ali'yi ara", metin);
        Assert.Single(_claude.Cagrilar());
        using var sonrasi = uygulama.YeniDb();
        Assert.Equal(yakalamalar, await sonrasi.Yakalamalar.CountAsync(Ct));
        Assert.Equal(eylemler, await sonrasi.Eylemler.CountAsync(Ct));
        Assert.Null(await sonrasi.Hatirlaticilar.FirstOrDefaultAsync(h => h.Baslik == baslik, Ct));
    }

    [Fact]
    public async Task WorkOut_ApplyingTheTickedOnes_GoesThroughTheQueue_AndAppliesOnlyThose()
    {
        BeyniKur();
        var secilen = Benzersiz("Secilen hatirlatici");
        var secilmeyen = Benzersiz("Secilmeyen hatirlatici");
        ClaudeCevabi(Hatirlatici(secilen, Gun(3)), Hatirlatici(secilmeyen, Gun(4)));
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(claude: true), UygulamaFabrikasi.SahipEposta, Ct);
        var onizleme = await WebOturumu.HamAsync(await PostAsync(tarayici, "/Gelen?handler=IsCikar", new() { ["Input.Metin"] = "iki is" }), Ct);
        var degerler = Regex.Matches(onizleme, "name=\"secilen\" value=\"([^\"]+)\"").Select(m => WebUtility.HtmlDecode(m.Groups[1].Value)).ToList();
        Assert.Equal(2, degerler.Count);

        var yanit = await PostAsync(tarayici, "/Gelen?handler=IsUygula", [], ("secilen", degerler.Single(d => d.Contains(secilen))));

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        using var db = uygulama.YeniDb();
        Assert.NotNull(await db.Hatirlaticilar.SingleOrDefaultAsync(h => h.Baslik == secilen, Ct));
        Assert.Null(await db.Hatirlaticilar.FirstOrDefaultAsync(h => h.Baslik == secilmeyen, Ct));
        // The applied one is in the queue as applied, like the phone's.
        var eylem = (await db.Eylemler.ToListAsync(Ct)).Single(e => e.Ozet.Contains(secilen));
        Assert.Equal(EylemDurumu.Uygulandi, eylem.Durum);
        Assert.Equal("ses", eylem.Kaynak);
        Assert.Contains("1 öneri uygulandı", await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct));
    }

    [Fact]
    public async Task WorkOut_ApplyingATamperedSuggestion_IsRefusedByTheSameRules()
    {
        BeyniKur();
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(claude: true), UygulamaFabrikasi.SahipEposta, Ct);
        var kotu = JsonSerializer.Serialize(new { tur = "dosya-sil", baslik = Benzersiz("Hepsini sil") });
        var gecmis = JsonSerializer.Serialize(new { tur = "hatirlatici-kur", baslik = Benzersiz("Gecmis"), gun = "2020-01-01", saat = "09:00" });

        await PostAsync(tarayici, "/Gelen?handler=IsUygula", [], ("secilen", kotu), ("secilen", gecmis));

        using var db = uygulama.YeniDb();
        Assert.Empty(await db.Hatirlaticilar.Where(h => h.Baslik.StartsWith("Gecmis")).ToListAsync(Ct));
        var metin = await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct);
        Assert.Contains("0 öneri uygulandı, 2 uygulanamadı", metin);
    }

    [Fact]
    public async Task WorkOut_WithClaudeOff_SaysSo_AndNothingIsAsked()
    {
        BeyniKur();
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(), UygulamaFabrikasi.SahipEposta, Ct);

        var yanit = await PostAsync(tarayici, "/Gelen?handler=IsCikar", new() { ["Input.Metin"] = "yarın Ali'yi ara" });

        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Empty(_claude.Cagrilar());
        Assert.Contains("Claude ayarlı değil", await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct));
    }

    [Fact]
    public async Task WorkOut_WithAnEmptyBox_SaysSo()
    {
        BeyniKur();
        var tarayici = await WebOturumu.GirisliAsync(Fabrika(claude: true), UygulamaFabrikasi.SahipEposta, Ct);

        await PostAsync(tarayici, "/Gelen?handler=IsCikar", new() { ["Input.Metin"] = "  " });

        Assert.Empty(_claude.Cagrilar());
        Assert.Contains("Metin boş olamaz", await WebOturumu.MetinAsync(await tarayici.GetAsync("/Gelen", Ct), Ct));
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
