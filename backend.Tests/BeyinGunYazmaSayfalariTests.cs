using System.Net;
using System.Text.RegularExpressions;
using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The writes on the web: the day page (new item, "yaptım", carry over, note, split, the leftovers of yesterday) and the project page,
// in a browser's shoes (cookies, antiforgery tokens, no automatic redirects) with a fake beyin.py behind it.
// What they hold on to: every write names the date, a refusal or an uncertain write is said on the page (never a silent
// success), and nothing a title contains reaches the page as markup.
public sealed partial class BeyinGunYazmaSayfalariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Gun = "2026-11-03";
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

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    // The let-go leftovers are rows now (BirakilanMadde), and the tests of a class share one database: each starts without them.
    private async Task<HttpClient> SahipAsync()
    {
        await using (var db = uygulama.YeniDb())
            await db.BirakilanMaddeler.ExecuteDeleteAsync(Ct);
        return await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);
    }

    private static string Plan(string tarih, bool kapandi, params (string Id, string Baslik, string Durum, int? Tahmin)[] maddeler)
    {
        var satirlar = string.Join(",", maddeler.Select(m =>
            $$"""{"id": "{{m.Id}}", "baslik": "{{m.Baslik}}", "durum": "{{m.Durum}}", "tahmin_dk": {{(m.Tahmin?.ToString() ?? "null")}}}"""));
        return $$"""{"tarih": "{{tarih}}", "plan_var": true, "kapandi": {{(kapandi ? "true" : "false")}}, "geciken": [], "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{{satirlar}}]}]}""";
    }

    private const string Madde = """{"id": "a3f09c", "baslik": "Yeni iş", "bolum": "Yapılacaklar", "durum": "acik"}""";

    private const string Gorevler = """[{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md"}]""";

    private const string Projeler = """[{"kimlik": "kitap-kulubu", "baslik": "Kitap Kulübü", "yol": "projects/kitap-kulubu/index.md"}]""";

    // Everything the day page asks the brain: the day, the projects, the open tasks.
    private void GunHazirla(string gunJson)
    {
        _beyin.Cikti("[]");
        _beyin.Cikti("gun goster", gunJson);
        _beyin.Cikti("proje liste", Projeler);
        _beyin.Cikti("gorev liste", Gorevler);
    }

    private string[][] Cagrilar(string komut, string alt) =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(c => c[0] == komut && c[1] == alt).ToArray();

    private static async Task<string> TokenAsync(HttpClient tarayici, string sayfa)
    {
        var token = TokenDeseni().Match(await tarayici.GetStringAsync(sayfa, Ct)).Groups[1].Value;
        Assert.NotEmpty(token);
        return token;
    }

    // Opens the page for its token, then posts the fields to the handler. The answer is the redirect, not followed.
    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string sayfa, string islem, Dictionary<string, string> alanlar)
    {
        var govde = new Dictionary<string, string>(alanlar) { ["__RequestVerificationToken"] = await TokenAsync(tarayici, sayfa) };
        return await tarayici.PostAsync($"{sayfa}?handler={islem}", new FormUrlEncodedContent(govde), Ct);
    }

    private static async Task<string> SonrakiSayfaAsync(HttpClient tarayici, HttpResponseMessage yonlendirme)
    {
        Assert.Equal(HttpStatusCode.Redirect, yonlendirme.StatusCode);
        var yanit = await tarayici.GetAsync(yonlendirme.Headers.Location, Ct);
        return WebUtility.HtmlDecode(await yanit.Content.ReadAsStringAsync(Ct));
    }

    // The forms

    [Fact]
    public async Task OpenDay_OffersTheForms_ForItsRows_AndTheNoteOnlyForAnItemWithAPermanentId()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Takvim", "acik", 90), ("b4e1d2", "Kitap", "yapildi", 30), ("a1", "Eski kimlik", "acik", null)));
        var tarayici = await SahipAsync();

        var ham = await tarayici.GetStringAsync($"/{Gun}", Ct);

        // One "yaptım" for every row; an item that is done offers "geri al" (name="geri" value="true").
        Assert.Contains("handler=Yaptim", ham);
        Assert.Contains("name=\"kimlik\" value=\"m:a3f09c\"", ham);
        Assert.Contains("name=\"kimlik\" value=\"m:b4e1d2\"", ham);
        Assert.Contains("name=\"geri\" value=\"true\"", ham);
        Assert.Contains("handler=Devret", ham);
        Assert.Contains("handler=Not", ham);
        Assert.Contains("name=\"madde\" value=\"a3f09c\"", ham);
        // "a1" is not a permanent id: the brain would refuse a note on it, so the form is not offered.
        Assert.DoesNotContain("name=\"madde\" value=\"a1\"", ham);
        // The new-item form, with its reminder options.
        Assert.Contains("handler=Ekle", ham);
        Assert.Contains("name=\"yeni.Baslik\"", ham);
        Assert.Contains("name=\"h.Tekrar\"", ham);
        Assert.Contains("__RequestVerificationToken", ham);
    }

    [Fact]
    public async Task ALateTask_IsARowWithABadge_AndOffersItsOwnSplit()
    {
        _beyin.Cikti("[]");
        _beyin.Cikti("gun goster", """{"tarih": "2026-11-03", "plan_var": true, "kapandi": false, "geciken": [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "bitis": "2026-10-31", "gun": 3, "proje": "kitap-kulubu"}], "bolumler": []}""");
        _beyin.Cikti("proje liste", Projeler);
        // The tasks the day may show (E9): the late task is one of them.
        _beyin.Cikti("gorev liste", """[{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "gizli": false}]""");
        var tarayici = await SahipAsync();

        var ham = WebUtility.HtmlDecode(await tarayici.GetStringAsync("/", Ct));

        Assert.Contains("3 gün gecikti", ham);
        Assert.Contains("Kitap Kulübü", ham);
        Assert.Contains("name=\"kimlik\" value=\"g:uye-girisi\"", ham);
        Assert.Single(Regex.Matches(ham, "handler=Bol"));
        // The split names the task's own slug, not the typed id.
        Assert.Contains("name=\"kimlik\" value=\"uye-girisi\"", ham);
    }

    [Fact]
    public async Task AClosedDay_HasNoWriteForms_AndSaysSo()
    {
        GunHazirla(Plan(Gun, true, ("a3f09c", "Takvim", "acik", 90)));
        var tarayici = await SahipAsync();

        var ham = await tarayici.GetStringAsync($"/{Gun}", Ct);

        Assert.Contains("Bu gün kapandı", WebUtility.HtmlDecode(ham));
        Assert.DoesNotContain("handler=Ekle", ham);
        Assert.DoesNotContain("handler=Yaptim", ham);
        Assert.DoesNotContain("handler=Devret", ham);
    }

    [Fact]
    public async Task TheWeightOfTheDay_SaysTheDayOverflows_WhenTheOpenEstimatesDoNotFit()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Büyük iş", "acik", 1000)));
        var tarayici = await SahipAsync();

        var metin = WebUtility.HtmlDecode(await tarayici.GetStringAsync($"/{Gun}", Ct));

        Assert.Contains("kd-yuk-cubuk is-asim", metin);
        Assert.Contains("taşıyor", metin);
        Assert.Contains("devret", metin);
    }

    [Fact]
    public async Task TheWeightOfTheDay_SaysThereIsRoom_WhenItFits()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Küçük iş", "acik", 60)));
        var tarayici = await SahipAsync();

        var metin = WebUtility.HtmlDecode(await tarayici.GetStringAsync($"/{Gun}", Ct));

        Assert.DoesNotContain("taşıyor", metin);
        Assert.DoesNotContain("is-asim", metin);
        Assert.Contains("boşluk var", metin);
    }

    [Fact]
    public async Task Titles_NeverReachThePageAsMarkup_InTheNewParts()
    {
        _beyin.Cikti("[]");
        _beyin.Cikti("gun goster", Plan(Gun, false, ("a3f09c", Kotu, "acik", 10)));
        _beyin.Cikti("proje liste", $$"""[{"kimlik": "kitap-kulubu", "baslik": "{{Kotu}}", "yol": "projects/kitap-kulubu/index.md"}]""");
        var tarayici = await SahipAsync();

        var ham = await tarayici.GetStringAsync($"/{Gun}", Ct);

        // The layout has its own script tags; the hostile one is the one with alert(...) in it.
        Assert.DoesNotContain("<script>alert", ham, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("&lt;script&gt;alert", ham);
    }

    // The writes

    [Fact]
    public async Task Add_NamesTheDate_PutsTheTextAfterDashDash_AndSaysItWorked()
    {
        GunHazirla(Plan(Gun, false));
        _beyin.Cikti("gun ekle", $$"""{"tarih": "{{Gun}}", "madde": {{Madde}}, "tahmin_onerisi": null}""");
        var tarayici = await SahipAsync();

        var yanit = await PostAsync(tarayici, $"/{Gun}", "Ekle", new() { ["yeni.Baslik"] = "--gizli-dahil", ["yeni.Bolum"] = "Okul" });
        var sonraki = await SonrakiSayfaAsync(tarayici, yanit);

        Assert.Equal($"/{Gun}", yanit.Headers.Location!.ToString());
        Assert.Equal(["gun", "ekle", $"--tarih={Gun}", "--bolum=Okul", "--json", "--vault", _beyin.Vault, "--", "--gizli-dahil"], Cagrilar("gun", "ekle").Single());
        Assert.Contains("Eklendi", sonraki);
    }

    [Fact]
    public async Task Yaptim_Undo_CarryOver_AndNote_GoToTheBrainWithTheDateAndTheId()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Takvim", "acik", 30)));
        _beyin.Cikti("gun isaretle", $$"""{"tarih": "{{Gun}}", "madde": {{Madde}}, "gorev_kapandi": false}""");
        _beyin.Cikti("gun devret", $$"""{"tarih": "{{Gun}}", "devredilen_gun": "2026-11-04", "madde": {{Madde}}}""");
        _beyin.Cikti("gun not", $$"""{"tarih": "{{Gun}}", "madde": {{Madde}}}""");
        var tarayici = await SahipAsync();
        var sayfa = $"/{Gun}";

        var tik = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Yaptim", new() { ["kimlik"] = "m:a3f09c", ["geri"] = "false" }));
        var geri = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Yaptim", new() { ["kimlik"] = "m:a3f09c", ["geri"] = "true" }));
        var devret = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Devret", new() { ["kimlik"] = "m:a3f09c" }));
        var not = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Not", new() { ["madde"] = "a3f09c", ["metin"] = "-bir not" }));

        Assert.Contains("Yapıldı", tik);
        Assert.Contains("Yeniden açıldı", geri);
        Assert.Contains("Ertesi güne devredildi", devret);
        Assert.Contains("Not eklendi", not);
        var isaretler = Cagrilar("gun", "isaretle");
        Assert.Equal(["gun", "isaretle", $"--tarih={Gun}", "--json", "--vault", _beyin.Vault, "--", "a3f09c"], isaretler[0]);
        Assert.Equal(["gun", "isaretle", $"--tarih={Gun}", "--geri", "--json", "--vault", _beyin.Vault, "--", "a3f09c"], isaretler[1]);
        Assert.Equal(["gun", "devret", $"--tarih={Gun}", "--json", "--vault", _beyin.Vault, "--", "a3f09c"], Cagrilar("gun", "devret").Single());
        Assert.Equal(["gun", "not", $"--tarih={Gun}", "--json", "--vault", _beyin.Vault, "--", "a3f09c", "-bir not"], Cagrilar("gun", "not").Single());
    }

    [Fact]
    public async Task APostWithoutTheAntiforgeryToken_IsRefused_AndNothingIsWritten()
    {
        GunHazirla(Plan(Gun, false));
        var tarayici = await SahipAsync();

        var yanit = await tarayici.PostAsync($"/{Gun}?handler=Ekle", new FormUrlEncodedContent(new Dictionary<string, string> { ["yeni.Baslik"] = "iş" }), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.Empty(Cagrilar("gun", "ekle"));
    }

    [Fact]
    public async Task ANotSignedInVisitor_CannotWrite()
    {
        GunHazirla(Plan(Gun, false));
        var misafir = Acik.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false, HandleCookies = true });

        var yanit = await misafir.PostAsync($"/{Gun}?handler=Ekle", new FormUrlEncodedContent(new Dictionary<string, string> { ["yeni.Baslik"] = "iş" }), Ct);

        Assert.NotEqual(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task ABrainRefusal_IsSaidOnThePage_NotASilentSuccess()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Takvim", "acik", 30)));
        _beyin.Cikti("gun isaretle", """{"hata": {"kod": "gun-kapali", "mesaj": "kapandı: /srv/gizli/yer"}}""", cikis: 1);
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Yaptim", new() { ["kimlik"] = "m:a3f09c", ["geri"] = "false" }));

        Assert.Contains("Kapanmış güne yazılmaz.", sonraki);
        Assert.DoesNotContain("Yapıldı</", sonraki.Replace("Yapıldı · ", ""));
        Assert.DoesNotContain("/srv", sonraki);
    }

    [Fact]
    public async Task AnUncertainWrite_SaysItMayHaveHappened()
    {
        GunHazirla(Plan(Gun, false));
        _beyin.Cikti("gun ekle", "???");
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Ekle", new() { ["yeni.Baslik"] = "iş" }));

        Assert.Contains("yazılmış olabilir", sonraki);
        Assert.DoesNotContain("Eklendi", sonraki);
    }

    [Fact]
    public async Task BadInput_IsSaid_AndTheBrainIsNotAsked()
    {
        GunHazirla(Plan(Gun, false));
        var tarayici = await SahipAsync();
        var sayfa = $"/{Gun}";

        var konum = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Yaptim", new() { ["kimlik"] = "m:3", ["geri"] = "false" }));
        var bos = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Ekle", new() { ["yeni.Baslik"] = "  " }));
        var etkinlik = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Yaptim", new() { ["kimlik"] = "e:" + Guid.NewGuid(), ["geri"] = "false" }));
        var gorevGeri = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Yaptim", new() { ["kimlik"] = "g:uye-girisi", ["geri"] = "true" }));

        Assert.Contains("kalıcı kimliğiyle", konum);
        Assert.Contains("Başlık zorunlu.", bos);
        Assert.Contains("yaptım yok", etkinlik);
        Assert.Contains("yeniden açılamaz", gorevGeri);
        Assert.Empty(Cagrilar("gun", "isaretle"));
        Assert.Empty(Cagrilar("gun", "ekle"));
        Assert.Empty(Cagrilar("gorev", "bitir"));
    }

    [Fact]
    public async Task APostForABadDate_IsRefused_BeforeTheBrain()
    {
        GunHazirla(Plan(Gun, false));
        var tarayici = await SahipAsync();

        var kotu = await tarayici.PostAsync("/2026-13-45?handler=Ekle",
            new FormUrlEncodedContent(new Dictionary<string, string> { ["yeni.Baslik"] = "iş", ["__RequestVerificationToken"] = await TokenAsync(tarayici, $"/{Gun}") }), Ct);

        var kotuSonraki = await SonrakiSayfaAsync(tarayici, kotu);
        Assert.Contains("Tarih yyyy-MM-dd biçiminde olmalı.", kotuSonraki);
        Assert.Empty(Cagrilar("gun", "ekle"));
    }

    [Fact]
    public async Task APostWithAForeignReturnAddress_GoesBackToThePageItself()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Takvim", "acik", 30)));
        _beyin.Cikti("gun isaretle", $$"""{"tarih": "{{Gun}}", "madde": {{Madde}}, "gorev_kapandi": false}""");
        var tarayici = await SahipAsync();

        var yerel = await PostAsync(tarayici, $"/{Gun}", "Yaptim", new() { ["kimlik"] = "m:a3f09c", ["geri"] = "false", ["donus"] = $"/Takvim?gun={Gun}" });
        var yabanci = await PostAsync(tarayici, $"/{Gun}", "Yaptim", new() { ["kimlik"] = "m:a3f09c", ["geri"] = "false", ["donus"] = "https://kotu.example/x" });

        Assert.Equal($"/Takvim?gun={Gun}", yerel.Headers.Location!.ToString());
        Assert.Equal($"/{Gun}", yabanci.Headers.Location!.ToString());
    }

    [Fact]
    public async Task BrainOff_APostIsAMessage_NeverA500()
    {
        var tarayici = await WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);
        var sayfa = $"/{Gun}";

        var yanit = await tarayici.PostAsync($"{sayfa}?handler=Yaptim",
            new FormUrlEncodedContent(new Dictionary<string, string> { ["kimlik"] = "m:a3f09c", ["__RequestVerificationToken"] = await TokenAsync(tarayici, "/Hesap/Sifre") }), Ct);

        // The antiforgery token of another page works for the same user and cookie; the write is a message.
        Assert.Contains((int)yanit.StatusCode, new[] { 302, 400 });
        if (yanit.StatusCode == HttpStatusCode.Redirect)
            Assert.Contains("Beyin bağlı değil", await SonrakiSayfaAsync(tarayici, yanit));
    }

    // Tasks

    [Fact]
    public async Task YaptimOnATask_FinishesItWithTheAppsOwnProof()
    {
        var bugun = GunSiniri.Bugun(DateTimeOffset.UtcNow);
        GunHazirla($$"""{"tarih": "{{bugun:yyyy-MM-dd}}", "plan_var": true, "kapandi": false, "geciken": [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "gun": 1, "proje": "kitap-kulubu"}], "bolumler": []}""");
        _beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");
        var tarayici = await SahipAsync();

        var bitir = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, "/", "Yaptim", new() { ["kimlik"] = "g:uye-girisi", ["geri"] = "false" }));

        Assert.Contains("Yapıldı", bitir);
        var kanit = Cagrilar("gorev", "bitir").Single().Single(a => a.StartsWith("--kanit="));
        Assert.Matches(@"^--kanit=onay:uygulama-\d{4}-\d{2}-\d{2}$", kanit);
    }

    [Fact]
    public async Task ATaskTheBrainHides_CannotBeFinishedByGuessingItsId()
    {
        GunHazirla(Plan(Gun, false));
        _beyin.Cikti("gorev liste", """[{"kimlik": "gizli-gorev", "baslik": "Gizli", "durum": "aktif", "proje": "p", "gizli": true}]""");
        _beyin.Cikti("gorev bitir", """{"yol": "x", "kimlik": "gizli-gorev", "degisen": []}""");
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Yaptim", new() { ["kimlik"] = "g:gizli-gorev", ["geri"] = "false" }));

        Assert.Contains("görev bulunamadı", sonraki);
        Assert.Empty(Cagrilar("gorev", "bitir"));
    }

    [Fact]
    public async Task Split_SendsTheDays_AndOnlyTheLastIsLinkedToTheTask()
    {
        GunHazirla(Plan(Gun, false));
        _beyin.Cikti("gun ekle", $$"""{"tarih": "{{Gun}}", "madde": {{Madde}}, "tahmin_onerisi": null}""");
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Bol",
            new() { ["kimlik"] = "uye-girisi", ["gunSayisi"] = "3", ["baslangic"] = Gun }));

        Assert.Contains("Görev günlere bölündü", sonraki);
        var ekler = Cagrilar("gun", "ekle");
        Assert.Equal(3, ekler.Length);
        Assert.Equal(["--tarih=2026-11-03", "--tarih=2026-11-04", "--tarih=2026-11-05"], ekler.Select(e => e[2]).ToArray());
        Assert.DoesNotContain(ekler.Take(2), e => e.Any(a => a.StartsWith("--gorev")));
        Assert.Contains("--gorev=uye-girisi", ekler[2]);
    }

    [Fact]
    public async Task AHalfDoneSplit_SaysWhichDaysWereWritten()
    {
        GunHazirla(Plan(Gun, false));
        _beyin.Sirali("gun ekle",
            ($$"""{"tarih": "{{Gun}}", "madde": {{Madde}}, "tahmin_onerisi": null}""", 0),
            ("""{"hata": {"kod": "gun-kapali", "mesaj": "kapandı"}}""", 1));
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Bol",
            new() { ["kimlik"] = "uye-girisi", ["gunSayisi"] = "3", ["baslangic"] = Gun }));

        Assert.Contains("Yarıda kaldı: 1 gün yazıldı", sonraki);
        Assert.Contains("4 Kas günü yazılamadı", sonraki);
        Assert.DoesNotContain("Görev günlere bölündü", sonraki);
    }

    [Fact]
    public async Task AnOverdueTask_ThatIsAlsoYesterdaysLeftover_ShowsOnce_UnderTheLeftover()
    {
        var bugun = GunSiniri.Bugun(DateTimeOffset.UtcNow);
        // The fake brain answers yesterday and today with the same day: an open "Üye girişi" line and the late task itself.
        var gun = $$"""
            {"tarih": "{{bugun.AddDays(-1):yyyy-MM-dd}}", "plan_var": true, "kapandi": false,
             "geciken": [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "gun": 2, "proje": "kitap-kulubu"}],
             "bolumler": [{"ad": "Görevler", "maddeler": [{"id": "c1d2e3", "baslik": "Üye girişi", "durum": "acik", "gorev": "uye-girisi"}]}]}
            """;
        GunHazirla(gun);
        var tarayici = await SahipAsync();

        var ham = await tarayici.GetStringAsync("/", Ct);
        var sayfa = WebUtility.HtmlDecode(ham);

        Assert.Contains("Dünden kalanlar", sayfa);
        Assert.Contains("2 gün gecikti", sayfa);
        // The day view joins the late task with the item that points at it: one row, not two.
        Assert.Single(Regex.Matches(ham, "data-kd-oge=\"[mg]:"));
    }

    [Fact]
    public async Task TheProjectPage_AddsToItsOwnProject_AndFinishesATask()
    {
        _beyin.Cikti("""{"kimlik": "kitap-kulubu", "baslik": "Kitap Kulübü", "yol": "projects/kitap-kulubu/index.md", "durum": "d", "siradaki_adim": "s", "acik_gorevler": [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md"}], "son_gunluk": []}""");
        _beyin.Cikti("gorev ekle", """{"yol": "projects/kitap-kulubu/gorevler/yeni.md", "kimlik": "yeni"}""");
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");
        var tarayici = await SahipAsync();
        var sayfa = "/Beyin/Proje/kitap-kulubu";

        var ham = await tarayici.GetStringAsync(sayfa, Ct);
        var ekle = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "GorevEkle", new() { ["baslik"] = "Yeni", ["proje"] = "baska-proje" }));
        var bitir = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "GorevBitir", new() { ["gorev"] = "uye-girisi" }));

        Assert.Contains("handler=GorevBitir", ham);
        Assert.Contains("Görev eklendi", ekle);
        Assert.Contains("Görev bitti", bitir);
        // The project is the one in the address, whatever the form says.
        Assert.Equal(["gorev", "ekle", "--baslik=Yeni", "--proje=kitap-kulubu", "--json", "--vault", _beyin.Vault], Cagrilar("gorev", "ekle").Single());
    }

    // The morning card

    private static string SabahKartiGunu(DateOnly gun) => Plan($"{gun:yyyy-MM-dd}", false, ("a3f09c", "Dünden kalan", "acik", 45), ("b4e1d2", "Yapılan", "yapildi", 10));

    [Fact]
    public async Task MorningCard_ListsYesterdaysOpenItems_OnTodaysPageOnly()
    {
        var bugun = GunSiniri.Bugun(DateTimeOffset.UtcNow);
        GunHazirla(SabahKartiGunu(bugun.AddDays(-1)));
        var tarayici = await SahipAsync();

        var bugunSayfasi = WebUtility.HtmlDecode(await tarayici.GetStringAsync("/", Ct));
        var baskaGun = WebUtility.HtmlDecode(await tarayici.GetStringAsync($"/{Gun}", Ct));

        Assert.Contains("Dünden kalanlar", bugunSayfasi);
        Assert.Contains("Dünden kalan", bugunSayfasi);
        Assert.DoesNotContain("Dünden kalanlar", baskaGun);
    }

    [Fact]
    public async Task MorningCard_Carry_IsADevretDatedYesterday()
    {
        var bugun = GunSiniri.Bugun(DateTimeOffset.UtcNow);
        var dun = $"{bugun.AddDays(-1):yyyy-MM-dd}";
        GunHazirla(SabahKartiGunu(bugun.AddDays(-1)));
        _beyin.Cikti("gun devret", $$"""{"tarih": "{{dun}}", "devredilen_gun": "{{bugun:yyyy-MM-dd}}", "madde": {{Madde}}}""");
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, "/", "SabahTasi", new() { ["madde"] = "a3f09c" }));

        Assert.Contains("Bugüne taşındı", sonraki);
        Assert.Equal(["gun", "devret", $"--tarih={dun}", "--json", "--vault", _beyin.Vault, "--", "a3f09c"], Cagrilar("gun", "devret").Single());
    }

    [Fact]
    public async Task MorningCard_Leave_WritesNothingToTheBrain_AndTheItemStaysGoneOnReload()
    {
        var bugun = GunSiniri.Bugun(DateTimeOffset.UtcNow);
        GunHazirla(SabahKartiGunu(bugun.AddDays(-1)));
        var tarayici = await SahipAsync();

        Assert.Contains("handler=SabahTasi", await tarayici.GetStringAsync("/", Ct));

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, "/", "SabahBirak", new() { ["madde"] = "a3f09c" }));

        // The fake serves the same plan for both days, so the item is still in the plan itself; the card is what is gone.
        Assert.DoesNotContain("handler=SabahTasi", sonraki);
        Assert.DoesNotContain(_beyin.Cagrilar().Select(SahteBeyin.Argumanlar), c => c[0] == "gun" && c[1] is "devret" or "isaretle" or "ekle" or "not");
        // The let-go id is a row of the database (the phone shares it), so a fresh page still has it gone, whoever opens it.
        await using (var db = uygulama.YeniDb())
            Assert.Equal("a3f09c", Assert.Single(await db.BirakilanMaddeler.ToListAsync(Ct)).MaddeId);
        var ham = await tarayici.GetStringAsync("/", Ct);
        Assert.DoesNotContain("handler=SabahTasi", ham);
        Assert.DoesNotContain("Dünden kalanlar", WebUtility.HtmlDecode(ham));
    }
}
