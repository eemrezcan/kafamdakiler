using System.Text.Json;
using Kafamdakiler.Beyin;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The write side against the real beyin.py and a throwaway copy of ornek-beyin/ (the template is never written to).
// Skipped when beyin.py is not on this machine (see TestAyari.GercekBeyin). What the fake brain answers is only as good as
// what these tests read off the real one: the shapes, the id format, "tick closes the linked task", the proof the brain accepts.
public sealed class GercekBeyinYazmaTests : IDisposable
{
    private static readonly NullLogger Gunluk = NullLogger.Instance;

    private readonly string _vault = Path.Combine(Path.GetTempPath(), "kd-yazma-" + Guid.NewGuid().ToString("N"));

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
        return new BeyinIstemcisi(ayar);
    }

    private void Yaz(string yol, string icerik)
    {
        var tam = Path.Combine(_vault, yol);
        Directory.CreateDirectory(Path.GetDirectoryName(tam)!);
        File.WriteAllText(tam, icerik);
    }

    private static async Task<(int Durum, JsonElement Govde)> Oku(YazmaYaniti yanit) =>
        await BeyinOkumaTests.Oku(yanit.Sonuc(), Ct);

    private static async Task<JsonElement> Gun(BeyinIstemcisi beyin, string tarih)
    {
        var (durum, govde) = await BeyinOkumaTests.Oku(await BeyinOkuma.Gun(tarih, beyin, Gunluk, Ct), Ct);
        Assert.Equal(200, durum);
        return govde;
    }

    private static JsonElement[] Maddeler(JsonElement gun) =>
        gun.GetProperty("bolumler").EnumerateArray().SelectMany(b => b.GetProperty("maddeler").EnumerateArray()).ToArray();

    private static JsonElement Madde(JsonElement gun, string id) =>
        Maddeler(gun).Single(m => m.GetProperty("id").GetString() == id);

    // The raw `gun goster`: the notes and the link to a task are not in the API's DTO.
    private static async Task<JsonElement> HamGun(BeyinIstemcisi beyin, string tarih)
    {
        var sonuc = await beyin.CalistirAsync(["gun", "goster", $"--tarih={tarih}"], Ct);
        Assert.True(sonuc.Basarili, sonuc.Mesaj);
        return sonuc.Veri!.Value;
    }

    private static async Task<JsonElement> Gorev(BeyinIstemcisi beyin, string kimlik)
    {
        var sonuc = await beyin.CalistirAsync(["gorev", "liste", "--durum=hepsi"], Ct);
        Assert.True(sonuc.Basarili, sonuc.Mesaj);
        return sonuc.Veri!.Value.EnumerateArray().Single(g => g.GetProperty("kimlik").GetString() == kimlik);
    }

    private static async Task<string> GorevOlustur(BeyinIstemcisi beyin, string baslik)
    {
        var (durum, govde) = await Oku(await BeyinYazma.GorevEkle(new(baslik, "kitap-kulubu", null, null, null, null), beyin, Gunluk, Ct));
        Assert.Equal(200, durum);
        return govde.GetProperty("kimlik").GetString()!;
    }

    [Fact]
    public async Task AddTickCarryOverAndNote_OnTheRealBrain()
    {
        var beyin = Hazirla();

        var ekle = await Oku(await BeyinYazma.MaddeEkle("2026-12-01", new("Gerçek komut denemesi ~30dk", "Okul", null), beyin, Gunluk, Ct));
        Assert.Equal(200, ekle.Durum);
        var id = ekle.Govde.GetProperty("madde").GetProperty("id").GetString()!;
        Assert.Matches("^[0-9a-f]{6}$", id);
        Assert.Equal("Okul", ekle.Govde.GetProperty("madde").GetProperty("bolum").GetString());
        Assert.Equal(30, ekle.Govde.GetProperty("madde").GetProperty("tahminDk").GetInt32());
        Assert.Equal("acik", Madde(await Gun(beyin, "2026-12-01"), id).GetProperty("durum").GetString());

        var tik = await Oku(await BeyinYazma.MaddeIsaretle("2026-12-01", new(id), beyin, Gunluk, Ct));
        Assert.Equal(200, tik.Durum);
        Assert.Equal("yapildi", Madde(await Gun(beyin, "2026-12-01"), id).GetProperty("durum").GetString());

        var geri = await Oku(await BeyinYazma.MaddeIsaretle("2026-12-01", new(id, Geri: true), beyin, Gunluk, Ct));
        Assert.Equal(200, geri.Durum);
        Assert.Equal("acik", Madde(await Gun(beyin, "2026-12-01"), id).GetProperty("durum").GetString());

        var not = await Oku(await BeyinYazma.MaddeNotu("2026-12-01", new(id, "-ilk not, \"tırnaklı\" ve ğüşiöç"), beyin, Gunluk, Ct));
        Assert.Equal(200, not.Durum);
        var notlar = Maddeler(await HamGun(beyin, "2026-12-01")).Single(m => m.GetProperty("id").GetString() == id).GetProperty("notlar");
        Assert.Contains("-ilk not, \"tırnaklı\" ve ğüşiöç", notlar.EnumerateArray().Select(n => n.GetString()));

        var devret = await Oku(await BeyinYazma.MaddeDevret("2026-12-01", new(id), beyin, Gunluk, Ct));
        Assert.Equal(200, devret.Durum);
        Assert.Equal("2026-12-02", devret.Govde.GetProperty("devredilenGun").GetString());
        Assert.Equal("devredildi", Madde(await Gun(beyin, "2026-12-01"), id).GetProperty("durum").GetString());
        // The carried item lives on the next day with a new id.
        var yarin = Maddeler(await Gun(beyin, "2026-12-02")).Where(m => m.GetProperty("baslik").GetString()!.StartsWith("Gerçek komut denemesi")).ToArray();
        var yeni = Assert.Single(yarin);
        Assert.NotEqual(id, yeni.GetProperty("id").GetString());
        Assert.Equal("acik", yeni.GetProperty("durum").GetString());
    }

    [Fact]
    public async Task APositionOrATitleFragment_NeverMarksAnything_ItIsRefusedBeforeTheBrain()
    {
        var beyin = Hazirla();
        var once = await Gun(beyin, "2026-11-03");

        foreach (var madde in new[] { "1", "2", "kitap", "Takvim" })
            Assert.Equal(400, (await Oku(await BeyinYazma.MaddeIsaretle("2026-11-03", new(madde), beyin, Gunluk, Ct))).Durum);

        Assert.Equal(once.ToString(), (await Gun(beyin, "2026-11-03")).ToString());
    }

    [Fact]
    public async Task ATickOnAnUnknownIdOrADayWithoutAPlan_IsARefusal_NotAServerError()
    {
        var beyin = Hazirla();

        var yokId = await Oku(await BeyinYazma.MaddeIsaretle("2026-11-03", new("ffffff"), beyin, Gunluk, Ct));
        var yokGun = await Oku(await BeyinYazma.MaddeIsaretle("2027-03-03", new("ffffff"), beyin, Gunluk, Ct));
        var yokDevret = await Oku(await BeyinYazma.MaddeDevret("2027-03-04", new("ffffff"), beyin, Gunluk, Ct));

        Assert.Contains(yokId.Durum, new[] { 404, 409 });
        Assert.Contains(yokGun.Durum, new[] { 404, 409 });
        Assert.Contains(yokDevret.Durum, new[] { 404, 409 });
        Assert.True(yokId.Durum < 500 && yokGun.Durum < 500 && yokDevret.Durum < 500);
    }

    [Fact]
    public async Task AClosedDay_IsRefused_With409()
    {
        var beyin = Hazirla();
        Yaz("kisisel/plan-2026-12-05.md", "---\nbaslik: 5 Aralık 2026 günlük planı\ntur: not\ntags: [görev]\n---\n\n# 5 Aralık 2026 Cumartesi planı\n\n## Yapılacaklar\n- [ ] Kalan iş ^abcdef\n\n## Kapanış\n- kapandı: 2026-12-06T09:00\n");

        var ekle = await Oku(await BeyinYazma.MaddeEkle("2026-12-05", new("Geç kalan iş", null, null), beyin, Gunluk, Ct));
        var tik = await Oku(await BeyinYazma.MaddeIsaretle("2026-12-05", new("abcdef"), beyin, Gunluk, Ct));

        Assert.Equal(409, ekle.Durum);
        Assert.Equal(409, tik.Durum);
        Assert.Equal("Gün kapandı", ekle.Govde.GetProperty("title").GetString());
        Assert.DoesNotContain("Geç kalan iş", File.ReadAllText(Path.Combine(_vault, "kisisel/plan-2026-12-05.md")));
    }

    [Fact]
    public async Task ProjectTask_AddThenFinish_TheAppsOwnProofIsAccepted()
    {
        var beyin = Hazirla();
        var kimlik = await GorevOlustur(beyin, "Gerçek komut deneme görevi");
        Assert.Equal("aktif", (await Gorev(beyin, kimlik)).GetProperty("durum").GetString());

        // The proof is `onay:uygulama-<date>`: the project task is refused without proof, and the brain checks its shape.
        var bitir = await Oku(await BeyinYazma.GorevBitir(kimlik, beyin, Gunluk, new ElleSaat(new DateTimeOffset(2026, 12, 1, 12, 0, 0, TimeSpan.Zero)), Ct));

        Assert.Equal(200, bitir.Durum);
        Assert.Equal(kimlik, bitir.Govde.GetProperty("kimlik").GetString());
        var gorev = await Gorev(beyin, kimlik);
        Assert.Equal("bitti", gorev.GetProperty("durum").GetString());
        Assert.Contains("onay:uygulama-2026-12-01", gorev.GetProperty("kanit").EnumerateArray().Select(k => k.GetString()));
    }

    [Fact]
    public async Task FinishingTwice_IsARefusal_NotAServerError()
    {
        var beyin = Hazirla();
        var kimlik = await GorevOlustur(beyin, "İki kez bitirilen görev");
        var saat = new ElleSaat(new DateTimeOffset(2026, 12, 1, 12, 0, 0, TimeSpan.Zero));
        await BeyinYazma.GorevBitir(kimlik, beyin, Gunluk, saat, Ct);

        // The list the API looks the task up in shows open tasks only, so a finished one is simply "not found".
        var ikinci = await Oku(await BeyinYazma.GorevBitir(kimlik, beyin, Gunluk, saat, Ct));

        Assert.Equal(404, ikinci.Durum);
    }

    [Fact]
    public async Task ATickOnAnItemLinkedToATask_ClosesTheTaskToo_TheBrainsOwnRule()
    {
        var beyin = Hazirla();
        var kimlik = await GorevOlustur(beyin, "Bağlı madde görevi");

        var ekle = await Oku(await BeyinYazma.MaddeEkle("2026-12-03", new("Bağlı madde", null, kimlik), beyin, Gunluk, Ct));
        Assert.Equal(200, ekle.Durum);
        Assert.Equal(kimlik, ekle.Govde.GetProperty("madde").GetProperty("gorev").GetString());
        var id = ekle.Govde.GetProperty("madde").GetProperty("id").GetString()!;

        var tik = await Oku(await BeyinYazma.MaddeIsaretle("2026-12-03", new(id), beyin, Gunluk, Ct));

        Assert.Equal(200, tik.Durum);
        Assert.True(tik.Govde.GetProperty("gorevKapandi").GetBoolean());
        Assert.Equal("bitti", (await Gorev(beyin, kimlik)).GetProperty("durum").GetString());
    }

    [Fact]
    public async Task SplitATask_ThreeDaysThreeLinkedItems_AndTheFirstTickClosesTheWholeTask()
    {
        var beyin = Hazirla();
        var kimlik = await GorevOlustur(beyin, "Üç güne bölünen görev");

        var bol = await Oku(await BeyinYazma.GunlereBol(kimlik, new(3, "2026-12-10", null, null), beyin, Gunluk, TimeProvider.System, Ct));

        Assert.Equal(200, bol.Durum);
        Assert.True(bol.Govde.GetProperty("tamamlandi").GetBoolean());
        var yazilan = bol.Govde.GetProperty("yazilanlar").EnumerateArray().ToArray();
        Assert.Equal(["2026-12-10", "2026-12-11", "2026-12-12"], yazilan.Select(g => g.GetProperty("tarih").GetString()).ToArray());
        foreach (var gun in yazilan)
        {
            var id = gun.GetProperty("madde").GetProperty("id").GetString()!;
            var gunVerisi = await Gun(beyin, gun.GetProperty("tarih").GetString()!);
            Assert.Equal(kimlik, Madde(gunVerisi, id).GetProperty("gorev").GetString());
        }

        // Measured on the real brain, and what the screens must know: one tick finishes the task for all the days.
        var ilkId = yazilan[0].GetProperty("madde").GetProperty("id").GetString()!;
        var tik = await Oku(await BeyinYazma.MaddeIsaretle("2026-12-10", new(ilkId), beyin, Gunluk, Ct));
        Assert.True(tik.Govde.GetProperty("gorevKapandi").GetBoolean());
        Assert.Equal("bitti", (await Gorev(beyin, kimlik)).GetProperty("durum").GetString());
    }

    [Fact]
    public async Task SplitOverAClosedDay_StopsThere_AndTheAnswerSaysWhatWasWritten()
    {
        var beyin = Hazirla();
        Yaz("kisisel/plan-2026-12-21.md", "---\nbaslik: 21 Aralık 2026 günlük planı\ntur: not\ntags: [görev]\n---\n\n# 21 Aralık 2026 Pazartesi planı\n\n## Yapılacaklar\n- [ ] Kalan iş ^abcdef\n\n## Kapanış\n- kapandı: 2026-12-22T09:00\n");
        var kimlik = await GorevOlustur(beyin, "Yarıda kalan bölme");

        var bol = await Oku(await BeyinYazma.GunlereBol(kimlik, new(4, "2026-12-20", null, null), beyin, Gunluk, TimeProvider.System, Ct));

        Assert.Equal(207, bol.Durum);
        Assert.False(bol.Govde.GetProperty("tamamlandi").GetBoolean());
        Assert.Equal(["2026-12-20"], bol.Govde.GetProperty("yazilanlar").EnumerateArray().Select(g => g.GetProperty("tarih").GetString()).ToArray());
        Assert.Equal("2026-12-21", bol.Govde.GetProperty("hata").GetProperty("tarih").GetString());
        Assert.Equal(409, bol.Govde.GetProperty("hata").GetProperty("durum").GetInt32());
        // The first day is really in the plan, the days after the stop are not.
        Assert.Contains(Maddeler(await Gun(beyin, "2026-12-20")), m => m.GetProperty("baslik").GetString()!.StartsWith("Yarıda kalan bölme"));
        Assert.False((await HamGun(beyin, "2026-12-22")).GetProperty("plan_var").GetBoolean());
    }

    [Fact]
    public async Task HiddenAndClosedFolderTasks_LookLikeTheyDoNotExist_AndAreNeverTouched()
    {
        var beyin = Hazirla();
        Yaz("projects/kitap-kulubu/gorevler/gizli-gorev.md", "---\nbaslik: Gizli görev zebraluk\ntur: gorev\nproje: kitap-kulubu\ndurum: aktif\ntags: []\nkanit: []\ngizli: true\n---\n\n# Gizli görev\n");
        var onceki = File.ReadAllText(Path.Combine(_vault, "projects/kitap-kulubu/gorevler/gizli-gorev.md"));

        foreach (var kimlik in new[] { "gizli-gorev", "dis-randevusu-al", "hic-yok" })
        {
            var bitir = await Oku(await BeyinYazma.GorevBitir(kimlik, beyin, Gunluk, TimeProvider.System, Ct));
            var madde = await Oku(await BeyinYazma.MaddeEkle("2026-12-04", new("bağlanmak isteyen", null, kimlik), beyin, Gunluk, Ct));
            var bol = await Oku(await BeyinYazma.GunlereBol(kimlik, new(2, "2026-12-04", null, null), beyin, Gunluk, TimeProvider.System, Ct));

            Assert.Equal([404, 404, 404], [bitir.Durum, madde.Durum, bol.Durum]);
            Assert.DoesNotContain("zebraluk", bitir.Govde + madde.Govde.ToString() + bol.Govde);
        }

        Assert.Equal(onceki, File.ReadAllText(Path.Combine(_vault, "projects/kitap-kulubu/gorevler/gizli-gorev.md")));
        Assert.False(File.Exists(Path.Combine(_vault, "kisisel/plan-2026-12-04.md")));
    }

    [Fact]
    public async Task AnAreaTask_AndTheClosedAreas()
    {
        var beyin = Hazirla();

        var ogrenme = await Oku(await BeyinYazma.GorevEkle(new("Alan görevi", null, "ogrenme", null, null, null), beyin, Gunluk, Ct));
        var finans = await Oku(await BeyinYazma.GorevEkle(new("Para görevi", null, "finans", null, null, null), beyin, Gunluk, Ct));

        Assert.Equal(200, ogrenme.Durum);
        Assert.Equal(400, finans.Durum);
        Assert.False(File.Exists(Path.Combine(_vault, "finans/gorevler/para-gorevi.md")));
    }
}
