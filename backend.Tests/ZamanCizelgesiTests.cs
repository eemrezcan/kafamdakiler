using System.Net;
using System.Text.Json;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The one timeline of a day (K2.3c). What matters: the order of the clock, the day turning at 05:00 (not at midnight), the items
// without an hour kept apart, the capacity warning counting the events, a plan that could not be read never passing for an empty day,
// and who may read it.
public sealed class ZamanCizelgesiTests(UygulamaFabrikasi uygulama) : TakvimTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private async Task<(JsonElement Govde, HttpStatusCode Durum)> CizelgeAsync(WebApplicationFactory<Program> fabrika, string? gun, bool sahip = true)
    {
        var token = await GirisAsync(sahip ? UygulamaFabrikasi.SahipEposta : UygulamaFabrikasi.AsistanEposta, fabrika);
        var yanit = await GonderAsync(HttpMethod.Get, "/api/zaman-cizelgesi" + (gun is null ? "" : $"?gun={gun}"), token, fabrika);
        var metin = await yanit.Content.ReadAsStringAsync(Ct);
        return (metin.Length > 0 ? JsonDocument.Parse(metin).RootElement.Clone() : default, yanit.StatusCode);
    }

    private static string[] Basliklar(JsonElement liste) => liste.EnumerateArray().Select(o => o.GetProperty("baslik").GetString()!).ToArray();

    private async Task<Hatirlatici> HatirlaticiEkleAsync(string baslik, DateTimeOffset an, bool saatli = true, DateTimeOffset? erteleAn = null, HatirlaticiDurumu durum = HatirlaticiDurumu.Acik)
    {
        var utc = an.ToUniversalTime();
        var h = new Hatirlatici
        {
            Baslik = baslik, Tur = HatirlaticiTuru.Gorev, Gun = HatirlaticiHesap.IstanbulGunu(utc), Saat = saatli ? HatirlaticiHesap.IstanbulSaati(utc) : null,
            Tekrar = Tekrar.Yok, Durum = durum, SonrakiAn = utc, ErteleAn = erteleAn?.ToUniversalTime(),
        };
        await using var db = YeniDb();
        db.Hatirlaticilar.Add(h);
        await db.SaveChangesAsync(Ct);
        return h;
    }

    // The caller disposes it (`using var`).
    private static SahteBeyin BeyniKur(string gunJson, int cikis = 0)
    {
        var beyin = new SahteBeyin("ok");
        beyin.Cikti("gun goster", gunJson, cikis);
        return beyin;
    }

    private static string PlanJson(params (string Id, string Baslik, string Durum, int? Tahmin)[] maddeler) =>
        $$"""{"tarih": "2026-11-07", "plan_var": true, "kapandi": false, "geciken": [], "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{{string.Join(",", maddeler.Select(m =>
            $$"""{"id": "{{m.Id}}", "baslik": "{{m.Baslik}}", "durum": "{{m.Durum}}", "tahmin_dk": {{(m.Tahmin?.ToString() ?? "null")}}}"""))}}]}]}""";

    private WebApplicationFactory<Program> BeyinliFabrika(SahteBeyin beyin, string? kapasiteSaat = null) =>
        Fabrika(kapasiteSaat: kapasiteSaat, ek: b => b.UseSetting("Beyin:Komut", beyin.Komut).UseSetting("Beyin:Vault", beyin.Vault));

    // Who may read

    [Fact]
    public async Task Reading_NeedsTheTakvimOkuPermission_TheSahipAlwaysHasIt()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(HttpMethod.Get, "/api/zaman-cizelgesi", null, fabrika)).StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await CizelgeAsync(fabrika, "2026-11-07", sahip: false)).Durum);
        var sahipToken = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        await IzinAsync(sahipToken, "takvim.oku", fabrika);
        Assert.Equal(HttpStatusCode.OK, (await CizelgeAsync(fabrika, "2026-11-07", sahip: false)).Durum);
        Assert.Equal(HttpStatusCode.OK, (await CizelgeAsync(fabrika, "2026-11-07")).Durum);
    }

    [Theory]
    [InlineData("yarin")]
    [InlineData("2026-13-01")]
    [InlineData("07.11.2026")]
    [InlineData("1999-12-31")]
    public async Task ABadDay_IsA400(string gun)
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        Assert.Equal(HttpStatusCode.BadRequest, (await CizelgeAsync(fabrika, gun)).Durum);
    }

    // Order

    [Fact]
    public async Task ItemsWithAnHour_AreInTheOrderOfTheClock_AndTheOnesWithoutAreApart()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await EtkinlikEkleAsync("Öğleden sonra", IstAn(2026, 11, 7, 14), IstAn(2026, 11, 7, 15), yer: "Oda 2");
        await EtkinlikEkleAsync("Sabah toplantısı", IstAn(2026, 11, 7, 9, 30), IstAn(2026, 11, 7, 10, 15));
        await TumGunEtkinligiEkleAsync("Bayram", Bugun, Bugun);
        await HatirlaticiEkleAsync("Saatli hatırlatıcı", IstAn(2026, 11, 7, 9, 30));
        await HatirlaticiEkleAsync("Ertelenmiş", IstAn(2026, 11, 7, 9), saatli: false, erteleAn: IstAn(2026, 11, 7, 11, 30));
        await HatirlaticiEkleAsync("Saatsiz hatırlatıcı", IstAn(2026, 11, 7, 9), saatli: false);
        await HatirlaticiEkleAsync("Yapılmış", IstAn(2026, 11, 7, 12), durum: HatirlaticiDurumu.Tamam);
        await HatirlaticiEkleAsync("Yarının", IstAn(2026, 11, 8, 12));

        var (govde, durum) = await CizelgeAsync(fabrika, "2026-11-07");

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Equal("2026-11-07", govde.GetProperty("gun").GetString());
        // At the same moment an event comes before a reminder.
        Assert.Equal(["Sabah toplantısı", "Saatli hatırlatıcı", "Ertelenmiş", "Öğleden sonra"], Basliklar(govde.GetProperty("saatli")));
        Assert.Equal(["Bayram", "Saatsiz hatırlatıcı"], Basliklar(govde.GetProperty("saatsiz")));

        var sabah = govde.GetProperty("saatli")[0];
        Assert.Equal("etkinlik", sabah.GetProperty("tur").GetString());
        Assert.Equal("09:30", sabah.GetProperty("saat").GetString());
        Assert.Equal("10:15", sabah.GetProperty("bitisSaati").GetString());
        Assert.Equal(45, sabah.GetProperty("sureDk").GetInt32());
        Assert.Equal("Oda 2", govde.GetProperty("saatli")[3].GetProperty("yer").GetString());
        Assert.Equal("11:30", govde.GetProperty("saatli")[2].GetProperty("saat").GetString());
        Assert.Equal("hatirlatici", govde.GetProperty("saatli")[1].GetProperty("tur").GetString());

        var bayram = govde.GetProperty("saatsiz")[0];
        Assert.True(bayram.GetProperty("tumGun").GetBoolean());
        Assert.Equal(JsonValueKind.Null, bayram.GetProperty("saat").ValueKind);
    }

    [Fact]
    public async Task TheDayTurnsAt0500_NotAtMidnight()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await EtkinlikEkleAsync("04:59 dünün", IstAn(2026, 11, 7, 4, 59), IstAn(2026, 11, 7, 5, 30));
        await EtkinlikEkleAsync("05:00 günün", IstAn(2026, 11, 7, 5), IstAn(2026, 11, 7, 6));
        await EtkinlikEkleAsync("Gece 23:30", IstAn(2026, 11, 7, 23, 30), IstAn(2026, 11, 8, 0, 30));
        await EtkinlikEkleAsync("Ertesi gün 04:59", IstAn(2026, 11, 8, 4, 59), IstAn(2026, 11, 8, 5, 30));
        await EtkinlikEkleAsync("Ertesi gün 05:00", IstAn(2026, 11, 8, 5), IstAn(2026, 11, 8, 6));
        await HatirlaticiEkleAsync("Gece yarısı sonrası", IstAn(2026, 11, 8, 2));

        var bugun = (await CizelgeAsync(fabrika, "2026-11-07")).Govde;
        var dun = (await CizelgeAsync(fabrika, "2026-11-06")).Govde;
        var yarin = (await CizelgeAsync(fabrika, "2026-11-08")).Govde;

        Assert.Equal(["05:00 günün", "Gece 23:30", "Gece yarısı sonrası", "Ertesi gün 04:59"], Basliklar(bugun.GetProperty("saatli")));
        Assert.Equal(["04:59 dünün"], Basliklar(dun.GetProperty("saatli")));
        Assert.Equal(["Ertesi gün 05:00"], Basliklar(yarin.GetProperty("saatli")));
    }

    [Fact]
    public async Task AllDayEvents_ShowOnEveryDayTheyCover_AndNotOnTheDayTheyEndOn()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await TumGunEtkinligiEkleAsync("İki günlük", new DateOnly(2026, 11, 9), new DateOnly(2026, 11, 10));

        foreach (var (gun, beklenen) in new[] { ("2026-11-08", 0), ("2026-11-09", 1), ("2026-11-10", 1), ("2026-11-11", 0) })
        {
            var govde = (await CizelgeAsync(fabrika, gun)).Govde;
            Assert.Equal(beklenen, govde.GetProperty("saatsiz").GetArrayLength());
            Assert.Equal(0, govde.GetProperty("saatli").GetArrayLength());
        }
    }

    [Fact]
    public async Task WithoutADay_ItIsToday_ByTheSameRule()
    {
        await TemizleAsync();
        // 03:00 on the 8th is still the 7th.
        var fabrika = Fabrika(an: new DateTimeOffset(2026, 11, 8, 3, 0, 0, TimeSpan.FromHours(3)));

        var govde = (await CizelgeAsync(fabrika, null)).Govde;

        Assert.Equal("2026-11-07", govde.GetProperty("gun").GetString());
    }

    // The plan and the capacity

    [Fact]
    public async Task ThePlansItems_AreUnhoured_FirstAmongThem_AndCountedInTheCapacityWithTheEvents()
    {
        await TemizleAsync();
        using var beyin = BeyniKur(PlanJson(("a1", "Rapor", "acik", 60), ("a2", "Bitmiş", "yapildi", 30), ("a3", "Tahminsiz", "acik", null)));
        var fabrika = BeyinliFabrika(beyin, kapasiteSaat: "2");
        await EtkinlikEkleAsync("Bir", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 10, 45));
        await EtkinlikEkleAsync("İki", IstAn(2026, 11, 7, 13), IstAn(2026, 11, 7, 13, 30));
        // An all-day event takes no minutes of the day's work.
        await TumGunEtkinligiEkleAsync("Tatil", Bugun, Bugun);
        await HatirlaticiEkleAsync("Hatırlat", IstAn(2026, 11, 7, 9), saatli: false);

        var govde = (await CizelgeAsync(fabrika, "2026-11-07")).Govde;

        Assert.Equal("tamam", govde.GetProperty("plan").GetString());
        // Plan items, then the all-day events, then the reminders without an hour.
        Assert.Equal(["Rapor", "Bitmiş", "Tahminsiz", "Tatil", "Hatırlat"], Basliklar(govde.GetProperty("saatsiz")));
        var rapor = govde.GetProperty("saatsiz")[0];
        Assert.Equal("plan", rapor.GetProperty("tur").GetString());
        Assert.Equal("acik", rapor.GetProperty("durum").GetString());
        Assert.Equal("Yapılacaklar", rapor.GetProperty("bolum").GetString());
        Assert.Equal(60, rapor.GetProperty("tahminDk").GetInt32());

        // 60 (open plan estimates; the done item and the one without an estimate add nothing) + 45 + 30 (events) = 135 > 120.
        var kapasite = govde.GetProperty("kapasite");
        Assert.Equal(60, kapasite.GetProperty("planDk").GetInt32());
        Assert.Equal(75, kapasite.GetProperty("etkinlikDk").GetInt32());
        Assert.Equal(135, kapasite.GetProperty("toplamDk").GetInt32());
        Assert.Equal(120, kapasite.GetProperty("kapasiteDk").GetInt32());
        Assert.Equal(15, kapasite.GetProperty("asimDk").GetInt32());
    }

    [Fact]
    public async Task TheCapacityWarning_NeedsMoreThanTheDayHolds_NotExactlyWhatItHolds()
    {
        await TemizleAsync();
        using var beyin = BeyniKur(PlanJson(("a1", "Rapor", "acik", 60)));
        var fabrika = BeyinliFabrika(beyin, kapasiteSaat: "2");
        await EtkinlikEkleAsync("Bir saat", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 11));

        // 60 + 60 = 120 = the capacity: no warning.
        Assert.Equal(JsonValueKind.Null, (await CizelgeAsync(fabrika, "2026-11-07")).Govde.GetProperty("kapasite").ValueKind);

        await EtkinlikEkleAsync("Bir dakika daha", IstAn(2026, 11, 7, 12), IstAn(2026, 11, 7, 12, 1));
        Assert.Equal(1, (await CizelgeAsync(fabrika, "2026-11-07")).Govde.GetProperty("kapasite").GetProperty("asimDk").GetInt32());
    }

    [Fact]
    public async Task EventsAlone_CanOverflowTheDay_EvenWithoutABrain()
    {
        await TemizleAsync();
        var fabrika = Fabrika(kapasiteSaat: "1");
        await EtkinlikEkleAsync("Uzun", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 12));

        var govde = (await CizelgeAsync(fabrika, "2026-11-07")).Govde;

        Assert.Equal("yok", govde.GetProperty("plan").GetString());
        Assert.Equal(60, govde.GetProperty("kapasite").GetProperty("asimDk").GetInt32());
    }

    [Fact]
    public async Task APlanThatCouldNotBeRead_IsSaidSo_AndTheEventsAreStillShown()
    {
        await TemizleAsync();
        using var beyin = BeyniKur("""{"hata": {"kod": "gecersiz", "mesaj": "kötü"}}""", cikis: 1);
        var fabrika = BeyinliFabrika(beyin);
        await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 11));

        var (govde, durum) = await CizelgeAsync(fabrika, "2026-11-07");

        Assert.Equal(HttpStatusCode.OK, durum);
        Assert.Equal("okunamadi", govde.GetProperty("plan").GetString());
        Assert.Equal(["Toplantı"], Basliklar(govde.GetProperty("saatli")));
        Assert.Equal(0, govde.GetProperty("saatsiz").GetArrayLength());
    }

    // Google's state

    [Fact]
    public async Task TheAnswer_SaysWhetherGoogleIsOffNotConnectedConnectedOrNeedsReconnect_AndRemindersShowRegardless()
    {
        await TemizleAsync();
        await HatirlaticiEkleAsync("Her zaman", IstAn(2026, 11, 7, 9));

        var kapali = Fabrika(google: false);
        var (kapaliGovde, _) = await CizelgeAsync(kapali, "2026-11-07");
        Assert.Equal("kapali", kapaliGovde.GetProperty("google").GetString());
        Assert.Equal(["Her zaman"], Basliklar(kapaliGovde.GetProperty("saatli")));

        var fabrika = Fabrika();
        Assert.Equal("bagliDegil", (await CizelgeAsync(fabrika, "2026-11-07")).Govde.GetProperty("google").GetString());

        await BaglaAsync(fabrika);
        Assert.Equal("bagli", (await CizelgeAsync(fabrika, "2026-11-07")).Govde.GetProperty("google").GetString());

        await using (var db = YeniDb())
            await db.GoogleBaglantilari.ExecuteUpdateAsync(s => s.SetProperty(b => b.Durum, GoogleBaglantiDurumu.YenidenBaglan), Ct);
        Assert.Equal("yenidenBaglan", (await CizelgeAsync(fabrika, "2026-11-07")).Govde.GetProperty("google").GetString());
    }

    [Fact]
    public async Task TheAnswer_CarriesTheTimeOfTheLastSync()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await BaglaAsync(fabrika);
        Assert.Equal(JsonValueKind.Null, (await CizelgeAsync(fabrika, "2026-11-07")).Govde.GetProperty("sonEsitleme").ValueKind);

        using (var kapsam = fabrika.Services.CreateScope())
            await kapsam.ServiceProvider.GetRequiredService<TakvimEsitleyici>().TurAsync(Ct);

        Assert.Equal(Saat.Simdi, (await CizelgeAsync(fabrika, "2026-11-07")).Govde.GetProperty("sonEsitleme").GetDateTimeOffset());
    }
}
