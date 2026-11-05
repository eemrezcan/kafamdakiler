using System.Text.Json;
using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The /api/beyin handlers with a fake beyin.py: input checks, the error table, the DTO conversion, the hidden-record locks.
public class BeyinOkumaTests : IDisposable
{
    private static readonly NullLogger Gunluk = NullLogger.Instance;

    private readonly SahteBeyin _beyin = new("ok");

    public void Dispose() => _beyin.Dispose();

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    // Runs the handler's IResult the way the server would and reads back the status and the JSON body.
    internal static async Task<(int Durum, JsonElement Govde)> Oku(IResult sonuc, CancellationToken ct)
    {
        var baglam = new DefaultHttpContext
        {
            RequestServices = new ServiceCollection().AddLogging().AddProblemDetails().BuildServiceProvider(),
        };
        baglam.Response.Body = new MemoryStream();
        await sonuc.ExecuteAsync(baglam);
        baglam.Response.Body.Position = 0;
        var metin = await new StreamReader(baglam.Response.Body).ReadToEndAsync(ct);
        return (baglam.Response.StatusCode, string.IsNullOrEmpty(metin) ? default : JsonDocument.Parse(metin).RootElement.Clone());
    }

    private BeyinIstemcisi Bagli() => _beyin.Istemci();

    private static BeyinIstemcisi Kapali() => new(new BeyinAyari());

    // Note path lock

    [Theory]
    [InlineData("projects/kitap-kulubu/notlar/takvim-kutuphanesi.md")]
    [InlineData("gelen/2026-11-03-1840-kitap-onerisi.md")]
    [InlineData("ogrenme/okul/veri-yapilari-ozet.md")]
    [InlineData("etiketler.md")]
    [InlineData("projects/çiçek bahçesi/günlük.md")]
    public void NotYolu_AcceptsPlainRelativeMarkdownPaths(string yol) => Assert.True(NotYolu.Gecerli(yol));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("/etc/passwd")]
    [InlineData("/projects/kitap-kulubu/index.md")]
    [InlineData("../kisisel/gizli-not.md")]
    [InlineData("projects/../kisisel/gizli-not.md")]
    [InlineData("projects/./kitap-kulubu/index.md")]
    [InlineData("projects//kitap-kulubu/index.md")]
    [InlineData("projects\\kitap-kulubu\\index.md")]
    [InlineData(".beyin/indeks.sqlite3")]
    [InlineData(".beyin/notlar.md")]
    [InlineData("projects/.gizli/x.md")]
    [InlineData(".env.md")]
    [InlineData("projects/kitap-kulubu/index.txt")]
    [InlineData("projects/kitap-kulubu/index")]
    [InlineData("projects/kitap-kulubu/")]
    [InlineData("projects/kitap-kulubu/index.md\n")]
    [InlineData("projects/kitap-kulubu/index.md\0.txt")]
    [InlineData("projects/kitap-kulubu/index.md ")]
    [InlineData("-x.md")]
    [InlineData("finans/ham/ekstre.md")]
    [InlineData("finans/abonelikler.md")]
    [InlineData("kisisel/plan-2026-11-03.md")]
    [InlineData("kisisel/gorevler/dis-randevusu-al.md")]
    [InlineData("KISISEL/tarihler.md")]
    [InlineData("FINANS/HAM/ekstre.md")]
    [InlineData("file:///etc/passwd.md")]
    [InlineData("~/brain/x.md")]
    [InlineData("projects/a..b/x.md")]
    public void NotYolu_RejectsEverythingElse(string? yol) => Assert.False(NotYolu.Gecerli(yol));

    [Fact]
    public void NotYolu_RejectsTooLongPaths() => Assert.False(NotYolu.Gecerli(new string('a', NotYolu.EnUzun) + ".md"));

    // Input checks come before the brain is asked, so a bad request is a 400 even when the brain is off.

    [Fact]
    public async Task BadInput_Is400_BeforeTheBrainIsCalled()
    {
        var kapali = Kapali();
        var uzun = new string('a', BeyinOkuma.EnUzunSorgu + 1);

        var sonuclar = new[]
        {
            await BeyinOkuma.Ara(null, null, null, kapali, Gunluk, Ct),
            await BeyinOkuma.Ara("  ", null, null, kapali, Gunluk, Ct),
            await BeyinOkuma.Ara(uzun, null, null, kapali, Gunluk, Ct),
            await BeyinOkuma.Ara("a\nb", null, null, kapali, Gunluk, Ct),
            await BeyinOkuma.Ara("a", "Büyük Harf", null, kapali, Gunluk, Ct),
            await BeyinOkuma.Ara("a", null, 0, kapali, Gunluk, Ct),
            await BeyinOkuma.Ara("a", null, BeyinOkuma.EnCokSonuc + 1, kapali, Gunluk, Ct),
            await BeyinOkuma.Not("../x.md", kapali, Gunluk, Ct),
            await BeyinOkuma.Proje("../x", kapali, Gunluk, Ct),
            await BeyinOkuma.Proje("Büyük", kapali, Gunluk, Ct),
            await BeyinOkuma.Gun("2026-13-45", kapali, Gunluk, Ct),
            await BeyinOkuma.Gun("bugun", kapali, Gunluk, Ct),
            await BeyinOkuma.Gun("2026-11-3", kapali, Gunluk, Ct),
        };

        foreach (var s in sonuclar)
            Assert.Equal(400, (await Oku(s, Ct)).Durum);
    }

    [Fact]
    public async Task BadInput_NamesTheField_InCamelCase()
    {
        var (durum, govde) = await Oku(await BeyinOkuma.Not("../x.md", Kapali(), Gunluk, Ct), Ct);

        Assert.Equal(400, durum);
        Assert.True(govde.GetProperty("errors").TryGetProperty("yol", out _));
    }

    [Fact]
    public async Task BrainOff_Is503_ForEveryEndpoint()
    {
        var kapali = Kapali();

        var sonuclar = new[]
        {
            await BeyinOkuma.Projeler(kapali, Gunluk, Ct),
            await BeyinOkuma.Proje("kitap-kulubu", kapali, Gunluk, Ct),
            await BeyinOkuma.Gun("2026-11-03", kapali, Gunluk, Ct),
            await BeyinOkuma.Ara("kitap", null, null, kapali, Gunluk, Ct),
            await BeyinOkuma.Not("etiketler.md", kapali, Gunluk, Ct),
        };

        foreach (var s in sonuclar)
        {
            var (durum, govde) = await Oku(s, Ct);
            Assert.Equal(503, durum);
            Assert.Equal("Beyin bağlı değil", govde.GetProperty("title").GetString());
        }
    }

    // Error table

    [Theory]
    [InlineData("gecersiz-arguman", 400)]
    [InlineData("yasak-yol", 400)]
    [InlineData("bulunamadi", 404)]
    [InlineData("gizli", 404)]
    [InlineData("gun-kapali", 502)]
    [InlineData("hata", 502)]
    [InlineData("", 502)]
    public void BrainErrorCode_MapsToStatus(string kod, int beklenen) =>
        Assert.Equal(beklenen, BeyinOkuma.DurumKodu(new BeyinSonucu(BeyinDurumu.BeyinHatasi, HataKodu: kod)));

    [Fact]
    public void OtherFailures_MapToStatus()
    {
        Assert.Equal(503, BeyinOkuma.DurumKodu(new BeyinSonucu(BeyinDurumu.BagliDegil)));
        Assert.Equal(504, BeyinOkuma.DurumKodu(new BeyinSonucu(BeyinDurumu.ZamanAsimi)));
        Assert.Equal(502, BeyinOkuma.DurumKodu(new BeyinSonucu(BeyinDurumu.BozukCikti)));
    }

    [Fact]
    public async Task BrainError_BecomesProblem_WithoutTheBrainsOwnMessage()
    {
        _beyin.Cikti("""{"hata": {"kod": "bulunamadi", "mesaj": "not bulunamadı: /srv/gizli/yer/x.md"}}""", cikis: 1);

        var (durum, govde) = await Oku(await BeyinOkuma.Not("projects/yok.md", Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(404, durum);
        Assert.DoesNotContain("/srv", govde.ToString());
    }

    [Fact]
    public async Task UnexpectedShape_Is502()
    {
        _beyin.Cikti("""{"bu": "liste degil"}""");

        Assert.Equal(502, (await Oku(await BeyinOkuma.Projeler(Bagli(), Gunluk, Ct), Ct)).Durum);
    }

    // Arguments

    [Fact]
    public async Task Ara_PassesTheQueryAfterDashDash_SoADashIsNotAnOption()
    {
        _beyin.Cikti("[]");

        await BeyinOkuma.Ara("--gizli-dahil", "kitap-kulubu", 5, Bagli(), Gunluk, Ct);

        var argumanlar = SahteBeyin.Argumanlar(_beyin.Cagrilar().Single());
        Assert.Equal(["ara", "--limit=5", "--proje=kitap-kulubu", "--json", "--vault", _beyin.Vault, "--", "--gizli-dahil"], argumanlar);
        Assert.DoesNotContain("--gizli-dahil", argumanlar.TakeWhile(a => a != "--"));
    }

    [Fact]
    public async Task Not_PassesThePathAfterDashDash()
    {
        _beyin.Cikti("""{"yol": "etiketler.md", "baslik": "E", "ustbilgi": {}, "govde": "x"}""");

        await BeyinOkuma.Not("etiketler.md", Bagli(), Gunluk, Ct);

        Assert.Equal(["not", "oku", "--json", "--vault", _beyin.Vault, "--", "etiketler.md"], SahteBeyin.Argumanlar(_beyin.Cagrilar().Single()));
    }

    [Fact]
    public async Task NoEndpointEverPassesGizliDahil()
    {
        _beyin.Cikti("[]");
        var istemci = Bagli();

        await BeyinOkuma.Projeler(istemci, Gunluk, Ct);
        await BeyinOkuma.Ara("a", null, null, istemci, Gunluk, Ct);
        await BeyinOkuma.Gun("2026-11-03", istemci, Gunluk, Ct);

        foreach (var cagri in _beyin.Cagrilar())
            Assert.DoesNotContain(SahteBeyin.Argumanlar(cagri), a => a.Contains("gizli", StringComparison.OrdinalIgnoreCase));
    }

    // Conversion and the fail-closed locks, with outputs the real brain should never give but the API must survive.

    [Fact]
    public async Task Projeler_DropsHiddenProjects_AndKeepsOnlyKimlikAndBaslik()
    {
        _beyin.Cikti("""
            [{"kimlik": "a", "baslik": "A", "yol": "projects/a/index.md", "repolar": ["/home/x/repo"], "gizli": false},
             {"kimlik": "b", "baslik": "B", "yol": "projects/b/index.md", "gizli": true},
             {"kimlik": "c", "baslik": "C", "gizli": "evet"}]
            """);

        var (durum, govde) = await Oku(await BeyinOkuma.Projeler(Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(200, durum);
        Assert.Equal(["a"], govde.EnumerateArray().Select(p => p.GetProperty("kimlik").GetString()).ToArray());
        Assert.DoesNotContain("repo", govde.ToString());
        Assert.DoesNotContain("yol", govde.ToString());
    }

    [Fact]
    public async Task Proje_Hidden_Is404()
    {
        _beyin.Cikti("""{"kimlik": "b", "baslik": "B", "gizli": true, "durum": "x", "acik_gorevler": [], "son_gunluk": []}""");

        Assert.Equal(404, (await Oku(await BeyinOkuma.Proje("b", Bagli(), Gunluk, Ct), Ct)).Durum);
    }

    [Fact]
    public async Task Proje_DropsHiddenTasks()
    {
        _beyin.Cikti("""
            {"kimlik": "a", "baslik": "A", "durum": "d", "siradaki_adim": "s",
             "acik_gorevler": [{"kimlik": "g1", "baslik": "Görünür", "durum": "aktif", "bitis": "2026-11-10", "yol": "x"},
                               {"kimlik": "g2", "baslik": "Gizli", "durum": "aktif", "gizli": true}],
             "son_gunluk": [{"zaman": "2026-11-03 18:42", "baslik": "b", "metin": "m"}]}
            """);

        var (_, govde) = await Oku(await BeyinOkuma.Proje("a", Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(["g1"], govde.GetProperty("acikGorevler").EnumerateArray().Select(g => g.GetProperty("kimlik").GetString()).ToArray());
        Assert.Equal("2026-11-10", govde.GetProperty("acikGorevler")[0].GetProperty("bitis").GetString());
        Assert.Equal("s", govde.GetProperty("siradakiAdim").GetString());
    }

    [Fact]
    public async Task Not_MarkedHidden_Is404_EvenIfTheBrainSentIt()
    {
        _beyin.Cikti("""{"yol": "projects/a/x.md", "baslik": "X", "ustbilgi": {"gizli": true, "tags": ["a"]}, "govde": "sir"}""");

        var (durum, govde) = await Oku(await BeyinOkuma.Not("projects/a/x.md", Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(404, durum);
        Assert.DoesNotContain("sir", govde.ToString());
    }

    [Fact]
    public async Task Not_ReturnsOnlyTheScreenFields()
    {
        _beyin.Cikti("""{"yol": "a/b.md", "baslik": "B", "ustbilgi": {"tur": "not", "soru": "q", "tags": ["x", "y"]}, "govde": "metin", "ustbilgi_hatalari": ["e"]}""");

        var (_, govde) = await Oku(await BeyinOkuma.Not("a/b.md", Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(["baslik", "etiketler", "govde", "yol"], govde.EnumerateObject().Select(p => p.Name).Order().ToArray());
        Assert.Equal(["x", "y"], govde.GetProperty("etiketler").EnumerateArray().Select(e => e.GetString()).ToArray());
    }

    [Fact]
    public async Task Ara_ReturnsOnlyTheScreenFields()
    {
        _beyin.Cikti("""[{"yol": "a/b.md", "baslik": "B", "tags": ["t"], "proje": "p", "alan": "projects", "tur": "not", "puan": 1.5, "alinti": "al", "yerine": null}]""");

        var (_, govde) = await Oku(await BeyinOkuma.Ara("b", null, null, Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(["alan", "alinti", "baslik", "proje", "yol"], govde[0].EnumerateObject().Select(p => p.Name).Order().ToArray());
    }

    [Fact]
    public async Task Gun_ConvertsPlanItemsAndDropsHiddenOnes()
    {
        _beyin.Cikti("""
            {"tarih": "2026-11-03", "gun_adi": "3 Kasım 2026", "hafta_gunu": "Salı", "bugun": false, "plan_var": true, "plan_yol": "kisisel/plan.md", "kapandi": false,
             "bolumler": [{"ad": "Yapılacaklar", "maddeler": [
                {"no": 1, "id": "d64fb2", "baslik": "Takvim", "metin": "t", "durum": "acik", "tahmin_dk": 90, "sure_dk": 45, "notlar": ["n"], "gorev": null, "proje": null},
                {"no": 2, "id": "x", "baslik": "Gizli madde", "durum": "acik", "gizli": true}]}],
             "geciken": [{"kimlik": "g", "baslik": "Geç", "bitis": "2026-11-01", "gun": 2, "proje": "p", "alan": "projects", "oncelik": null},
                         {"kimlik": "h", "baslik": "Gizli görev", "bitis": "2026-11-01", "gun": 2, "gizli": true}],
             "toplam": {"madde": 2, "yapildi": 0, "acik": 2, "tahmin_dk": 90, "tahmin": "1s30dk"}}
            """);

        var (durum, govde) = await Oku(await BeyinOkuma.Gun("2026-11-03", Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(200, durum);
        Assert.Equal("2026-11-03", govde.GetProperty("tarih").GetString());
        var maddeler = govde.GetProperty("bolumler")[0].GetProperty("maddeler");
        Assert.Equal(1, maddeler.GetArrayLength());
        Assert.Equal(90, maddeler[0].GetProperty("tahminDk").GetInt32());
        Assert.Equal(["g"], govde.GetProperty("geciken").EnumerateArray().Select(g => g.GetProperty("kimlik").GetString()).ToArray());
        Assert.DoesNotContain("kisisel/plan.md", govde.ToString());
        Assert.DoesNotContain("Gizli", govde.ToString());
    }

    // The closed folders (finans/, kisisel/): nothing from them leaves, wherever the brain mentions a path.

    [Fact]
    public async Task Ara_DropsHitsFromTheClosedFolders()
    {
        _beyin.Cikti("""
            [{"yol": "projects/a/notlar/n.md", "baslik": "Açık", "alan": "projects", "alinti": "a"},
             {"yol": "kisisel/plan-2026-11-03.md", "baslik": "Plan", "alan": "kisisel", "alinti": "sir"},
             {"yol": "finans/abonelikler.md", "baslik": "Abonelikler", "alan": "finans", "alinti": "sir"},
             {"yol": "Finans/Ham/x.md", "baslik": "Büyük harf", "alinti": "sir"}]
            """);

        var (durum, govde) = await Oku(await BeyinOkuma.Ara("a", null, null, Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(200, durum);
        Assert.Equal(["projects/a/notlar/n.md"], govde.EnumerateArray().Select(s => s.GetProperty("yol").GetString()).ToArray());
        Assert.DoesNotContain("sir", govde.ToString());
    }

    [Fact]
    public async Task Ara_SnippetComesAsPlainText()
    {
        _beyin.Cikti("""[{"yol": "a/b.md", "baslik": "B", "alinti": "# Başlık ## 2026-11-03 · **Kalın** ve [bağlantı](http://x.y) - [x] 20 sayfa ^c4d957"}]""");

        var (_, govde) = await Oku(await BeyinOkuma.Ara("b", null, null, Bagli(), Gunluk, Ct), Ct);

        Assert.Equal("Başlık 2026-11-03 · Kalın ve bağlantı 20 sayfa", govde[0].GetProperty("alinti").GetString());
    }

    [Fact]
    public async Task Proje_InAClosedFolder_Is404()
    {
        _beyin.Cikti("""{"kimlik": "a", "baslik": "A", "yol": "kisisel/a/index.md", "durum": "sir", "acik_gorevler": [], "son_gunluk": []}""");

        var (durum, govde) = await Oku(await BeyinOkuma.Proje("a", Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(404, durum);
        Assert.DoesNotContain("sir", govde.ToString());
    }

    [Fact]
    public async Task Proje_DropsTasksAndProjectsFromTheClosedFolders()
    {
        _beyin.Cikti("""
            {"kimlik": "a", "baslik": "A", "yol": "projects/a/index.md", "durum": "d",
             "acik_gorevler": [{"kimlik": "g1", "baslik": "Açık", "durum": "aktif", "yol": "projects/a/gorevler/g1.md"},
                               {"kimlik": "g2", "baslik": "Kişisel", "durum": "aktif", "yol": "kisisel/gorevler/dis-randevusu-al.md"},
                               {"kimlik": "g3", "baslik": "Finans", "durum": "aktif", "yol": "finans/borc.md"}],
             "son_gunluk": []}
            """);
        var (_, proje) = await Oku(await BeyinOkuma.Proje("a", Bagli(), Gunluk, Ct), Ct);
        Assert.Equal(["g1"], proje.GetProperty("acikGorevler").EnumerateArray().Select(g => g.GetProperty("kimlik").GetString()).ToArray());

        _beyin.Cikti("""
            [{"kimlik": "a", "baslik": "A", "yol": "projects/a/index.md"},
             {"kimlik": "k", "baslik": "K", "yol": "kisisel/k/index.md"}]
            """);
        var (_, liste) = await Oku(await BeyinOkuma.Projeler(Bagli(), Gunluk, Ct), Ct);
        Assert.Equal(["a"], liste.EnumerateArray().Select(p => p.GetProperty("kimlik").GetString()).ToArray());
    }

    [Fact]
    public async Task Gun_DropsOverdueTasksFromTheClosedFolders()
    {
        _beyin.Cikti("""
            {"tarih": "2026-11-03", "plan_var": true, "bolumler": [],
             "geciken": [{"kimlik": "g", "baslik": "Açık", "yol": "projects/p/gorevler/g.md", "gun": 2},
                         {"kimlik": "h", "baslik": "Kişisel", "yol": "kisisel/gorevler/dis-randevusu-al.md", "gun": 2}]}
            """);

        var (_, govde) = await Oku(await BeyinOkuma.Gun("2026-11-03", Bagli(), Gunluk, Ct), Ct);

        Assert.Equal(["g"], govde.GetProperty("geciken").EnumerateArray().Select(g => g.GetProperty("kimlik").GetString()).ToArray());
    }

    // The plain-text snippet

    [Theory]
    [InlineData("# Başlık", "Başlık")]
    [InlineData("## Durum Okuma listesi sayfası bitti. ## Sıradaki adım Buluşma", "Durum Okuma listesi sayfası bitti. Sıradaki adım Buluşma")]
    [InlineData("**kalın** ve *italik* ve __altı__ ve `kod` ve ~~çizili~~", "kalın ve italik ve altı ve kod ve çizili")]
    [InlineData("[[proje/not|Görünen ad]] ve [[düz not]]", "Görünen ad ve düz not")]
    [InlineData("![resim](a.png) [bağ](http://x)", "resim bağ")]
    [InlineData("…~30dk ^10a508 - [x] 20 sayfa kitap ^c4d957", "…~30dk 20 sayfa kitap")]
    [InlineData("> alıntı satırı", "alıntı satırı")]
    [InlineData("<b>kalın</b> yazı", "kalın yazı")]
    [InlineData("C# dili, snake_case_ad, a-b ve 5 - 3", "C# dili, snake_case_ad, a-b ve 5 3")]
    [InlineData("  çok   boşluk  var  ", "çok boşluk var")]
    public void DuzMetin_TakesTheMarksOut_AndKeepsTheWords(string girdi, string beklenen) =>
        Assert.Equal(beklenen, DuzMetin.Temizle(girdi));

    [Fact]
    public void DuzMetin_LeavesNullAndEmptyAlone()
    {
        Assert.Null(DuzMetin.Temizle(null));
        Assert.Equal("", DuzMetin.Temizle(""));
    }
}
