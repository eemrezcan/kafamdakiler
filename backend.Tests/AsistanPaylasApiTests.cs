using System.Net;
using System.Text.Json;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// Text that came through the share menu may be another app's (K-0024, E7): only a note is made of it at once, every other kind waits in the approval
// queue as an action from an outside source, which no mode ever applies by itself. The person's permission and the `Yasak` mode are still asked.
// The other three sources are the person's own words and are applied as before.
public sealed class AsistanPaylasApiTests(UygulamaFabrikasi uygulama) : AsistanTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private const string Metin = "Yarın 9'da Ali'yi ara. Raporu bugün bitir. Üye girişi görevi eklensin. Yarın 14:00'te toplantı var. Bir fikir: aylık tema. Takvim sayfası yazılsın.";

    private static string Altili() => Cevap(
        Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00", kaynakParca: "Yarın 9'da Ali'yi ara."),
        Oneri("plan-ekle", "Raporu bitir", gun: BugunMetni, tahmin: 30, kaynakParca: "Raporu bugün bitir."),
        Oneri("gorev-ekle", "Üye girişi", proje: "kitap-kulubu", kaynakParca: "Üye girişi görevi eklensin."),
        Oneri("takvim-ekle", "Toplantı", gun: Yarin, saat: "14:00", kaynakParca: "Yarın 14:00'te toplantı var."),
        Oneri("not", "Fikir", kaynakParca: "Bir fikir: aylık tema."),
        Oneri("is", "Takvim sayfası", proje: "kitap-kulubu", tip: "kod", kaynakParca: "Takvim sayfası yazılsın."));

    private async Task<List<T>> Satirlar<T>(Func<Kafamdakiler.Data.AppDbContext, IQueryable<T>> sorgu) where T : class
    {
        await using var db = YeniDb();
        return await sorgu(db).AsNoTracking().ToListAsync(Ct);
    }

    private int BeyinYazmalari() => BeyinCagrisi("gun", "ekle") + BeyinCagrisi("gorev", "ekle") + BeyinCagrisi("is", "ekle");

    [Fact]
    public async Task Paylas_OnlyTheNoteIsDoneAtOnce_EveryOtherKindWaitsInTheQueueAsAnOutsideAction()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        AsistanClaude.YapiliYanit(Altili());

        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), Metin, "paylas");

        var sonuclar = yanit.GetProperty("sonuclar").EnumerateArray().ToList();
        Assert.Equal(
            [("hatirlatici-kur", "onayda"), ("plan-ekle", "onayda"), ("gorev-ekle", "onayda"), ("takvim-ekle", "onayda"), ("not", "uygulandi"), ("is", "onayda")],
            sonuclar.Select(s => (s.GetProperty("tur").GetString()!, s.GetProperty("durum").GetString()!)));
        // The queued ones name their action and cannot be undone yet (nothing was done); the note is done and can be taken back.
        Assert.Equal([true, true, true, true, false, true], sonuclar.Select(s => s.GetProperty("eylemId").ValueKind == JsonValueKind.String));
        Assert.Equal([false, false, false, false, true, false], sonuclar.Select(s => s.GetProperty("geriAlinabilir").GetBoolean()));
        Assert.All(sonuclar.Where(s => s.GetProperty("durum").GetString() == "onayda"), s => Assert.Contains("onay", s.GetProperty("mesaj").GetString()));

        // Nothing was written outside the queue: no reminder, no plan item, no task, no card, no event.
        Assert.Empty(await Satirlar(db => db.Hatirlaticilar));
        Assert.Equal(0, BeyinYazmalari());
        Assert.Empty(await Satirlar(db => db.TakvimEtkinlikleri));
        Assert.DoesNotContain(Google.Cagrilar, c => c.Contains("Ekle", StringComparison.OrdinalIgnoreCase));
        var yakalama = Assert.Single(await Satirlar(db => db.Yakalamalar));
        Assert.Equal("Bir fikir: aylık tema.", yakalama.Metin);

        // The queue holds five actions from an outside source, kept as the share menu's.
        var eylemler = (await Satirlar(db => db.Eylemler)).OrderBy(e => e.CreatedAt).ToList();
        Assert.Equal(["hatirlatici-kur", "plan-ekle", "gorev-ekle", "takvim-ekle", "is-ac"], eylemler.Select(e => e.Tur));
        Assert.All(eylemler, e => Assert.Equal(("paylas", true, EylemDurumu.Bekliyor), (e.Kaynak, e.DisKaynak, e.Durum)));
        // A row in the notification center only for what was done (the note), none for what waits.
        Assert.Single(await Satirlar(db => db.Bildirimler));

        // The feed shows them as approval cards, and the badge counts them.
        var akis = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/asistan/akis?suzgec=bekleyen", sahip, fabrika))).EnumerateArray().ToList();
        Assert.Equal(5, akis.Count(a => a.GetProperty("tur").GetString() == "onay"));
        Assert.Equal(5, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/asistan/sayi", sahip, fabrika))).GetProperty("bekleyen").GetInt32());
    }

    [Fact]
    public async Task Paylas_ApprovingInTheQueueDoesIt_TheReminderAndTheCard()
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        AsistanClaude.YapiliYanit(Cevap(
            Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00"),
            Oneri("is", "Takvim sayfası", proje: "kitap-kulubu", tip: "kod")));
        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Yarın 9'da Ali'yi ara. Takvim sayfası yazılsın.", "paylas");
        var sonuclar = yanit.GetProperty("sonuclar").EnumerateArray().ToList();

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{sonuclar[0].GetProperty("eylemId").GetGuid()}/uygula", sahip, fabrika, new { })).StatusCode);
        Assert.Equal(0, BeyinCagrisi("is", "ekle"));
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{sonuclar[1].GetProperty("eylemId").GetGuid()}/uygula", sahip, fabrika, new { })).StatusCode);

        Assert.Equal("Ali'yi ara", Assert.Single(await Satirlar(db => db.Hatirlaticilar)).Baslik);
        var isEkle = Beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Single(a => a[0] == "is" && a[1] == "ekle");
        Assert.Contains("--proje=kitap-kulubu", isEkle);
        Assert.Contains("--tip=kod", isEkle);
        // A card cannot be taken back, so the kind is never one a mode applies by itself.
        var tur = (await Satirlar(db => db.Eylemler)).Single(e => e.Tur == "is-ac");
        Assert.Equal(EylemDurumu.Uygulandi, tur.Durum);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{tur.Id}/geri-al", sahip, fabrika)).StatusCode);
    }

    [Fact]
    public async Task Paylas_EvenTheModeKendinYapDoesNotApplyAnOutsideAction()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        AsistanClaude.YapiliYanit(Altili());
        foreach (var tur in new[] { "hatirlatici-kur", "plan-ekle", "gorev-ekle", "takvim-ekle", "is-ac" })
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Put, $"/api/yonetim/eylem-izinleri/{tur}", sahip, fabrika, new { kip = "kendinYap" })).StatusCode);

        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), Metin, "paylas");

        Assert.Equal(5, yanit.GetProperty("sonuclar").EnumerateArray().Count(s => s.GetProperty("durum").GetString() == "onayda"));
        Assert.All(await Satirlar(db => db.Eylemler), e => Assert.Equal(EylemDurumu.Bekliyor, e.Durum));
        Assert.Empty(await Satirlar(db => db.Hatirlaticilar));
        Assert.Equal(0, BeyinYazmalari());

        // The same words typed by the person (a source of their own) with the same modes are applied.
        AsistanClaude.YapiliYanit(Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00")));
        var kendi = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Yarın 9'da Ali'yi ara", "yazi");
        Assert.Equal("uygulandi", Assert.Single(kendi.GetProperty("sonuclar").EnumerateArray()).GetProperty("durum").GetString());
        Assert.Single(await Satirlar(db => db.Hatirlaticilar));
    }

    [Theory]
    [InlineData("yazi")]
    [InlineData("ses")]
    [InlineData("widget")]
    public async Task OtherSources_AreThePersonsOwnWords_AndAreAppliedAtOnce(string kaynak)
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        AsistanClaude.YapiliYanit(Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00"), Oneri("is", "Takvim sayfası", proje: "kitap-kulubu", tip: "kod")));

        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Yarın 9'da Ali'yi ara. Takvim sayfası yazılsın.", kaynak);

        Assert.All(yanit.GetProperty("sonuclar").EnumerateArray(), s => Assert.Equal("uygulandi", s.GetProperty("durum").GetString()));
        Assert.Single(await Satirlar(db => db.Hatirlaticilar));
        Assert.Equal(1, BeyinCagrisi("is", "ekle"));
        Assert.All(await Satirlar(db => db.Eylemler), e => Assert.Equal(("asistan", false), (e.Kaynak, e.DisKaynak)));
    }

    [Fact]
    public async Task Paylas_TheForbiddenModeAndTheMissingPermissionAreStillAsked()
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinAsync(sahip, "asistan.kullan", fabrika);
        AsistanClaude.YapiliYanit(Cevap(
            Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00"),
            Oneri("plan-ekle", "Raporu bitir", gun: BugunMetni),
            Oneri("is", "Takvim sayfası", proje: "kitap-kulubu", tip: "kod")));
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Put, "/api/yonetim/eylem-izinleri/plan-ekle", sahip, fabrika, new { kip = "yasak" })).StatusCode);

        // The Asistan without any permission: nothing is even queued.
        var izinsiz = await GirdiAsync(fabrika, asistan, Guid.NewGuid(), "x paylaştı", "paylas");
        Assert.All(izinsiz.GetProperty("sonuclar").EnumerateArray(), s => Assert.Equal("izinYok", s.GetProperty("durum").GetString()));
        Assert.Empty(await Satirlar(db => db.Eylemler));

        // With the reminder and card permissions: the reminder and the card are queued; the forbidden plan kind is refused.
        await IzinAsync(sahip, "hatirlatici.yaz", fabrika);
        await IzinAsync(sahip, "isler.yaz", fabrika);
        await IzinAsync(sahip, "plan.yaz", fabrika);
        var sonuclar = (await GirdiAsync(fabrika, asistan, Guid.NewGuid(), "y paylaştı", "paylas")).GetProperty("sonuclar").EnumerateArray().ToList();
        Assert.Equal(["onayda", "izinYok", "onayda"], sonuclar.Select(s => s.GetProperty("durum").GetString()));
        Assert.Contains("yasak", sonuclar[1].GetProperty("mesaj").GetString());
        Assert.Equal(["hatirlatici-kur", "is-ac"], (await Satirlar(db => db.Eylemler)).OrderBy(e => e.CreatedAt).Select(e => e.Tur));
    }

    [Fact]
    public async Task Paylas_AQuestionAnsweredLater_StillKeepsTheSourceOfTheFirstWords()
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        AsistanClaude.YapiliSirali(
            SoruluCevap("Hatırlatıcı mı?", "Evet", "Hayır"),
            Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00")));
        var ilk = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Yarın Ali", "paylas");

        var cevap = await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/asistan/sorular/{ilk.GetProperty("soru").GetProperty("id").GetGuid()}/cevap", sahip, fabrika, new { cevap = "Evet" }));

        var sonuc = Assert.Single(cevap.GetProperty("sonuclar").EnumerateArray());
        Assert.Equal("onayda", sonuc.GetProperty("durum").GetString());
        Assert.Empty(await Satirlar(db => db.Hatirlaticilar));
        var eylem = Assert.Single(await Satirlar(db => db.Eylemler));
        Assert.Equal(("paylas", true), (eylem.Kaynak, eylem.DisKaynak));
    }

    [Fact]
    public async Task Paylas_WhenClaudeCannotBeUsed_TheWordsAreStillKeptAsANote()
    {
        var (fabrika, sahip) = await HazirlaAsync(claude: false, google: false);

        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Paylaşılan bir metin", "paylas");

        var sonuc = Assert.Single(yanit.GetProperty("sonuclar").EnumerateArray());
        Assert.Equal(("not", "uygulandi"), (sonuc.GetProperty("tur").GetString(), sonuc.GetProperty("durum").GetString()));
        Assert.Equal("Paylaşılan bir metin", Assert.Single(await Satirlar(db => db.Yakalamalar)).Metin);
    }

    [Fact]
    public async Task Paylas_TheQueuedActionIsTheSameChecksAsAnyOther_ABadSuggestionIsToldNotQueued()
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        AsistanClaude.YapiliYanit(Cevap(Oneri("hatirlatici-kur", "Geçmişte", gun: "2026-11-01"), Oneri("is", "Alansız")));

        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "bir şey", "paylas");

        var sonuclar = yanit.GetProperty("sonuclar").EnumerateArray().ToList();
        Assert.Equal(["gecersiz", "gecersiz", "uygulandi"], sonuclar.Select(s => s.GetProperty("durum").GetString()));
        Assert.Equal("not", sonuclar[2].GetProperty("tur").GetString());
        Assert.Empty(await Satirlar(db => db.Eylemler));
    }
}
