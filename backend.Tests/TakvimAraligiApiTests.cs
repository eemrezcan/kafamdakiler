using System.Net;
using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The calendar's range view (K-0024, sözleşme §3) through the whole app: a count per day for the month grid (plan only around today,
// tasks from one call, reminders and events from the database), the overloaded days, what is coming, and the limits of the range.
public sealed class TakvimAraligiApiTests(UygulamaFabrikasi uygulama) : GunTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private async Task<(WebApplicationFactory<Program> Fabrika, string Sahip)> HazirlaAsync()
    {
        await GunTemizleAsync();
        var fabrika = GunFabrikasi();
        Beyin.Cikti("gun goster", GunJson(BugunMetni, []));
        Beyin.Cikti("gorev liste", "[]");
        return (fabrika, await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika));
    }

    private static JsonElement Gun(JsonElement aralik, string tarih) =>
        aralik.GetProperty("gunler").EnumerateArray().Single(g => g.GetProperty("tarih").GetString() == tarih);

    private static int Sayi(JsonElement aralik, string tarih, string tur) => Gun(aralik, tarih).GetProperty("sayilar").GetProperty(tur).GetInt32();

    private async Task<JsonElement> AralikAsync(WebApplicationFactory<Program> fabrika, string sahip, string baslangic, string bitis)
    {
        var yanit = await GonderAsync(HttpMethod.Get, $"/api/takvim?baslangic={baslangic}&bitis={bitis}", sahip, fabrika);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return await OkuAsync(yanit);
    }

    [Fact]
    public async Task Takvim_TheRangeHasALimit_AndNeedsGoodDatesAndThePermission()
    {
        var (fabrika, sahip) = await HazirlaAsync();

        // 42 days, both ends counted, is the most.
        var tam = await AralikAsync(fabrika, sahip, "2026-11-01", "2026-12-12");
        Assert.Equal(42, tam.GetProperty("gunler").GetArrayLength());
        Assert.Equal("2026-11-01", tam.GetProperty("gunler")[0].GetProperty("tarih").GetString());
        Assert.Equal("2026-12-12", tam.GetProperty("gunler")[41].GetProperty("tarih").GetString());
        var tekGun = await AralikAsync(fabrika, sahip, "2026-11-09", "2026-11-09");
        Assert.Equal(1, tekGun.GetProperty("gunler").GetArrayLength());

        foreach (var kotu in new[]
        {
            "baslangic=2026-11-01&bitis=2026-12-13", "baslangic=2026-11-05&bitis=2026-11-04", "baslangic=bugun&bitis=2026-11-04",
            "baslangic=2026-11-01", "bitis=2026-11-01", "baslangic=2026-13-01&bitis=2026-13-02", "baslangic=1999-01-01&bitis=1999-01-02",
        })
            Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, $"/api/takvim?{kotu}", sahip, fabrika)).StatusCode);

        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinKapatAsync(sahip, "takvim.oku", fabrika);
        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, "/api/takvim?baslangic=2026-11-01&bitis=2026-11-02", null, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/takvim?baslangic=2026-11-01&bitis=2026-11-02", asistan, fabrika)).StatusCode);
    }

    [Fact]
    public async Task Takvim_CountsWhatEachDayHolds()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        // The plan: two items on Monday 9th (and a made-up item for a task, which is counted with the tasks), one on Tuesday 10th.
        Beyin.CiktiTarihli("gun goster", "2026-11-09", GunJson("2026-11-09", [Madde("a3f09c", "Rapor"), Madde("b4e1d2", "Mail"), Madde("g:uye-girisi", "Üye girişi", gorev: "uye-girisi")]));
        Beyin.CiktiTarihli("gun goster", "2026-11-10", GunJson("2026-11-10", [Madde("c5d6e7", "Kitap")]));
        // Tasks: two are due on the 12th, one has no date.
        Beyin.Cikti("gorev liste", """
            [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "gizli": false, "bitis": "2026-11-12"},
             {"kimlik": "rapor", "baslik": "Rapor", "durum": "aktif", "alan": "ogrenme", "yol": "ogrenme/gorevler/rapor.md", "gizli": false, "bitis": "2026-11-12"},
             {"kimlik": "tarihsiz", "baslik": "Tarihsiz", "durum": "aktif", "alan": "ogrenme", "yol": "ogrenme/gorevler/tarihsiz.md", "gizli": false, "bitis": null}]
            """);
        // Reminders: one-off on the 10th, daily from the 9th, one tied to a plan item (shows with the item), one archived.
        await HatirlaticiEkleAsync("Tek", new DateOnly(2026, 11, 10), new TimeOnly(10, 0));
        await HatirlaticiEkleAsync("Her gün", BugunGunu, new TimeOnly(8, 0), Tekrar.Gunluk);
        await HatirlaticiEkleAsync("Maddeye bağlı", new DateOnly(2026, 11, 10), new TimeOnly(11, 0), maddeId: "c5d6e7", maddeTarihi: new DateOnly(2026, 11, 10));
        await HatirlaticiEkleAsync("Arşivde", new DateOnly(2026, 11, 10), new TimeOnly(12, 0), durum: HatirlaticiDurumu.Arsiv);
        // Events: a timed one on the 11th, an all-day one over the 12th to the 14th.
        await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 11, 10), IstAn(2026, 11, 11, 11));
        await TumGunEtkinligiEkleAsync("Konferans", new DateOnly(2026, 11, 12), new DateOnly(2026, 11, 14));

        var aralik = await AralikAsync(fabrika, sahip, "2026-11-09", "2026-11-15");

        Assert.Equal(7, aralik.GetProperty("gunler").GetArrayLength());
        Assert.Equal((2, 0, 1, 0), (Sayi(aralik, "2026-11-09", "plan"), Sayi(aralik, "2026-11-09", "gorev"), Sayi(aralik, "2026-11-09", "hatirlatici"), Sayi(aralik, "2026-11-09", "etkinlik")));
        Assert.Equal((1, 0, 2, 0), (Sayi(aralik, "2026-11-10", "plan"), Sayi(aralik, "2026-11-10", "gorev"), Sayi(aralik, "2026-11-10", "hatirlatici"), Sayi(aralik, "2026-11-10", "etkinlik")));
        Assert.Equal((0, 0, 1, 1), (Sayi(aralik, "2026-11-11", "plan"), Sayi(aralik, "2026-11-11", "gorev"), Sayi(aralik, "2026-11-11", "hatirlatici"), Sayi(aralik, "2026-11-11", "etkinlik")));
        foreach (var gun in new[] { "2026-11-12", "2026-11-13", "2026-11-14" })
            Assert.Equal(1, Sayi(aralik, gun, "etkinlik"));
        Assert.Equal(2, Sayi(aralik, "2026-11-12", "gorev"));
        Assert.Equal(0, Sayi(aralik, "2026-11-15", "etkinlik"));
        Assert.Equal(0, Sayi(aralik, "2026-11-13", "gorev"));
    }

    [Fact]
    public async Task Takvim_ThePlanIsReadOnlyAroundToday_AndNotAtAll_WhenTheDaysAreFarOff()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        // The brain says five items on every day: only the days from yesterday to a week from today are asked.
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [Madde("a1a1a1", "1"), Madde("a2a2a2", "2"), Madde("a3a3a3", "3"), Madde("a4a4a4", "4"), Madde("a5a5a5", "5")]));

        var aralik = await AralikAsync(fabrika, sahip, "2026-11-01", "2026-11-30");

        Assert.Equal(0, Sayi(aralik, "2026-11-07", "plan"));
        Assert.Equal(5, Sayi(aralik, "2026-11-08", "plan"));
        Assert.Equal(5, Sayi(aralik, "2026-11-16", "plan"));
        Assert.Equal(0, Sayi(aralik, "2026-11-17", "plan"));
        Assert.Equal(0, Sayi(aralik, "2026-11-30", "plan"));
        Assert.Equal(9, BeyinCagrisi("gun", "goster"));
        // One call for all the tasks, whatever the range.
        Assert.Equal(1, BeyinCagrisi("gorev", "liste"));
    }

    [Fact]
    public async Task Takvim_AnOverloadedDayIsMarked_ByThePersonsCapacityOfThatKindOfDay()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Put, "/api/ayarlar/gun", sahip, fabrika, new { haftaIciDk = 360, haftaSonuDk = 60 })).StatusCode);
        // Tuesday: 300 minutes of plan and a 90-minute meeting is over 360; Wednesday: 300 alone is not. Saturday: a 2-hour event is over 60.
        Beyin.CiktiTarihli("gun goster", "2026-11-10", GunJson("2026-11-10", [Madde("a3f09c", "Büyük iş", tahmin: 300)]));
        Beyin.CiktiTarihli("gun goster", "2026-11-11", GunJson("2026-11-11", [Madde("b4e1d2", "Büyük iş", tahmin: 300)]));
        await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 10, 10), IstAn(2026, 11, 10, 11, 30));
        await EtkinlikEkleAsync("Sosyal", IstAn(2026, 11, 14, 15), IstAn(2026, 11, 14, 17));

        var aralik = await AralikAsync(fabrika, sahip, "2026-11-09", "2026-11-15");

        Assert.True(Gun(aralik, "2026-11-10").GetProperty("yukAsimi").GetBoolean());
        Assert.False(Gun(aralik, "2026-11-11").GetProperty("yukAsimi").GetBoolean());
        Assert.True(Gun(aralik, "2026-11-14").GetProperty("yukAsimi").GetBoolean());
        Assert.False(Gun(aralik, "2026-11-09").GetProperty("yukAsimi").GetBoolean());
        Assert.False(Gun(aralik, "2026-11-15").GetProperty("yukAsimi").GetBoolean());
    }

    [Fact]
    public async Task Takvim_WithoutABrain_StillCountsRemindersAndEvents_AndTheTasksAndPlanAreZero()
    {
        await GunTemizleAsync();
        var brainsiz = Fabrika(Pazartesi, google: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, brainsiz);
        await HatirlaticiEkleAsync("Tek", new DateOnly(2026, 11, 10), new TimeOnly(10, 0));
        await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 10, 10), IstAn(2026, 11, 10, 11));

        var aralik = await AralikAsync(brainsiz, sahip, "2026-11-09", "2026-11-11");

        Assert.Equal((0, 0, 1, 1), (Sayi(aralik, "2026-11-10", "plan"), Sayi(aralik, "2026-11-10", "gorev"), Sayi(aralik, "2026-11-10", "hatirlatici"), Sayi(aralik, "2026-11-10", "etkinlik")));
        Assert.Empty(Beyin.Cagrilar());
    }

    // What is coming

    [Fact]
    public async Task Yaklasan_ListsRemindersTasksAndAllDayEventsOfTheNext30Days_SoonestFirst()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gorev liste", """
            [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "gizli": false, "bitis": "2026-11-12"},
             {"kimlik": "uzak", "baslik": "Uzak görev", "durum": "aktif", "alan": "ogrenme", "yol": "ogrenme/gorevler/uzak.md", "gizli": false, "bitis": "2026-12-20"},
             {"kimlik": "bugunku", "baslik": "Bugünkü görev", "durum": "aktif", "alan": "ogrenme", "yol": "ogrenme/gorevler/bugunku.md", "gizli": false, "bitis": "2026-11-09"}]
            """);
        var tekrar = await HatirlaticiEkleAsync("Spor", BugunGunu, new TimeOnly(19, 0), Tekrar.Gunluk);
        var yakin = await HatirlaticiEkleAsync("Vergi", new DateOnly(2026, 11, 20), new TimeOnly(9, 0));
        await HatirlaticiEkleAsync("Çok uzak", new DateOnly(2026, 12, 15), new TimeOnly(9, 0));
        await HatirlaticiEkleAsync("Geçmiş", new DateOnly(2026, 11, 5), new TimeOnly(9, 0));
        var gorevHatirlaticisi = await HatirlaticiEkleAsync("Üye girişi için", new DateOnly(2026, 11, 11), new TimeOnly(17, 0), gorev: "uye-girisi");
        await TumGunEtkinligiEkleAsync("Konferans", new DateOnly(2026, 11, 18), new DateOnly(2026, 11, 19));
        // An all-day event that started before tomorrow and runs into the window shows once, from the first day of it.
        await TumGunEtkinligiEkleAsync("Tatil", new DateOnly(2026, 11, 8), new DateOnly(2026, 11, 11));

        var aralik = await AralikAsync(fabrika, sahip, "2026-11-09", "2026-11-09");
        var yaklasan = aralik.GetProperty("yaklasan").EnumerateArray().ToList();
        var kimlikler = yaklasan.Select(o => o.GetProperty("kimlik").GetString()!).Select(k => k.StartsWith("e:") ? "e:" : k).ToList();

        // Tomorrow first: the all-day event that runs into it, then the daily reminder's next turn (shown once); the task due the 12th with its
        // own reminder (joined, not a row of its own); the 18th; the 20th. No past reminder, no day beyond 30 days, no task due today or far off.
        Assert.Equal(["e:", $"h:{tekrar.Id}", "g:uye-girisi", "e:", $"h:{yakin.Id}"], kimlikler);
        Assert.DoesNotContain(kimlikler, k => k == $"h:{gorevHatirlaticisi.Id}");
        var gorev = yaklasan.Single(o => o.GetProperty("kimlik").GetString() == "g:uye-girisi");
        Assert.Equal("gorev", gorev.GetProperty("tur").GetString());
        Assert.Equal("17:00", gorev.GetProperty("saat").GetString());
        Assert.Equal(gorevHatirlaticisi.Id, gorev.GetProperty("hatirlatici").GetProperty("id").GetGuid());
        var tatil = yaklasan.First(o => o.GetProperty("tur").GetString() == "etkinlik");
        Assert.Equal("Tatil", tatil.GetProperty("baslik").GetString());
        Assert.True(tatil.GetProperty("tumGun").GetBoolean());
        // Every row says the day it is coming on (E1): the day of its moment, its due day, the day the event starts in the window.
        Assert.Equal(
            ["2026-11-10", "2026-11-10", "2026-11-12", "2026-11-18", "2026-11-20"],
            yaklasan.Select(o => o.GetProperty("tarih").GetString()));
        // The ones that are not on the list are really not in it (the daily reminder shows its next turn, the 10th).
        Assert.Equal(5, yaklasan.Count);
    }

    [Fact]
    public async Task Yaklasan_HoldsTwentyAtMost()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        for (var i = 0; i < 25; i++)
            await HatirlaticiEkleAsync($"H{i:00}", new DateOnly(2026, 11, 10).AddDays(i % 20), new TimeOnly(8 + i % 10, 0));

        var aralik = await AralikAsync(fabrika, sahip, "2026-11-09", "2026-11-09");
        var yaklasan = aralik.GetProperty("yaklasan").EnumerateArray().ToList();

        Assert.Equal(20, yaklasan.Count);
        // Soonest first: the earliest day with the earliest hour.
        Assert.Equal("08:00", yaklasan[0].GetProperty("saat").GetString());
    }
}
