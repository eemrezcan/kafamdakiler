using System.Net;
using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Takvim;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The day view (K-0024, sözleşme §1), the leftovers of yesterday (§1.3) and the day capacity setting (§5), through the whole app:
// one list for plan items, tasks, reminders and events, the join of a reminder with its item, the weight of the day, who may read.
public sealed class GunGorunumuApiTests(UygulamaFabrikasi uygulama) : GunTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private async Task<(Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> Fabrika, string Sahip)> HazirlaAsync(string? kapasiteSaat = null)
    {
        await GunTemizleAsync();
        var fabrika = GunFabrikasi(kapasiteSaat: kapasiteSaat);
        return (fabrika, await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika));
    }

    private static JsonElement Oge(JsonElement gun, string kimlik) =>
        gun.GetProperty("ogeler").EnumerateArray().Single(o => o.GetProperty("kimlik").GetString() == kimlik);

    [Fact]
    public async Task Gun_PutsPlanTasksRemindersAndEventsInOneList_WithTheWeightOfTheDay()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun goster", GunJson(BugunMetni,
        [
            Madde("a3f09c", "Rapor yaz ~30dk", tahmin: 30, proje: "kitap-kulubu"),
            Madde("b4e1d2", "Mail cevapla ~15dk", tahmin: 15),
            Madde("c5d6e7", "Kitap oku (2/3)"),
            Madde("g:uye-girisi", "Üye girişi", gorev: "uye-girisi"),
        ], geciken: "[" + Geciken("eski-is", "Eski iş", "2026-11-05", 4) + "]"));
        await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 9, 10), IstAn(2026, 11, 9, 11), yer: "Ofis");
        var bagli = await HatirlaticiEkleAsync("Rapor için hatırlat", BugunGunu, new TimeOnly(14, 0), maddeId: "a3f09c", maddeTarihi: BugunGunu);
        var bagsiz = await HatirlaticiEkleAsync("Eczaneye uğra", BugunGunu, new TimeOnly(16, 30));
        var saatsiz = await HatirlaticiEkleAsync("Çiçekleri sula", BugunGunu);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var gun = await OkuAsync(yanit);

        Assert.Equal(BugunMetni, gun.GetProperty("tarih").GetString());
        Assert.True(gun.GetProperty("bugun").GetBoolean());
        Assert.False(gun.GetProperty("kapandi").GetBoolean());
        // The order: by the clock first (event 10:00, the item whose reminder is at 14:00, the reminder at 16:30), then late items,
        // then the plan in the brain's order, and the reminder without an hour last.
        Assert.Equal(
            ["e:", "m:a3f09c", $"h:{bagsiz.Id}", "g:eski-is", "m:b4e1d2", "m:c5d6e7", "g:uye-girisi", $"h:{saatsiz.Id}"],
            gun.GetProperty("ogeler").EnumerateArray().Select(o => o.GetProperty("kimlik").GetString()!).Select(k => k.StartsWith("e:") ? "e:" : k));

        // A reminder tied to an item is not a row of its own: it is in the item's `hatirlatici`, and gives the item its hour.
        Assert.DoesNotContain(gun.GetProperty("ogeler").EnumerateArray(), o => o.GetProperty("kimlik").GetString() == $"h:{bagli.Id}");
        var rapor = Oge(gun, "m:a3f09c");
        Assert.Equal("plan", rapor.GetProperty("tur").GetString());
        Assert.Equal("Rapor yaz", rapor.GetProperty("baslik").GetString());
        Assert.Equal("14:00", rapor.GetProperty("saat").GetString());
        Assert.Equal(30, rapor.GetProperty("tahminDk").GetInt32());
        Assert.Equal("acik", rapor.GetProperty("durum").GetString());
        Assert.Equal("kitap-kulubu", rapor.GetProperty("proje").GetString());
        Assert.Equal("Yapılacaklar", rapor.GetProperty("bolum").GetString());
        Assert.Equal("a3f09c", rapor.GetProperty("maddeId").GetString());
        var ozet = rapor.GetProperty("hatirlatici");
        Assert.Equal(bagli.Id, ozet.GetProperty("id").GetGuid());
        Assert.Equal("14:00", ozet.GetProperty("saat").GetString());
        Assert.Equal("yok", ozet.GetProperty("tekrar").GetString());
        Assert.False(ozet.GetProperty("acil").GetBoolean());
        Assert.Equal(0, ozet.GetProperty("onceGun").GetInt32());

        var kitap = Oge(gun, "m:c5d6e7");
        Assert.Equal("Kitap oku", kitap.GetProperty("baslik").GetString());
        Assert.Equal(2, kitap.GetProperty("bolunmus").GetProperty("sira").GetInt32());
        Assert.Equal(3, kitap.GetProperty("bolunmus").GetProperty("toplam").GetInt32());

        // A task that is due today shows in the plan as `g:<task>`: it is a task row, not a plan row.
        var gorev = Oge(gun, "g:uye-girisi");
        Assert.Equal("gorev", gorev.GetProperty("tur").GetString());
        Assert.Equal("uye-girisi", gorev.GetProperty("gorevKimligi").GetString());
        Assert.Equal(JsonValueKind.Null, gorev.GetProperty("maddeId").ValueKind);
        var gecikmis = Oge(gun, "g:eski-is");
        Assert.Equal(4, gecikmis.GetProperty("gecikmeGun").GetInt32());
        Assert.Equal("gorev", gecikmis.GetProperty("tur").GetString());

        var etkinlik = gun.GetProperty("ogeler").EnumerateArray().Single(o => o.GetProperty("tur").GetString() == "etkinlik");
        Assert.Equal("10:00", etkinlik.GetProperty("saat").GetString());
        Assert.Equal("11:00", etkinlik.GetProperty("bitisSaati").GetString());
        Assert.Equal(60, etkinlik.GetProperty("sureDk").GetInt32());
        Assert.Equal("Ofis", etkinlik.GetProperty("yer").GetString());
        Assert.Equal("acik", etkinlik.GetProperty("durum").GetString());
        Assert.NotEqual(JsonValueKind.Null, etkinlik.GetProperty("etkinlikId").ValueKind);

        var own = Oge(gun, $"h:{bagsiz.Id}");
        Assert.Equal("hatirlatici", own.GetProperty("tur").GetString());
        Assert.Equal("16:30", own.GetProperty("saat").GetString());
        Assert.Equal(bagsiz.Id, own.GetProperty("hatirlaticiId").GetGuid());
        Assert.Equal(JsonValueKind.Null, Oge(gun, $"h:{saatsiz.Id}").GetProperty("saat").ValueKind);

        // Open plan and task items: 30 + 15 minutes of estimate; the other three (a split item, the task due today, the late task) have none.
        // 360 minutes of capacity (the setting's default), the event takes 60.
        var yuk = gun.GetProperty("yuk");
        Assert.Equal(45, yuk.GetProperty("acikTahminDk").GetInt32());
        Assert.Equal(60, yuk.GetProperty("etkinlikDk").GetInt32());
        Assert.Equal(360, yuk.GetProperty("kapasiteDk").GetInt32());
        Assert.Equal(0, yuk.GetProperty("asimDk").GetInt32());
        Assert.Equal(255, yuk.GetProperty("bosDk").GetInt32());
        Assert.Equal(3, yuk.GetProperty("tahminsizSayi").GetInt32());

        // Every item carries its day: the list's day for the plan, the events and the reminders of that day; a late task keeps its due day.
        Assert.All(gun.GetProperty("ogeler").EnumerateArray(), o => Assert.Equal(JsonValueKind.String, o.GetProperty("tarih").ValueKind));
        Assert.Equal(BugunMetni, rapor.GetProperty("tarih").GetString());
        Assert.Equal(BugunMetni, gorev.GetProperty("tarih").GetString());
        Assert.Equal("2026-11-05", gecikmis.GetProperty("tarih").GetString());
        Assert.Equal(BugunMetni, etkinlik.GetProperty("tarih").GetString());
        Assert.Equal(BugunMetni, own.GetProperty("tarih").GetString());

        var kaynaklar = gun.GetProperty("kaynaklar");
        Assert.Equal("tamam", kaynaklar.GetProperty("plan").GetString());
        Assert.Equal("kapali", kaynaklar.GetProperty("google").GetString());
    }

    [Fact]
    public async Task Gun_ALateOpenReminderShowsOnToday_AClosedOneAsDone_AndATaskReminderJoinsTheLateTask()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [], geciken: "[" + Geciken("eski-is", "Eski iş", "2026-11-05", 4) + "]"));
        var gecikmis = await HatirlaticiEkleAsync("Dünkü hatırlatıcı", BugunGunu.AddDays(-2), new TimeOnly(9, 0));
        var tamam = await HatirlaticiEkleAsync("Sabah ilacı", BugunGunu, new TimeOnly(6, 0), durum: HatirlaticiDurumu.Tamam);
        var gorevBagli = await HatirlaticiEkleAsync("Eski işi hatırla", BugunGunu, new TimeOnly(18, 0), gorev: "eski-is");

        var gun = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));

        var gec = Oge(gun, $"h:{gecikmis.Id}");
        Assert.Equal("acik", gec.GetProperty("durum").GetString());
        Assert.Equal(2, gec.GetProperty("gecikmeGun").GetInt32());
        Assert.Equal(JsonValueKind.Null, gec.GetProperty("saat").ValueKind);
        Assert.Equal("yapildi", Oge(gun, $"h:{tamam.Id}").GetProperty("durum").GetString());

        // The reminder tied to the task joins the task's row (and gives it its hour); it is not a row of its own.
        var gorev = Oge(gun, "g:eski-is");
        Assert.Equal(gorevBagli.Id, gorev.GetProperty("hatirlatici").GetProperty("id").GetGuid());
        Assert.Equal("18:00", gorev.GetProperty("saat").GetString());
        Assert.DoesNotContain(gun.GetProperty("ogeler").EnumerateArray(), o => o.GetProperty("kimlik").GetString() == $"h:{gorevBagli.Id}");
    }

    [Fact]
    public async Task Gun_ARepeatingReminderShowsOnItsDays_AndADayAfterTheLastItIsStillThere()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun goster", GunJson("2026-11-11", []));
        // Every Monday and Wednesday from today on.
        var haftalik = await HatirlaticiEkleAsync(
            "Spor", BugunGunu, new TimeOnly(19, 0), Tekrar.Haftalik, gunler: Gunler.Pzt | Gunler.Car);

        // Wednesday 11 Nov is a day of the rule; Tuesday 10 Nov is not.
        var carsamba = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/2026-11-11", sahip, fabrika));
        var oge = Oge(carsamba, $"h:{haftalik.Id}");
        Assert.Equal("19:00", oge.GetProperty("saat").GetString());
        Assert.Equal("haftalik", oge.GetProperty("hatirlatici").GetProperty("tekrar").GetString());
        Assert.Equal(["pzt", "car"], oge.GetProperty("hatirlatici").GetProperty("gunler").EnumerateArray().Select(g => g.GetString()));

        var sali = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/2026-11-10", sahip, fabrika));
        Assert.DoesNotContain(sali.GetProperty("ogeler").EnumerateArray(), o => o.GetProperty("kimlik").GetString() == $"h:{haftalik.Id}");
    }

    [Fact]
    public async Task Gun_ForAnotherDay_HasNoLeftoversAndNoSummary()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun goster", GunJson("2026-11-10", [Madde("a3f09c", "Yarın işi")]));

        var gun = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/2026-11-10", sahip, fabrika));

        Assert.False(gun.GetProperty("bugun").GetBoolean());
        Assert.Empty(gun.GetProperty("dundenKalanlar").EnumerateArray());
        Assert.Equal(JsonValueKind.Null, gun.GetProperty("ozet").ValueKind);
        Assert.Single(gun.GetProperty("ogeler").EnumerateArray());
        // Late tasks are today's business only.
        Assert.Equal(1, BeyinCagrisi("gun", "goster"));
    }

    [Fact]
    public async Task Dunden_LeftoversAreYesterdaysOpenItems_AndBirakTakesOneOutWithoutTouchingTheBrain()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [Madde("a3f09c", "Bugünün işi")]));
        Beyin.CiktiTarihli("gun goster", DunMetni, GunJson(DunMetni,
        [
            Madde("d1d1d1", "Dünkü iş ~20dk", tahmin: 20, proje: "kitap-kulubu"),
            Madde("d2d2d2", "Dünkü ikinci iş"),
            Madde("d3d3d3", "Zaten yapıldı", durum: "yapildi"),
            Madde("g:eski-is", "Eski iş", gorev: "eski-is"),
        ]));
        Beyin.CiktiTarihli("gun goster", BugunMetni, GunJson(BugunMetni, [Madde("a3f09c", "Bugünün işi")],
            geciken: "[" + Geciken("eski-is", "Eski iş", "2026-11-05", 4) + "]"));

        var once = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));
        // Open ones only; the task that already shows as late is not repeated here.
        Assert.Equal(["d1d1d1", "d2d2d2"], once.GetProperty("dundenKalanlar").EnumerateArray().Select(d => d.GetProperty("maddeId").GetString()));
        var ilk = once.GetProperty("dundenKalanlar")[0];
        Assert.Equal("Dünkü iş", ilk.GetProperty("baslik").GetString());
        Assert.Equal(20, ilk.GetProperty("tahminDk").GetInt32());
        Assert.Equal("kitap-kulubu", ilk.GetProperty("proje").GetString());

        var yazmadanOnce = Beyin.Cagrilar().Count;
        var birak = await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/dunden/d1d1d1/birak", sahip, fabrika);
        Assert.Equal(HttpStatusCode.OK, birak.StatusCode);
        var govde = await OkuAsync(birak);
        Assert.Equal("d1d1d1", govde.GetProperty("maddeId").GetString());
        Assert.True(govde.GetProperty("birakildi").GetBoolean());
        // Again: the same answer, still one row.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/dunden/d1d1d1/birak", sahip, fabrika)).StatusCode);
        Assert.Equal(yazmadanOnce, Beyin.Cagrilar().Count);
        await using (var db = YeniDb())
            Assert.Equal(1, await db.BirakilanMaddeler.CountAsync(Ct));

        var sonra = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));
        Assert.Equal(["d2d2d2"], sonra.GetProperty("dundenKalanlar").EnumerateArray().Select(d => d.GetProperty("maddeId").GetString()));

        // A bad id is a 400 and writes nothing.
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/dunden/yanlis/birak", sahip, fabrika)).StatusCode);
        await using (var db = YeniDb())
            Assert.Equal(1, await db.BirakilanMaddeler.CountAsync(Ct));
    }

    [Fact]
    public async Task Birak_NeedsThePlanPermission()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinKapatAsync(sahip, "plan.yaz", fabrika);
        var yol = $"/api/gun/{BugunMetni}/dunden/d1d1d1/birak";

        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Post, yol, null, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, yol, asistan, fabrika)).StatusCode);
        await using var db = YeniDb();
        Assert.Equal(0, await db.BirakilanMaddeler.CountAsync(Ct));

        await IzinAsync(sahip, "plan.yaz", fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, yol, asistan, fabrika)).StatusCode);
    }

    [Fact]
    public async Task Gun_NeedsTheCalendarPermission_AndAGoodDate()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun goster", GunJson(BugunMetni, []));
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinKapatAsync(sahip, "takvim.oku", fabrika);

        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, "/api/gun/bugun", null, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/gun/bugun", asistan, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/takvim?baslangic=2026-11-01&bitis=2026-11-30", asistan, fabrika)).StatusCode);
        Assert.Empty(Beyin.Cagrilar());

        await IzinAsync(sahip, "takvim.oku", fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/gun/bugun", asistan, fabrika)).StatusCode);
        foreach (var kotu in new[] { "dun", "2026-13-40", "09-11-2026", "1999-01-01" })
            Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, $"/api/gun/{kotu}", sahip, fabrika)).StatusCode);
    }

    [Fact]
    public async Task Gun_WithoutABrain_SaysSoInsteadOfFailing_AndAnUnreadablePlanIsNotAnEmptyDay()
    {
        await GunTemizleAsync();
        var brainsiz = Fabrika(Pazartesi, google: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, brainsiz);
        await HatirlaticiEkleAsync("Eczaneye uğra", BugunGunu, new TimeOnly(16, 30));

        var gun = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, brainsiz));
        Assert.Equal("yok", gun.GetProperty("kaynaklar").GetProperty("plan").GetString());
        Assert.Single(gun.GetProperty("ogeler").EnumerateArray());

        Beyin.Mod = "hata";
        var bozuk = GunFabrikasi();
        var sahip2 = await GirisAsync(UygulamaFabrikasi.SahipEposta, bozuk);
        var okunamayan = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip2, bozuk));
        Assert.Equal("okunamadi", okunamayan.GetProperty("kaynaklar").GetProperty("plan").GetString());
        Assert.Single(okunamayan.GetProperty("ogeler").EnumerateArray());
    }

    [Fact]
    public async Task Ozet_IsTheFirstCardOfTheStoredBriefing_ElseALineFromTheNumbers_AndNullWhenThereIsNothing()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [Madde("a3f09c", "Rapor ~30dk", tahmin: 30), Madde("b4e1d2", "Mail ~45dk", tahmin: 45)]));

        var kural = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));
        Assert.Equal("Bugün 2 açık iş var, tahmini 1 sa 15 dk.", kural.GetProperty("ozet").GetString());

        await using (var db = YeniDb())
        {
            db.Brifingler.Add(new GunlukBrifing
            {
                Gun = BugunGunu, UretimAni = Pazartesi.ToUniversalTime(), Yontem = BrifingYontemi.Hesap,
                Kartlar = JsonSerializer.Serialize(new[] { new BrifingKarti("plan", "Bugün", "Sakin bir gün: iki iş var.", []), new BrifingKarti("bos", "x", "ikinci", []) }, new JsonSerializerOptions(JsonSerializerDefaults.Web)),
            });
            await db.SaveChangesAsync(Ct);
        }

        var brifingli = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));
        Assert.Equal("Sakin bir gün: iki iş var.", brifingli.GetProperty("ozet").GetString());

        await using (var db = YeniDb())
            await db.Brifingler.ExecuteDeleteAsync(Ct);
        Beyin.Cikti("gun goster", GunJson(BugunMetni, []));
        var bos = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));
        Assert.Equal(JsonValueKind.Null, bos.GetProperty("ozet").ValueKind);
    }

    // The day capacity (§5)

    [Fact]
    public async Task Ayar_FallsBackToTheConfiguredHours_ThenTheSahipSetsWeekdayAndWeekendApart_AndEveryReaderUsesIt()
    {
        var (fabrika, sahip) = await HazirlaAsync(kapasiteSaat: "5");
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinAsync(sahip, "takvim.oku", fabrika);
        // 2026-11-14 is a Saturday. 200 minutes of open estimates every day.
        foreach (var gun in new[] { BugunMetni, "2026-11-14" })
            Beyin.CiktiTarihli("gun goster", gun, GunJson(gun, [Madde("a3f09c", "Büyük iş ~3s20dk", tahmin: 200)]));

        // Without a row: Gun:KapasiteSaat for both kinds of day.
        var yedek = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/ayarlar/gun", asistan, fabrika));
        Assert.Equal(300, yedek.GetProperty("haftaIciDk").GetInt32());
        Assert.Equal(300, yedek.GetProperty("haftaSonuDk").GetInt32());

        // Only the Sahip sets it; the same input is refused when it is out of range.
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Put, "/api/ayarlar/gun", asistan, fabrika, new { haftaIciDk = 120, haftaSonuDk = 60 })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Put, "/api/ayarlar/gun", null, fabrika, new { haftaIciDk = 120, haftaSonuDk = 60 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Put, "/api/ayarlar/gun", sahip, fabrika, new { haftaIciDk = 0, haftaSonuDk = 60 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Put, "/api/ayarlar/gun", sahip, fabrika, new { haftaIciDk = 120 })).StatusCode);
        var koy = await GonderAsync(HttpMethod.Put, "/api/ayarlar/gun", sahip, fabrika, new { haftaIciDk = 240, haftaSonuDk = 120 });
        Assert.Equal(HttpStatusCode.OK, koy.StatusCode);
        Assert.Equal(120, (await OkuAsync(koy)).GetProperty("haftaSonuDk").GetInt32());
        // Putting it again changes the one row.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Put, "/api/ayarlar/gun", sahip, fabrika, new { haftaIciDk = 250, haftaSonuDk = 120 })).StatusCode);
        await using (var db = YeniDb())
            Assert.Equal(1, await db.GunAyarlari.CountAsync(Ct));

        var okunan = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/ayarlar/gun", asistan, fabrika));
        Assert.Equal(250, okunan.GetProperty("haftaIciDk").GetInt32());

        // The day view: Monday 250, Saturday 120 (so 80 over).
        var pazartesi = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika))).GetProperty("yuk");
        Assert.Equal(250, pazartesi.GetProperty("kapasiteDk").GetInt32());
        Assert.Equal(0, pazartesi.GetProperty("asimDk").GetInt32());
        Assert.Equal(50, pazartesi.GetProperty("bosDk").GetInt32());
        var cumartesi = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/2026-11-14", sahip, fabrika))).GetProperty("yuk");
        Assert.Equal(120, cumartesi.GetProperty("kapasiteDk").GetInt32());
        Assert.Equal(80, cumartesi.GetProperty("asimDk").GetInt32());
        Assert.Equal(0, cumartesi.GetProperty("bosDk").GetInt32());

        // The brain's own day warning reads the same setting, and so does the timeline.
        var uyari = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/beyin/gunler/2026-11-14", sahip, fabrika))).GetProperty("kapasiteUyarisi");
        Assert.Equal(120, uyari.GetProperty("kapasiteDk").GetInt32());
        Assert.Equal(80, uyari.GetProperty("asimDk").GetInt32());
        Assert.Equal(JsonValueKind.Null, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/beyin/gunler/" + BugunMetni, sahip, fabrika))).GetProperty("kapasiteUyarisi").ValueKind);
        var cizelge = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/zaman-cizelgesi?gun=2026-11-14", sahip, fabrika));
        Assert.Equal(120, cizelge.GetProperty("kapasite").GetProperty("kapasiteDk").GetInt32());
    }
}
