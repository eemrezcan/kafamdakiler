using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The inbox against the real beyin.py and a throwaway copy of ornek-beyin/ (the template is never written to). Skipped when
// beyin.py is not on this machine (TestAyari.GercekBeyin). The fake brain of the other tests is only as good as what is read
// off the real one here: the shape of `gelen liste`, of `not oku` on a card and on etiketler.md, the answer of `gelen isle`,
// and that the brain would put a card into finans/ if the server let it.
public sealed class GercekBeyinGelenTests : IAsyncLifetime
{
    private const string Kart = "2026-11-03-1840-kitap-onerisi";
    private const string GizliKart = "2026-11-03-2000-gizli-kart";
    private const string GizliProjeKarti = "2026-11-03-2100-gizli-proje-karti";

    private static readonly NullLogger Gunluk = NullLogger.Instance;

    private readonly string _vault = Path.Combine(Path.GetTempPath(), "kd-gelen-" + Guid.NewGuid().ToString("N"));
    private readonly TestVeritabani _vt = new();
    private readonly SahteClaude _claude = new();

    public ValueTask InitializeAsync() => ValueTask.CompletedTask;

    public async ValueTask DisposeAsync()
    {
        await _vt.DisposeAsync();
        _claude.Dispose();
        if (Directory.Exists(_vault))
            Directory.Delete(_vault, recursive: true);
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private BeyinIstemcisi Hazirla()
    {
        var ayar = TestAyari.GercekBeyin(_vault);
        Assert.True(OrnekBeyinKopyasi.HazirlaGerekirse(ayar));
        Yaz("projects/gizli-proje/index.md", "---\nbaslik: Gizli Proje\ntur: proje\nrepolar: []\ntags: []\ngizli: true\n---\n# Gizli Proje\n\n## Durum\nx\n\n## Sıradaki adım\nx\n");
        Yaz($"gelen/{GizliKart}.md", "---\nbaslik: \"Gizli kart\"\ntur: gelen\ntags: []\ngizli: true\nyakalandi: 2026-11-03T20:00\n---\nzebraluk gizli metin\n");
        Yaz($"gelen/{GizliProjeKarti}.md", "---\nbaslik: \"Gizli projenin kartı\"\ntur: gelen\ntags: []\nhedef: projects/gizli-proje\nyakalandi: 2026-11-03T21:00\n---\nzebraluk gizli projenin metni\n");
        return new BeyinIstemcisi(ayar);
    }

    private void Yaz(string yol, string icerik)
    {
        var tam = Path.Combine(_vault, yol);
        Directory.CreateDirectory(Path.GetDirectoryName(tam)!);
        File.WriteAllText(tam, icerik);
    }

    private static async Task<List<BeyinKarti>> KartlarAsync(BeyinIstemcisi beyin)
    {
        var yanit = await GelenBeyin.KartlariAlAsync(beyin, Gunluk, Ct);
        Assert.True(yanit.Basarili);
        return yanit.Veri!;
    }

    [Fact]
    public async Task List_HasTheVisibleCards_WithTheirFields_AndNoHiddenOne()
    {
        var beyin = Hazirla();

        var kartlar = await KartlarAsync(beyin);

        Assert.DoesNotContain(kartlar, k => k.Kimlik is GizliKart or GizliProjeKarti);
        var kitap = Assert.Single(kartlar, k => k.Kimlik == Kart);
        Assert.Equal("Kitap önerisi", kitap.Baslik);
        Assert.Equal("2026-11-03T18:40", kitap.Yakalandi);
        Assert.Null(kitap.Hedef);
        Assert.False(kitap.GorselVar);
        var takvim = Assert.Single(kartlar, k => k.Kimlik == "2026-11-03-0915-takvim-renkleri");
        Assert.Equal("projects/kitap-kulubu", takvim.Hedef);
    }

    [Fact]
    public async Task TheProjectsAndTheDictionary_AreReadFromTheRealBrain_WithoutTheHiddenProject()
    {
        var beyin = Hazirla();

        var projeler = await GelenBeyin.ProjeleriAlAsync(beyin, Gunluk, Ct);
        var sozluk = await GelenBeyin.SozluguAlAsync(beyin, Gunluk, Ct);

        Assert.True(projeler.Basarili);
        Assert.Contains("kitap-kulubu", projeler.Veri!);
        Assert.DoesNotContain("gizli-proje", projeler.Veri!);
        Assert.True(sozluk.Basarili);
        Assert.False(sozluk.Veri!.Bos);
        Assert.Contains("yazılım", sozluk.Veri.AnaAdlar);
        Assert.Contains("okul", sozluk.Veri.AnaAdlar);
        // A synonym is a valid tag for the brain, but not a main name.
        Assert.Equal("doğrulama", sozluk.Veri.Coz("doğrulama"));
        Assert.False(sozluk.Veri.AnaAdMi("doğrulama"));
        Assert.Null(sozluk.Veri.Coz("yepyeni-etiket"));
    }

    [Fact]
    public async Task ACardBody_CanBeReadWithNotOku_AndAHiddenOneIsRefused()
    {
        var beyin = Hazirla();

        var kart = await GelenBeyin.KartMetniAlAsync(Kart, beyin, Gunluk, Ct);
        var gizli = await GelenBeyin.KartMetniAlAsync(GizliKart, beyin, Gunluk, Ct);

        Assert.True(kart.Basarili);
        Assert.Contains("Simyacı", kart.Veri!.Govde);
        Assert.False(gizli.Basarili);
        Assert.Equal(404, gizli.Durum);
    }

    [Fact]
    public async Task Place_TurnsTheCardIntoANote_AndTheCardIsGone()
    {
        var beyin = Hazirla();

        var yanit = await GelenIslemleri.Isle(Kart, new("projects/kitap-kulubu/notlar/simyaci-onerisi.md", "Simyacı önerisi", ["kaynak", "okul"], null), beyin, Gunluk, Ct);

        var (durum, govde) = await BeyinOkumaTests.Oku(yanit.Sonuc(), Ct);
        Assert.Equal(200, durum);
        Assert.Equal("projects/kitap-kulubu/notlar/simyaci-onerisi.md", govde.GetProperty("yol").GetString());
        Assert.DoesNotContain(await KartlarAsync(beyin), k => k.Kimlik == Kart);
        var not = File.ReadAllText(Path.Combine(_vault, "projects/kitap-kulubu/notlar/simyaci-onerisi.md"));
        Assert.Contains("baslik: Simyacı önerisi", not);
        Assert.Contains("Ayşe", not);
        Assert.False(File.Exists(Path.Combine(_vault, "gelen", Kart + ".md")));
    }

    [Theory]
    [InlineData("finans/gelen-not.md")]
    [InlineData("kisisel/gelen-not.md")]
    [InlineData("gelen/baska.md")]
    [InlineData("projects/gizli-proje/notlar/x.md")]
    [InlineData("../kaçak.md")]
    public async Task Place_IntoAClosedPlace_IsRefusedByTheServer_AndTheCardStays(string yol)
    {
        // The brain itself would write into finans/; it is the server's check that keeps the card out of there.
        var beyin = Hazirla();

        var yanit = await GelenIslemleri.Isle(Kart, new(yol, "Başlık", ["kaynak"], null), beyin, Gunluk, Ct);

        var (durum, _) = await BeyinOkumaTests.Oku(yanit.Sonuc(), Ct);
        Assert.Equal(400, durum);
        Assert.Contains(await KartlarAsync(beyin), k => k.Kimlik == Kart);
        Assert.False(File.Exists(Path.Combine(_vault, "finans", "gelen-not.md")));
    }

    [Fact]
    public async Task Place_WithATagTheDictionaryDoesNotHave_IsRefused_AndTheCardStays()
    {
        var beyin = Hazirla();

        var yanit = await GelenIslemleri.Isle(Kart, new("ogrenme/x.md", "Başlık", ["yepyeni-etiket"], null), beyin, Gunluk, Ct);

        var (durum, _) = await BeyinOkumaTests.Oku(yanit.Sonuc(), Ct);
        Assert.Equal(400, durum);
        Assert.Contains(await KartlarAsync(beyin), k => k.Kimlik == Kart);
    }

    [Fact]
    public async Task Place_ACardThatIsHidden_LooksLikeOneThatDoesNotExist()
    {
        var beyin = Hazirla();

        var gizli = await GelenIslemleri.Isle(GizliKart, new("ogrenme/x.md", "Başlık", ["kaynak"], null), beyin, Gunluk, Ct);
        var yok = await GelenIslemleri.Isle("2026-11-03-0001-yok", new("ogrenme/x.md", "Başlık", ["kaynak"], null), beyin, Gunluk, Ct);
        var silGizli = await GelenIslemleri.Sil(GizliKart, beyin, Gunluk, Ct);

        Assert.Equal(404, (await BeyinOkumaTests.Oku(gizli.Sonuc(), Ct)).Durum);
        Assert.Equal(404, (await BeyinOkumaTests.Oku(yok.Sonuc(), Ct)).Durum);
        Assert.Equal(404, (await BeyinOkumaTests.Oku(silGizli.Sonuc(), Ct)).Durum);
        Assert.True(File.Exists(Path.Combine(_vault, "gelen", GizliKart + ".md")));
    }

    [Fact]
    public async Task Delete_RemovesTheCard()
    {
        var beyin = Hazirla();

        var yanit = await GelenIslemleri.Sil(Kart, beyin, Gunluk, Ct);

        Assert.Equal(200, (await BeyinOkumaTests.Oku(yanit.Sonuc(), Ct)).Durum);
        Assert.DoesNotContain(await KartlarAsync(beyin), k => k.Kimlik == Kart);
        Assert.False(File.Exists(Path.Combine(_vault, "gelen", Kart + ".md")));
    }

    [Fact]
    public async Task TheWholeFlow_ASuggestionForTheCard_ApprovedInTheQueue_PlacesItInTheRealBrain()
    {
        var beyin = Hazirla();
        await _vt.InitializeAsync();
        _claude.YapiliYanit(JsonSerializer.Serialize(new
        {
            yol = "projects/kitap-kulubu/notlar/simyaci-onerisi.md", baslik = "Simyacı önerisi", etiketler = new[] { "kaynak", "okul", "özet" },
            gerekce = "Kitap önerisi.", guven = 0.9, yeniEtiketGerekir = false,
        }));
        var saat = TimeProvider.System;
        var turler = new EylemTurleri([new YerlestirTuru(beyin, NullLogger<YerlestirTuru>.Instance)]);
        var eylemler = new EylemServisi(_vt.Db, turler, saat, NullLogger<EylemServisi>.Instance);
        var claude = _claude.Istemci();
        var onerici = new GelenOnerici(_vt.Db, beyin, claude, eylemler, new GelenAyari(), saat, NullLogger<GelenOnerici>.Instance);

        var ozet = await onerici.TurAsync(Ct);

        // Every visible card was asked, the two hidden ones were not: Claude never saw their text.
        var gorunur = (await KartlarAsync(beyin)).Count;
        Assert.Equal(gorunur, _claude.Cagrilar().Count);
        Assert.DoesNotContain(_claude.Cagrilar(), c => c.GetProperty("stdin").GetString()!.Contains("zebraluk"));
        Assert.Equal(gorunur, ozet.Onerilen + ozet.Basarisiz);

        // The queue holds one suggestion for the book card (the others got the same answer for the same path: refused on apply).
        var eylem = (await _vt.Db.Eylemler.AsNoTracking().ToListAsync(Ct)).First(e => e.Yuk.Contains(Kart));
        Assert.Equal(EylemDurumu.Bekliyor, eylem.Durum);
        Assert.True(File.Exists(Path.Combine(_vault, "gelen", Kart + ".md")));

        var sonuc = await eylemler.UygulaAsync(eylem.Id, null, null, Ct);

        Assert.Equal(EylemSonucuTuru.Tamam, sonuc.Tur);
        Assert.True(File.Exists(Path.Combine(_vault, "projects/kitap-kulubu/notlar/simyaci-onerisi.md")));
        Assert.False(File.Exists(Path.Combine(_vault, "gelen", Kart + ".md")));
        Assert.DoesNotContain(await KartlarAsync(beyin), k => k.Kimlik == Kart);
    }
}
