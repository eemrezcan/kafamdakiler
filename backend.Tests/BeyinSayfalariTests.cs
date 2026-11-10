using System.Net;
using System.Text.RegularExpressions;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Kafamdakiler.Tests;

// The Beyin pages of the web (the Sahip reads the second brain), the whole app with a fake beyin.py behind it.
// The two things these tests hold on to: the brain being off is a message, never a 500; and nothing a note or a title
// contains reaches the page as markup.
public sealed partial class BeyinSayfalariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Kotu = "<script>alert('xss')</script>";

    private readonly SahteBeyin _beyin = new("ok");
    private WebApplicationFactory<Program>? _acik;

    // The app with the fake brain connected. The sender of captures is set to wake up once an hour, so it stays out of the way.
    private WebApplicationFactory<Program> Acik => _acik ??= uygulama.WithWebHostBuilder(b => b
        .UseSetting("Beyin:Komut", _beyin.Komut)
        .UseSetting("Beyin:Vault", _beyin.Vault)
        .UseSetting("Beyin:GonderimAraligiSaniye", "3600"));

    public void Dispose()
    {
        _acik?.Dispose();
        _beyin.Dispose();
    }

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private Task<HttpClient> SahipAsync(bool beyinBagli) =>
        WebOturumu.GirisliAsync(beyinBagli ? Acik : uygulama, UygulamaFabrikasi.SahipEposta, Ct);

    private async Task<(HttpStatusCode Durum, string Ham, string Metin)> AlAsync(HttpClient tarayici, string yol)
    {
        var yanit = await tarayici.GetAsync(yol, Ct);
        return (yanit.StatusCode, await WebOturumu.HamAsync(yanit, Ct), await WebOturumu.MetinAsync(yanit, Ct));
    }

    private static string Kodla(string deger) => Uri.EscapeDataString(deger);

    [GeneratedRegex("<script", RegexOptions.IgnoreCase)]
    private static partial Regex ScriptEtiketi();

    [GeneratedRegex("<div class=\"kd-md\">(.*?)</div>", RegexOptions.Singleline)]
    private static partial Regex NotBolgesi();

    // The pages and the fake outputs

    private static readonly string[] Sayfalar =
    [
        "/Beyin",
        "/Beyin/Proje/kitap-kulubu",
        "/",
        "/2026-11-03",
        "/Beyin/Ara?q=kitap",
        "/Beyin/Not?yol=projects%2Fkitap-kulubu%2Fnotlar%2Ftakvim.md",
    ];

    private const string ProjeListesi = """
        [{"kimlik": "kitap-kulubu", "baslik": "Kitap Kulübü Sitesi", "yol": "projects/kitap-kulubu/index.md"},
         {"kimlik": "balkon-bahcesi", "baslik": "Balkon Bahçesi Sulama", "yol": "projects/balkon-bahcesi/index.md"},
         {"kimlik": "gizli-proje", "baslik": "Gizli Proje", "gizli": true}]
        """;

    private const string ProjeAyrintisi = """
        {"kimlik": "kitap-kulubu", "baslik": "Kitap Kulübü Sitesi", "yol": "projects/kitap-kulubu/index.md",
         "durum": "Okuma listesi sayfası bitti.", "siradaki_adim": "Buluşma takvimi sayfası.",
         "acik_gorevler": [{"kimlik": "g1", "baslik": "Üye girişi", "durum": "aktif", "bitis": "2026-11-10", "oncelik": "yuksek", "sonraki_adim": "Şifre sıfırlama", "yol": "projects/kitap-kulubu/gorevler/g1.md"},
                           {"kimlik": "g2", "baslik": "Gizli görev", "durum": "aktif", "gizli": true}],
         "son_gunluk": [{"zaman": "2026-11-03 18:42", "baslik": "Takvim denemesi", "metin": "İlk sürüm çalıştı."}]}
        """;

    private const string GunPlani = """
        {"tarih": "2026-11-03", "gun_adi": "3 Kasım 2026", "hafta_gunu": "Salı", "bugun": false, "plan_var": true, "kapandi": false,
         "bolumler": [{"ad": "Yapılacaklar", "maddeler": [
            {"no": 1, "id": "a1", "baslik": "Takvim sayfası", "durum": "acik", "tahmin_dk": 90},
            {"no": 2, "id": "a2", "baslik": "Kitap listesi", "durum": "yapildi", "tahmin_dk": 30},
            {"no": 3, "id": "a3", "baslik": "Gizli madde", "durum": "acik", "gizli": true}]}],
         "geciken": [{"kimlik": "g", "baslik": "Geciken iş", "bitis": "2026-11-01", "gun": 2, "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/g.md"}],
         "toplam": {"madde": 2, "yapildi": 1, "acik": 1}}
        """;

    private const string Notu = """
        {"yol": "projects/kitap-kulubu/notlar/takvim.md", "baslik": "Takvim için kütüphane",
         "ustbilgi": {"tur": "not", "tags": ["takvim", "arac"]},
         "govde": "# Seçenekler\n\nBir **kalın** söz, bir [bağlantı](https://ornek.example/x) ve bir liste:\n\n- bir\n- iki\n"}
        """;

    // Who may open them

    [Fact]
    public async Task EveryPage_SendsAnAnonymousVisitorToTheSignInPage()
    {
        var tarayici = uygulama.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });

        foreach (var sayfa in Sayfalar)
        {
            var yanit = await tarayici.GetAsync(sayfa, Ct);
            Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
            Assert.Equal("/Hesap/Giris", yanit.Headers.Location!.AbsolutePath);
        }
    }

    [Fact]
    public async Task EveryPage_IsClosedToTheAsistan()
    {
        _beyin.Cikti(ProjeListesi);
        var tarayici = await WebOturumu.GirisliAsync(Acik, UygulamaFabrikasi.AsistanEposta, Ct);

        foreach (var sayfa in Sayfalar)
        {
            var yanit = await tarayici.GetAsync(sayfa, Ct);
            Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
            Assert.Equal("/Hesap/Erisim", yanit.Headers.Location!.AbsolutePath);
        }

        Assert.Empty(_beyin.Cagrilar());
    }

    // The brain is off

    [Fact]
    public async Task BrainOff_EveryPageSaysSo_AndNoneFails()
    {
        var tarayici = await SahipAsync(beyinBagli: false);

        foreach (var sayfa in Sayfalar)
        {
            var (durum, _, metin) = await AlAsync(tarayici, sayfa);
            Assert.Equal(HttpStatusCode.OK, durum);
            Assert.Contains("Beyin bağlı değil", metin);
        }

        // The rest of the app is not touched by it.
        Assert.Equal(HttpStatusCode.OK, (await tarayici.GetAsync("/Yonetim", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await tarayici.GetAsync("/Beyin/Ara", Ct)).StatusCode);
    }

    [Fact]
    public async Task BrainConnectedButBroken_IsAMessageToo_NotAnError()
    {
        _beyin.Mod = "bozuk";
        var tarayici = await SahipAsync(beyinBagli: true);

        foreach (var sayfa in Sayfalar)
        {
            var (durum, _, metin) = await AlAsync(tarayici, sayfa);
            Assert.Equal(HttpStatusCode.OK, durum);
            Assert.Contains("Beyin cevabı anlaşılamadı", metin);
        }
    }

    // What they show

    [Fact]
    public async Task Projects_AreListed_WithLinks_AndTheHiddenOneIsNot()
    {
        _beyin.Cikti(ProjeListesi);
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, ham, metin) = await AlAsync(tarayici, "/Beyin");

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Contains("Kitap Kulübü Sitesi", metin);
        Assert.Contains("Balkon Bahçesi Sulama", metin);
        Assert.Contains("href=\"/Beyin/Proje/kitap-kulubu\"", ham);
        Assert.DoesNotContain("Gizli Proje", metin);
        Assert.DoesNotContain("Beyin bağlı değil", metin);
    }

    [Fact]
    public async Task Project_ShowsStatusNextStepTasksAndJournal_WithoutTheHiddenTask()
    {
        _beyin.Cikti(ProjeAyrintisi);
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, "/Beyin/Proje/kitap-kulubu");

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Contains("Okuma listesi sayfası bitti.", metin);
        Assert.Contains("Buluşma takvimi sayfası.", metin);
        Assert.Contains("Üye girişi", metin);
        Assert.Contains("Aktif · Bitiş 10 Kas · Yüksek öncelik", metin);
        Assert.Contains("→ Şifre sıfırlama", metin);
        Assert.Contains("Takvim denemesi", metin);
        Assert.Contains("İlk sürüm çalıştı.", metin);
        Assert.DoesNotContain("Gizli görev", metin);
    }

    [Fact]
    public async Task Project_WithABadId_Is400_AndTheBrainIsNotAsked()
    {
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, "/Beyin/Proje/B%C3%BCy%C3%BCk");

        Assert.Equal(HttpStatusCode.BadRequest, durum);
        Assert.Contains("Proje kimliği küçük harf, rakam ve tire olmalı.", metin);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task Project_TheBrainDoesNotKnow_Is404WithAMessage()
    {
        _beyin.Cikti("""{"hata": {"kod": "bulunamadi", "mesaj": "proje yok: /srv/gizli/yer"}}""", cikis: 1);
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, "/Beyin/Proje/yok");

        Assert.Equal(HttpStatusCode.NotFound, durum);
        Assert.Contains("Bulunamadı", metin);
        Assert.DoesNotContain("/srv", metin);
    }

    [Fact]
    public async Task Day_DefaultsToToday_ShowsThePlan_AndDropsTheHiddenLine()
    {
        _beyin.Cikti(GunPlani);
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, "/");

        Assert.Equal(HttpStatusCode.OK, durum);
        // Today is the brain's today (the day turns at 05:00); the page asks for that day, and for yesterday for the morning card.
        var gunCagrilari = _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(c => c[0] == "gun").ToArray();
        Assert.Contains($"--tarih={GunSiniri.Bugun(DateTimeOffset.UtcNow):yyyy-MM-dd}", gunCagrilari[0]);
        Assert.Contains($"--tarih={GunSiniri.Dun(DateTimeOffset.UtcNow):yyyy-MM-dd}", gunCagrilari[1]);
        Assert.Contains("Takvim sayfası", metin);
        Assert.Contains("1 sa 30 dk", metin);
        Assert.Contains("Kitap listesi", metin);
        Assert.Contains("Yapıldı", metin);
        Assert.Contains("Geciken iş", metin);
        // The late task is a row of the one list too, so the count is of three rows (the hidden line is not one).
        Assert.Contains("1 / 3 tamam", metin);
        Assert.DoesNotContain("Gizli madde", metin);
    }

    [Fact]
    public async Task Day_FromTheAddress_AsksForThatDay_AndOffersTheNeighbours()
    {
        _beyin.Cikti(GunPlani);
        var tarayici = await SahipAsync(beyinBagli: true);

        var (_, ham, metin) = await AlAsync(tarayici, "/2026-11-03");

        Assert.Contains("--tarih=2026-11-03", SahteBeyin.Argumanlar(_beyin.Cagrilar().Single(c => SahteBeyin.Argumanlar(c)[0] == "gun")));
        Assert.Contains("3 Kasım 2026 Salı", metin);
        Assert.Contains("href=\"/2026-11-02\"", ham);
        Assert.Contains("href=\"/2026-11-04\"", ham);
    }

    [Fact]
    public async Task Day_WithABadDate_Is400_AndTheBrainIsNotAsked()
    {
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, "/2026-13-45");

        Assert.Equal(HttpStatusCode.BadRequest, durum);
        Assert.Contains("gerçek bir gün olmalı", metin);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task Search_ShowsPlainSnippets_LinksToTheNote_AndDropsClosedFolders()
    {
        _beyin.Cikti("""
            [{"yol": "projects/kitap-kulubu/notlar/takvim.md", "baslik": "Takvim için kütüphane", "proje": "kitap-kulubu", "alan": "projects", "alinti": "# Seçenekler **kalın** <b>etiket</b> [bağ](http://x.y)"},
             {"yol": "kisisel/plan-2026-11-03.md", "baslik": "Kişisel plan", "alinti": "kapali-klasor-sozcugu"}]
            """);
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, ham, metin) = await AlAsync(tarayici, "/Beyin/Ara?q=takvim");

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Contains("Takvim için kütüphane", metin);
        Assert.Contains("Seçenekler kalın etiket bağ", metin);
        Assert.Contains("kitap-kulubu", metin);
        Assert.Contains($"href=\"/Beyin/Not?yol={Kodla("projects/kitap-kulubu/notlar/takvim.md")}\"", ham);
        Assert.DoesNotContain("Kişisel plan", metin);
        Assert.DoesNotContain("kapali-klasor-sozcugu", metin);
        Assert.Equal(["ara", "--limit=10", "--json", "--vault", _beyin.Vault, "--", "takvim"], SahteBeyin.Argumanlar(_beyin.Cagrilar().Single()));
    }

    [Fact]
    public async Task Search_WithNoQuery_AsksNothing_AndWithABadOne_Is400()
    {
        var tarayici = await SahipAsync(beyinBagli: true);

        Assert.Equal(HttpStatusCode.OK, (await AlAsync(tarayici, "/Beyin/Ara")).Durum);
        Assert.Equal(HttpStatusCode.OK, (await AlAsync(tarayici, "/Beyin/Ara?q=%20%20")).Durum);
        var uzun = await AlAsync(tarayici, $"/Beyin/Ara?q={new string('a', 201)}");
        Assert.Equal(HttpStatusCode.BadRequest, uzun.Durum);
        Assert.Contains("Arama sorgusu en çok 200 karakter olabilir.", uzun.Metin);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task Search_PassesAQueryThatLooksLikeAnOption_AfterDashDash()
    {
        _beyin.Cikti("[]");
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, "/Beyin/Ara?q=--gizli-dahil");

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Contains("Sonuç yok", metin);
        var argumanlar = SahteBeyin.Argumanlar(_beyin.Cagrilar().Single());
        Assert.DoesNotContain("--gizli-dahil", argumanlar.TakeWhile(a => a != "--"));
    }

    [Fact]
    public async Task Note_ShowsTitleTagsAndTheBodyAsHtml()
    {
        _beyin.Cikti(Notu);
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, ham, metin) = await AlAsync(tarayici, "/Beyin/Not?yol=projects%2Fkitap-kulubu%2Fnotlar%2Ftakvim.md");

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Contains("Takvim için kütüphane", metin);
        Assert.Contains("takvim", metin);
        Assert.Contains("arac", metin);
        Assert.Contains("<h1>Seçenekler</h1>", WebUtility.HtmlDecode(NotBolgesi().Match(ham).Groups[1].Value));
        Assert.Contains("<strong>kalın</strong>", NotBolgesi().Match(ham).Groups[1].Value);
        Assert.Contains("href=\"https://ornek.example/x\"", ham);
        Assert.Contains("rel=\"noopener noreferrer nofollow\"", ham);
        NotGovdesiTests.KapaliMi(NotBolgesi().Match(ham).Groups[1].Value);
    }

    [Theory]
    [InlineData("../kisisel/gizli-not.md")]
    [InlineData("kisisel/plan-2026-11-03.md")]
    [InlineData("finans/abonelikler.md")]
    [InlineData("/etc/passwd")]
    [InlineData(".beyin/indeks.sqlite3")]
    [InlineData("projects/kitap-kulubu/index.txt")]
    public async Task Note_WithAForbiddenPath_Is400_AndTheBrainIsNotAsked(string yol)
    {
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, $"/Beyin/Not?yol={Kodla(yol)}");

        Assert.Equal(HttpStatusCode.BadRequest, durum);
        Assert.Contains("izinli bir not yolu olmalı", metin);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task Note_NoPath_Is400()
    {
        var tarayici = await SahipAsync(beyinBagli: true);

        Assert.Equal(HttpStatusCode.BadRequest, (await AlAsync(tarayici, "/Beyin/Not")).Durum);
        Assert.Empty(_beyin.Cagrilar());
    }

    // The hidden-note filter lives in beyin.py and in BeyinOkuma; the web goes through both.

    [Fact]
    public async Task Note_MarkedHidden_Is404_EvenIfTheBrainSentIt()
    {
        _beyin.Cikti("""{"yol": "projects/a/x.md", "baslik": "Gizli not", "ustbilgi": {"gizli": true, "tags": ["sirr"]}, "govde": "çok-gizli-sözcük"}""");
        var tarayici = await SahipAsync(beyinBagli: true);

        var (durum, _, metin) = await AlAsync(tarayici, "/Beyin/Not?yol=projects%2Fa%2Fx.md");

        Assert.Equal(HttpStatusCode.NotFound, durum);
        Assert.DoesNotContain("çok-gizli-sözcük", metin);
        Assert.DoesNotContain("Gizli not", metin);
        Assert.DoesNotContain("sirr", metin);
    }

    [Fact]
    public async Task NoPageEverPassesGizliDahil_ToTheBrain()
    {
        _beyin.Cikti(ProjeListesi);
        var tarayici = await SahipAsync(beyinBagli: true);

        foreach (var sayfa in Sayfalar)
            await tarayici.GetAsync(sayfa, Ct);

        var cagrilar = _beyin.Cagrilar();
        Assert.True(cagrilar.Count >= Sayfalar.Length - 1);
        foreach (var cagri in cagrilar)
            Assert.DoesNotContain(SahteBeyin.Argumanlar(cagri).TakeWhile(a => a != "--"), a => a.Contains("gizli", StringComparison.OrdinalIgnoreCase));
    }

    // Nothing from a note or a title reaches the page as markup

    // The scripts a page loads on its own (the layout's). A hostile text must not add one.
    private async Task<int> ScriptSayisiAsync(HttpClient tarayici, string yol, string cikti)
    {
        _beyin.Cikti(cikti);
        return ScriptEtiketi().Matches((await AlAsync(tarayici, yol)).Ham).Count;
    }

    [Fact]
    public async Task HostileNote_NeverBecomesMarkupOnThePage()
    {
        var tarayici = await SahipAsync(beyinBagli: true);
        const string yol = "/Beyin/Not?yol=projects%2Fa%2Fx.md";
        var temiz = await ScriptSayisiAsync(tarayici, yol, """{"yol": "projects/a/x.md", "baslik": "Temiz", "ustbilgi": {"tags": []}, "govde": "düz yazı"}""");

        var govde = string.Join("\\n\\n", new[]
        {
            "<script>alert('xss')</script>",
            "<img src=x onerror=alert(1)>",
            "<svg onload=alert(1)>",
            "<iframe src=//evil.example></iframe>",
            "[tıkla](javascript:alert(1))",
            "[tıkla](java&#9;script:alert(1))",
            "<javascript:alert(1)>",
            "![resim](http://evil.example/izle.png)",
            "<a href=\\\"javascript:alert(1)\\\">x</a>",
            "<div onmouseover=\\\"alert(1)\\\">üstüne gel</div>",
            "<!-- <script>alert(1)</script> -->",
        });
        _beyin.Cikti($$"""{"yol": "projects/a/x.md", "baslik": "{{Kotu}}", "ustbilgi": {"tags": ["{{Kotu}}"]}, "govde": "{{govde}}"}""");

        var (durum, ham, metin) = await AlAsync(tarayici, yol);

        Assert.Equal(HttpStatusCode.OK, durum);
        // The body: only allowed tags, attributes and addresses.
        var bolge = NotBolgesi().Match(ham);
        Assert.True(bolge.Success);
        NotGovdesiTests.KapaliMi(bolge.Groups[1].Value);
        // The whole page: no script of its own was added, and none of the payloads came through as a tag or an address.
        Assert.Equal(temiz, ScriptEtiketi().Matches(ham).Count);
        Assert.DoesNotContain("<script>alert", ham);
        Assert.DoesNotContain("<img", ham);
        Assert.DoesNotContain("<iframe", ham);
        Assert.DoesNotContain("<svg onload", ham);
        Assert.DoesNotContain("href=\"javascript:", ham, StringComparison.OrdinalIgnoreCase);
        // The picture is never fetched and its address is not even written: only its alt text stays.
        Assert.DoesNotContain("izle.png", ham);
        Assert.Contains("[Görsel: resim]", metin);
        // The words are there, as text: the title and the tag are escaped by Razor, the body by NotGovdesi.
        Assert.Contains("&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;", ham);
        Assert.Contains(Kotu, metin);
    }

    [Fact]
    public async Task HostileTitlesAndTexts_AreEscapedOnEveryPage()
    {
        var tarayici = await SahipAsync(beyinBagli: true);
        var temiz = new Dictionary<string, int>();
        var kotuMetin = Kotu.Replace("'", "\\u0027");

        var kurulum = new (string Yol, string Temiz, string Kotu)[]
        {
            ("/Beyin", """[{"kimlik": "a", "baslik": "Temiz"}]""", $$"""[{"kimlik": "a", "baslik": "{{kotuMetin}}"}]"""),
            ("/Beyin/Proje/a",
                """{"kimlik": "a", "baslik": "Temiz", "durum": "d", "siradaki_adim": "s", "acik_gorevler": [{"kimlik": "g", "baslik": "t", "durum": "aktif"}], "son_gunluk": [{"zaman": "z", "baslik": "b", "metin": "m"}]}""",
                $$"""{"kimlik": "a", "baslik": "{{kotuMetin}}", "durum": "{{kotuMetin}}", "siradaki_adim": "{{kotuMetin}}", "acik_gorevler": [{"kimlik": "g", "baslik": "{{kotuMetin}}", "durum": "{{kotuMetin}}", "sonraki_adim": "{{kotuMetin}}"}], "son_gunluk": [{"zaman": "{{kotuMetin}}", "baslik": "{{kotuMetin}}", "metin": "{{kotuMetin}}"}]}"""),
            ("/2026-11-03",
                """{"tarih": "2026-11-03", "plan_var": true, "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{"id": "1", "baslik": "t", "durum": "acik"}]}], "geciken": [{"kimlik": "g", "baslik": "t", "proje": "p"}]}""",
                $$"""{"tarih": "2026-11-03", "plan_var": true, "bolumler": [{"ad": "{{kotuMetin}}", "maddeler": [{"id": "1", "baslik": "{{kotuMetin}}", "durum": "acik"}]}], "geciken": [{"kimlik": "g", "baslik": "{{kotuMetin}}", "proje": "{{kotuMetin}}"}]}"""),
            ("/Beyin/Ara?q=a",
                """[{"yol": "a/b.md", "baslik": "t", "alinti": "al", "proje": "p"}]""",
                $$"""[{"yol": "a/b.md", "baslik": "{{kotuMetin}}", "alinti": "{{kotuMetin}}", "proje": "{{kotuMetin}}"}]"""),
        };

        foreach (var (yol, temizCikti, _) in kurulum)
            temiz[yol] = await ScriptSayisiAsync(tarayici, yol, temizCikti);

        foreach (var (yol, _, kotuCikti) in kurulum)
        {
            _beyin.Cikti(kotuCikti);
            var (durum, ham, _) = await AlAsync(tarayici, yol);

            Assert.Equal(HttpStatusCode.OK, durum);
            Assert.Equal(temiz[yol], ScriptEtiketi().Matches(ham).Count);
            Assert.DoesNotContain("<script>alert", ham);
        }
    }

    // The one place text from the vault becomes markup is NotGovdesi. Nothing else may print markup: no Html.Raw, no HtmlString.
    [Fact]
    public void OnlyNotGovdesi_MakesMarkupOutOfText()
    {
        var kok = DepoKoku();
        var sayfalar = Directory.EnumerateFiles(Path.Combine(kok, "backend", "Pages"), "*.*", SearchOption.AllDirectories)
            .Where(f => f.EndsWith(".cshtml") || f.EndsWith(".cs"))
            .ToList();
        Assert.NotEmpty(sayfalar);

        foreach (var dosya in sayfalar)
        {
            var icerik = File.ReadAllText(dosya);
            Assert.DoesNotContain("Html.Raw", icerik);
            Assert.DoesNotContain("new HtmlString(", icerik);
            Assert.DoesNotContain("HtmlContentBuilder", icerik);
        }

        var uretenler = Directory.EnumerateFiles(Path.Combine(kok, "backend"), "*.cs", SearchOption.AllDirectories)
            .Where(f => !f.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}") && !f.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}"))
            .Where(f => File.ReadAllText(f).Contains("new HtmlString("))
            .Select(Path.GetFileName)
            .ToList();
        Assert.Equal(["NotGovdesi.cs"], uretenler);
    }

    private static string DepoKoku()
    {
        var klasor = new DirectoryInfo(AppContext.BaseDirectory);
        while (klasor is not null && !Directory.Exists(Path.Combine(klasor.FullName, "backend", "Pages")))
            klasor = klasor.Parent;

        return klasor?.FullName ?? throw new DirectoryNotFoundException("backend/Pages not found above the test folder.");
    }
}
