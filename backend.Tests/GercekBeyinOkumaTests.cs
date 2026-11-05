using System.Text.Json;
using Kafamdakiler.Beyin;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The read endpoints against the real beyin.py and a throwaway copy of ornek-beyin/ with extra hidden records added
// (a hidden project with a note, a hidden task, a hidden note). Skipped when beyin.py is not on this machine.
// The point: whatever is marked hidden does not come out of any endpoint, through any of the ways to ask for it.
public sealed class GercekBeyinOkumaTests : IDisposable
{
    private const string GizliKelime = "zebraluk";
    private const string GorunurKelime = "salyangozlama";

    private static readonly NullLogger Gunluk = NullLogger.Instance;

    private readonly string _vault = Path.Combine(Path.GetTempPath(), "kd-okuma-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(_vault))
            Directory.Delete(_vault, recursive: true);
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private BeyinIstemcisi Hazirla()
    {
        var ayar = TestAyari.GercekBeyin(_vault);
        Assert.True(OrnekBeyinKopyasi.HazirlaGerekirse(ayar));

        Yaz("projects/gizli-proje/index.md", $"---\nbaslik: Gizli Proje\ntur: proje\nrepolar: []\ntags: []\ngizli: true\n---\n# Gizli Proje\n\n## Durum\n{GizliKelime} durumu\n\n## Sıradaki adım\n{GizliKelime} adımı\n");
        Yaz("projects/gizli-proje/notlar/sir.md", $"---\nbaslik: Gizli projenin notu\ntur: not\ntags: []\n---\n\n{GizliKelime} burada yazılı.\n");
        Yaz("projects/gizli-proje/gorevler/sir-gorev.md", $"---\nbaslik: Gizli proje görevi {GizliKelime}\ntur: gorev\ndurum: aktif\nbitis: 2026-11-01\ntags: []\nkanit: []\n---\n\n# Gizli proje görevi\n");
        Yaz("projects/kitap-kulubu/gorevler/gizli-gorev.md", $"---\nbaslik: Gizli görev {GizliKelime}\ntur: gorev\ndurum: aktif\nbitis: 2026-11-01\ntags: []\nkanit: []\ngizli: true\n---\n\n# Gizli görev\n");
        Yaz("projects/kitap-kulubu/notlar/gizli-not-2.md", $"---\nbaslik: Gizli proje notu {GizliKelime}\ntur: not\ntags: []\ngizli: true\n---\n\n{GizliKelime} gizli not.\n");
        Yaz("projects/kitap-kulubu/notlar/gorunur.md", $"---\nbaslik: Görünür not\ntur: not\ntags: [deneme]\n---\n\n{GorunurKelime} burada yazılı.\n");
        return new BeyinIstemcisi(ayar);
    }

    private void Yaz(string yol, string icerik)
    {
        var tam = Path.Combine(_vault, yol);
        Directory.CreateDirectory(Path.GetDirectoryName(tam)!);
        File.WriteAllText(tam, icerik);
    }

    private static async Task<(int Durum, JsonElement Govde)> Oku(Task<IResult> sonuc) =>
        await BeyinOkumaTests.Oku(await sonuc, Ct);

    private static string[] Alan(JsonElement liste, string ad) =>
        liste.EnumerateArray().Select(e => e.GetProperty(ad).GetString()!).ToArray();

    [Fact]
    public async Task Projeler_HasTheVisibleProjects_NotTheHiddenOne()
    {
        var beyin = Hazirla();

        var (durum, govde) = await Oku(BeyinOkuma.Projeler(beyin, Gunluk, Ct));

        Assert.Equal(200, durum);
        Assert.Equal(["balkon-bahcesi", "kitap-kulubu", "staj-hazirligi"], Alan(govde, "kimlik").Order().ToArray());
        Assert.DoesNotContain("gizli-proje", govde.ToString());
    }

    [Fact]
    public async Task Proje_Visible_HasStatusNextStepAndTasks_WithoutTheHiddenTask()
    {
        var beyin = Hazirla();

        var (durum, govde) = await Oku(BeyinOkuma.Proje("kitap-kulubu", beyin, Gunluk, Ct));

        Assert.Equal(200, durum);
        Assert.Equal("Kitap Kulübü Sitesi", govde.GetProperty("baslik").GetString());
        Assert.False(string.IsNullOrEmpty(govde.GetProperty("siradakiAdim").GetString()));
        var gorevler = Alan(govde.GetProperty("acikGorevler"), "kimlik");
        Assert.Contains("uye-girisi", gorevler);
        Assert.DoesNotContain("gizli-gorev", gorevler);
        Assert.DoesNotContain(GizliKelime, govde.ToString());
    }

    [Fact]
    public async Task Proje_Hidden_LooksLikeOneThatDoesNotExist()
    {
        var beyin = Hazirla();

        var gizli = await Oku(BeyinOkuma.Proje("gizli-proje", beyin, Gunluk, Ct));
        var yok = await Oku(BeyinOkuma.Proje("hic-yok", beyin, Gunluk, Ct));

        Assert.Equal(404, gizli.Durum);
        Assert.Equal(404, yok.Durum);
        Assert.Equal(yok.Govde.GetProperty("detail").GetString(), gizli.Govde.GetProperty("detail").GetString());
        Assert.DoesNotContain(GizliKelime, gizli.Govde.ToString());
    }

    [Fact]
    public async Task Ara_FindsVisibleNotes_NeverTheHiddenOnes()
    {
        var beyin = Hazirla();

        // Control: the index sees the files we just added, so an empty answer below means "filtered", not "not indexed".
        var kontrol = await Oku(BeyinOkuma.Ara(GorunurKelime, null, null, beyin, Gunluk, Ct));
        Assert.Equal(200, kontrol.Durum);
        Assert.Contains("projects/kitap-kulubu/notlar/gorunur.md", Alan(kontrol.Govde, "yol"));

        foreach (var sorgu in new[] { GizliKelime, "Gizli örnek not", "yapay zekâ isteğinde", "gizli" })
        {
            var (durum, govde) = await Oku(BeyinOkuma.Ara(sorgu, null, EnCok(), beyin, Gunluk, Ct));
            Assert.Equal(200, durum);
            var yollar = Alan(govde, "yol");
            Assert.DoesNotContain("kisisel/gizli-not.md", yollar);
            Assert.DoesNotContain(yollar, y => y.Contains("gizli-proje") || y.Contains("gizli-not-2") || y.Contains("gizli-gorev"));
            Assert.DoesNotContain(GizliKelime, govde.ToString().Replace("gizli-proje", ""));
        }

        // Inside the hidden project too.
        var icerde = await Oku(BeyinOkuma.Ara(GizliKelime, "gizli-proje", null, beyin, Gunluk, Ct));
        Assert.DoesNotContain("sir.md", icerde.Govde.ToString());
    }

    private static int EnCok() => BeyinOkuma.EnCokSonuc;

    // finans/ and kisisel/ are closed to the API: the brain does find them, the answer must not carry them.
    [Fact]
    public async Task Ara_NeverReturnsTheClosedFolders_EvenWhenTheBrainFindsThem()
    {
        var beyin = Hazirla();

        var ham = await beyin.CalistirAsync(["ara", "--limit=50"], Ct, ["kitap"]);
        Assert.True(ham.Basarili);
        Assert.Contains(ham.Veri!.Value.EnumerateArray(), e => e.GetProperty("yol").GetString()!.StartsWith("kisisel/"));

        var (durum, govde) = await Oku(BeyinOkuma.Ara("kitap", null, EnCok(), beyin, Gunluk, Ct));

        Assert.Equal(200, durum);
        Assert.NotEmpty(Alan(govde, "yol"));
        Assert.DoesNotContain(Alan(govde, "yol"), y => y.StartsWith("kisisel/") || y.StartsWith("finans/"));
    }

    [Fact]
    public async Task Ara_QueryThatLooksLikeAnOption_IsJustText()
    {
        var beyin = Hazirla();

        foreach (var sorgu in new[] { "--gizli-dahil", "-x", "--vault=/tmp", "--json" })
        {
            var (durum, govde) = await Oku(BeyinOkuma.Ara(sorgu, null, null, beyin, Gunluk, Ct));
            Assert.Equal(200, durum);
            Assert.DoesNotContain("gizli-not.md", govde.ToString());
        }
    }

    [Fact]
    public async Task Not_HiddenNotes_AreRefused_AsIfMissing()
    {
        var beyin = Hazirla();

        var yok = await Oku(BeyinOkuma.Not("projects/kitap-kulubu/notlar/hic-yok.md", beyin, Gunluk, Ct));
        Assert.Equal(404, yok.Durum);

        foreach (var yol in new[]
                 {
                     "projects/kitap-kulubu/notlar/gizli-not-2.md",
                     "projects/gizli-proje/index.md",
                     "projects/gizli-proje/notlar/sir.md",
                 })
        {
            var (durum, govde) = await Oku(BeyinOkuma.Not(yol, beyin, Gunluk, Ct));
            Assert.Equal(404, durum);
            Assert.Equal(yok.Govde.GetProperty("detail").GetString(), govde.GetProperty("detail").GetString());
            Assert.DoesNotContain(GizliKelime, govde.ToString());
        }
    }

    [Fact]
    public async Task Not_Visible_ReturnsTitleTagsAndBody()
    {
        var beyin = Hazirla();

        var (durum, govde) = await Oku(BeyinOkuma.Not("projects/kitap-kulubu/notlar/gorunur.md", beyin, Gunluk, Ct));

        Assert.Equal(200, durum);
        Assert.Equal("Görünür not", govde.GetProperty("baslik").GetString());
        Assert.Equal(["deneme"], govde.GetProperty("etiketler").EnumerateArray().Select(e => e.GetString()).ToArray());
        Assert.Contains(GorunurKelime, govde.GetProperty("govde").GetString());
    }

    [Theory]
    [InlineData("../kisisel/gizli-not.md")]
    [InlineData("/etc/passwd")]
    [InlineData(".beyin/indeks.sqlite3")]
    [InlineData("finans/ham/ekstre.md")]
    [InlineData("finans/abonelikler.md")]
    [InlineData("kisisel/gizli-not.md")]
    [InlineData("kisisel/plan-2026-11-03.md")]
    [InlineData("projects/../kisisel/gizli-not.md")]
    public async Task Not_BadPath_Is400_AndNeverReachesTheBrain(string yol)
    {
        var beyin = Hazirla();

        Assert.Equal(400, (await Oku(BeyinOkuma.Not(yol, beyin, Gunluk, Ct))).Durum);
    }

    [Fact]
    public async Task Gun_HasThePlan_WithoutHiddenTasks_AndAReadChangesNothingTheSecondTime()
    {
        var beyin = Hazirla();

        // The brain gives plan lines a permanent id (`^d64fb2`) the first time it shows a day: that first read writes
        // the plan file. After it, reading again must change nothing.
        var plan = await Oku(BeyinOkuma.Gun("2026-11-03", beyin, Gunluk, Ct));
        var onceki = Dosyalar();
        plan = await Oku(BeyinOkuma.Gun("2026-11-03", beyin, Gunluk, Ct));
        var bos = await Oku(BeyinOkuma.Gun("2026-12-24", beyin, Gunluk, Ct));

        Assert.Equal(200, plan.Durum);
        Assert.True(plan.Govde.GetProperty("planVar").GetBoolean());
        Assert.Equal(3, plan.Govde.GetProperty("toplam").GetProperty("madde").GetInt32());
        Assert.Equal(200, bos.Durum);
        // The overdue list is where a hidden task would show up.
        var geciken = Alan(bos.Govde.GetProperty("geciken"), "kimlik");
        Assert.NotEmpty(geciken);
        Assert.DoesNotContain(geciken, k => k.Contains("gizli") || k.Contains("sir-gorev"));
        Assert.DoesNotContain(GizliKelime, plan.Govde.ToString() + bos.Govde);
        Assert.Equal(onceki, Dosyalar());
    }

    // Names, sizes of every file outside the search index (which the brain may refresh by itself).
    private string[] Dosyalar() => Directory.EnumerateFiles(_vault, "*", SearchOption.AllDirectories)
        .Where(f => !f.Contains(Path.DirectorySeparatorChar + ".beyin" + Path.DirectorySeparatorChar))
        .Select(f => $"{Path.GetRelativePath(_vault, f)}:{new FileInfo(f).Length}:{File.GetLastWriteTimeUtc(f).Ticks}")
        .Order().ToArray();
}
