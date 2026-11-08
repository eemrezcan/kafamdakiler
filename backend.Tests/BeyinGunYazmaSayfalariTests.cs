using System.Net;
using System.Text.RegularExpressions;
using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// The writes on the web: the day page (add, tick, carry over, note, tasks, split, the morning card) and the project page,
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

    private Task<HttpClient> SahipAsync() => WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.SahipEposta, Ct);

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
    public async Task OpenDay_OffersTheForms_ForItemsWithAPermanentId_AndNotForOthers()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Takvim", "acik", 90), ("b4e1d2", "Kitap", "yapildi", 30), ("a1", "Eski kimlik", "acik", null)));
        var tarayici = await SahipAsync();

        var ham = await tarayici.GetStringAsync($"/{Gun}", Ct);

        Assert.Contains("handler=Ekle", ham);
        Assert.Contains("handler=Isaretle", ham);
        Assert.Contains("name=\"madde\" value=\"a3f09c\"", ham);
        Assert.Contains("name=\"madde\" value=\"b4e1d2\"", ham);
        Assert.Contains("name=\"geri\" value=\"true\"", ham);
        Assert.DoesNotContain("value=\"a1\"", ham);
        Assert.Contains("handler=Devret", ham);
        Assert.Contains("handler=Not", ham);
        Assert.Contains("handler=GorevEkle", ham);
        Assert.Contains("handler=Bol", ham);
        Assert.Contains("__RequestVerificationToken", ham);
    }

    [Fact]
    public async Task Tasks_AreOneList_LateFirstWithABadge_AndEachRowOpensItsOwnSplit()
    {
        _beyin.Cikti("[]");
        _beyin.Cikti("gun goster", """{"tarih": "2026-11-03", "plan_var": true, "kapandi": false, "geciken": [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "bitis": "2026-10-31", "gun": 3, "proje": "kitap-kulubu"}], "bolumler": []}""");
        _beyin.Cikti("proje liste", Projeler);
        _beyin.Cikti("gorev liste", """[{"kimlik": "a-yeni", "baslik": "Afiş bas", "durum": "aktif", "proje": "kitap-kulubu", "bitis": "2026-11-20"}, {"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "bitis": "2026-10-31"}, {"kimlik": "z-son", "baslik": "Zil sesi", "durum": "aktif"}]""");
        var tarayici = await SahipAsync();

        var ham = WebUtility.HtmlDecode(await tarayici.GetStringAsync($"/{Gun}", Ct));

        Assert.DoesNotContain("Geciken görevler", ham);
        Assert.DoesNotContain("Açık görevler", ham);
        Assert.Contains("3 gün gecikti", ham);
        Assert.True(ham.IndexOf("Üye girişi", StringComparison.Ordinal) < ham.IndexOf("Afiş bas", StringComparison.Ordinal));
        Assert.True(ham.IndexOf("Afiş bas", StringComparison.Ordinal) < ham.IndexOf("Zil sesi", StringComparison.Ordinal));
        Assert.Equal(3, Regex.Matches(ham, "<summary>Günlere böl</summary>").Count);
        Assert.Equal(3, Regex.Matches(ham, "handler=Bol").Count);
        Assert.DoesNotContain("id=\"bol-gorev\"", ham);
    }

    [Fact]
    public async Task AClosedDay_HasNoWriteForms_AndSaysSo()
    {
        GunHazirla(Plan(Gun, true, ("a3f09c", "Takvim", "acik", 90)));
        var tarayici = await SahipAsync();

        var ham = await tarayici.GetStringAsync($"/{Gun}", Ct);

        Assert.Contains("Bu gün kapandı", WebUtility.HtmlDecode(ham));
        Assert.DoesNotContain("handler=Ekle", ham);
        Assert.DoesNotContain("handler=Isaretle", ham);
        Assert.DoesNotContain("handler=Devret", ham);
    }

    [Fact]
    public async Task TheCapacityWarning_ShowsWhenTheOpenEstimatesDoNotFit()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Büyük iş", "acik", 400)));
        var tarayici = await SahipAsync();

        var metin = WebUtility.HtmlDecode(await tarayici.GetStringAsync($"/{Gun}", Ct));

        Assert.Contains("Bugün sığmıyor", metin);
        Assert.Contains("6 sa", metin);
        Assert.Contains("40 dk fazla", metin);
    }

    [Fact]
    public async Task NoWarning_WhenItFits()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Küçük iş", "acik", 60)));
        var tarayici = await SahipAsync();

        Assert.DoesNotContain("Bugün sığmıyor", WebUtility.HtmlDecode(await tarayici.GetStringAsync($"/{Gun}", Ct)));
    }

    [Fact]
    public async Task Titles_NeverReachThePageAsMarkup_InTheNewParts()
    {
        _beyin.Cikti("[]");
        _beyin.Cikti("gun goster", Plan(Gun, false, ("a3f09c", Kotu, "acik", 10)));
        _beyin.Cikti("proje liste", $$"""[{"kimlik": "kitap-kulubu", "baslik": "{{Kotu}}", "yol": "projects/kitap-kulubu/index.md"}]""");
        _beyin.Cikti("gorev liste", $$"""[{"kimlik": "g1", "baslik": "{{Kotu}}", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/g1.md"}]""");
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

        var yanit = await PostAsync(tarayici, $"/{Gun}", "Ekle", new() { ["metin"] = "--gizli-dahil", ["bolum"] = "Okul" });
        var sonraki = await SonrakiSayfaAsync(tarayici, yanit);

        Assert.Equal($"/{Gun}", yanit.Headers.Location!.ToString());
        Assert.Equal(["gun", "ekle", $"--tarih={Gun}", "--bolum=Okul", "--json", "--vault", _beyin.Vault, "--", "--gizli-dahil"], Cagrilar("gun", "ekle").Single());
        Assert.Contains("Madde eklendi", sonraki);
    }

    [Fact]
    public async Task Tick_Undo_CarryOver_AndNote_GoToTheBrainWithTheDateAndTheId()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Takvim", "acik", 30)));
        _beyin.Cikti("gun isaretle", $$"""{"tarih": "{{Gun}}", "madde": {{Madde}}, "gorev_kapandi": false}""");
        _beyin.Cikti("gun devret", $$"""{"tarih": "{{Gun}}", "devredilen_gun": "2026-11-04", "madde": {{Madde}}}""");
        _beyin.Cikti("gun not", $$"""{"tarih": "{{Gun}}", "madde": {{Madde}}}""");
        var tarayici = await SahipAsync();
        var sayfa = $"/{Gun}";

        var tik = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Isaretle", new() { ["madde"] = "a3f09c", ["geri"] = "false" }));
        var geri = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Isaretle", new() { ["madde"] = "a3f09c", ["geri"] = "true" }));
        var devret = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Devret", new() { ["madde"] = "a3f09c" }));
        var not = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Not", new() { ["madde"] = "a3f09c", ["metin"] = "-bir not" }));

        Assert.Contains("Madde yapıldı", tik);
        Assert.Contains("Madde yeniden açıldı", geri);
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

        var yanit = await tarayici.PostAsync($"/{Gun}?handler=Ekle", new FormUrlEncodedContent(new Dictionary<string, string> { ["metin"] = "iş" }), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.Empty(Cagrilar("gun", "ekle"));
    }

    [Fact]
    public async Task ANotSignedInVisitor_CannotWrite()
    {
        GunHazirla(Plan(Gun, false));
        var misafir = Acik.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false, HandleCookies = true });

        var yanit = await misafir.PostAsync($"/{Gun}?handler=Ekle", new FormUrlEncodedContent(new Dictionary<string, string> { ["metin"] = "iş" }), Ct);

        Assert.NotEqual(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task ABrainRefusal_IsSaidOnThePage_NotASilentSuccess()
    {
        GunHazirla(Plan(Gun, false, ("a3f09c", "Takvim", "acik", 30)));
        _beyin.Cikti("gun isaretle", """{"hata": {"kod": "gun-kapali", "mesaj": "kapandı: /srv/gizli/yer"}}""", cikis: 1);
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Isaretle", new() { ["madde"] = "a3f09c", ["geri"] = "false" }));

        Assert.Contains("Kapanmış güne yazılmaz.", sonraki);
        Assert.DoesNotContain("Madde yapıldı", sonraki);
        Assert.DoesNotContain("/srv", sonraki);
    }

    [Fact]
    public async Task AnUncertainWrite_SaysItMayHaveHappened()
    {
        GunHazirla(Plan(Gun, false));
        _beyin.Cikti("gun ekle", "???");
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Ekle", new() { ["metin"] = "iş" }));

        Assert.Contains("yazılmış olabilir", sonraki);
        Assert.DoesNotContain("Madde eklendi", sonraki);
    }

    [Fact]
    public async Task BadInput_IsSaid_AndTheBrainIsNotAsked()
    {
        GunHazirla(Plan(Gun, false));
        var tarayici = await SahipAsync();
        var sayfa = $"/{Gun}";

        var konum = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Isaretle", new() { ["madde"] = "3", ["geri"] = "false" }));
        var bos = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "Ekle", new() { ["metin"] = "  " }));

        Assert.Contains("kalıcı kimliğiyle", konum);
        Assert.Contains("Boş olamaz.", bos);
        Assert.Empty(Cagrilar("gun", "isaretle"));
        Assert.Empty(Cagrilar("gun", "ekle"));
    }

    [Fact]
    public async Task APostForABadDate_IsRefused_BeforeTheBrain()
    {
        GunHazirla(Plan(Gun, false));
        var tarayici = await SahipAsync();

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "Ekle", new() { ["metin"] = "iş" }));
        var kotu = await tarayici.PostAsync("/2026-13-45?handler=Ekle",
            new FormUrlEncodedContent(new Dictionary<string, string> { ["metin"] = "iş", ["__RequestVerificationToken"] = await TokenAsync(tarayici, $"/{Gun}") }), Ct);

        Assert.NotNull(sonraki);
        var kotuSonraki = await SonrakiSayfaAsync(tarayici, kotu);
        Assert.Contains("Tarih yyyy-MM-dd biçiminde olmalı.", kotuSonraki);
    }

    [Fact]
    public async Task BrainOff_APostIsAMessage_NeverA500()
    {
        var tarayici = await WebOturumu.GirisliAsync(uygulama, UygulamaFabrikasi.SahipEposta, Ct);
        var sayfa = $"/{Gun}";

        var yanit = await tarayici.PostAsync($"{sayfa}?handler=Ekle",
            new FormUrlEncodedContent(new Dictionary<string, string> { ["metin"] = "iş", ["__RequestVerificationToken"] = await TokenAsync(tarayici, "/Hesap/Sifre") }), Ct);

        // The antiforgery token of another page works for the same user and cookie; the write is a message.
        Assert.Contains((int)yanit.StatusCode, new[] { 302, 400 });
        if (yanit.StatusCode == HttpStatusCode.Redirect)
            Assert.Contains("Beyin bağlı değil", await SonrakiSayfaAsync(tarayici, yanit));
    }

    // Tasks

    [Fact]
    public async Task AddATask_ToTheChosenProject_AndFinishOne_WithTheAppsOwnProof()
    {
        GunHazirla(Plan(Gun, false));
        _beyin.Cikti("gorev ekle", """{"yol": "projects/kitap-kulubu/gorevler/yeni.md", "kimlik": "yeni"}""");
        _beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");
        var tarayici = await SahipAsync();
        var sayfa = $"/{Gun}";

        var ekle = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "GorevEkle", new() { ["baslik"] = "Yeni görev", ["proje"] = "kitap-kulubu", ["bitis"] = "2026-12-01" }));
        var bitir = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, sayfa, "GorevBitir", new() { ["kimlik"] = "uye-girisi" }));

        Assert.Contains("Görev eklendi", ekle);
        Assert.Contains("Görev bitti", bitir);
        Assert.Equal(["gorev", "ekle", "--baslik=Yeni görev", "--proje=kitap-kulubu", "--bitis=2026-12-01", "--json", "--vault", _beyin.Vault], Cagrilar("gorev", "ekle").Single());
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

        var sonraki = await SonrakiSayfaAsync(tarayici, await PostAsync(tarayici, $"/{Gun}", "GorevBitir", new() { ["kimlik"] = "gizli-gorev" }));

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
        // A fresh page in the same browser still has it gone: the let-go ids are kept in a cookie.
        var ham = await tarayici.GetStringAsync("/", Ct);
        Assert.DoesNotContain("handler=SabahTasi", ham);
        Assert.DoesNotContain("Dünden kalanlar", WebUtility.HtmlDecode(ham));
    }
}
