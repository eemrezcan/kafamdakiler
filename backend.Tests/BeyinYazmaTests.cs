using System.Text.Json;
using Kafamdakiler.Beyin;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The write side of the brain with a fake beyin.py: input checks, the exact arguments (the date is always explicit, the
// plan item's id and free text go after `--`), the error table, the "may have been written" outcome, splitting a task
// over days, the capacity warning and the morning card.
public class BeyinYazmaTests : IDisposable
{
    private static readonly NullLogger Gunluk = NullLogger.Instance;

    private readonly SahteBeyin _beyin = new("ok");

    public void Dispose() => _beyin.Dispose();

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private BeyinIstemcisi Bagli(TimeSpan? zamanAsimi = null) => _beyin.Istemci(zamanAsimi);

    private static BeyinIstemcisi Kapali() => new(new BeyinAyari());

    private static Task<(int Durum, JsonElement Govde)> Cevap(YazmaYaniti yanit) => BeyinOkumaTests.Oku(yanit.Sonuc(), Ct);

    private string[][] Cagrilar() => _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).ToArray();

    // What `gun ekle`, `gun isaretle`... print (the real shapes were read off the real beyin.py, see GercekBeyinYazmaTests).
    private const string Madde = """{"no": 4, "id": "a3f09c", "baslik": "Yeni iş", "metin": "Yeni iş ~45dk", "bolum": "Yapılacaklar", "durum": "acik", "kaynak": "plan", "tahmin_dk": 45, "sure_dk": 0, "notlar": [], "gorev": null, "proje": null}""";

    private static string Eklendi(string tarih = "2026-11-03", string? oneri = null) =>
        $$"""{"tarih": "{{tarih}}", "madde": {{Madde}}, "tahmin_onerisi": {{oneri ?? "null"}}}""";

    private const string Gorevler = """
        [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "alan": "projects", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "gizli": false},
         {"kimlik": "gizli-gorev", "baslik": "Gizli", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/gizli-gorev.md", "gizli": true},
         {"kimlik": "dis-randevusu-al", "baslik": "Randevu", "durum": "aktif", "alan": "kisisel", "yol": "kisisel/gorevler/dis-randevusu-al.md", "gizli": false}]
        """;

    // Input checks come before the brain is asked: a bad request is a 400 even when the brain is off.

    [Theory]
    [InlineData("a3f09c")]
    [InlineData("0a1b2c")]
    [InlineData("ffffff")]
    [InlineData("g:uye-girisi")]
    [InlineData("  a3f09c  ")]
    public async Task Madde_PermanentId_IsAccepted(string madde)
    {
        _beyin.Cikti("""{"tarih": "2026-11-03", "madde": """ + Madde + ", \"gorev_kapandi\": false}");

        var (durum, _) = await Cevap(await BeyinYazma.MaddeIsaretle("2026-11-03", new(madde), Bagli(), Gunluk, Ct));

        Assert.Equal(200, durum);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("3")]
    [InlineData("123456")]
    [InlineData("a3f09")]
    [InlineData("a3f09c1")]
    [InlineData("A3F09C")]
    [InlineData("teklif")]
    [InlineData("teklif hazırla")]
    [InlineData("-x")]
    [InlineData("--geri")]
    [InlineData("../x")]
    [InlineData("a3f09c\nb")]
    [InlineData("g:")]
    [InlineData("g:Üye")]
    public async Task Madde_ListPositionOrTitleFragment_Is400_AndNeverReachesTheBrain(string? madde)
    {
        var kapali = Kapali();
        var sonuclar = new[]
        {
            await BeyinYazma.MaddeIsaretle("2026-11-03", new(madde), kapali, Gunluk, Ct),
            await BeyinYazma.MaddeDevret("2026-11-03", new(madde), kapali, Gunluk, Ct),
            await BeyinYazma.MaddeNotu("2026-11-03", new(madde, "bir not"), kapali, Gunluk, Ct),
        };

        foreach (var s in sonuclar)
        {
            var (durum, govde) = await Cevap(s);
            Assert.Equal(400, durum);
            Assert.True(govde.GetProperty("errors").TryGetProperty("madde", out _));
        }
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("bugun")]
    [InlineData("yarin")]
    [InlineData("2026-13-45")]
    [InlineData("2026-11-3")]
    [InlineData("03.11.2026")]
    [InlineData("2026-11-03T00:00")]
    public async Task Date_NotInTheFixedFormat_Is400_ForEveryPlanWrite(string? tarih)
    {
        var kapali = Kapali();
        var sonuclar = new[]
        {
            await BeyinYazma.MaddeEkle(tarih!, new("iş", null, null), kapali, Gunluk, Ct),
            await BeyinYazma.MaddeIsaretle(tarih!, new("a3f09c"), kapali, Gunluk, Ct),
            await BeyinYazma.MaddeDevret(tarih!, new("a3f09c"), kapali, Gunluk, Ct),
            await BeyinYazma.MaddeNotu(tarih!, new("a3f09c", "not"), kapali, Gunluk, Ct),
        };

        foreach (var s in sonuclar)
            Assert.Equal(400, (await Cevap(s)).Durum);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("   ")]
    [InlineData("a\nb")]
    [InlineData("a\tb")]
    [InlineData("a\u2028b")]
    public async Task ItemText_EmptyOrWithALineBreak_Is400(string? metin) =>
        Assert.Equal(400, (await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new(metin, null, null), Kapali(), Gunluk, Ct))).Durum);

    [Fact]
    public async Task ItemText_TooLong_Is400_AndTheLimitItselfPasses()
    {
        _beyin.Cikti(Eklendi());

        Assert.Equal(400, (await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new(new string('a', BeyinYazma.EnUzunMetin + 1), null, null), Bagli(), Gunluk, Ct))).Durum);
        Assert.Equal(200, (await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new(new string('a', BeyinYazma.EnUzunMetin), null, null), Bagli(), Gunluk, Ct))).Durum);
    }

    [Theory]
    [InlineData("Kapanış")]
    [InlineData("kapanış")]
    [InlineData("a\nb")]
    public async Task Section_ClosingOrBroken_Is400(string bolum) =>
        Assert.Equal(400, (await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new("iş", bolum, null), Kapali(), Gunluk, Ct))).Durum);

    [Fact]
    public async Task NoteText_TooLong_Is400() =>
        Assert.Equal(400, (await Cevap(await BeyinYazma.MaddeNotu("2026-11-03", new("a3f09c", new string('n', BeyinYazma.EnUzunNot + 1)), Kapali(), Gunluk, Ct))).Durum);

    [Fact]
    public async Task BrainOff_Is503_ForAValidWrite_AndNothingIsKept()
    {
        var yanit = await BeyinYazma.MaddeEkle("2026-11-03", new("iş", null, null), Kapali(), Gunluk, Ct);

        var (durum, govde) = await Cevap(yanit);

        Assert.Equal(503, durum);
        Assert.Equal("Beyin bağlı değil", govde.GetProperty("title").GetString());
        Assert.False(yanit.Hatirlanir);
    }

    // Arguments

    [Fact]
    public async Task MaddeEkle_DateIsExplicit_AndTheTextGoesAfterDashDash_EvenWhenItLooksLikeAnOption()
    {
        _beyin.Cikti(Eklendi(oneri: """{"oneri_dk": 60, "oneri": "1s", "ornekler": []}"""));

        var (durum, govde) = await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new("--gizli-dahil", "Okul", null), Bagli(), Gunluk, Ct));

        Assert.Equal(200, durum);
        Assert.Equal(["gun", "ekle", "--tarih=2026-11-03", "--bolum=Okul", "--json", "--vault", _beyin.Vault, "--", "--gizli-dahil"], Cagrilar().Single());
        Assert.Equal("2026-11-03", govde.GetProperty("tarih").GetString());
        Assert.Equal("a3f09c", govde.GetProperty("madde").GetProperty("id").GetString());
        Assert.Equal("Yapılacaklar", govde.GetProperty("madde").GetProperty("bolum").GetString());
        Assert.Equal(60, govde.GetProperty("onerilenTahminDk").GetInt32());
    }

    [Fact]
    public async Task MaddeEkle_ASectionThatStartsWithADash_IsOneArgument_NotAnOption()
    {
        _beyin.Cikti(Eklendi());

        await BeyinYazma.MaddeEkle("2026-11-03", new("iş", "--vault=/tmp", null), Bagli(), Gunluk, Ct);

        var arguman = Cagrilar().Single();
        Assert.Contains("--bolum=--vault=/tmp", arguman);
        Assert.DoesNotContain("--vault=/tmp", arguman);
        Assert.Equal(_beyin.Vault, arguman[Array.IndexOf(arguman, "--vault") + 1]);
    }

    [Fact]
    public async Task MaddeEkle_WithATask_LooksTheTaskUpFirst_ThenLinksIt()
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gun ekle", Eklendi());

        var (durum, _) = await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new("Üye girişi", null, "uye-girisi"), Bagli(), Gunluk, Ct));

        Assert.Equal(200, durum);
        var cagrilar = Cagrilar();
        Assert.Equal(2, cagrilar.Length);
        Assert.Equal(["gorev", "liste", "--json", "--vault", _beyin.Vault], cagrilar[0]);
        Assert.Equal(["gun", "ekle", "--tarih=2026-11-03", "--gorev=uye-girisi", "--json", "--vault", _beyin.Vault, "--", "Üye girişi"], cagrilar[1]);
    }

    [Theory]
    [InlineData("gizli-gorev")]
    [InlineData("dis-randevusu-al")]
    [InlineData("hic-yok")]
    public async Task MaddeEkle_ATaskTheApiMayNotSee_LooksLikeOneThatDoesNotExist_AndNothingIsWritten(string gorev)
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gun ekle", Eklendi());

        var (durum, govde) = await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new("iş", null, gorev), Bagli(), Gunluk, Ct));

        Assert.Equal(404, durum);
        Assert.DoesNotContain("Gizli", govde.ToString());
        Assert.DoesNotContain(Cagrilar(), c => c[0] == "gun");
    }

    [Fact]
    public async Task MaddeEkle_BadTaskId_Is400()
    {
        var (durum, govde) = await Cevap(await BeyinYazma.MaddeEkle("2026-11-03", new("iş", null, "../x.md"), Kapali(), Gunluk, Ct));

        Assert.Equal(400, durum);
        Assert.True(govde.GetProperty("errors").TryGetProperty("gorev", out _));
    }

    [Fact]
    public async Task Isaretle_SendsGeriOnlyWhenAsked_AndTheIdAfterDashDash()
    {
        _beyin.Cikti("""{"tarih": "2026-11-03", "madde": """ + Madde + ", \"gorev_kapandi\": true}");

        var ileri = await Cevap(await BeyinYazma.MaddeIsaretle("2026-11-03", new("a3f09c"), Bagli(), Gunluk, Ct));
        await BeyinYazma.MaddeIsaretle("2026-11-03", new("a3f09c", Geri: true), Bagli(), Gunluk, Ct);

        var cagrilar = Cagrilar();
        Assert.Equal(["gun", "isaretle", "--tarih=2026-11-03", "--json", "--vault", _beyin.Vault, "--", "a3f09c"], cagrilar[0]);
        Assert.Equal(["gun", "isaretle", "--tarih=2026-11-03", "--geri", "--json", "--vault", _beyin.Vault, "--", "a3f09c"], cagrilar[1]);
        Assert.True(ileri.Govde.GetProperty("gorevKapandi").GetBoolean());
    }

    [Fact]
    public async Task Devret_And_Not_SendTheDateAndTheIdAfterDashDash()
    {
        _beyin.Cikti("gun devret", """{"tarih": "2026-11-03", "devredilen_gun": "2026-11-04", "madde": """ + Madde + "}");
        _beyin.Cikti("gun not", """{"tarih": "2026-11-03", "madde": """ + Madde + "}");

        var devret = await Cevap(await BeyinYazma.MaddeDevret("2026-11-03", new("a3f09c"), Bagli(), Gunluk, Ct));
        var not = await Cevap(await BeyinYazma.MaddeNotu("2026-11-03", new("a3f09c", "-bir not"), Bagli(), Gunluk, Ct));

        var cagrilar = Cagrilar();
        Assert.Equal(["gun", "devret", "--tarih=2026-11-03", "--json", "--vault", _beyin.Vault, "--", "a3f09c"], cagrilar[0]);
        Assert.Equal(["gun", "not", "--tarih=2026-11-03", "--json", "--vault", _beyin.Vault, "--", "a3f09c", "-bir not"], cagrilar[1]);
        Assert.Equal("2026-11-04", devret.Govde.GetProperty("devredilenGun").GetString());
        Assert.Equal(200, not.Durum);
    }

    [Fact]
    public async Task EveryPlanWrite_CarriesTheDate_AndNeverGizliDahil()
    {
        _beyin.Cikti(Eklendi());

        await BeyinYazma.MaddeEkle("2026-11-03", new("iş", null, null), Bagli(), Gunluk, Ct);
        await BeyinYazma.MaddeIsaretle("2026-11-03", new("a3f09c"), Bagli(), Gunluk, Ct);
        await BeyinYazma.MaddeDevret("2026-11-03", new("a3f09c"), Bagli(), Gunluk, Ct);
        await BeyinYazma.MaddeNotu("2026-11-03", new("a3f09c", "n"), Bagli(), Gunluk, Ct);

        var cagrilar = Cagrilar();
        Assert.Equal(4, cagrilar.Length);
        foreach (var c in cagrilar)
        {
            Assert.Contains("--tarih=2026-11-03", c.TakeWhile(a => a != "--"));
            Assert.DoesNotContain(c, a => a.Contains("gizli", StringComparison.OrdinalIgnoreCase));
        }
    }

    // The error table: nothing was written in any of these, and the brain's own message does not reach the client.

    [Theory]
    [InlineData("gecersiz-arguman", "x", 400)]
    [InlineData("yasak-yol", "x", 400)]
    [InlineData("bulunamadi", "x", 404)]
    [InlineData("gizli", "x", 404)]
    [InlineData("gun-kapali", "x", 409)]
    [InlineData("hata", "madde bulunamadı: 'abc'", 404)]
    [InlineData("hata", "açık görev bulunamadı: x", 404)]
    [InlineData("hata", "yalnız açık madde devredilir: iş (yapildi)", 409)]
    [InlineData("hata", "", 409)]
    [InlineData("baska-bir-kod", "x", 502)]
    [InlineData("", "x", 502)]
    public void BrainRefusal_MapsToStatus(string kod, string mesaj, int beklenen)
    {
        var yanit = BeyinYazma.Esle(new BeyinSonucu(BeyinDurumu.BeyinHatasi, HataKodu: kod, Mesaj: mesaj), Gunluk);

        Assert.Equal(beklenen, yanit.Durum);
        Assert.Equal(YazmaTuru.Reddedildi, yanit.Tur);
        Assert.False(yanit.Hatirlanir);
    }

    [Fact]
    public async Task BrainRefusal_BecomesProblem_WithoutTheBrainsOwnMessage()
    {
        _beyin.Cikti("""{"hata": {"kod": "hata", "mesaj": "yalnız açık madde devredilir: /srv/gizli/yer/x.md"}}""", cikis: 1);

        var (durum, govde) = await Cevap(await BeyinYazma.MaddeDevret("2026-11-03", new("a3f09c"), Bagli(), Gunluk, Ct));

        Assert.Equal(409, durum);
        Assert.DoesNotContain("/srv", govde.ToString());
    }

    // "May have been written": the command did not finish or printed something we cannot read, so it is not a failure to retry.

    [Fact]
    public async Task Timeout_IsNot502Or503Or504_ItSaysTheWriteMayHaveHappened()
    {
        _beyin.Mod = "uyku";

        var yanit = await BeyinYazma.MaddeEkle("2026-11-03", new("iş", null, null), Bagli(TimeSpan.FromMilliseconds(400)), Gunluk, Ct);
        var (durum, govde) = await Cevap(yanit);

        Assert.Equal(YazmaTuru.Belirsiz, yanit.Tur);
        Assert.Equal(202, durum);
        Assert.True(govde.GetProperty("belirsiz").GetBoolean());
        Assert.True(govde.GetProperty("yazilmisOlabilir").GetBoolean());
        Assert.True(yanit.Hatirlanir);
    }

    [Fact]
    public async Task UnreadableOutput_IsTheSameOutcome()
    {
        _beyin.Mod = "bozuk";

        var yanit = await BeyinYazma.MaddeIsaretle("2026-11-03", new("a3f09c"), Bagli(), Gunluk, Ct);

        Assert.Equal(YazmaTuru.Belirsiz, yanit.Tur);
        Assert.Equal(202, (await Cevap(yanit)).Durum);
    }

    [Fact]
    public async Task ASuccessInAShapeWeDoNotKnow_IsTheSameOutcome_NotA502()
    {
        _beyin.Cikti("""{"bu": "beklenen sekil degil"}""");

        var yanit = await BeyinYazma.MaddeEkle("2026-11-03", new("iş", null, null), Bagli(), Gunluk, Ct);

        Assert.Equal(YazmaTuru.Belirsiz, yanit.Tur);
        Assert.Equal(202, yanit.Durum);
    }

    // Tasks

    [Fact]
    public async Task GorevEkle_SendsEveryValueAsOneArgument()
    {
        _beyin.Cikti("""{"yol": "projects/kitap-kulubu/gorevler/yeni.md", "kimlik": "yeni"}""");

        var (durum, govde) = await Cevap(await BeyinYazma.GorevEkle(
            new("-başlık", "kitap-kulubu", null, "2026-12-01", "--sonraki", "ölçüt"), Bagli(), Gunluk, Ct));

        Assert.Equal(200, durum);
        Assert.Equal(["gorev", "ekle", "--baslik=-başlık", "--proje=kitap-kulubu", "--bitis=2026-12-01", "--sonraki-adim=--sonraki", "--olcut=ölçüt", "--json", "--vault", _beyin.Vault], Cagrilar().Single());
        Assert.Equal("yeni", govde.GetProperty("kimlik").GetString());
        Assert.DoesNotContain("projects/", govde.ToString());
    }

    [Fact]
    public async Task GorevEkle_AnAreaTask_UsesAlan()
    {
        _beyin.Cikti("""{"yol": "ogrenme/gorevler/x.md", "kimlik": "x"}""");

        await BeyinYazma.GorevEkle(new("Oku", null, "ogrenme", null, null, null), Bagli(), Gunluk, Ct);

        Assert.Equal(["gorev", "ekle", "--baslik=Oku", "--alan=ogrenme", "--json", "--vault", _beyin.Vault], Cagrilar().Single());
    }

    [Theory]
    [InlineData(null, "p", null, null)]
    [InlineData("  ", "p", null, null)]
    [InlineData("b", null, null, null)]
    [InlineData("b", "p", "a", null)]
    [InlineData("b", "Büyük Harf", null, null)]
    [InlineData("b", null, "finans", null)]
    [InlineData("b", null, "kisisel", null)]
    [InlineData("b", null, "projects", null)]
    [InlineData("b", null, "sistem", null)]
    [InlineData("b", null, "../kisisel", null)]
    [InlineData("b", null, "a/b", null)]
    [InlineData("b", "p", null, "yarin")]
    [InlineData("b", "p", null, "2026-13-45")]
    public async Task GorevEkle_BadInput_Is400_BeforeTheBrain(string? baslik, string? proje, string? alan, string? bitis) =>
        Assert.Equal(400, (await Cevap(await BeyinYazma.GorevEkle(new(baslik, proje, alan, bitis, null, null), Kapali(), Gunluk, Ct))).Durum);

    [Theory]
    [InlineData("2026-11-07T01:59:00+00:00", "onay:uygulama-2026-11-06")]
    [InlineData("2026-11-07T02:00:00+00:00", "onay:uygulama-2026-11-07")]
    public async Task GorevBitir_TheProofIsTheUsersOwnDone_DatedByTheDayTurnRule(string an, string kanit)
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");

        var (durum, govde) = await Cevap(await BeyinYazma.GorevBitir("uye-girisi", Bagli(), Gunluk, new ElleSaat(DateTimeOffset.Parse(an)), Ct));

        Assert.Equal(200, durum);
        Assert.Equal(["gorev", "bitir", $"--kanit={kanit}", "--json", "--vault", _beyin.Vault, "--", "uye-girisi"], Cagrilar()[1]);
        Assert.False(govde.GetProperty("planMaddesiYapildi").GetBoolean());
    }

    [Theory]
    [InlineData("gizli-gorev")]
    [InlineData("dis-randevusu-al")]
    [InlineData("hic-yok")]
    public async Task GorevBitir_ATaskTheApiMayNotSee_Is404_AndIsNeverFinished(string kimlik)
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gorev bitir", """{"yol": "x", "kimlik": "x", "degisen": []}""");

        var (durum, _) = await Cevap(await BeyinYazma.GorevBitir(kimlik, Bagli(), Gunluk, TimeProvider.System, Ct));

        Assert.Equal(404, durum);
        Assert.DoesNotContain(Cagrilar(), c => c[1] == "bitir");
    }

    // Splitting a task over days

    private static string Gorunum(string tarih, string id, string metin) =>
        $$"""{"tarih": "{{tarih}}", "madde": {"id": "{{id}}", "baslik": "{{metin}}", "bolum": "Yapılacaklar", "durum": "acik", "gorev": "uye-girisi"}, "tahmin_onerisi": null}""";

    [Fact]
    public async Task GunlereBol_WritesOneLinkedItemPerDay_InOrder_FromTheDayTurnToday()
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Sirali("gun ekle",
            (Gorunum("2026-11-06", "aaaaa1", "Üye girişi (1/3)"), 0),
            (Gorunum("2026-11-07", "aaaaa2", "Üye girişi (2/3)"), 0),
            (Gorunum("2026-11-08", "aaaaa3", "Üye girişi (3/3)"), 0));
        // 04:59 in Istanbul on the 7th: the plan's today is still the 6th.
        var saat = new ElleSaat(new DateTimeOffset(2026, 11, 7, 4, 59, 0, TimeSpan.FromHours(3)));

        var (durum, govde) = await Cevap(await BeyinYazma.GunlereBol("uye-girisi", new(3, null, null, null), Bagli(), Gunluk, saat, Ct));

        Assert.Equal(200, durum);
        Assert.True(govde.GetProperty("tamamlandi").GetBoolean());
        Assert.Equal(["2026-11-06", "2026-11-07", "2026-11-08"], govde.GetProperty("yazilanlar").EnumerateArray().Select(g => g.GetProperty("tarih").GetString()).ToArray());
        var ekler = Cagrilar().Where(c => c[1] == "ekle").ToArray();
        Assert.Equal(3, ekler.Length);
        Assert.Equal(["gun", "ekle", "--tarih=2026-11-06", "--gorev=uye-girisi", "--json", "--vault", _beyin.Vault, "--", "Üye girişi (1/3)"], ekler[0]);
        Assert.Equal("--tarih=2026-11-08", ekler[2][2]);
        Assert.Equal("Üye girişi (3/3)", ekler[2][^1]);
    }

    [Fact]
    public async Task GunlereBol_OneDay_KeepsTheTitleAsIs_AndAGivenStartDayWins()
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gun ekle", Gorunum("2026-12-01", "aaaaa1", "Üye girişi"));

        var (durum, _) = await Cevap(await BeyinYazma.GunlereBol("uye-girisi", new(1, "2026-12-01", null, "Okul"), Bagli(), Gunluk, TimeProvider.System, Ct));

        Assert.Equal(200, durum);
        var ekle = Cagrilar().Single(c => c[1] == "ekle");
        Assert.Equal(["gun", "ekle", "--tarih=2026-12-01", "--bolum=Okul", "--gorev=uye-girisi", "--json", "--vault", _beyin.Vault, "--", "Üye girişi"], ekle);
    }

    [Fact]
    public async Task GunlereBol_ARefusalOnDayTwo_StopsThere_AndTheAnswerSaysWhichDaysWereWritten()
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Sirali("gun ekle",
            (Gorunum("2026-11-10", "aaaaa1", "Üye girişi (1/4)"), 0),
            ("""{"hata": {"kod": "gun-kapali", "mesaj": "2026-11-11 günü kapandı"}}""", 1));

        var yanit = await BeyinYazma.GunlereBol("uye-girisi", new(4, "2026-11-10", null, null), Bagli(), Gunluk, TimeProvider.System, Ct);
        var (durum, govde) = await Cevap(yanit);

        Assert.Equal(YazmaTuru.Kismi, yanit.Tur);
        Assert.True(yanit.Hatirlanir);
        Assert.Equal(207, durum);
        Assert.False(govde.GetProperty("tamamlandi").GetBoolean());
        Assert.Equal(["2026-11-10"], govde.GetProperty("yazilanlar").EnumerateArray().Select(g => g.GetProperty("tarih").GetString()).ToArray());
        var hata = govde.GetProperty("hata");
        Assert.Equal("2026-11-11", hata.GetProperty("tarih").GetString());
        Assert.Equal(409, hata.GetProperty("durum").GetInt32());
        Assert.False(hata.GetProperty("yazilmisOlabilir").GetBoolean());
        // Days three and four were not tried.
        Assert.Equal(2, Cagrilar().Count(c => c[1] == "ekle"));
    }

    [Fact]
    public async Task GunlereBol_AnUncertainDayTwo_IsMarkedMayHaveBeenWritten()
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Sirali("gun ekle", (Gorunum("2026-11-10", "aaaaa1", "Üye girişi (1/3)"), 0), ("???", 0));

        var (durum, govde) = await Cevap(await BeyinYazma.GunlereBol("uye-girisi", new(3, "2026-11-10", null, null), Bagli(), Gunluk, TimeProvider.System, Ct));

        Assert.Equal(207, durum);
        Assert.True(govde.GetProperty("hata").GetProperty("yazilmisOlabilir").GetBoolean());
        Assert.Single(govde.GetProperty("yazilanlar").EnumerateArray());
    }

    [Fact]
    public async Task GunlereBol_ARefusalOnTheFirstDay_IsAPlainRefusal_NothingWasWritten()
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gun ekle", """{"hata": {"kod": "gun-kapali", "mesaj": "kapandı"}}""", cikis: 1);

        var yanit = await BeyinYazma.GunlereBol("uye-girisi", new(3, "2026-11-10", null, null), Bagli(), Gunluk, TimeProvider.System, Ct);

        Assert.Equal(409, yanit.Durum);
        Assert.False(yanit.Hatirlanir);
        Assert.Single(Cagrilar(), c => c[1] == "ekle");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(BeyinYazma.EnCokBolmeGunu + 1)]
    public async Task GunlereBol_DayCountOutOfRange_Is400(int gunSayisi) =>
        Assert.Equal(400, (await Cevap(await BeyinYazma.GunlereBol("uye-girisi", new(gunSayisi, null, null, null), Kapali(), Gunluk, TimeProvider.System, Ct))).Durum);

    [Fact]
    public async Task GunlereBol_ATaskTheApiMayNotSee_Is404_AndNothingIsWritten()
    {
        _beyin.Cikti("gorev liste", Gorevler);
        _beyin.Cikti("gun ekle", Eklendi());

        var (durum, _) = await Cevap(await BeyinYazma.GunlereBol("gizli-gorev", new(2, "2026-11-10", null, null), Bagli(), Gunluk, TimeProvider.System, Ct));

        Assert.Equal(404, durum);
        Assert.DoesNotContain(Cagrilar(), c => c[1] == "ekle");
    }

    // "Bugün sığmıyor": the open items' estimates against the day's capacity.

    private static string GunVerisi(params (string Id, string Durum, int? Tahmin, bool Gizli)[] maddeler)
    {
        var satirlar = maddeler.Select(m => JsonSerializer.Serialize(new Dictionary<string, object?>
        {
            ["id"] = m.Id, ["baslik"] = "iş " + m.Id, ["durum"] = m.Durum, ["tahmin_dk"] = m.Tahmin, ["gizli"] = m.Gizli,
        }));
        return $$"""{"tarih": "2026-11-03", "plan_var": true, "kapandi": false, "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{{string.Join(",", satirlar)}}]}], "geciken": []}""";
    }

    private async Task<JsonElement> GunOku(string json, GunAyari? ayar = null)
    {
        _beyin.Cikti(json);
        var (durum, govde) = await BeyinOkumaTests.Oku((await BeyinOkuma.GunAl("2026-11-03", Bagli(), Gunluk, Ct, ayar)).Sonuc(), Ct);
        Assert.Equal(200, durum);
        return govde;
    }

    [Fact]
    public async Task Capacity_OpenEstimatesOverTheLimit_GiveAWarning()
    {
        var gun = await GunOku(GunVerisi(("a", "acik", 240, false), ("b", "acik", 150, false)));

        var uyari = gun.GetProperty("kapasiteUyarisi");
        Assert.Equal(390, uyari.GetProperty("acikTahminDk").GetInt32());
        Assert.Equal(360, uyari.GetProperty("kapasiteDk").GetInt32());
        Assert.Equal(30, uyari.GetProperty("asimDk").GetInt32());
    }

    [Fact]
    public async Task Capacity_ExactlyTheLimit_IsNotAWarning()
    {
        var gun = await GunOku(GunVerisi(("a", "acik", 200, false), ("b", "acik", 160, false)));

        Assert.Equal(JsonValueKind.Null, gun.GetProperty("kapasiteUyarisi").ValueKind);
    }

    [Fact]
    public async Task Capacity_OnlyOpenItemsCount_NotDoneOnesNorHiddenOnes_AndNoEstimateIsZero()
    {
        var gun = await GunOku(GunVerisi(
            ("a", "acik", 200, false), ("b", "yapildi", 500, false), ("c", "iptal", 500, false),
            ("d", "devredildi", 500, false), ("e", "acik", 500, true), ("f", "acik", null, false)));

        Assert.Equal(JsonValueKind.Null, gun.GetProperty("kapasiteUyarisi").ValueKind);
    }

    [Fact]
    public async Task Capacity_FollowsTheSetting()
    {
        var gun = await GunOku(GunVerisi(("a", "acik", 130, false)), new GunAyari { KapasiteSaat = 2 });

        Assert.Equal(10, gun.GetProperty("kapasiteUyarisi").GetProperty("asimDk").GetInt32());
        Assert.Equal(120, gun.GetProperty("kapasiteUyarisi").GetProperty("kapasiteDk").GetInt32());
    }

    // The morning card

    [Theory]
    // 04:59 on the 7th is still the 6th, so "yesterday" is the 5th; at 05:00 it is the 6th.
    [InlineData("2026-11-07T04:59:00+03:00", "2026-11-05", "2026-11-06")]
    [InlineData("2026-11-07T05:00:00+03:00", "2026-11-06", "2026-11-07")]
    public async Task Sabah_AsksForYesterdayByTheDayTurnRule(string an, string dun, string bugun)
    {
        _beyin.Cikti(GunVerisi(("a3f09c", "acik", 60, false)));

        var (durum, govde) = await BeyinOkumaTests.Oku((await BeyinOkuma.SabahAl(Bagli(), Gunluk, new ElleSaat(DateTimeOffset.Parse(an)), Ct)).Sonuc(), Ct);

        Assert.Equal(200, durum);
        Assert.Equal(["gun", "goster", $"--tarih={dun}", "--json", "--vault", _beyin.Vault], Cagrilar().Single());
        Assert.Equal(dun, govde.GetProperty("dun").GetString());
        Assert.Equal(bugun, govde.GetProperty("bugun").GetString());
    }

    [Fact]
    public async Task Sabah_HasOnlyTheOpenItems_WithTheirSection_NotTheHiddenOnes()
    {
        _beyin.Cikti(GunVerisi(("a3f09c", "acik", 60, false), ("b3f09c", "yapildi", 30, false), ("c3f09c", "devredildi", 30, false), ("d3f09c", "acik", 30, true)));

        var (_, govde) = await BeyinOkumaTests.Oku((await BeyinOkuma.SabahAl(Bagli(), Gunluk, new ElleSaat(DateTimeOffset.UtcNow), Ct)).Sonuc(), Ct);

        var maddeler = govde.GetProperty("maddeler").EnumerateArray().ToArray();
        Assert.Equal(["a3f09c"], maddeler.Select(m => m.GetProperty("id").GetString()).ToArray());
        Assert.Equal("Yapılacaklar", maddeler[0].GetProperty("bolum").GetString());
        Assert.Equal(60, maddeler[0].GetProperty("tahminDk").GetInt32());
    }

    [Fact]
    public async Task Sabah_BrainOff_Is503()
    {
        var (durum, _) = await BeyinOkumaTests.Oku((await BeyinOkuma.SabahAl(Kapali(), Gunluk, TimeProvider.System, Ct)).Sonuc(), Ct);

        Assert.Equal(503, durum);
    }
}
