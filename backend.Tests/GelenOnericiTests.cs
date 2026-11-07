using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Claude;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The inbox suggestions end to end, minus the real programs: real PostgreSQL, a real child process each for the fake
// beyin.py and the fake claude. The part that must not pass silently is what does NOT happen: a hidden card going to
// Claude, a closed path being queued, an outside text being applied by itself, a day's cap being passed.
public class GelenOnericiTests : IAsyncLifetime
{
    private const string Kart1 = "2026-11-03-1840-kitap-onerisi";
    private const string Kart2 = "2026-11-03-0915-takvim-renkleri";
    private const string Kart3 = "2026-11-04-1000-sulama";

    private const string Sozluk = """
        # Etiketler

        ## projects
        - yazılım: kod, program
        ## ogrenme
        - okul: üniversite, sınav
        - kaynak: kitap
        - özet: çıkarım
        - kitap-kulübü: kulüp
        """;

    private const string Projeler = """
        [{"kimlik": "kitap-kulubu", "yol": "projects/kitap-kulubu/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false},
         {"kimlik": "balkon-bahcesi", "yol": "projects/balkon-bahcesi/index.md", "baslik": "Balkon Bahçesi", "gizli": false}]
        """;

    private static readonly DateTimeOffset Baslangic = new(2026, 11, 7, 12, 0, 0, TimeSpan.Zero);

    private readonly TestVeritabani _vt = new();
    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahteClaude _claude = new();
    private readonly ElleSaat _saat = new(Baslangic);

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public async ValueTask DisposeAsync()
    {
        await _vt.DisposeAsync();
        _beyin.Dispose();
        _claude.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    // The fake brain: which cards are in the list, what each one says, the projects and the dictionary.
    private void BeyniKur(params (string Id, string Metin, string? Hedef, bool Gorsel)[] kartlar)
    {
        var liste = kartlar.Select(k => JsonSerializer.Serialize(new
        {
            yol = $"gelen/{k.Id}.md", baslik = k.Metin.Split('\n')[0], yakalandi = "2026-11-03T18:40", hedef = k.Hedef,
            gorsel = k.Gorsel ? $"gelen/ekler/{k.Id}.jpg" : null,
        }));
        _beyin.Cikti("gelen liste", "[" + string.Join(",", liste) + "]");
        _beyin.Cikti("proje liste", Projeler);
        _beyin.CiktiKonumsal("not oku", "etiketler.md", NotJson("etiketler.md", Sozluk));
        foreach (var k in kartlar)
            _beyin.CiktiKonumsal("not oku", $"gelen/{k.Id}.md", NotJson($"gelen/{k.Id}.md", k.Gorsel ? $"{k.Metin}\n\n![](ekler/{k.Id}.jpg)\n" : k.Metin + "\n"));
    }

    private void BeyniKur(string metin = "Ayşe \"Simyacı\"yı önerdi, kulübün aralık listesine eklenebilir.") =>
        BeyniKur((Kart1, metin, null, false));

    private static string NotJson(string yol, string govde, bool gizli = false) => JsonSerializer.Serialize(new
    {
        yol, baslik = "x", ustbilgi = new Dictionary<string, object> { ["tur"] = "gelen", ["gizli"] = gizli }, govde, ustbilgi_hatalari = Array.Empty<string>(),
    });

    private void ClaudeCevabi(
        string yol = "projects/kitap-kulubu/notlar/simyaci-onerisi.md", string baslik = "Simyacı önerisi",
        string[]? etiketler = null, double guven = 0.9, bool yeni = false) =>
        _claude.YapiliYanit(JsonSerializer.Serialize(new
        {
            yol, baslik, etiketler = etiketler ?? ["kaynak", "okul", "özet"], gerekce = "Kitap önerisi.", guven, yeniEtiketGerekir = yeni,
        }));

    private sealed record Takim(GelenOnerici Onerici, EylemServisi Eylemler, ClaudeIstemcisi Claude);

    private Takim Kur(int gunluk = 50, bool claudeBagli = true, GelenAyari? ayar = null)
    {
        var beyin = _beyin.Istemci();
        var claude = claudeBagli
            ? _claude.Istemci(gunluk: gunluk, saat: _saat)
            : new ClaudeIstemcisi(new ClaudeAyari(), _saat, NullLogger<ClaudeIstemcisi>.Instance);
        var turler = new EylemTurleri([new YerlestirTuru(beyin, NullLogger<YerlestirTuru>.Instance)]);
        var eylemler = new EylemServisi(_vt.Db, turler, _saat, NullLogger<EylemServisi>.Instance);
        var onerici = new GelenOnerici(_vt.Db, beyin, claude, eylemler, ayar ?? new GelenAyari(), _saat, NullLogger<GelenOnerici>.Instance);
        return new Takim(onerici, eylemler, claude);
    }

    private IEnumerable<string[]> BeyinCagrilari() => _beyin.Cagrilar().Select(SahteBeyin.Argumanlar);

    private int IsleCagrisi() => BeyinCagrilari().Count(a => a[0] == "gelen" && a[1] == "isle");

    private async Task<List<Eylem>> EylemleriAlAsync()
    {
        await using var db = _vt.YeniDb();
        return await db.Eylemler.AsNoTracking().Where(e => e.Tur == "yerlestir").OrderBy(e => e.CreatedAt).ToListAsync(Ct);
    }

    private async Task<GelenKartDurumu?> SatirAsync(string kart)
    {
        await using var db = _vt.YeniDb();
        return await db.GelenKartlari.AsNoTracking().SingleOrDefaultAsync(r => r.Kart == kart, Ct);
    }

    // A suggestion

    [Fact]
    public async Task NewCard_GetsASuggestion_InTheQueue_AndTheCardTextTravelsAsDataOnly()
    {
        BeyniKur("Ayşe \"Simyacı\"yı önerdi, kulübün aralık listesine eklenebilir.");
        ClaudeCevabi();
        var t = Kur();

        var ozet = await t.Onerici.TurAsync(Ct);

        Assert.Equal(1, ozet.Onerilen);
        var eylem = Assert.Single(await EylemleriAlAsync());
        Assert.Equal(EylemDurumu.Bekliyor, eylem.Durum);
        Assert.Equal("gelen", eylem.Kaynak);
        Assert.False(eylem.DisKaynak);
        Assert.Equal(0.9, eylem.Guven);
        Assert.Equal("Kitap önerisi.", eylem.Gerekce);
        using var yuk = JsonDocument.Parse(eylem.Yuk);
        Assert.Equal(Kart1, yuk.RootElement.GetProperty("kart").GetString());
        Assert.Equal("projects/kitap-kulubu/notlar/simyaci-onerisi.md", yuk.RootElement.GetProperty("yol").GetString());
        Assert.Equal(["kaynak", "okul", "özet"], yuk.RootElement.GetProperty("etiketler").EnumerateArray().Select(e => e.GetString()).ToArray());

        // Claude: one call, no tools; the projects and the tags are in the fixed instruction, the card text is only in stdin.
        var cagri = Assert.Single(_claude.Cagrilar());
        var arg = SahteClaude.Argumanlar(cagri);
        var talimat = arg[Array.IndexOf(arg, "--system-prompt") + 1];
        Assert.Equal("", arg[Array.IndexOf(arg, "--tools") + 1]);
        Assert.Contains("kitap-kulubu: Kitap Kulübü Sitesi", talimat);
        Assert.Contains("kitap-kulübü", talimat);
        Assert.DoesNotContain("Simyacı", talimat);
        Assert.Contains("Simyacı", cagri.GetProperty("stdin").GetString());
        var sema = JsonDocument.Parse(arg[Array.IndexOf(arg, "--json-schema") + 1]).RootElement;
        Assert.Equal(
            ["yazılım", "okul", "kaynak", "özet", "kitap-kulübü"],
            sema.GetProperty("properties").GetProperty("etiketler").GetProperty("items").GetProperty("enum").EnumerateArray().Select(e => e.GetString()).ToArray());

        // Nothing was applied.
        Assert.Equal(0, IsleCagrisi());
        Assert.NotNull((await SatirAsync(Kart1))!.OneriAni);

        // The round does not ask again for a card that has a suggestion.
        await t.Onerici.TurAsync(Ct);
        Assert.Single(_claude.Cagrilar());
        Assert.Single(await EylemleriAlAsync());
    }

    // Hidden cards

    [Theory]
    [InlineData("projects/gizli-proje")]
    [InlineData("projects/yok-proje")]
    [InlineData("finans")]
    [InlineData("finans/abonelikler")]
    [InlineData("kisisel/saglik")]
    public async Task CardAimedAtAHiddenProjectOrAClosedFolder_NeverReachesClaude(string hedef)
    {
        // Even if the brain's list let it through, the server keeps it back.
        BeyniKur((Kart1, "Gizli bir şey: ilaç saati", hedef, false));
        ClaudeCevabi();
        var t = Kur();

        var ozet = await t.Onerici.TurAsync(Ct);
        var elle = await t.Onerici.OnerAsync(Kart1, Ct);

        Assert.Equal(0, ozet.Onerilen);
        Assert.Equal(OneriDurumu.Gonderilemez, elle.Durum);
        Assert.Empty(_claude.Cagrilar());
        Assert.Empty(await EylemleriAlAsync());
        // The card was not even read.
        Assert.DoesNotContain(BeyinCagrilari(), a => a.Contains($"gelen/{Kart1}.md"));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task CardThatTheBrainRefusesToRead_NeverReachesClaude(bool hataKoduyla)
    {
        BeyniKur();
        var yol = $"gelen/{Kart1}.md";
        if (hataKoduyla)
            _beyin.CiktiKonumsal("not oku", yol, """{"hata": {"kod": "gizli", "mesaj": "gizli not"}}""", cikis: 1);
        else
            _beyin.CiktiKonumsal("not oku", yol, NotJson(yol, "Gizli bir şey", gizli: true));
        ClaudeCevabi();
        var t = Kur();

        var ozet = await t.Onerici.TurAsync(Ct);

        Assert.Equal(0, ozet.Onerilen);
        Assert.Empty(_claude.Cagrilar());
        Assert.Empty(await EylemleriAlAsync());
        // Not tried again by the round.
        await t.Onerici.TurAsync(Ct);
        Assert.Equal(1, BeyinCagrilari().Count(a => a.Contains(yol)));
    }

    [Fact]
    public async Task SuggestingAgain_ForACardThatIsNotInTheList_FindsNothing_AndAsksNothing()
    {
        // A hidden card is not in `gelen liste`, so it looks like a card that does not exist.
        BeyniKur();
        ClaudeCevabi();
        var t = Kur();

        var sonuc = await t.Onerici.OnerAsync("2026-11-03-0001-gizli-kart", Ct);

        Assert.Equal(OneriDurumu.KartYok, sonuc.Durum);
        Assert.Empty(_claude.Cagrilar());
        Assert.DoesNotContain(BeyinCagrilari(), a => a.Any(x => x.Contains("gizli-kart")));
    }

    // Outside text

    [Theory]
    [InlineData("Bak şu yazıya https://ornek.com/yazi: kitaplar hakkında", true)]
    [InlineData("Ayşe Simyacı'yı önerdi, kulübün aralık listesine eklenebilir.", false)]
    public async Task OutsideText_IsMarked_AndNothingIsAppliedByItself_EvenWhenTheKindIsKendinYap(string metin, bool disKaynak)
    {
        BeyniKur(metin);
        ClaudeCevabi();
        var t = Kur();
        await t.Eylemler.KipAyarlaAsync("yerlestir", EylemKipi.KendinYap, null, Ct);

        await t.Onerici.TurAsync(Ct);

        // Outside text: Sor by the queue's order of rules. Own text: still Sor, because a placement cannot be undone.
        var eylem = Assert.Single(await EylemleriAlAsync());
        Assert.Equal(EylemDurumu.Bekliyor, eylem.Durum);
        Assert.Equal(disKaynak, eylem.DisKaynak);
        Assert.Equal(0, IsleCagrisi());
    }

    [Fact]
    public async Task KindOfYasak_DropsTheSuggestion_AndTheCardIsNotAskedAgain()
    {
        BeyniKur();
        ClaudeCevabi();
        var t = Kur();
        await t.Eylemler.KipAyarlaAsync("yerlestir", EylemKipi.Yasak, null, Ct);

        var ozet = await t.Onerici.TurAsync(Ct);
        await t.Onerici.TurAsync(Ct);

        Assert.Equal(1, ozet.Atlanan);
        Assert.Empty(await EylemleriAlAsync());
        Assert.Single(_claude.Cagrilar());
    }

    // New tag

    [Fact]
    public async Task NewTagNeeded_MarksTheCardForTheLaptop_AndQueuesNothing()
    {
        BeyniKur();
        ClaudeCevabi(yeni: true);
        var t = Kur();

        var ozet = await t.Onerici.TurAsync(Ct);

        Assert.Equal(1, ozet.Onerilen);
        Assert.Empty(await EylemleriAlAsync());
        var satir = (await SatirAsync(Kart1))!;
        Assert.True(satir.LaptoptaIslenecek);
        Assert.Equal("Kitap önerisi.", satir.LaptopNotu);

        // The inbox read shows the mark, and the round leaves the card alone.
        var liste = await GelenIslemleri.ListeAl(_beyin.Istemci(), _vt.Db, NullLogger.Instance, Ct);
        var kart = Assert.Single(liste.Veri!);
        Assert.True(kart.LaptoptaIslenecek);
        Assert.Null(kart.Oneri);
        await t.Onerici.TurAsync(Ct);
        Assert.Single(_claude.Cagrilar());
    }

    // The daily cap

    [Fact]
    public async Task WhenTheDailyCapIsReached_TheRoundStops_AndContinuesTheNextDay()
    {
        BeyniKur((Kart1, "Kitap önerisi: Simyacı", null, false), (Kart2, "Takvimde renkler olsun", null, false));
        ClaudeCevabi();
        var t = Kur(gunluk: 1);

        var ozet = await t.Onerici.TurAsync(Ct);

        Assert.Equal(1, ozet.Onerilen);
        Assert.Single(_claude.Cagrilar());
        Assert.Single(await EylemleriAlAsync());
        // The card that was not asked is not counted as a failed try.
        Assert.Null(await SatirAsync(Kart2));

        await t.Onerici.TurAsync(Ct);
        Assert.Single(_claude.Cagrilar());

        _saat.Simdi = Baslangic.AddDays(1);
        await t.Onerici.TurAsync(Ct);
        Assert.Equal(2, _claude.Cagrilar().Count);
        Assert.Equal(2, (await EylemleriAlAsync()).Count);
    }

    [Fact]
    public async Task OneRound_AsksForAtMostTheConfiguredNumberOfCards()
    {
        BeyniKur((Kart1, "Bir", null, false), (Kart2, "İki", null, false), (Kart3, "Üç", null, false));
        ClaudeCevabi();
        var t = Kur(ayar: new GelenAyari { TurBasinaEnCok = 2 });

        await t.Onerici.TurAsync(Ct);
        Assert.Equal(2, _claude.Cagrilar().Count);

        await t.Onerici.TurAsync(Ct);
        Assert.Equal(3, _claude.Cagrilar().Count);
        Assert.Equal(3, (await EylemleriAlAsync()).Count);
    }

    // Answers that break a rule

    [Theory]
    [InlineData("yeni-etiket", "projects/kitap-kulubu/notlar/x.md", 0.9)]
    [InlineData("kaynak", "finans/abonelik.md", 0.9)]
    [InlineData("kaynak", "kisisel/plan.md", 0.9)]
    [InlineData("kaynak", "../finans/x.md", 0.9)]
    [InlineData("kaynak", "/etc/x.md", 0.9)]
    [InlineData("kaynak", ".beyin/x.md", 0.9)]
    [InlineData("kaynak", "projects/gizli-proje/notlar/x.md", 0.9)]
    [InlineData("kaynak", "projects/kitap-kulubu/notlar/x.md", 2.0)]
    public async Task AnswerBreakingARule_IsNotQueued_AndTheTryIsCounted(string etiket, string yol, double guven)
    {
        BeyniKur();
        ClaudeCevabi(yol, etiketler: ["okul", "özet", etiket], guven: guven);
        var t = Kur();

        var ozet = await t.Onerici.TurAsync(Ct);

        Assert.Equal(1, ozet.Basarisiz);
        Assert.Empty(await EylemleriAlAsync());
        var satir = (await SatirAsync(Kart1))!;
        Assert.Equal(1, satir.DenemeSayisi);
        Assert.Null(satir.OneriAni);
        Assert.Contains("kurala uymuyor", satir.SonHata);
    }

    [Fact]
    public async Task FailedTry_WaitsLongerEachTime_AndGivesUpAfterTheLimit()
    {
        BeyniKur();
        _claude.Cikti("bozuk", 0);
        var t = Kur();

        await t.Onerici.TurAsync(Ct);
        Assert.Single(_claude.Cagrilar());

        // Too soon: no call.
        _saat.Simdi = Baslangic.AddMinutes(5);
        await t.Onerici.TurAsync(Ct);
        Assert.Single(_claude.Cagrilar());

        // 10 minutes after the 1st failure: the 2nd try, which then waits 20.
        _saat.Simdi = Baslangic.AddMinutes(10);
        await t.Onerici.TurAsync(Ct);
        Assert.Equal(2, _claude.Cagrilar().Count);
        _saat.Simdi = Baslangic.AddMinutes(25);
        await t.Onerici.TurAsync(Ct);
        Assert.Equal(2, _claude.Cagrilar().Count);

        _saat.Simdi = Baslangic.AddMinutes(30);
        await t.Onerici.TurAsync(Ct);
        Assert.Equal(3, _claude.Cagrilar().Count);

        // Three failures: left for a person.
        _saat.Simdi = Baslangic.AddDays(2);
        await t.Onerici.TurAsync(Ct);
        Assert.Equal(3, _claude.Cagrilar().Count);
        Assert.Equal(3, (await SatirAsync(Kart1))!.DenemeSayisi);
        Assert.Empty(await EylemleriAlAsync());

        // ...but the manual "suggest again" still works, and a good answer clears the count.
        ClaudeCevabi();
        var elle = await t.Onerici.OnerAsync(Kart1, Ct);
        Assert.Equal(OneriDurumu.Olustu, elle.Durum);
        Assert.Equal(0, (await SatirAsync(Kart1))!.DenemeSayisi);
    }

    // Claude off

    [Fact]
    public async Task ClaudeNotConnected_DoesNothing_Quietly()
    {
        BeyniKur();
        var t = Kur(claudeBagli: false);

        var ozet = await t.Onerici.TurAsync(Ct);
        var elle = await t.Onerici.OnerAsync(Kart1, Ct);

        Assert.Equal(new GelenOnerici.TurOzeti(0, 0, 0), ozet);
        Assert.Equal(OneriDurumu.BagliDegil, elle.Durum);
        Assert.Empty(_claude.Cagrilar());
        Assert.Empty(_beyin.Cagrilar());
        Assert.Empty(await EylemleriAlAsync());
    }

    // Images, and a second suggestion

    [Fact]
    public async Task ImageOnlyCard_IsNotSent_AndIsLeftForTheHand()
    {
        BeyniKur((Kart1, "", null, true));
        ClaudeCevabi();
        var t = Kur();

        var ozet = await t.Onerici.TurAsync(Ct);
        var elle = await t.Onerici.OnerAsync(Kart1, Ct);

        Assert.Equal(0, ozet.Onerilen);
        Assert.Equal(OneriDurumu.MetinYok, elle.Durum);
        Assert.Empty(_claude.Cagrilar());
        Assert.Empty(await EylemleriAlAsync());
    }

    [Fact]
    public async Task CardWithAWaitingSuggestion_IsNotSuggestedAgain()
    {
        BeyniKur();
        ClaudeCevabi();
        var t = Kur();
        await t.Onerici.TurAsync(Ct);

        var elle = await t.Onerici.OnerAsync(Kart1, Ct);

        Assert.Equal(OneriDurumu.BekleyenVar, elle.Durum);
        Assert.Single(_claude.Cagrilar());
        Assert.Single(await EylemleriAlAsync());
    }

    [Fact]
    public async Task RowsOfCardsThatAreGone_AreDropped()
    {
        BeyniKur();
        ClaudeCevabi();
        _vt.Db.GelenKartlari.Add(new GelenKartDurumu { Kart = "2026-01-01-0000-eski", LaptoptaIslenecek = true });
        await _vt.Db.SaveChangesAsync(Ct);
        var t = Kur();

        await t.Onerici.TurAsync(Ct);

        Assert.Null(await SatirAsync("2026-01-01-0000-eski"));
        Assert.NotNull(await SatirAsync(Kart1));
    }

    // Applying

    [Fact]
    public async Task Approving_RunsGelenIsle_WithTheRightArguments_AndCannotBeUndone()
    {
        BeyniKur();
        ClaudeCevabi();
        _beyin.Cikti("gelen isle", $$"""{"yol": "projects/kitap-kulubu/notlar/simyaci-onerisi.md", "kart": "gelen/{{Kart1}}.md", "gorsel": null}""");
        var t = Kur();
        await t.Onerici.TurAsync(Ct);
        var eylem = Assert.Single(await EylemleriAlAsync());

        var sonuc = await t.Eylemler.UygulaAsync(eylem.Id, null, null, Ct);

        Assert.Equal(EylemSonucuTuru.Tamam, sonuc.Tur);
        Assert.Equal(EylemDurumu.Uygulandi, sonuc.Eylem!.Durum);
        var isle = Assert.Single(BeyinCagrilari(), a => a[0] == "gelen" && a[1] == "isle");
        Assert.Equal(
            ["gelen", "isle", "--yol=projects/kitap-kulubu/notlar/simyaci-onerisi.md", "--baslik=Simyacı önerisi", "--tags=kaynak,okul,özet",
             "--json", "--vault", _beyin.Vault, "--", $"gelen/{Kart1}.md"],
            isle);

        // No undo: the brain cannot put a card back.
        Assert.False(t.Eylemler.DtoYap(sonuc.Eylem).GeriAlinabilir);
        var geri = await t.Eylemler.GeriAlAsync(eylem.Id, null, Ct);
        Assert.Equal(EylemSonucuTuru.Catisma, geri.Tur);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemleriAlAsync()).Single().Durum);
    }

    [Theory]
    [InlineData("finans/x.md", "okul")]
    [InlineData("kisisel/x.md", "okul")]
    [InlineData("../x.md", "okul")]
    [InlineData("projects/gizli-proje/notlar/x.md", "okul")]
    [InlineData("ogrenme/x.md", "yeni-etiket")]
    public async Task ACorrectedPayload_IsCheckedAgainstTheBrain_BeforeAnythingIsPlaced(string yol, string etiket)
    {
        BeyniKur();
        ClaudeCevabi();
        _beyin.Cikti("gelen isle", """{"yol": "x", "kart": "y", "gorsel": null}""");
        var t = Kur();
        await t.Onerici.TurAsync(Ct);
        var eylem = Assert.Single(await EylemleriAlAsync());
        var duzeltilmis = JsonSerializer.SerializeToElement(new { kart = Kart1, yol, baslik = "B", etiketler = new[] { etiket } });

        var sonuc = await t.Eylemler.UygulaAsync(eylem.Id, duzeltilmis, null, Ct);

        Assert.Equal(EylemSonucuTuru.Gecersiz, sonuc.Tur);
        Assert.Equal(0, IsleCagrisi());
        Assert.Equal(EylemDurumu.Bekliyor, (await EylemleriAlAsync()).Single().Durum);
    }

    [Fact]
    public async Task WhenTheBrainRefusesThePlacement_TheActionIsHatali_AndSaysNothingOfTheBrainsMessage()
    {
        BeyniKur();
        ClaudeCevabi();
        _beyin.Cikti("gelen isle", """{"hata": {"kod": "hata", "mesaj": "hedef klasör yok: /home/gizli/yol"}}""", cikis: 1);
        var t = Kur();
        await t.Onerici.TurAsync(Ct);
        var eylem = Assert.Single(await EylemleriAlAsync());

        var sonuc = await t.Eylemler.UygulaAsync(eylem.Id, null, null, Ct);

        Assert.Equal(EylemSonucuTuru.Hata, sonuc.Tur);
        var kayit = Assert.Single(await EylemleriAlAsync());
        Assert.Equal(EylemDurumu.Hatali, kayit.Durum);
        Assert.DoesNotContain("/home/gizli", kayit.HataMesaji);
    }

    // The inbox read

    [Fact]
    public async Task InboxList_ShowsTheWaitingSuggestionUnderItsCard()
    {
        BeyniKur((Kart1, "Kitap önerisi: Simyacı", "projects/kitap-kulubu", false), (Kart2, "Takvimde renkler olsun", null, true));
        ClaudeCevabi();
        var t = Kur(ayar: new GelenAyari { TurBasinaEnCok = 1 });
        await t.Onerici.TurAsync(Ct);

        var liste = (await GelenIslemleri.ListeAl(_beyin.Istemci(), _vt.Db, NullLogger.Instance, Ct)).Veri!;

        Assert.Equal([Kart1, Kart2], liste.Select(k => k.Kimlik).ToArray());
        var ilk = liste[0];
        Assert.Equal("Kitap önerisi: Simyacı", ilk.Ozet);
        Assert.Equal("projects/kitap-kulubu", ilk.Hedef);
        Assert.False(ilk.GorselVar);
        Assert.Equal("2026-11-03T18:40", ilk.Yakalandi);
        Assert.NotNull(ilk.Oneri);
        Assert.Equal("projects/kitap-kulubu/notlar/simyaci-onerisi.md", ilk.Oneri.Yol);
        Assert.Equal(["kaynak", "okul", "özet"], ilk.Oneri.Etiketler);
        Assert.Equal(0.9, ilk.Oneri.Guven);
        Assert.True(liste[1].GorselVar);
        Assert.Null(liste[1].Oneri);
    }
}
