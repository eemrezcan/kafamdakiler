using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Eylemler;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The two action kinds of the voice module (K2.4) against the real beyin.py and a throwaway copy of ornek-beyin/.
// Skipped when beyin.py is not on this machine (see TestAyari.GercekBeyin). The fake brain only answers what these tests
// read off the real one: the arguments `gorev ekle` and `gun ekle` accept, `~45dk` as an estimate, and what `gorev guncelle
// --durum iptal` does to the file.
public sealed class GercekBeyinSesTests : IDisposable
{
    private readonly string _vault = Path.Combine(Path.GetTempPath(), "kd-ses-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(_vault))
            Directory.Delete(_vault, recursive: true);
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static readonly EylemBaglami Baglam = new(null!, DateTimeOffset.UtcNow);

    private BeyinIstemcisi Hazirla()
    {
        var ayar = TestAyari.GercekBeyin(_vault);
        Assert.True(OrnekBeyinKopyasi.HazirlaGerekirse(ayar));
        return new BeyinIstemcisi(ayar);
    }

    private static JsonElement Yuk(object yuk) => JsonSerializer.SerializeToElement(yuk, JsonSerializerOptions.Web);

    private static GorevEkleTuru GorevTuru(BeyinIstemcisi beyin) => new(beyin, NullLogger<GorevEkleTuru>.Instance);

    private static PlanEkleTuru PlanTuru(BeyinIstemcisi beyin) => new(beyin, NullLogger<PlanEkleTuru>.Instance);

    // The task as `gorev liste` shows it, whatever its state.
    private static async Task<JsonElement> GorevSatiri(BeyinIstemcisi beyin, string yol)
    {
        var sonuc = await beyin.CalistirAsync(["gorev", "liste", "--durum=hepsi"], Ct);
        Assert.True(sonuc.Basarili, sonuc.Mesaj);
        return sonuc.Veri!.Value.EnumerateArray().Single(g => g.GetProperty("yol").GetString() == yol);
    }

    private static async Task<(string Kimlik, string Yol, JsonElement Bilgi)> GorevOlustur(BeyinIstemcisi beyin, GorevEkleTuru tur, string baslik, string? proje = "kitap-kulubu", string? alan = null)
    {
        var yuk = Yuk(new { baslik, proje, alan });
        var dogrulama = await tur.DogrulaAsync(yuk, Ct);
        Assert.True(dogrulama.Basarili, dogrulama.Mesaj);
        var bilgi = await tur.UygulaAsync(yuk, Baglam, Ct);
        return (bilgi.GetProperty("kimlik").GetString()!, bilgi.GetProperty("yol").GetString()!, bilgi);
    }

    [Fact]
    public async Task Task_IsAdded_AndUndoCancelsItWithAReason()
    {
        var beyin = Hazirla();
        var tur = GorevTuru(beyin);

        var (kimlik, yol, bilgi) = await GorevOlustur(beyin, tur, "Sesten gelen görev");

        Assert.Equal("projects/kitap-kulubu/gorevler/" + kimlik + ".md", yol);
        Assert.Equal("aktif", (await GorevSatiri(beyin, yol)).GetProperty("durum").GetString());
        Assert.True(((IEylemTuru)tur).GeriAlinabilir);

        await tur.GeriAlAsync(bilgi, Baglam, Ct);

        Assert.Equal("iptal", (await GorevSatiri(beyin, yol)).GetProperty("durum").GetString());
        Assert.Contains("iptal", File.ReadAllText(Path.Combine(_vault, yol)));
        Assert.Contains("geri alındı", File.ReadAllText(Path.Combine(_vault, yol)));
    }

    [Fact]
    public async Task Task_InAnOpenArea_IsAdded()
    {
        var beyin = Hazirla();

        var (_, yol, _) = await GorevOlustur(beyin, GorevTuru(beyin), "Kitap oku", proje: null, alan: "ogrenme");

        Assert.StartsWith("ogrenme/gorevler/", yol);
        Assert.Equal("ogrenme", (await GorevSatiri(beyin, yol)).GetProperty("alan").GetString());
    }

    [Theory]
    [InlineData("bitti")]
    [InlineData("bekliyor")]
    [InlineData("iptal")]
    public async Task Undo_LeavesATaskThePersonHasMovedOn(string durum)
    {
        var beyin = Hazirla();
        var tur = GorevTuru(beyin);
        var (kimlik, yol, bilgi) = await GorevOlustur(beyin, tur, "Başka yere geçti");

        var degisti = durum == "bitti"
            ? await beyin.CalistirAsync(["gorev", "bitir", "--kanit=onay:uygulama-2026-11-07"], Ct, [kimlik])
            : durum == "iptal"
                ? await beyin.CalistirAsync(["gorev", "guncelle", "--durum=iptal", "--gerekce=vazgeçtim"], Ct, [kimlik])
                : await beyin.CalistirAsync(["gorev", "guncelle", "--durum=bekliyor"], Ct, [kimlik]);
        Assert.True(degisti.Basarili, degisti.Mesaj);
        var once = File.ReadAllText(Path.Combine(_vault, yol));

        await tur.GeriAlAsync(bilgi, Baglam, Ct);

        Assert.Equal(durum, (await GorevSatiri(beyin, yol)).GetProperty("durum").GetString());
        Assert.Equal(once, File.ReadAllText(Path.Combine(_vault, yol)));
    }

    [Fact]
    public async Task Undo_OfATaskThatIsGone_IsQuietlyDone()
    {
        var beyin = Hazirla();
        var tur = GorevTuru(beyin);
        var (_, yol, bilgi) = await GorevOlustur(beyin, tur, "Silinecek");
        File.Delete(Path.Combine(_vault, yol));

        await tur.GeriAlAsync(bilgi, Baglam, Ct);
    }

    [Fact]
    public async Task Task_WithAProjectThatDoesNotExist_IsRefusedBeforeAnythingIsWritten()
    {
        var beyin = Hazirla();
        var tur = GorevTuru(beyin);

        var dogrulama = await tur.DogrulaAsync(Yuk(new { baslik = "Olmayan", proje = "olmayan-proje" }), Ct);

        Assert.False(dogrulama.Basarili);
        Assert.Equal("proje", dogrulama.Alan);
        Assert.False(Directory.Exists(Path.Combine(_vault, "projects", "olmayan-proje")));
    }

    [Fact]
    public async Task Task_InAClosedArea_IsRefused_ByTheSameRulesAsTheTaskEndpoint()
    {
        var beyin = Hazirla();
        var tur = GorevTuru(beyin);

        Assert.False((await tur.DogrulaAsync(Yuk(new { baslik = "Para", alan = "finans" }), Ct)).Basarili);
        Assert.False((await tur.DogrulaAsync(Yuk(new { baslik = "Para", proje = "kitap-kulubu", alan = "ogrenme" }), Ct)).Basarili);
        Assert.False((await tur.DogrulaAsync(Yuk(new { baslik = "Para" }), Ct)).Basarili);
        Assert.False((await tur.DogrulaAsync(Yuk(new { baslik = "Para", proje = "kitap-kulubu", bitis = "yarın" }), Ct)).Basarili);
    }

    [Fact]
    public async Task PlanItem_IsWrittenWithItsEstimate_AndCannotBeUndone()
    {
        var beyin = Hazirla();
        var tur = PlanTuru(beyin);
        var yuk = Yuk(new { gun = "2030-03-04", metin = "Raporu bitir", bolum = "Okul", tahminDk = 45 });
        Assert.True(tur.Dogrula(yuk).Basarili);
        Assert.False(tur.GeriAlinabilir);

        var bilgi = await tur.UygulaAsync(yuk, Baglam, Ct);

        Assert.Equal("2030-03-04", bilgi.GetProperty("tarih").GetString());
        var gun = await BeyinOkuma.GunAl("2030-03-04", beyin, NullLogger.Instance, Ct);
        Assert.True(gun.Basarili);
        var madde = gun.Veri!.Bolumler.SelectMany(b => b.Maddeler).Single(m => m.Id == bilgi.GetProperty("madde").GetString());
        // The brain keeps `~45dk` in the title and reads the estimate off it: the same as for an item made by hand.
        Assert.Equal(("Raporu bitir ~45dk", 45, "Okul"), (madde.Baslik, madde.TahminDk, gun.Veri.Bolumler.Single(b => b.Maddeler.Contains(madde)).Ad));
        await Assert.ThrowsAsync<NotSupportedException>(() => tur.GeriAlAsync(bilgi, Baglam, Ct));
    }

    [Theory]
    [InlineData("{\"gun\":\"2030-03-04\"}")]
    [InlineData("{\"gun\":\"yarın\",\"metin\":\"x\"}")]
    [InlineData("{\"gun\":\"2030-03-04\",\"metin\":\"x\",\"bolum\":\"Kapanış\"}")]
    [InlineData("{\"gun\":\"2030-03-04\",\"metin\":\"x\",\"tahminDk\":0}")]
    [InlineData("{\"gun\":\"2030-03-04\",\"metin\":\"x\",\"baska\":1}")]
    [InlineData("{\"gun\":\"2030-03-04\",\"metin\":\"satır\\nsonu\"}")]
    public void PlanItem_WithABadShape_IsRefused(string json)
    {
        var tur = PlanTuru(new BeyinIstemcisi(new BeyinAyari()));

        Assert.False(tur.Dogrula(JsonDocument.Parse(json).RootElement).Basarili);
    }
}
