using System.Net;
using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The one "yaptım" of the day view (K-0024, sözleşme §1.1) and the chain between a task and its reminder (§1.2), through the whole app
// with a fake brain: the id's prefix decides where it goes, what is tied together closes together (both ways, and from every old
// route too), a failed step of the chain never undoes the first, and a repeated request is applied once.
public sealed class GunYaptimApiTests(UygulamaFabrikasi uygulama) : GunTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private const string Rapor = "a3f09c";

    private static string YaptimYolu(string tarih = BugunMetni) => $"/api/gun/{tarih}/yaptim";

    private async Task<(WebApplicationFactory<Program> Fabrika, string Sahip)> HazirlaAsync()
    {
        await GunTemizleAsync();
        var fabrika = GunFabrikasi();
        Beyin.Cikti("gun goster", GunJson(BugunMetni, [Madde(Rapor, "Rapor yaz", durum: "yapildi", tahmin: 30), Madde("g:uye-girisi", "Üye girişi", gorev: "uye-girisi")]));
        Beyin.Cikti("gun isaretle", IsaretlendiJson(BugunMetni, Madde(Rapor, "Rapor yaz", "yapildi", 30)));
        Beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");
        Beyin.Cikti("gorev liste", GorevListesi);
        return (fabrika, await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika));
    }

    private static string[] Argumanlar(SahteBeyin beyin, string komut, string alt) =>
        beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Single(a => a[0] == komut && a[1] == alt);

    // Prefix routing

    [Fact]
    public async Task Yaptim_GoesWhereThePrefixSays_AndEventsAndUnknownIdsAreRefused()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var hatirlatici = await HatirlaticiEkleAsync("Eczane", BugunGunu, new TimeOnly(16, 30));

        // m: -> `gun isaretle` for that day, with the item's id after `--`.
        var plan = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"m:{Rapor}" });
        Assert.Equal(HttpStatusCode.OK, plan.StatusCode);
        var govde = await OkuAsync(plan);
        Assert.Equal($"m:{Rapor}", govde.GetProperty("oge").GetProperty("kimlik").GetString());
        Assert.Equal("yapildi", govde.GetProperty("oge").GetProperty("durum").GetString());
        Assert.Empty(govde.GetProperty("zincir").EnumerateArray());
        var isaretle = Argumanlar(Beyin, "gun", "isaretle");
        Assert.Contains($"--tarih={BugunMetni}", isaretle);
        Assert.DoesNotContain("--geri", isaretle);
        Assert.Equal(Rapor, isaretle[^1]);

        // Taking it back: the same command with --geri.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"m:{Rapor}", geri = true })).StatusCode);
        Assert.Contains("--geri", Beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Last(a => a[0] == "gun" && a[1] == "isaretle"));

        // g: -> `gorev bitir`, with the app's own "done" as the proof.
        var gorev = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = "g:uye-girisi" });
        Assert.Equal(HttpStatusCode.OK, gorev.StatusCode);
        var gorevGovde = await OkuAsync(gorev);
        Assert.Equal("g:uye-girisi", gorevGovde.GetProperty("oge").GetProperty("kimlik").GetString());
        Assert.Equal("yapildi", gorevGovde.GetProperty("oge").GetProperty("durum").GetString());
        Assert.Equal("Üye girişi", gorevGovde.GetProperty("oge").GetProperty("baslik").GetString());
        var bitir = Argumanlar(Beyin, "gorev", "bitir");
        Assert.Contains($"--kanit=onay:uygulama-{BugunMetni}", bitir);
        Assert.Equal("uye-girisi", bitir[^1]);

        // A task cannot be reopened from here: 409 with its own code, and the brain is not asked.
        var cagri = Beyin.Cagrilar().Count;
        var geri = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = "g:uye-girisi", geri = true });
        Assert.Equal(HttpStatusCode.Conflict, geri.StatusCode);
        var sorun = await OkuAsync(geri);
        Assert.Equal("gorev-geri-alinamaz", sorun.GetProperty("kod").GetString());
        Assert.Equal(cagri, Beyin.Cagrilar().Count);

        // h: -> the reminder's own "yaptım"; nothing is written to the brain (nothing is tied to it; the day is only read for the answer).
        var yazmaOnce = BeyinCagrisi("gun", "isaretle") + BeyinCagrisi("gorev", "bitir");
        var h = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{hatirlatici.Id}" });
        Assert.Equal(HttpStatusCode.OK, h.StatusCode);
        var hGovde = await OkuAsync(h);
        Assert.Equal($"h:{hatirlatici.Id}", hGovde.GetProperty("oge").GetProperty("kimlik").GetString());
        Assert.Equal("yapildi", hGovde.GetProperty("oge").GetProperty("durum").GetString());
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(hatirlatici.Id)).Durum);
        Assert.Equal(yazmaOnce, BeyinCagrisi("gun", "isaretle") + BeyinCagrisi("gorev", "bitir"));
        // Done twice: the reminder is not open any more.
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{hatirlatici.Id}" })).StatusCode);

        // An event has no "yaptım"; anything else is not an id of the list.
        var etkinlik = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"e:{Guid.NewGuid()}" });
        Assert.Equal(HttpStatusCode.BadRequest, etkinlik.StatusCode);
        foreach (var kotu in new[] { "x:1", "a3f09c", "m:", "h:degil-guid" })
            Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = kotu })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, YaptimYolu("dun"), sahip, fabrika, new { kimlik = $"m:{Rapor}" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { })).StatusCode);
    }

    [Fact]
    public async Task Yaptim_NeedsThePermissionOfWhatItTouches_AndWritesNothingWithout()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        var hatirlatici = await HatirlaticiEkleAsync("Eczane", BugunGunu, new TimeOnly(16, 30));
        foreach (var izin in new[] { "plan.yaz", "gorev.yaz", "hatirlatici.yaz" })
            await IzinKapatAsync(sahip, izin, fabrika);

        var istekler = new object[] { new { kimlik = $"m:{Rapor}" }, new { kimlik = "g:uye-girisi" }, new { kimlik = $"h:{hatirlatici.Id}" } };
        foreach (var istek in istekler)
        {
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Post, YaptimYolu(), null, fabrika, istek)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, YaptimYolu(), asistan, fabrika, istek)).StatusCode);
        }

        Assert.Empty(Beyin.Cagrilar());
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(hatirlatici.Id)).Durum);

        // Each permission opens its own kind and no other.
        await IzinAsync(sahip, "plan.yaz", fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), asistan, fabrika, istekler[0])).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, YaptimYolu(), asistan, fabrika, istekler[1])).StatusCode);
        await IzinKapatAsync(sahip, "plan.yaz", fabrika);
        await IzinAsync(sahip, "gorev.yaz", fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), asistan, fabrika, istekler[1])).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, YaptimYolu(), asistan, fabrika, istekler[0])).StatusCode);
        await IzinAsync(sahip, "hatirlatici.yaz", fabrika);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), asistan, fabrika, istekler[2])).StatusCode);
    }

    // The chain: item or task -> reminder

    [Fact]
    public async Task Chain_ATickedItemClosesItsOneOffReminder_AndTheTaskItClosedTakesTheTaskReminderToo()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var maddeye = await HatirlaticiEkleAsync("Rapor hatırlat", BugunGunu, new TimeOnly(14, 0), maddeId: Rapor, maddeTarihi: BugunGunu);
        var baskaGun = await HatirlaticiEkleAsync("Başka günün maddesi", BugunGunu, new TimeOnly(15, 0), maddeId: Rapor, maddeTarihi: BugunGunu.AddDays(1));
        var gorevHatirlaticisi = await HatirlaticiEkleAsync("Üye girişi hatırlat", BugunGunu, new TimeOnly(17, 0), gorev: "uye-girisi");
        var ilgisiz = await HatirlaticiEkleAsync("Başka iş", BugunGunu, new TimeOnly(18, 0), maddeId: "b4e1d2", maddeTarihi: BugunGunu);
        // The brain says it closed the task together with the item.
        Beyin.Cikti("gun isaretle", IsaretlendiJson(BugunMetni, Madde(Rapor, "Rapor yaz", "yapildi", 30, gorev: "uye-girisi"), gorevKapandi: true));

        var yanit = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"m:{Rapor}" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        var zincir = govde.GetProperty("zincir").EnumerateArray().Select(z => z.GetString()).ToList();
        Assert.Equal("g:uye-girisi", zincir[0]);
        Assert.Equivalent(new[] { $"h:{maddeye.Id}", $"h:{gorevHatirlaticisi.Id}" }, zincir.Skip(1));
        Assert.Equal(JsonValueKind.Null, govde.GetProperty("zincirHatasi").ValueKind);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(maddeye.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(gorevHatirlaticisi.Id)).Durum);
        // The item of another day and an unrelated item keep their reminders.
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(baskaGun.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(ilgisiz.Id)).Durum);
        // The weekly summary counts it as a "yaptım".
        await using var db = YeniDb();
        Assert.Equal(2, await db.HatirlaticiOlaylari.CountAsync(o => o.Tur == HatirlaticiOlayTuru.Yapildi, Ct));
    }

    [Fact]
    public async Task Chain_AFinishedTaskClosesTheRemindersOfThatTask()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var gorevHatirlaticisi = await HatirlaticiEkleAsync("Üye girişi hatırlat", BugunGunu, new TimeOnly(17, 0), gorev: "uye-girisi");

        var yanit = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = "g:uye-girisi" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Equal([$"h:{gorevHatirlaticisi.Id}"], (await OkuAsync(yanit)).GetProperty("zincir").EnumerateArray().Select(z => z.GetString()));
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(gorevHatirlaticisi.Id)).Durum);
    }

    [Fact]
    public async Task Chain_ARepeatingReminderCountsTheTurnAsDone_AndKeepsGoing()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var gunluk = await HatirlaticiEkleAsync("Rapor her gün", BugunGunu, new TimeOnly(14, 0), Tekrar.Gunluk, maddeId: Rapor, maddeTarihi: BugunGunu);
        var once = await HatirlaticiOkuAsync(gunluk.Id);

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"m:{Rapor}" })).StatusCode);

        var sonra = await HatirlaticiOkuAsync(gunluk.Id);
        Assert.Equal(HatirlaticiDurumu.Acik, sonra.Durum);
        Assert.Equal(once.SonrakiAn.AddDays(1), sonra.SonrakiAn);
    }

    [Fact]
    public async Task Chain_UntickingDoesNotTouchTheReminder()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var h = await HatirlaticiEkleAsync("Rapor hatırlat", BugunGunu, new TimeOnly(14, 0), maddeId: Rapor, maddeTarihi: BugunGunu);

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"m:{Rapor}", geri = true })).StatusCode);

        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(h.Id)).Durum);
    }

    // The chain: reminder -> item or task

    [Fact]
    public async Task Chain_AReminderDoneTicksItsItem_OrFinishesItsTaskWhenItHasNoItem()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var maddeli = await HatirlaticiEkleAsync("Rapor", BugunGunu, new TimeOnly(14, 0), maddeId: Rapor, maddeTarihi: BugunGunu);
        var gorevli = await HatirlaticiEkleAsync("Üye girişi", BugunGunu, new TimeOnly(17, 0), gorev: "uye-girisi");

        var madde = await OkuAsync(await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{maddeli.Id}" }));
        Assert.Equal([$"m:{Rapor}"], madde.GetProperty("zincir").EnumerateArray().Select(z => z.GetString()));
        var isaretle = Argumanlar(Beyin, "gun", "isaretle");
        Assert.Contains($"--tarih={BugunMetni}", isaretle);
        Assert.Equal(Rapor, isaretle[^1]);
        Assert.Equal(0, BeyinCagrisi("gorev", "bitir"));

        var gorev = await OkuAsync(await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{gorevli.Id}" }));
        Assert.Equal(["g:uye-girisi"], gorev.GetProperty("zincir").EnumerateArray().Select(z => z.GetString()));
        Assert.Equal("uye-girisi", Argumanlar(Beyin, "gorev", "bitir")[^1]);
    }

    [Fact]
    public async Task Chain_ARepeatingReminderTicksOnlyTheItemOfItsOwnDay_AndNeverFinishesATask()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var bugunku = await HatirlaticiEkleAsync("Rapor", BugunGunu, new TimeOnly(14, 0), Tekrar.Gunluk, maddeId: Rapor, maddeTarihi: BugunGunu);
        var dunku = await HatirlaticiEkleAsync("Eski madde", BugunGunu, new TimeOnly(15, 0), Tekrar.Gunluk, maddeId: "d1d1d1", maddeTarihi: BugunGunu.AddDays(-3));
        var gorevli = await HatirlaticiEkleAsync("Üye girişi", BugunGunu, new TimeOnly(17, 0), Tekrar.Gunluk, gorev: "uye-girisi");

        Assert.Equal([$"m:{Rapor}"], (await OkuAsync(await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{bugunku.Id}" }))).GetProperty("zincir").EnumerateArray().Select(z => z.GetString()));
        Assert.Empty((await OkuAsync(await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{dunku.Id}" }))).GetProperty("zincir").EnumerateArray());
        Assert.Empty((await OkuAsync(await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{gorevli.Id}" }))).GetProperty("zincir").EnumerateArray());

        // Only the first one reached the brain.
        Assert.Equal(1, BeyinCagrisi("gun", "isaretle"));
        Assert.Equal(0, BeyinCagrisi("gorev", "bitir"));
        // All three counted their turn: they are open, one day further.
        foreach (var h in new[] { bugunku, dunku, gorevli })
            Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(h.Id)).Durum);
    }

    [Fact]
    public async Task Chain_AFailedBrainStepKeepsTheReminderDone_AndSaysSo()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var h = await HatirlaticiEkleAsync("Rapor", BugunGunu, new TimeOnly(14, 0), maddeId: Rapor, maddeTarihi: BugunGunu);
        Beyin.Cikti("gun isaretle", """{"hata": {"kod": "bulunamadi", "mesaj": "madde yok"}}""", cikis: 1);

        var yanit = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{h.Id}" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        Assert.Contains("işaretlenemedi", govde.GetProperty("zincirHatasi").GetString());
        Assert.Empty(govde.GetProperty("zincir").EnumerateArray());
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);
        // The brain's own words never reach the client.
        Assert.DoesNotContain("madde yok", govde.GetRawText());
    }

    [Fact]
    public async Task Chain_WithoutABrain_TheReminderIsStillDone_AndTheErrorSaysWhy()
    {
        await GunTemizleAsync();
        var brainsiz = Fabrika(Pazartesi, google: false);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, brainsiz);
        var h = await HatirlaticiEkleAsync("Rapor", BugunGunu, new TimeOnly(14, 0), maddeId: Rapor, maddeTarihi: BugunGunu);

        var govde = await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{h.Id}/yaptim", sahip, brainsiz));

        Assert.Contains("Beyin bağlı değil", govde.GetProperty("zincirHatasi").GetString());
        Assert.Equal("tamam", govde.GetProperty("durum").GetString());
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);
    }

    // The old routes run the chain too

    [Fact]
    public async Task OldRoutes_TheDayPlanTickAndTheTaskFinish_CloseTheReminders_AndTheReminderRouteTicksTheItem()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var maddeye = await HatirlaticiEkleAsync("Rapor", BugunGunu, new TimeOnly(14, 0), maddeId: Rapor, maddeTarihi: BugunGunu);
        var gorevliye = await HatirlaticiEkleAsync("Üye girişi", BugunGunu, new TimeOnly(17, 0), gorev: "uye-girisi");

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/beyin/gunler/{BugunMetni}/isaretle", sahip, fabrika, new { madde = Rapor })).StatusCode);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(maddeye.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(gorevliye.Id)).Durum);

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, "/api/beyin/gorevler/uye-girisi/bitir", sahip, fabrika, new { })).StatusCode);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(gorevliye.Id)).Durum);

        // The reminder's own route: its item is ticked (and the answer says what went wrong when it could not be).
        var yeni = await HatirlaticiEkleAsync("Mail", BugunGunu, new TimeOnly(10, 0), maddeId: "b4e1d2", maddeTarihi: BugunGunu);
        var yanit = await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{yeni.Id}/yaptim", sahip, fabrika);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Equal(JsonValueKind.Null, (await OkuAsync(yanit)).GetProperty("zincirHatasi").ValueKind);
        Assert.Equal("b4e1d2", Beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Last(a => a[0] == "gun" && a[1] == "isaretle")[^1]);
    }

    [Fact]
    public async Task OldRoutes_UntickingAndARepeatedKey_DoNotRunTheChainAgain()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var h = await HatirlaticiEkleAsync("Rapor", BugunGunu, new TimeOnly(14, 0), Tekrar.Gunluk, maddeId: Rapor, maddeTarihi: BugunGunu);
        var onceki = (await HatirlaticiOkuAsync(h.Id)).SonrakiAn;
        var yol = $"/api/beyin/gunler/{BugunMetni}/isaretle";
        var anahtar = Anahtar();

        var ilk = await AnahtarliGonderAsync(HttpMethod.Post, yol, sahip, fabrika, new { madde = Rapor }, anahtar);
        var ikinci = await AnahtarliGonderAsync(HttpMethod.Post, yol, sahip, fabrika, new { madde = Rapor }, anahtar);

        Assert.Equal(HttpStatusCode.OK, ilk.StatusCode);
        Assert.True(ikinci.Headers.Contains("Idempotent-Replayed"));
        Assert.Equal(1, BeyinCagrisi("gun", "isaretle"));
        // One turn done, not two.
        Assert.Equal(onceki.AddDays(1), (await HatirlaticiOkuAsync(h.Id)).SonrakiAn);

        // Taking a tick back leaves the reminder where it is.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, yol, sahip, fabrika, new { madde = Rapor, geri = true })).StatusCode);
        Assert.Equal(onceki.AddDays(1), (await HatirlaticiOkuAsync(h.Id)).SonrakiAn);
    }

    // Idempotency

    [Fact]
    public async Task Yaptim_IsAppliedOnceUnderTheSameKey_AndTheKeyIsNotForAnotherRequest()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var h = await HatirlaticiEkleAsync("Rapor", BugunGunu, new TimeOnly(14, 0), maddeId: Rapor, maddeTarihi: BugunGunu);
        var anahtar = Anahtar();
        var istek = new { kimlik = $"h:{h.Id}" };

        var ilk = await AnahtarliGonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, istek, anahtar);
        var ikinci = await AnahtarliGonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, istek, anahtar);

        Assert.Equal(HttpStatusCode.OK, ilk.StatusCode);
        Assert.Equal(HttpStatusCode.OK, ikinci.StatusCode);
        Assert.True(ikinci.Headers.Contains("Idempotent-Replayed"));
        Assert.Equal(await ilk.Content.ReadAsStringAsync(Ct), await ikinci.Content.ReadAsStringAsync(Ct));
        Assert.Equal(1, BeyinCagrisi("gun", "isaretle"));
        await using (var db = YeniDb())
            Assert.Equal(1, await db.HatirlaticiOlaylari.CountAsync(o => o.HatirlaticiId == h.Id, Ct));

        var baska = await AnahtarliGonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"m:{Rapor}" }, anahtar);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, baska.StatusCode);
    }

    [Fact]
    public async Task Yaptim_ARefusedWriteIsNotKeptUnderTheKey_SoItCanBeTriedAgain()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gun isaretle", """{"hata": {"kod": "gun-kapali", "mesaj": "kapandı"}}""", cikis: 1);
        var anahtar = Anahtar();
        var istek = new { kimlik = $"m:{Rapor}" };

        var red = await AnahtarliGonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, istek, anahtar);
        Assert.Equal(HttpStatusCode.Conflict, red.StatusCode);

        Beyin.Cikti("gun isaretle", IsaretlendiJson(BugunMetni, Madde(Rapor, "Rapor yaz", "yapildi", 30)));
        var tekrar = await AnahtarliGonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, istek, anahtar);
        Assert.Equal(HttpStatusCode.OK, tekrar.StatusCode);
        Assert.False(tekrar.Headers.Contains("Idempotent-Replayed"));
    }

    // Opening a one-off reminder again

    [Fact]
    public async Task Yaptim_GeriOpensAClosedOneOffReminder_AndTakesTheCountBack_ButNotARepeatingOne()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var tek = await HatirlaticiEkleAsync("Eczane", BugunGunu, new TimeOnly(16, 30));
        var tekrarli = await HatirlaticiEkleAsync("Spor", BugunGunu, new TimeOnly(19, 0), Tekrar.Gunluk);
        var acik = await HatirlaticiEkleAsync("Açık olan", BugunGunu, new TimeOnly(20, 0));

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{tek.Id}" })).StatusCode);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(tek.Id)).Durum);
        await using (var db = YeniDb())
            Assert.Equal(1, await db.HatirlaticiOlaylari.CountAsync(o => o.HatirlaticiId == tek.Id, Ct));

        var geri = await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{tek.Id}", geri = true });
        Assert.Equal(HttpStatusCode.OK, geri.StatusCode);
        Assert.Equal("acik", (await OkuAsync(geri)).GetProperty("oge").GetProperty("durum").GetString());
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(tek.Id)).Durum);
        await using (var db = YeniDb())
            Assert.Equal(0, await db.HatirlaticiOlaylari.CountAsync(o => o.HatirlaticiId == tek.Id, Ct));

        // A repeating reminder has moved on; one that was never done has nothing to open.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{tekrarli.Id}" })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{tekrarli.Id}", geri = true })).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{acik.Id}", geri = true })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, YaptimYolu(), sahip, fabrika, new { kimlik = $"h:{Guid.NewGuid()}" })).StatusCode);
    }
}
