using System.Net;
using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// A new item of the day with its reminder (K-0024, sözleşme §4) and the reminder shortcut of an item (§2), through the whole app with a
// fake brain: the estimate goes in the brain's own syntax, the reminder is tied to the item that was just written, what is wrong is
// refused before anything is written, and a repeated request is applied once.
public sealed class GunOgeApiTests(UygulamaFabrikasi uygulama) : GunTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private const string Yarin = "2026-11-10";
    private const string Yeni = "e1e1e1";

    private async Task<(WebApplicationFactory<Program> Fabrika, string Sahip)> HazirlaAsync()
    {
        await GunTemizleAsync();
        var fabrika = GunFabrikasi();
        Beyin.Cikti("gun ekle", $$"""{"tarih": "{{Yarin}}", "madde": {{Madde(Yeni, "Rapor yaz ~30dk", tahmin: 30)}}, "tahmin_onerisi": null}""");
        Beyin.Cikti("gun goster", GunJson(Yarin, [Madde(Yeni, "Rapor yaz ~30dk", tahmin: 30)]));
        return (fabrika, await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika));
    }

    private async Task<List<Hatirlatici>> HatirlaticilariOkuAsync()
    {
        await using var db = YeniDb();
        return await db.Hatirlaticilar.AsNoTracking().ToListAsync(Ct);
    }

    // §4

    [Fact]
    public async Task OgeEkle_WritesTheItemWithTheEstimateInTheBrainsSyntax_AndAnswersWithTheListItem()
    {
        var (fabrika, sahip) = await HazirlaAsync();

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gun/{Yarin}/ogeler", sahip, fabrika, new { baslik = "  Rapor yaz ", tahminDk = 30, bolum = "Sabah", proje = "kitap-kulubu" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var oge = await OkuAsync(yanit);
        Assert.Equal($"m:{Yeni}", oge.GetProperty("kimlik").GetString());
        Assert.Equal("plan", oge.GetProperty("tur").GetString());
        Assert.Equal("Rapor yaz", oge.GetProperty("baslik").GetString());
        Assert.Equal(30, oge.GetProperty("tahminDk").GetInt32());
        var ekle = Beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Single(a => a[0] == "gun" && a[1] == "ekle");
        Assert.Contains($"--tarih={Yarin}", ekle);
        Assert.Contains("--bolum=Sabah", ekle);
        Assert.Equal("Rapor yaz ~30dk", ekle[^1]);
        Assert.Empty(await HatirlaticilariOkuAsync());
    }

    [Fact]
    public async Task OgeEkle_WithAReminder_TiesItToTheNewItem_AndTheFormsHourIsTheRemindersWhenItHasNone()
    {
        var (fabrika, sahip) = await HazirlaAsync();

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/gun/{Yarin}/ogeler", sahip, fabrika, new
        {
            baslik = "Rapor yaz", saat = "09:30", tahminDk = 30,
            hatirlatici = new { tekrar = "gunluk", acil = true, israrli = true, onceGun = 1 },
        });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var h = Assert.Single(await HatirlaticilariOkuAsync());
        Assert.Equal(Yeni, h.MaddeId);
        Assert.Equal(new DateOnly(2026, 11, 10), h.MaddeTarihi);
        Assert.Equal(new DateOnly(2026, 11, 10), h.Gun);
        Assert.Equal("Rapor yaz", h.Baslik);
        Assert.Equal(new TimeOnly(9, 30), h.Saat);
        Assert.Equal(Tekrar.Gunluk, h.Tekrar);
        Assert.True(h.Acil);
        Assert.True(h.Israrli);
        Assert.Equal(1, h.OnceGun);
        Assert.Equal(HatirlaticiHesap.An(new DateOnly(2026, 11, 10), new TimeOnly(9, 30)), h.SonrakiAn);
        // The answer is the item with its reminder.
        var oge = await OkuAsync(yanit);
        Assert.Equal(h.Id, oge.GetProperty("hatirlatici").GetProperty("id").GetGuid());
        Assert.Equal("09:30", oge.GetProperty("saat").GetString());

        // The reminder's own hour wins over the form's.
        await GonderAsync(HttpMethod.Post, $"/api/gun/{Yarin}/ogeler", sahip, fabrika, new
        {
            baslik = "İkinci", saat = "09:30", hatirlatici = new { saat = "18:00", tekrar = "yok" },
        });
        Assert.Contains(await HatirlaticilariOkuAsync(), x => x.Baslik == "Rapor yaz" && x.Saat == new TimeOnly(9, 30));
        Assert.Equal(2, (await HatirlaticilariOkuAsync()).Count);
        Assert.Contains(await HatirlaticilariOkuAsync(), x => x.Saat == new TimeOnly(18, 0));
    }

    [Fact]
    public async Task OgeEkle_WhatIsWrongIsRefusedBeforeAnythingIsWritten()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var kotuler = new (string Yol, object Govde)[]
        {
            ($"/api/gun/{Yarin}/ogeler", new { tahminDk = 30 }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = "   " }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = new string('x', 201) }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = "x", tahminDk = 0 }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = "x", tahminDk = 721 }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = "x", hatirlatici = new { tekrar = "yok", onceGun = 99 } }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = "x", hatirlatici = new { tekrar = "haftalik", gunler = new[] { "yok" } } }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = "x", hatirlatici = new { tekrar = "haftalik", gunler = new[] { "pazartesi" } } }),
            ("/api/gun/yarin/ogeler", new { baslik = "x" }),
            ($"/api/gun/{Yarin}/ogeler", new { baslik = "x", bolum = "Kapanış" }),
        };

        foreach (var (yol, govde) in kotuler)
            Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, yol, sahip, fabrika, govde)).StatusCode);

        Assert.Equal(0, BeyinCagrisi("gun", "ekle"));
        Assert.Empty(await HatirlaticilariOkuAsync());
    }

    [Fact]
    public async Task OgeEkle_NeedsThePlanPermission_AndTheReminderPermissionWhenItAsksForAReminder()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinKapatAsync(sahip, "plan.yaz", fabrika);
        await IzinKapatAsync(sahip, "hatirlatici.yaz", fabrika);
        var yol = $"/api/gun/{Yarin}/ogeler";
        var duz = new { baslik = "Rapor yaz" };
        var hatirlaticili = new { baslik = "Rapor yaz", hatirlatici = new { tekrar = "yok", saat = "10:00" } };

        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Post, yol, null, fabrika, duz)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, yol, asistan, fabrika, duz)).StatusCode);
        await IzinAsync(sahip, "plan.yaz", fabrika);
        // Plan permission only: a plain item goes through, one that wants a reminder does not (and nothing is written for it).
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, yol, asistan, fabrika, hatirlaticili)).StatusCode);
        Assert.Equal(0, BeyinCagrisi("gun", "ekle"));
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, yol, asistan, fabrika, duz)).StatusCode);
        await IzinAsync(sahip, "hatirlatici.yaz", fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, yol, asistan, fabrika, hatirlaticili)).StatusCode);
        Assert.Single(await HatirlaticilariOkuAsync());
    }

    [Fact]
    public async Task OgeEkle_ARefusalOfTheBrainWritesNoReminder_AndARepeatedKeyIsAppliedOnce()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var yol = $"/api/gun/{Yarin}/ogeler";
        var govde = new { baslik = "Rapor yaz", hatirlatici = new { tekrar = "yok", saat = "10:00" } };

        Beyin.Cikti("gun ekle", """{"hata": {"kod": "gun-kapali", "mesaj": "kapandı"}}""", cikis: 1);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, yol, sahip, fabrika, govde)).StatusCode);
        Assert.Empty(await HatirlaticilariOkuAsync());

        Beyin.Cikti("gun ekle", $$"""{"tarih": "{{Yarin}}", "madde": {{Madde(Yeni, "Rapor yaz", tahmin: null)}}, "tahmin_onerisi": null}""");
        var anahtar = Anahtar();
        var ilk = await AnahtarliGonderAsync(HttpMethod.Post, yol, sahip, fabrika, govde, anahtar);
        var ikinci = await AnahtarliGonderAsync(HttpMethod.Post, yol, sahip, fabrika, govde, anahtar);
        Assert.Equal(HttpStatusCode.OK, ilk.StatusCode);
        Assert.True(ikinci.Headers.Contains("Idempotent-Replayed"));
        Assert.Equal(await ilk.Content.ReadAsStringAsync(Ct), await ikinci.Content.ReadAsStringAsync(Ct));
        Assert.Single(await HatirlaticilariOkuAsync());
    }

    // §2: the reminder of an item

    [Fact]
    public async Task Shortcut_SetsUpChangesAndRemovesTheReminderOfAnItem()
    {
        await GunTemizleAsync();
        var fabrika = GunFabrikasi();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [Madde("a3f09c", "Rapor yaz ~30dk", tahmin: 30)]));
        var yol = $"/api/gun/{BugunMetni}/ogeler/m:a3f09c/hatirlatici";

        // Setting it up: the title is the item's, the link names the item and its day. The clock is Monday 07:00, the rule is Monday and Friday.
        var kur = await GonderAsync(HttpMethod.Post, yol, sahip, fabrika, new { saat = "14:00", tekrar = "haftalik", gunler = new[] { "pzt", "cum" }, acil = true, israrli = true, onceGun = 1 });
        Assert.Equal(HttpStatusCode.Created, kur.StatusCode);
        var h = await OkuAsync(kur);
        Assert.Equal("Rapor yaz", h.GetProperty("baslik").GetString());
        Assert.Equal("a3f09c", h.GetProperty("maddeId").GetString());
        Assert.Equal(BugunMetni, h.GetProperty("maddeTarihi").GetString());
        Assert.Equal(["pzt", "cum"], h.GetProperty("gunler").EnumerateArray().Select(g => g.GetString()));
        Assert.Equal("haftalik", h.GetProperty("tekrar").GetString());
        Assert.Equal(HatirlaticiHesap.An(BugunGunu, new TimeOnly(14, 0)), h.GetProperty("sonrakiAn").GetDateTimeOffset().ToUniversalTime());
        var id = h.GetProperty("id").GetGuid();

        // One per item.
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, yol, sahip, fabrika, new { tekrar = "yok" })).StatusCode);

        // The day shows it on the item.
        var gun = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/gun/{BugunMetni}", sahip, fabrika));
        var oge = gun.GetProperty("ogeler").EnumerateArray().Single(o => o.GetProperty("kimlik").GetString() == "m:a3f09c");
        Assert.Equal(id, oge.GetProperty("hatirlatici").GetProperty("id").GetGuid());
        Assert.Equal("14:00", oge.GetProperty("saat").GetString());

        // Changing it: the rule is the new one, the title and the link stay.
        var degis = await GonderAsync(HttpMethod.Put, yol, sahip, fabrika, new { saat = "15:00", tekrar = "yok", gunler = new[] { "pzt" } });
        Assert.Equal(HttpStatusCode.OK, degis.StatusCode);
        var yeni = await OkuAsync(degis);
        Assert.Equal(id, yeni.GetProperty("id").GetGuid());
        Assert.Equal("Rapor yaz", yeni.GetProperty("baslik").GetString());
        Assert.Equal("a3f09c", yeni.GetProperty("maddeId").GetString());
        Assert.Empty(yeni.GetProperty("gunler").EnumerateArray());
        Assert.Equal("yok", yeni.GetProperty("tekrar").GetString());
        Assert.Equal(new TimeOnly(15, 0), (await HatirlaticilariOkuAsync()).Single().Saat);

        // Taking it away.
        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Delete, yol, sahip, fabrika)).StatusCode);
        Assert.Empty(await HatirlaticilariOkuAsync());
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Delete, yol, sahip, fabrika)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Put, yol, sahip, fabrika, new { tekrar = "yok" })).StatusCode);
    }

    [Fact]
    public async Task Shortcut_ATaskReminderIsTiedByTheTasksSlug_AndWhatIsNotAnItemIsRefused()
    {
        await GunTemizleAsync();
        var fabrika = GunFabrikasi();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        Beyin.Cikti("gorev liste", GorevListesi);
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [Madde("g:uye-girisi", "Üye girişi", gorev: "uye-girisi")]));

        var kur = await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/ogeler/g:uye-girisi/hatirlatici", sahip, fabrika, new { saat = "17:00", tekrar = "yok" });
        Assert.Equal(HttpStatusCode.Created, kur.StatusCode);
        var h = Assert.Single(await HatirlaticilariOkuAsync());
        Assert.Equal("uye-girisi", h.GorevKimligi);
        Assert.Null(h.MaddeId);
        Assert.Null(h.MaddeTarihi);
        Assert.Equal("Üye girişi", h.Baslik);

        // An item that is not in that day's list is a 404, a reminder or an event is not an item, a bad body is a 400.
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/ogeler/m:b4e1d2/hatirlatici", sahip, fabrika, new { tekrar = "yok" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/ogeler/h:{Guid.NewGuid()}/hatirlatici", sahip, fabrika, new { tekrar = "yok" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/ogeler/e:{Guid.NewGuid()}/hatirlatici", sahip, fabrika, new { tekrar = "yok" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/ogeler/g:baska/hatirlatici", sahip, fabrika, new { tekrar = "yok", onceGun = 61 })).StatusCode);
        Assert.Single(await HatirlaticilariOkuAsync());
    }

    [Fact]
    public async Task Shortcut_NeedsTheReminderPermission_AndABrainToFindTheItem()
    {
        await GunTemizleAsync();
        var fabrika = GunFabrikasi();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [Madde("a3f09c", "Rapor yaz")]));
        await IzinKapatAsync(sahip, "hatirlatici.yaz", fabrika);
        var yol = $"/api/gun/{BugunMetni}/ogeler/m:a3f09c/hatirlatici";

        foreach (var yontem in new[] { HttpMethod.Post, HttpMethod.Put, HttpMethod.Delete })
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(yontem, yol, null, fabrika, new { tekrar = "yok" })).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(yontem, yol, asistan, fabrika, new { tekrar = "yok" })).StatusCode);
        }

        Assert.Empty(await HatirlaticilariOkuAsync());

        // Without a brain the item cannot be found: 503, nothing is written.
        var brainsiz = Fabrika(Pazartesi, google: false);
        var sahip2 = await GirisAsync(UygulamaFabrikasi.SahipEposta, brainsiz);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await GonderAsync(HttpMethod.Post, yol, sahip2, brainsiz, new { tekrar = "yok" })).StatusCode);
        Assert.Empty(await HatirlaticilariOkuAsync());
    }
}
