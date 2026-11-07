using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The whole app: the approval queue (suggest, approve, reject, undo), the permission modes and who may do what.
// The queue is the safety base of later modules, so the order of the rules is tested, not just the happy path.
public class EylemApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private const string Tur = "hatirlatici-kur";

    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private async Task<string> GirisAsync(string eposta)
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string token, object? govde = null, WebApplicationFactory<Program>? fabrika = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await (fabrika ?? uygulama).CreateClient().SendAsync(istek, Ct);
    }

    private async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    private static object GecerliYuk(string baslik) => new { baslik, gun = "2030-01-01" };

    private static string Baslik() => "Test " + Guid.NewGuid().ToString("N");

    // The kind's mode is shared by the tests of this class: every test sets the one it needs first (this also clears the count of rejections).
    private async Task KipAyarlaAsync(string sahip, string kip, string tur = Tur, WebApplicationFactory<Program>? fabrika = null)
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/eylem-izinleri/{tur}", sahip, new { kip }, fabrika);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
    }

    private async Task<string> KipOkuAsync(string sahip, string tur = Tur)
    {
        var liste = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/yonetim/eylem-izinleri", sahip));
        return liste.EnumerateArray().Single(k => k.GetProperty("tur").GetString() == tur).GetProperty("kip").GetString()!;
    }

    // A suggestion from another module: straight into EylemServisi, there is no endpoint for it.
    private async Task<EylemSonucu> OnerAsync(object yuk, bool disKaynak = false, string ozet = "Ali'yi ara", string kaynak = "gelen",
        string tur = Tur, double? guven = null, WebApplicationFactory<Program>? fabrika = null)
    {
        using var kapsam = (fabrika ?? uygulama).Services.CreateScope();
        var servis = kapsam.ServiceProvider.GetRequiredService<EylemServisi>();
        return await servis.OnerAsync(new EylemOnerisi(tur, JsonSerializer.SerializeToElement(yuk), ozet, kaynak, disKaynak, Guven: guven), Ct);
    }

    private async Task<Guid> BekleyenOlusturAsync(string baslik, bool disKaynak = false)
    {
        var sonuc = await OnerAsync(GecerliYuk(baslik), disKaynak);
        Assert.Equal(EylemSonucuTuru.Tamam, sonuc.Tur);
        Assert.Equal(EylemDurumu.Bekliyor, sonuc.Eylem!.Durum);
        return sonuc.Eylem.Id;
    }

    private async Task<Hatirlatici?> HatirlaticiAsync(string baslik)
    {
        using var db = uygulama.YeniDb();
        return await db.Hatirlaticilar.SingleOrDefaultAsync(h => h.Baslik == baslik, Ct);
    }

    [Theory]
    // kip, outside source, expected: the order is Yasak, then outside source, then KendinYap, else Sor.
    [InlineData("sor", false, "bekliyor")]
    [InlineData("sor", true, "bekliyor")]
    [InlineData("kendinYap", false, "uygulandi")]
    [InlineData("kendinYap", true, "bekliyor")]
    [InlineData("yasak", false, "atlandi")]
    [InlineData("yasak", true, "atlandi")]
    public async Task Suggestion_FollowsTheDecisionOrder(string kip, bool disKaynak, string beklenen)
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, kip);
        var baslik = Baslik();
        using var oncesi = uygulama.YeniDb();
        var oncekiSayi = await oncesi.Eylemler.CountAsync(Ct);

        var sonuc = await OnerAsync(GecerliYuk(baslik), disKaynak, ozet: baslik);

        using var db = uygulama.YeniDb();
        switch (beklenen)
        {
            case "atlandi":
                Assert.Equal(EylemSonucuTuru.Atlandi, sonuc.Tur);
                Assert.Equal(oncekiSayi, await db.Eylemler.CountAsync(Ct));
                Assert.Null(await HatirlaticiAsync(baslik));
                var atlandi = await db.EylemGunlukleri.SingleAsync(g => g.Aciklama.Contains(baslik), Ct);
                Assert.Equal(EylemOlayi.YasakAtlandi, atlandi.Olay);
                Assert.Contains("Yasak olduğu için atlandı", atlandi.Aciklama);
                break;
            case "bekliyor":
                Assert.Equal(EylemDurumu.Bekliyor, sonuc.Eylem!.Durum);
                Assert.Null(await HatirlaticiAsync(baslik));
                break;
            default:
                Assert.Equal(EylemDurumu.Uygulandi, sonuc.Eylem!.Durum);
                Assert.Null(sonuc.Eylem.KararVerenId);
                Assert.NotNull(await HatirlaticiAsync(baslik));
                Assert.Contains(await db.EylemGunlukleri.Where(g => g.EylemId == sonuc.Eylem.Id).Select(g => g.Olay).ToListAsync(Ct), o => o == EylemOlayi.OtomatikUygulandi);
                break;
        }
    }

    [Fact]
    public async Task FirstTime_WithoutAModeRow_AsksFirst()
    {
        // A kind nobody has set a mode for (no row): the default is Sor, not KendinYap.
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await using var yeniFabrika = new YeniTurFabrikasi(uygulama);
        var kip = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/yonetim/eylem-izinleri", sahip, fabrika: yeniFabrika.Fabrika));
        var sessiz = kip.EnumerateArray().Single(k => k.GetProperty("tur").GetString() == SessizTur.Anahtar);
        Assert.Equal("sor", sessiz.GetProperty("kip").GetString());

        var sonuc = await OnerAsync(new { }, fabrika: yeniFabrika.Fabrika, tur: SessizTur.Anahtar);

        Assert.Equal(EylemDurumu.Bekliyor, sonuc.Eylem!.Durum);
        using var db = uygulama.YeniDb();
        Assert.Null(await db.EylemIzinleri.FindAsync([SessizTur.Anahtar], Ct));
    }

    [Fact]
    public async Task Approve_AppliesTheAction_AndRecordsWhoDecided()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var baslik = Baslik();
        var id = await BekleyenOlusturAsync(baslik, disKaynak: true);
        var ben = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/ben", sahip));

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var eylem = await OkuAsync(yanit);
        Assert.Equal("uygulandi", eylem.GetProperty("durum").GetString());
        Assert.Equal(ben.GetProperty("id").GetGuid(), eylem.GetProperty("kararVerenId").GetGuid());
        Assert.True(eylem.GetProperty("disKaynak").GetBoolean());
        Assert.Equal("Hatırlatıcı kur", eylem.GetProperty("turAdi").GetString());
        var h = await HatirlaticiAsync(baslik);
        Assert.NotNull(h);
        Assert.Equal(h.Id, eylem.GetProperty("geriAlmaBilgisi").GetProperty("hatirlaticiId").GetGuid());
        Assert.NotEqual(JsonValueKind.Null, eylem.GetProperty("uygulamaAni").ValueKind);

        // Decided once: a second approval, and a rejection after it, are conflicts.
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/reddet", sahip)).StatusCode);
        using var db = uygulama.YeniDb();
        Assert.Equal(1, await db.Hatirlaticilar.CountAsync(x => x.Baslik == baslik, Ct));
    }

    [Fact]
    public async Task Approve_WithACorrectedPayload_AppliesThatPayload_AfterCheckingIt()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var id = await BekleyenOlusturAsync(Baslik());
        var duzeltilmis = Baslik();

        // Wrong: the title is empty. 400, and the action stays in the queue.
        var yanlis = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip, new { yuk = new { baslik = "", gun = "2030-01-01" } });
        Assert.Equal(HttpStatusCode.BadRequest, yanlis.StatusCode);
        Assert.Contains("yuk", (await OkuAsync(yanlis)).GetProperty("errors").EnumerateObject().Select(p => p.Name));
        // An invented property is refused too.
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip, new { yuk = new { baslik = "x", gun = "2030-01-01", uydurma = 1 } })).StatusCode);
        var hala = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/eylemler/{id}", sahip));
        Assert.Equal("bekliyor", hala.GetProperty("durum").GetString());

        var tamam = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip, new { yuk = GecerliYuk(duzeltilmis) });

        Assert.Equal(HttpStatusCode.OK, tamam.StatusCode);
        Assert.NotNull(await HatirlaticiAsync(duzeltilmis));
        Assert.Equal(duzeltilmis, (await OkuAsync(tamam)).GetProperty("yuk").GetProperty("baslik").GetString());
    }

    [Fact]
    public async Task Reject_KeepsTheModeAndCreatesNothing()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var baslik = Baslik();
        var id = await BekleyenOlusturAsync(baslik);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/reddet", sahip, new { birDahaOnerme = false });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Equal("reddedildi", (await OkuAsync(yanit)).GetProperty("durum").GetString());
        Assert.Null(await HatirlaticiAsync(baslik));
        Assert.Equal("sor", await KipOkuAsync(sahip));
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/reddet", sahip)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip)).StatusCode);
    }

    [Fact]
    public async Task Reject_WithNeverAgain_MakesTheKindYasak_ForGood()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var id = await BekleyenOlusturAsync(Baslik());

        // An empty body is a plain rejection; this one asks never again.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/reddet", sahip, new { birDahaOnerme = true })).StatusCode);

        Assert.Equal("yasak", await KipOkuAsync(sahip));
        var sonra = await OnerAsync(GecerliYuk(Baslik()));
        Assert.Equal(EylemSonucuTuru.Atlandi, sonra.Tur);
        using var db = uygulama.YeniDb();
        Assert.Contains(await db.EylemGunlukleri.Where(g => g.Tur == Tur && g.Olay == EylemOlayi.KipDegisti).Select(g => g.Aciklama).ToListAsync(Ct),
            a => a.Contains("Yasak") && a.Contains("bir daha önerme"));
    }

    [Fact]
    public async Task ThreeRejectionsInARow_TakeKendinYapBackToSor()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "kendinYap");

        // Outside-source suggestions always wait, even in KendinYap; those are the ones that can be rejected.
        for (var i = 1; i <= 3; i++)
        {
            Assert.Equal("kendinYap", await KipOkuAsync(sahip));
            var id = await BekleyenOlusturAsync(Baslik(), disKaynak: true);
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/reddet", sahip)).StatusCode);
        }

        Assert.Equal("sor", await KipOkuAsync(sahip));
        using var db = uygulama.YeniDb();
        Assert.Contains(await db.EylemGunlukleri.Where(g => g.Tur == Tur && g.Olay == EylemOlayi.KipDegisti).Select(g => g.Aciklama).ToListAsync(Ct),
            a => a.Contains("KendinYap → Sor") && a.Contains("art arda 3 red"));
        // From now on a suggestion from the user's own words waits too.
        Assert.Equal(EylemDurumu.Bekliyor, (await OnerAsync(GecerliYuk(Baslik()))).Eylem!.Durum);
    }

    [Fact]
    public async Task AnApproval_BreaksTheRunOfRejections()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "kendinYap");

        foreach (var karar in new[] { "reddet", "reddet", "uygula", "reddet", "reddet" })
        {
            var id = await BekleyenOlusturAsync(Baslik(), disKaynak: true);
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/{karar}", sahip)).StatusCode);
        }

        // 2 + approval + 2: never 3 in a row.
        Assert.Equal("kendinYap", await KipOkuAsync(sahip));
    }

    [Fact]
    public async Task Undo_ArchivesTheReminder_AndOnlyAnAppliedActionCanBeUndone()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var baslik = Baslik();
        var id = await BekleyenOlusturAsync(baslik);

        // Not applied yet: 409.
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/geri-al", sahip)).StatusCode);
        await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip);
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiAsync(baslik))!.Durum);

        var yanit = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/geri-al", sahip);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var eylem = await OkuAsync(yanit);
        Assert.Equal("geriAlindi", eylem.GetProperty("durum").GetString());
        Assert.NotEqual(JsonValueKind.Null, eylem.GetProperty("geriAlmaAni").ValueKind);
        // Archived, not deleted.
        var h = await HatirlaticiAsync(baslik);
        Assert.NotNull(h);
        Assert.Equal(HatirlaticiDurumu.Arsiv, h.Durum);
        // Once only.
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/geri-al", sahip)).StatusCode);

        // A rejected action was never applied either.
        var reddedilen = await BekleyenOlusturAsync(Baslik());
        await GonderAsync(HttpMethod.Post, $"/api/eylemler/{reddedilen}/reddet", sahip);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{reddedilen}/geri-al", sahip)).StatusCode);
    }

    [Fact]
    public async Task Undo_LeavesAReminderTheUserHasAlreadyFinished()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var baslik = Baslik();
        var id = await BekleyenOlusturAsync(baslik);
        await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip);
        var h = (await HatirlaticiAsync(baslik))!;
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{h.Id}/yaptim", sahip)).StatusCode);

        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/geri-al", sahip)).StatusCode);

        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiAsync(baslik))!.Durum);
    }

    [Fact]
    public async Task TwoApprovalsAtOnce_ApplyTheActionOnce()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var baslik = Baslik();
        var id = await BekleyenOlusturAsync(baslik);

        var yanitlar = await Task.WhenAll(
            GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip),
            GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", sahip));

        Assert.Equal([HttpStatusCode.OK, HttpStatusCode.Conflict], yanitlar.Select(y => y.StatusCode).Order().ToArray());
        using var db = uygulama.YeniDb();
        Assert.Equal(1, await db.Hatirlaticilar.CountAsync(x => x.Baslik == baslik, Ct));
    }

    [Fact]
    public async Task UnknownId_Is404_OnEveryEndpoint()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var id = Guid.CreateVersion7();

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Get, $"/api/eylemler/{id}", sahip)).StatusCode);
        foreach (var islem in new[] { "uygula", "reddet", "geri-al" })
            Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/{islem}", sahip)).StatusCode);
    }

    [Fact]
    public async Task List_DefaultsToPending_NewestFirst_AndFiltersByStatus()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        var eski = await BekleyenOlusturAsync(Baslik());
        await Task.Delay(20, Ct);
        var yeni = await BekleyenOlusturAsync(Baslik());
        var uygulanan = await BekleyenOlusturAsync(Baslik());
        await GonderAsync(HttpMethod.Post, $"/api/eylemler/{uygulanan}/uygula", sahip);

        var bekleyenler = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/eylemler", sahip))).EnumerateArray()
            .Select(e => e.GetProperty("id").GetGuid()).ToList();
        Assert.Contains(eski, bekleyenler);
        Assert.Contains(yeni, bekleyenler);
        Assert.DoesNotContain(uygulanan, bekleyenler);
        Assert.True(bekleyenler.IndexOf(yeni) < bekleyenler.IndexOf(eski), "newest first");

        var uygulananlar = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/eylemler?durum=uygulandi", sahip))).EnumerateArray()
            .Select(e => e.GetProperty("id").GetGuid()).ToList();
        Assert.Contains(uygulanan, uygulananlar);
        Assert.DoesNotContain(eski, uygulananlar);

        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, "/api/eylemler?durum=olmayan", sahip)).StatusCode);
    }

    [Theory]
    [InlineData("tur")]
    [InlineData("yuk-bos-baslik")]
    [InlineData("yuk-uydurma-alan")]
    [InlineData("ozet")]
    [InlineData("guven")]
    public async Task InvalidSuggestion_IsRefused_AndNothingIsStored(string neden)
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await KipAyarlaAsync(sahip, "sor");
        using var oncesi = uygulama.YeniDb();
        var oncekiSayi = await oncesi.Eylemler.CountAsync(Ct);

        var sonuc = neden switch
        {
            "tur" => await OnerAsync(GecerliYuk(Baslik()), tur: "olmayan-tur"),
            "yuk-bos-baslik" => await OnerAsync(new { baslik = "", gun = "2030-01-01" }),
            "yuk-uydurma-alan" => await OnerAsync(new { baslik = "x", gun = "2030-01-01", uydurma = 1 }),
            "ozet" => await OnerAsync(GecerliYuk(Baslik()), ozet: " "),
            _ => await OnerAsync(GecerliYuk(Baslik()), guven: 2),
        };

        Assert.Equal(EylemSonucuTuru.Gecersiz, sonuc.Tur);
        using var db = uygulama.YeniDb();
        Assert.Equal(oncekiSayi, await db.Eylemler.CountAsync(Ct));
    }

    [Fact]
    public async Task Modes_AreListedAndSetBySahip_AndRefuseWrongValues()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/eylem-izinleri/{Tur}", sahip, new { kip = "KendinYap" });
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var kip = await OkuAsync(yanit);
        Assert.Equal("kendinYap", kip.GetProperty("kip").GetString());
        Assert.Equal("Hatırlatıcı kur", kip.GetProperty("turAdi").GetString());
        Assert.Equal("kendinYap", await KipOkuAsync(sahip));

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Put, "/api/yonetim/eylem-izinleri/olmayan-tur", sahip, new { kip = "sor" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Put, $"/api/yonetim/eylem-izinleri/{Tur}", sahip, new { kip = "belki" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Put, $"/api/yonetim/eylem-izinleri/{Tur}", sahip, new { kip = 99 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Put, $"/api/yonetim/eylem-izinleri/{Tur}", sahip, new { })).StatusCode);
        Assert.Equal("kendinYap", await KipOkuAsync(sahip));
        await KipAyarlaAsync(sahip, "sor");
    }

    [Fact]
    public async Task Asistan_NeedsThePermissions_AndNeverTouchesTheModes()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        await KipAyarlaAsync(sahip, "sor");
        var id = await BekleyenOlusturAsync(Baslik());
        var tumIzinler = new[] { "eylem.oku", "eylem.onayla" };
        foreach (var izin in tumIzinler)
            await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, new { acik = false });
        try
        {
            // No permission: 403 everywhere, no token: 401.
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/eylemler", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, $"/api/eylemler/{id}", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await uygulama.CreateClient().GetAsync("/api/eylemler", Ct)).StatusCode);

            // Read only: may look, may not decide.
            await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/eylem.oku", sahip, new { acik = true });
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/eylemler", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, $"/api/eylemler/{id}", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/uygula", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/reddet", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/geri-al", asistan)).StatusCode);

            // Both permissions: may decide, and the decision records them.
            await GonderAsync(HttpMethod.Put, "/api/yonetim/izinler/eylem.onayla", sahip, new { acik = true });
            var yanit = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{id}/reddet", asistan);
            Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
            var ben = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/ben", asistan));
            Assert.Equal(ben.GetProperty("id").GetGuid(), (await OkuAsync(yanit)).GetProperty("kararVerenId").GetGuid());

            // The modes are the Sahip's alone, whatever the Asistan holds.
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Get, "/api/yonetim/eylem-izinleri", asistan)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await GonderAsync(HttpMethod.Put, $"/api/yonetim/eylem-izinleri/{Tur}", asistan, new { kip = "kendinYap" })).StatusCode);
            Assert.Equal("sor", await KipOkuAsync(sahip));
        }
        finally
        {
            foreach (var izin in tumIzinler)
                await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, new { acik = false });
        }
    }

    [Fact]
    public async Task AFailingAction_IsKeptAsHatali_WithoutHalfDoneEffects()
    {
        await using var yeniFabrika = new YeniTurFabrikasi(uygulama);
        var fabrika = yeniFabrika.Fabrika;
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        // Approval: 500, the action is Hatali, the reminder the kind had added before throwing is gone.
        await KipAyarlaAsync(sahip, "sor", PatlayanTur.Anahtar, fabrika);
        var bekleyen = await OnerAsync(new { }, fabrika: fabrika, tur: PatlayanTur.Anahtar);
        var yanit = await GonderAsync(HttpMethod.Post, $"/api/eylemler/{bekleyen.Eylem!.Id}/uygula", sahip, fabrika: fabrika);
        Assert.Equal(HttpStatusCode.InternalServerError, yanit.StatusCode);
        var kayit = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/eylemler/{bekleyen.Eylem.Id}", sahip, fabrika: fabrika));
        Assert.Equal("hatali", kayit.GetProperty("durum").GetString());
        Assert.NotEqual(JsonValueKind.Null, kayit.GetProperty("hataMesaji").ValueKind);
        Assert.Equal(HttpStatusCode.Conflict, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{bekleyen.Eylem.Id}/uygula", sahip, fabrika: fabrika)).StatusCode);

        // Automatic: the suggestion is stored and shown as Hatali, not lost.
        await KipAyarlaAsync(sahip, "kendinYap", PatlayanTur.Anahtar, fabrika);
        var otomatik = await OnerAsync(new { }, fabrika: fabrika, tur: PatlayanTur.Anahtar);
        Assert.Equal(EylemSonucuTuru.Hata, otomatik.Tur);
        Assert.Equal(EylemDurumu.Hatali, otomatik.Eylem!.Durum);

        using var db = uygulama.YeniDb();
        Assert.False(await db.Hatirlaticilar.AnyAsync(h => h.Baslik == PatlayanTur.YarimKalan, Ct));
        Assert.Equal(2, await db.EylemGunlukleri.CountAsync(g => g.Tur == PatlayanTur.Anahtar && g.Olay == EylemOlayi.Hatali, Ct));
    }

    // A second app on the same database with one more kind that always fails after touching the context.
    private sealed class YeniTurFabrikasi : IAsyncDisposable
    {
        public YeniTurFabrikasi(UygulamaFabrikasi ana) =>
            Fabrika = ana.WithWebHostBuilder(b => b.ConfigureServices(s =>
            {
                s.AddSingleton<IEylemTuru, PatlayanTur>();
                s.AddSingleton<IEylemTuru, SessizTur>();
            }));

        public WebApplicationFactory<Program> Fabrika { get; }

        public ValueTask DisposeAsync() => Fabrika.DisposeAsync();
    }

    // A kind whose mode row is never written by any test.
    private sealed class SessizTur : IEylemTuru
    {
        public const string Anahtar = "sessiz-tur";

        public string Ad => Anahtar;
        public string GorunenAd => "Sessiz";
        public Sonuc Dogrula(JsonElement yuk) => Sonuc.Tamam;
        public Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct) => Task.FromResult(yuk.Clone());
        public Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct) => Task.CompletedTask;
    }

    private sealed class PatlayanTur : IEylemTuru
    {
        public const string Anahtar = "patlayan-tur";
        public const string YarimKalan = "Yarım kalan hatırlatıcı";

        public string Ad => Anahtar;
        public string GorunenAd => "Patlayan";
        public Sonuc Dogrula(JsonElement yuk) => Sonuc.Tamam;

        public Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
        {
            baglam.Db.Hatirlaticilar.Add(new Hatirlatici { Baslik = YarimKalan, Gun = new DateOnly(2030, 1, 1), SonrakiAn = baglam.Simdi });
            throw new InvalidOperationException("boom");
        }

        public Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct) => Task.CompletedTask;
    }
}
