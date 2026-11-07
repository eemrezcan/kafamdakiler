using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Claude;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The morning briefing end to end, minus the real programs: real PostgreSQL, a real child process each for the fake beyin.py and
// the fake claude. What must not pass silently: a made-up id or card reaching a person, a failed Claude leaving no briefing, the
// wrong day (05:00) or the wrong hour deciding whether one is made, a day getting two briefings.
public class BrifingHazirlayiciTests : IAsyncLifetime
{
    private static readonly DateOnly Gun = new(2026, 11, 7);

    private readonly TestVeritabani _vt = new();
    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahteClaude _claude = new();
    private readonly ElleSaat _saat = new(Ist(2026, 11, 7, 7, 0));

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public async ValueTask DisposeAsync()
    {
        await _vt.DisposeAsync();
        _beyin.Dispose();
        _claude.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    // A moment in Istanbul time (UTC+3), as the UTC moment the database takes.
    private static DateTimeOffset Ist(int yil, int ay, int gun, int saat, int dakika, int saniye = 0) =>
        new DateTimeOffset(yil, ay, gun, saat, dakika, saniye, TimeSpan.FromHours(3)).ToUniversalTime();

    private static string GunJson(string tarih, params (string Id, string Baslik, string Durum, int? Tahmin)[] maddeler)
    {
        var satirlar = string.Join(",", maddeler.Select(m =>
            $$"""{"id": "{{m.Id}}", "baslik": "{{m.Baslik}}", "durum": "{{m.Durum}}", "tahmin_dk": {{(m.Tahmin?.ToString() ?? "null")}}}"""));
        return $$"""{"tarih": "{{tarih}}", "plan_var": true, "kapandi": false, "geciken": [], "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{{satirlar}}]}]}""";
    }

    // The brain answers `gun goster` in turn: today first, then yesterday, then again (one pair per briefing made).
    // With `ilkHata` the very first call fails, as a brain that is set up but not answering would.
    private void BeyniKur(string bugun, string dun, int tur = 8, bool ilkHata = false)
    {
        var adimlar = Enumerable.Range(0, tur).SelectMany(_ => new[] { (bugun, 0), (dun, 0) }).ToList();
        if (ilkHata)
            adimlar.Insert(0, ("""{"hata": {"kod": "gecersiz", "mesaj": "kötü istek"}}""", 1));
        _beyin.Sirali("gun goster", adimlar.ToArray());
    }

    private void DoluGunuKur(bool ilkHata = false) => BeyniKur(
        GunJson("2026-11-07", ("a1", "Rapor", "acik", 30), ("a2", "Fatura", "acik", 20), ("a3", "Bitmiş iş", "yapildi", 10)),
        GunJson("2026-11-06", ("y1", "Dünden kalan iş", "acik", 15), ("y2", "Dünkü bitmiş", "yapildi", 5)), ilkHata: ilkHata);

    private void BosGunuKur() => BeyniKur(
        """{"tarih": "2026-11-07", "plan_var": false, "kapandi": false, "geciken": [], "bolumler": []}""",
        """{"tarih": "2026-11-06", "plan_var": false, "kapandi": false, "geciken": [], "bolumler": []}""");

    private sealed record Takim(BrifingHazirlayici Hazirlayici, BrifingGirdiOkuyucu Okuyucu);

    private Takim Kur(bool claudeBagli = true, int gunluk = 50, bool beyinBagli = true, AppDbContext? db = null, BrifingAyari? ayar = null, TimeSpan? zamanAsimi = null)
    {
        db ??= _vt.Db;
        var beyin = beyinBagli ? _beyin.Istemci() : new BeyinIstemcisi(new BeyinAyari());
        var claude = claudeBagli
            ? _claude.Istemci(zamanAsimi, gunluk: gunluk, saat: _saat)
            : new ClaudeIstemcisi(new ClaudeAyari(), _saat, NullLogger<ClaudeIstemcisi>.Instance);
        var okuyucu = new BrifingGirdiOkuyucu(db, beyin, new GunAyari(), NullLogger<BrifingGirdiOkuyucu>.Instance);
        return new Takim(new BrifingHazirlayici(db, okuyucu, claude, ayar ?? new BrifingAyari(), _saat, NullLogger<BrifingHazirlayici>.Instance), okuyucu);
    }

    private async Task<Hatirlatici> HatirlaticiEkleAsync(string baslik, DateTimeOffset an, HatirlaticiDurumu durum = HatirlaticiDurumu.Acik, DateTimeOffset? erteleAn = null)
    {
        var h = new Hatirlatici
        {
            Baslik = baslik, Tur = HatirlaticiTuru.Gorev, Gun = HatirlaticiHesap.IstanbulGunu(an), Saat = HatirlaticiHesap.IstanbulSaati(an),
            Tekrar = Tekrar.Yok, Durum = durum, SonrakiAn = an, ErteleAn = erteleAn,
        };
        _vt.Db.Hatirlaticilar.Add(h);
        await _vt.Db.SaveChangesAsync(Ct);
        return h;
    }

    private async Task<Eylem> EylemEkleAsync(string ozet, DateTimeOffset olusma, EylemDurumu durum = EylemDurumu.Bekliyor)
    {
        var e = new Eylem { Tur = "gorev-ekle", Yuk = "{}", Ozet = ozet, Kaynak = "gelen", Durum = durum, CreatedAt = olusma };
        _vt.Db.Eylemler.Add(e);
        await _vt.Db.SaveChangesAsync(Ct);
        return e;
    }

    private void ClaudeCevabi(params object[] kartlar) => _claude.YapiliYanit(JsonSerializer.Serialize(new { kartlar }));

    private static object Kart(string tur, string baslik, string metin, params string[] kimlikler) => new { tur, baslik, metin, bagliKimlikler = kimlikler };

    private string Talimat() => Arguman("--system-prompt");

    private string Sema() => Arguman("--json-schema");

    private string Arguman(string ad)
    {
        var a = SahteClaude.Argumanlar(_claude.Cagrilar().Last());
        return a[Array.IndexOf(a, ad) + 1];
    }

    private async Task<List<GunlukBrifing>> SatirlarAsync()
    {
        await using var db = _vt.YeniDb();
        return await db.Brifingler.AsNoTracking().OrderBy(b => b.Gun).ToListAsync(Ct);
    }

    private static List<BrifingKarti> Kartlar(GunlukBrifing b) => BrifingHazirlayici.KartlariOku(b);

    // Claude's briefing

    [Fact]
    public async Task Briefing_IsMadeByClaude_StoredOnce_AndTheDaysDataTravelsOnlyAsData()
    {
        DoluGunuKur();
        var h = await HatirlaticiEkleAsync("Diş randevusu", Ist(2026, 11, 7, 14, 0));
        var e = await EylemEkleAsync("Görev: Kira öde", Ist(2026, 11, 5, 10, 0));
        ClaudeCevabi(
            Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1", "a2"),
            Kart("kalan", "Dünden kalan", "Bir iş açık kaldı.", "y1"),
            Kart("hatirlatici", "Diş randevusu", "Bugün 14:00.", h.Id.ToString()),
            Kart("onay", "Onay bekleyen", "Bir eylem bekliyor.", e.Id.ToString()),
            Kart("kapasite", "Kapasite", "Bugün sığıyor gibi ama sınırda."));
        var t = Kur();

        var sonuc = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(BrifingDurumu.Tamam, sonuc.Durum);
        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal((Gun, BrifingYontemi.Claude, 0), (satir.Gun, satir.Yontem, satir.YenilemeSayisi));
        Assert.Equal(_saat.Simdi, satir.UretimAni);
        // "kapasite" is not backed by the input (the plan fits in the day), so that card is not kept.
        Assert.Equal(["plan", "kalan", "hatirlatici", "onay"], Kartlar(satir).Select(k => k.Tur));
        Assert.Equal([h.Id.ToString()], Kartlar(satir)[2].BagliKimlikler);

        var cagri = Assert.Single(_claude.Cagrilar());
        var arg = SahteClaude.Argumanlar(cagri);
        Assert.Equal("", arg[Array.IndexOf(arg, "--tools") + 1]);
        // The instruction is fixed text; the day's titles are in stdin only.
        Assert.DoesNotContain("Rapor", Talimat());
        Assert.DoesNotContain("Diş randevusu", Talimat());
        var girdi = cagri.GetProperty("stdin").GetString()!;
        Assert.Contains("id=a1 | Rapor", girdi);
        Assert.Contains("id=y1 | Dünden kalan iş", girdi);
        Assert.Contains($"id={h.Id} | Diş randevusu | bugün 14:00", girdi);
        Assert.Contains($"id={e.Id} | gorev-ekle | Görev: Kira öde", girdi);
        Assert.Contains("3 madde, 1 yapıldı, 2 açık", girdi);

        // The schema allows only the kinds the input has and only the ids it holds.
        var sema = JsonDocument.Parse(Sema()).RootElement.GetProperty("properties").GetProperty("kartlar").GetProperty("items").GetProperty("properties");
        Assert.Equal(["plan", "kalan", "hatirlatici", "onay"], sema.GetProperty("tur").GetProperty("enum").EnumerateArray().Select(x => x.GetString()));
        Assert.Equal(["a1", "a2", "y1", h.Id.ToString(), e.Id.ToString()], sema.GetProperty("bagliKimlikler").GetProperty("items").GetProperty("enum").EnumerateArray().Select(x => x.GetString()));
    }

    [Fact]
    public async Task Briefing_AMadeUpId_IsThrownAway_BeforeItIsStored()
    {
        DoluGunuKur();
        var h = await HatirlaticiEkleAsync("Diş randevusu", Ist(2026, 11, 7, 14, 0));
        ClaudeCevabi(
            Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1", "uydurma-kimlik", "a2"),
            Kart("hatirlatici", "Hayali toplantı", "Yarın 10:00.", "11111111-1111-1111-1111-111111111111"),
            Kart("hatirlatici", "Diş randevusu", "Bugün 14:00.", h.Id.ToString()),
            Kart("kalan", "Dünden kalan", "Bir iş açık kaldı.", "y1"));
        var t = Kur();

        await t.Hazirlayici.BugunAsync(Ct);

        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal(BrifingYontemi.Claude, satir.Yontem);
        var kartlar = Kartlar(satir);
        Assert.Equal(["plan", "hatirlatici", "kalan"], kartlar.Select(k => k.Tur));
        Assert.Equal(["a1", "a2"], kartlar[0].BagliKimlikler);
        Assert.DoesNotContain("uydurma", satir.Kartlar);
        Assert.DoesNotContain("Hayali", satir.Kartlar);
        Assert.DoesNotContain("11111111", satir.Kartlar);
    }

    [Fact]
    public async Task Briefing_WhenMostOfClaudesCardsAreMadeUp_RulesMakeItInstead()
    {
        DoluGunuKur();
        ClaudeCevabi(
            Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"),
            Kart("hatirlatici", "Hayali 1", "Yarın.", "x1"),
            Kart("hatirlatici", "Hayali 2", "Yarın.", "x2"));
        var t = Kur();

        await t.Hazirlayici.BugunAsync(Ct);

        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal(BrifingYontemi.Hesap, satir.Yontem);
        Assert.DoesNotContain("Hayali", satir.Kartlar);
        Assert.Contains(Kartlar(satir), k => k.Tur == "kalan" && k.BagliKimlikler.SequenceEqual(["y1"]));
    }

    [Fact]
    public async Task Briefing_TheAnswerIsLimitedToSevenCards()
    {
        DoluGunuKur();
        var hler = new List<Hatirlatici>();
        for (var i = 1; i <= 9; i++)
            hler.Add(await HatirlaticiEkleAsync($"Hatırlatıcı {i}", Ist(2026, 11, 7, 10, 0).AddMinutes(i)));
        ClaudeCevabi(hler.Select(x => Kart("hatirlatici", x.Baslik, "Bugün.", x.Id.ToString())).ToArray());
        var t = Kur();

        await t.Hazirlayici.BugunAsync(Ct);

        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal(BrifingYontemi.Claude, satir.Yontem);
        Assert.Equal(7, Kartlar(satir).Count);
    }

    // When Claude cannot be used

    public static TheoryData<string> ClaudeYoldanDusenler => new()
    {
        "bagliDegil", "sinirDoldu", "bozukCikti", "cikisKodu", "semaDisi", "bosKartlar", "zamanAsimi",
    };

    [Theory]
    [MemberData(nameof(ClaudeYoldanDusenler))]
    public async Task Briefing_WhenClaudeCannotBeUsed_RulesMakeIt_AndSayTheMethod(string durum)
    {
        DoluGunuKur();
        var h = await HatirlaticiEkleAsync("Diş randevusu", Ist(2026, 11, 7, 14, 0));
        var t = durum switch
        {
            "bagliDegil" => Kur(claudeBagli: false),
            "sinirDoldu" => Kur(gunluk: 0),
            "zamanAsimi" => Kur(zamanAsimi: TimeSpan.FromMilliseconds(400)),
            _ => Kur(),
        };
        switch (durum)
        {
            case "bozukCikti":
                _claude.Cikti("bu bir JSON değil");
                break;
            case "cikisKodu":
                _claude.Cikti("{}", cikis: 1);
                break;
            case "semaDisi":
                _claude.YapiliYanit("""{"baska": 1}""");
                break;
            case "bosKartlar":
                ClaudeCevabi();
                break;
            case "zamanAsimi":
                _claude.Mod("uyku");
                break;
        }

        var sonuc = await t.Hazirlayici.BugunAsync(Ct);

        // The briefing is there, and it says it was not Claude's.
        Assert.Equal(BrifingDurumu.Tamam, sonuc.Durum);
        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal(BrifingYontemi.Hesap, satir.Yontem);
        var kartlar = Kartlar(satir);
        Assert.Equal(["kalan", "plan", "hatirlatici"], kartlar.Select(k => k.Tur));
        Assert.Equal([h.Id.ToString()], kartlar[2].BagliKimlikler);
        if (durum is "bagliDegil" or "sinirDoldu")
            Assert.Empty(_claude.Cagrilar());
    }

    [Fact]
    public async Task Briefing_AnEmptyDay_NeedsNoClaudeCall_AndIsOneEmptyDayCard()
    {
        BosGunuKur();
        var t = Kur();

        var sonuc = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(BrifingDurumu.Tamam, sonuc.Durum);
        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal(BrifingYontemi.Hesap, satir.Yontem);
        var kart = Assert.Single(Kartlar(satir));
        Assert.Equal("bos", kart.Tur);
        Assert.Empty(_claude.Cagrilar());
    }

    // The brain set up but unreadable is not an empty day: nothing is stored, and the next try can still make the briefing.
    [Fact]
    public async Task Briefing_WhenTheBrainIsSetUpButCannotBeRead_NothingIsStored()
    {
        DoluGunuKur(ilkHata: true);
        var t = Kur();

        var sonuc = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(BrifingDurumu.GirdiOkunamadi, sonuc.Durum);
        Assert.Empty(await SatirlarAsync());
        Assert.Empty(_claude.Cagrilar());

        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.BugunAsync(Ct)).Durum);
        Assert.Single(await SatirlarAsync());
    }

    [Fact]
    public async Task Briefing_WhenTheBrainIsNotSetUpHere_IsMadeFromTheDatabaseAlone()
    {
        var h = await HatirlaticiEkleAsync("Diş randevusu", Ist(2026, 11, 7, 14, 0));
        ClaudeCevabi(Kart("hatirlatici", "Diş randevusu", "Bugün 14:00.", h.Id.ToString()));
        var t = Kur(beyinBagli: false);

        var sonuc = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(BrifingDurumu.Tamam, sonuc.Durum);
        Assert.Equal(["hatirlatici"], Kartlar(Assert.Single(await SatirlarAsync())).Select(k => k.Tur));
        Assert.Empty(_beyin.Cagrilar());
        Assert.DoesNotContain("Bugünün planı", Assert.Single(_claude.Cagrilar()).GetProperty("stdin").GetString()!);
    }

    // The hour and the day

    [Fact]
    public async Task Briefing_BeforeItsHour_IsNotMade()
    {
        DoluGunuKur();
        var t = Kur();

        _saat.Simdi = Ist(2026, 11, 7, 5, 30);
        var once = await t.Hazirlayici.BugunAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 7, 6, 29, 59);
        var hemenOnce = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal((BrifingDurumu.HenuzHazirDegil, BrifingDurumu.HenuzHazirDegil), (once.Durum, hemenOnce.Durum));
        Assert.Contains("06:30", once.Mesaj);
        Assert.Empty(await SatirlarAsync());
        Assert.Empty(_claude.Cagrilar());
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task Briefing_AtItsHour_IsMade_ForTheDayOfThatMoment()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();

        _saat.Simdi = Ist(2026, 11, 7, 6, 30);
        var sonuc = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(BrifingDurumu.Tamam, sonuc.Durum);
        Assert.Equal(Gun, Assert.Single(await SatirlarAsync()).Gun);
    }

    [Fact]
    public async Task Briefing_TheHourFollowsTheSetting()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur(ayar: new BrifingAyari { Saat = new TimeOnly(8, 15) });

        _saat.Simdi = Ist(2026, 11, 7, 8, 14, 59);
        Assert.Equal(BrifingDurumu.HenuzHazirDegil, (await t.Hazirlayici.BugunAsync(Ct)).Durum);
        _saat.Simdi = Ist(2026, 11, 7, 8, 15);
        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.BugunAsync(Ct)).Durum);
    }

    // After midnight the day is still yesterday's until 05:00: the briefing of the 7th is the one asked for at 02:00 on the 8th,
    // and it is not made a second time, nor does the 8th get one early.
    [Fact]
    public async Task Briefing_AfterMidnight_BeforeFive_StillBelongsToYesterday()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();
        _saat.Simdi = Ist(2026, 11, 7, 7, 0);
        await t.Hazirlayici.BugunAsync(Ct);
        var ilk = Assert.Single(await SatirlarAsync());

        _saat.Simdi = Ist(2026, 11, 8, 2, 0);
        var gece = await t.Hazirlayici.BugunAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 8, 4, 59, 59);
        var sabaha = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal((Gun, Gun), (gece.Brifing!.Gun, sabaha.Brifing!.Gun));
        Assert.Equal(ilk.UretimAni, gece.Brifing.UretimAni);
        Assert.Single(await SatirlarAsync());
        Assert.Single(_claude.Cagrilar());
    }

    [Fact]
    public async Task Briefing_AtFive_TheNewDayBegins_AndItsBriefingWaitsForItsHour()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();
        _saat.Simdi = Ist(2026, 11, 7, 7, 0);
        await t.Hazirlayici.BugunAsync(Ct);

        _saat.Simdi = Ist(2026, 11, 8, 5, 0);
        var bes = await t.Hazirlayici.BugunAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 8, 6, 29);
        var altiYirmiDokuz = await t.Hazirlayici.BugunAsync(Ct);
        Assert.Equal((BrifingDurumu.HenuzHazirDegil, BrifingDurumu.HenuzHazirDegil), (bes.Durum, altiYirmiDokuz.Durum));
        Assert.Single(await SatirlarAsync());

        _saat.Simdi = Ist(2026, 11, 8, 6, 30);
        var yeni = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(new DateOnly(2026, 11, 8), yeni.Brifing!.Gun);
        Assert.Equal([Gun, new DateOnly(2026, 11, 8)], (await SatirlarAsync()).Select(b => b.Gun));
    }

    // Nobody opened the app on the 7th. At 02:00 on the 8th the 7th is still "today", its hour is long past: it is made for the 7th.
    [Fact]
    public async Task Briefing_AskedForAfterMidnight_ForADayThatHasNone_IsMadeForThatDay()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();

        _saat.Simdi = Ist(2026, 11, 8, 2, 0);
        var sonuc = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(Gun, sonuc.Brifing!.Gun);
        Assert.Equal(Gun, Assert.Single(await SatirlarAsync()).Gun);
        // The plan asked for is the 7th's, yesterday's is the 6th.
        var gunler = _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(a => a[0] == "gun").Select(a => a.Single(x => x.StartsWith("--tarih=", StringComparison.Ordinal))).ToArray();
        Assert.Equal(["--tarih=2026-11-07", "--tarih=2026-11-06"], gunler);
    }

    // Once a day

    [Fact]
    public async Task Briefing_AskedForTwice_IsMadeOnce()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();

        var birinci = await t.Hazirlayici.BugunAsync(Ct);
        var ikinci = await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(birinci.Brifing!.UretimAni, ikinci.Brifing!.UretimAni);
        Assert.Single(await SatirlarAsync());
        Assert.Single(_claude.Cagrilar());
    }

    [Fact]
    public async Task Briefing_TwoRequestsAtOnce_MakeOneBriefing_AndOneClaudeCall()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        _claude.Mod("yavas");
        await using var db2 = _vt.YeniDb();
        var a = Kur();
        var b = Kur(db: db2);

        var sonuclar = await Task.WhenAll(a.Hazirlayici.BugunAsync(Ct), b.Hazirlayici.BugunAsync(Ct));

        Assert.All(sonuclar, s => Assert.Equal(BrifingDurumu.Tamam, s.Durum));
        Assert.Equal(sonuclar[0].Brifing!.UretimAni, sonuclar[1].Brifing!.UretimAni);
        Assert.Single(await SatirlarAsync());
        Assert.Single(_claude.Cagrilar());
    }

    // New briefing on request

    [Fact]
    public async Task Refresh_ReplacesTheBriefing_ClearsItsVotes_AndIsCountedUpToThree()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();
        await t.Hazirlayici.BugunAsync(Ct);
        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.OyVerAsync(Gun, 0, 1, Ct)).Durum);

        ClaudeCevabi(Kart("plan", "Yeni başlık", "Yeni cümle.", "a2"));
        _saat.Simdi = Ist(2026, 11, 7, 9, 0);
        var yenilenen = await t.Hazirlayici.YenileAsync(Ct);

        Assert.Equal(BrifingDurumu.Tamam, yenilenen.Durum);
        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal(1, satir.YenilemeSayisi);
        Assert.Equal(_saat.Simdi, satir.UretimAni);
        Assert.Equal("Yeni başlık", Kartlar(satir).Single().Baslik);
        await using (var db = _vt.YeniDb())
            Assert.Empty(await db.BrifingOylari.ToListAsync(Ct));

        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.YenileAsync(Ct)).Durum);
        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.YenileAsync(Ct)).Durum);
        var sinir = await t.Hazirlayici.YenileAsync(Ct);

        Assert.Equal(BrifingDurumu.SinirDoldu, sinir.Durum);
        Assert.Equal(3, Assert.Single(await SatirlarAsync()).YenilemeSayisi);
        // 1 first + 3 refreshes; the refused one called nothing.
        Assert.Equal(4, _claude.Cagrilar().Count);
    }

    [Fact]
    public async Task Refresh_WhenThereIsNoBriefingYet_MakesIt_WithoutCountingIt()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();
        _saat.Simdi = Ist(2026, 11, 7, 5, 30);

        var sonuc = await t.Hazirlayici.YenileAsync(Ct);

        Assert.Equal(BrifingDurumu.Tamam, sonuc.Durum);
        Assert.Equal(0, Assert.Single(await SatirlarAsync()).YenilemeSayisi);
    }

    [Fact]
    public async Task Refresh_WhenTheBrainCannotBeRead_KeepsTheStoredBriefing_AndDoesNotCountIt()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();
        await t.Hazirlayici.BugunAsync(Ct);
        _beyin.Mod = "hata";

        var sonuc = await t.Hazirlayici.YenileAsync(Ct);

        Assert.Equal(BrifingDurumu.GirdiOkunamadi, sonuc.Durum);
        var satir = Assert.Single(await SatirlarAsync());
        Assert.Equal((0, "Bugünün işleri"), (satir.YenilemeSayisi, Kartlar(satir).Single().Baslik));
    }

    // Votes

    [Fact]
    public async Task Vote_IsStored_ChangedAndTakenBack_OneRowPerCard()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"), Kart("kalan", "Dünden kalan", "Bir iş açık kaldı.", "y1"));
        var t = Kur();
        await t.Hazirlayici.BugunAsync(Ct);

        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.OyVerAsync(Gun, 1, 1, Ct)).Durum);
        await using (var db = _vt.YeniDb())
        {
            var oy = await db.BrifingOylari.SingleAsync(Ct);
            Assert.Equal((Gun, 1, "kalan", 1), (oy.Gun, oy.Sira, oy.Tur, oy.Oy));
        }

        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.OyVerAsync(Gun, 1, -1, Ct)).Durum);
        await using (var db = _vt.YeniDb())
            Assert.Equal(-1, (await db.BrifingOylari.SingleAsync(Ct)).Oy);

        var dto = await t.Hazirlayici.DtoYapAsync((await t.Hazirlayici.GetirAsync(Gun, Ct))!, Ct);
        Assert.Equal([0, -1], dto.Kartlar.Select(k => k.Oy));

        Assert.Equal(BrifingDurumu.Tamam, (await t.Hazirlayici.OyVerAsync(Gun, 1, 0, Ct)).Durum);
        await using (var db = _vt.YeniDb())
            Assert.Empty(await db.BrifingOylari.ToListAsync(Ct));
    }

    [Theory]
    [InlineData(2, 0)]
    [InlineData(-2, 0)]
    [InlineData(1, 5)]
    [InlineData(1, -1)]
    public async Task Vote_ThatIsNotAThumbOrOnNoCard_IsRefused_AndStoresNothing(int oy, int sira)
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();
        await t.Hazirlayici.BugunAsync(Ct);

        var sonuc = await t.Hazirlayici.OyVerAsync(Gun, sira, oy, Ct);

        Assert.Equal(oy is 1 ? BrifingDurumu.Bulunamadi : BrifingDurumu.Gecersiz, sonuc.Durum);
        await using var db = _vt.YeniDb();
        Assert.Empty(await db.BrifingOylari.ToListAsync(Ct));
    }

    [Fact]
    public async Task Vote_ForADayWithoutABriefing_IsNotFound()
    {
        var t = Kur();

        var sonuc = await t.Hazirlayici.OyVerAsync(new DateOnly(2026, 1, 1), 0, 1, Ct);

        Assert.Equal(BrifingDurumu.Bulunamadi, sonuc.Durum);
    }

    // The votes of the last 14 days end up in the next instruction: the 14th day before counts, the 15th does not, and neither does today's.
    [Fact]
    public async Task Votes_OfTheLastFourteenDays_ReachTheNextInstruction()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        BrifingOyu Oy(string tur, int oy, int gunOnce, int sira) => new() { Gun = Gun.AddDays(-gunOnce), Sira = sira, Tur = tur, Oy = oy, Zaman = _saat.Simdi };
        _vt.Db.BrifingOylari.AddRange(
            Oy("plan", 1, 2, 0), Oy("plan", 1, 3, 0),
            Oy("kapasite", -1, 1, 0), Oy("kapasite", -1, 14, 0),
            Oy("onay", -1, 15, 0), Oy("onay", -1, 15, 1),
            Oy("hatirlatici", -1, 0, 0), Oy("hatirlatici", -1, 0, 1));
        await _vt.Db.SaveChangesAsync(Ct);
        var t = Kur();

        await t.Hazirlayici.BugunAsync(Ct);

        Assert.Contains("daha çok görmek istediği türler: plan; daha az görmek istediği türler: kapasite.", Talimat());
    }

    [Fact]
    public async Task Instruction_WhenThereAreNoVotes_HasNoVoteSentence()
    {
        DoluGunuKur();
        ClaudeCevabi(Kart("plan", "Bugünün işleri", "İki açık iş var.", "a1"));
        var t = Kur();

        await t.Hazirlayici.BugunAsync(Ct);

        Assert.DoesNotContain("görmek istediği", Talimat());
    }

    // The input

    [Fact]
    public async Task Input_Reminders_AreThoseOfTheDayAndTheThreeAfter_ByTheFiveOClockDay()
    {
        var bugun = await HatirlaticiEkleAsync("Bugün sabah", Ist(2026, 11, 7, 9, 0));
        var uc = await HatirlaticiEkleAsync("Üç gün sonra akşam", Ist(2026, 11, 10, 20, 0));
        // 04:00 on the 11th still belongs to the 10th.
        var gece = await HatirlaticiEkleAsync("Gece yarısından sonra", Ist(2026, 11, 11, 4, 0));
        var fazla = await HatirlaticiEkleAsync("Dört gün sonra", Ist(2026, 11, 11, 6, 0));
        var dun = await HatirlaticiEkleAsync("Dün akşam", Ist(2026, 11, 6, 20, 0));
        var tamam = await HatirlaticiEkleAsync("Yapılmış", Ist(2026, 11, 8, 9, 0), HatirlaticiDurumu.Tamam);
        var ertelenmis = await HatirlaticiEkleAsync("Ertelenmiş", Ist(2026, 11, 20, 9, 0), erteleAn: Ist(2026, 11, 8, 10, 0));
        // Snoozed away from the window: its rule says the 8th, its snooze says the 20th.
        var uzaga = await HatirlaticiEkleAsync("Uzağa ertelenmiş", Ist(2026, 11, 8, 9, 0), erteleAn: Ist(2026, 11, 20, 9, 0));
        var t = Kur(beyinBagli: false);

        var girdi = (await t.Okuyucu.OkuAsync(Gun, Ct)).Girdi!;

        Assert.Equal(
            [bugun.Id.ToString(), ertelenmis.Id.ToString(), uc.Id.ToString(), gece.Id.ToString()],
            girdi.Hatirlaticilar.Select(x => x.Kimlik));
        Assert.Equal([0, 1, 3, 3], girdi.Hatirlaticilar.Select(x => x.KalanGun));
        Assert.Equal(["09:00", "10:00", "20:00", "04:00"], girdi.Hatirlaticilar.Select(x => x.Saat));
        Assert.DoesNotContain(girdi.Hatirlaticilar, x => x.Kimlik == fazla.Id.ToString() || x.Kimlik == dun.Id.ToString()
            || x.Kimlik == tamam.Id.ToString() || x.Kimlik == uzaga.Id.ToString());
    }

    [Fact]
    public async Task Input_Approvals_AreCounted_AndTheOldestFiveAreNamed()
    {
        for (var i = 1; i <= 7; i++)
            await EylemEkleAsync($"Bekleyen {i}", Ist(2026, 11, 1, 10, 0).AddHours(i));
        await EylemEkleAsync("Uygulanmış", Ist(2026, 10, 1, 10, 0), EylemDurumu.Uygulandi);
        await EylemEkleAsync("Reddedilmiş", Ist(2026, 10, 2, 10, 0), EylemDurumu.Reddedildi);
        var t = Kur(beyinBagli: false);

        var girdi = (await t.Okuyucu.OkuAsync(Gun, Ct)).Girdi!;

        Assert.Equal(7, girdi.OnayBekleyen);
        Assert.Equal(["Bekleyen 1", "Bekleyen 2", "Bekleyen 3", "Bekleyen 4", "Bekleyen 5"], girdi.Onaylar.Select(o => o.Ozet));
    }

    [Fact]
    public async Task Input_TheCapacityWarning_AndYesterdaysLeftovers_AreWorkedOutByTheServer()
    {
        BeyniKur(
            GunJson("2026-11-07", ("a1", "Büyük iş", "acik", 300), ("a2", "Bir iş daha", "acik", 90), ("a3", "Yapıldı", "yapildi", 500)),
            GunJson("2026-11-06", ("y1", "Dünden", "acik", null), ("y2", "Dünkü bitmiş", "yapildi", 5)));
        var t = Kur();

        var girdi = (await t.Okuyucu.OkuAsync(Gun, Ct)).Girdi!;

        // 300 + 90 open minutes against a 6-hour day.
        Assert.Equal(new BrifingKapasitesi(390, 360, 30), girdi.Kapasite);
        Assert.Equal(["a1", "a2"], girdi.Plan.Select(m => m.Kimlik));
        Assert.Equal((3, 1), (girdi.PlanToplam, girdi.PlanYapildi));
        Assert.Equal(["y1"], girdi.Kalan.Select(m => m.Kimlik));
    }
}
