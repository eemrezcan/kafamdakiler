using System.Net;
using System.Text.Json;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static Kafamdakiler.Tests.SahteGoogle;

namespace Kafamdakiler.Tests;

// Writing to the calendar goes only through the approval queue (K2.3c): "takvim-ekle" (events.insert, undo events.delete) and
// "takvim-tasi" (events.patch, undo patches the old time back). What must not pass silently: a write before approval, an undo that
// deletes or moves an event the person edited on Google since (etag), a payload nobody checked, a write when Google is not connected.
public sealed class TakvimEylemTests(UygulamaFabrikasi uygulama) : TakvimTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private const string Pzt10 = "2026-11-09T10:00:00+03:00";
    private const string Pzt11 = "2026-11-09T11:00:00+03:00";

    private static JsonElement Yuk(object o) => JsonSerializer.SerializeToElement(o);

    private static JsonElement Json(string metin)
    {
        using var belge = JsonDocument.Parse(metin);
        return belge.RootElement.Clone();
    }

    private static IEylemTuru Tur(WebApplicationFactory<Program> fabrika, string ad) => fabrika.Services.GetRequiredService<EylemTurleri>().Bul(ad)!;

    private async Task<Eylem> OnerAsync(WebApplicationFactory<Program> fabrika, string tur, object yuk, bool disKaynak = false)
    {
        using var kapsam = fabrika.Services.CreateScope();
        var sonuc = await kapsam.ServiceProvider.GetRequiredService<EylemServisi>().OnerAsync(
            new EylemOnerisi(tur, Yuk(yuk), "Takvim önerisi", "test", disKaynak), Ct);
        Assert.True(sonuc.Basarili, $"{sonuc.Tur}: {sonuc.Mesaj}");
        return sonuc.Eylem!;
    }

    private async Task<Eylem> EylemAlAsync(Guid id)
    {
        await using var db = YeniDb();
        return await db.Eylemler.AsNoTracking().SingleAsync(e => e.Id == id, Ct);
    }

    private async Task<HttpResponseMessage> SahipPostAsync(WebApplicationFactory<Program> fabrika, string yol) =>
        await GonderAsync(HttpMethod.Post, yol, await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika), fabrika);

    private async Task<WebApplicationFactory<Program>> BagliFabrikaAsync(string takvimler = "primary,is")
    {
        await TemizleAsync();
        var fabrika = Fabrika(takvimler: takvimler);
        await BaglaAsync(fabrika);
        return fabrika;
    }

    // The payload checks

    [Theory]
    [InlineData("""{"baslik":"Toplantı","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""")]
    [InlineData("""{"baslik":"Toplantı","baslangic":"2026-11-09T14:00+03:00","bitis":"2026-11-09T15:00+03:00","yer":"Ofis","takvim":"is"}""")]
    [InlineData("""{"baslik":"Tatil","tumGun":true,"gun":"2026-11-09"}""")]
    [InlineData("""{"baslik":"Tatil","tumGun":true,"gun":"2026-11-09","bitisGunu":"2026-11-12"}""")]
    [InlineData("""{"baslik":"Gece","baslangic":"2026-11-09T23:00:00+03:00","bitis":"2026-11-10T01:00:00+03:00"}""")]
    public async Task AnAddPayload_ThatIsRight_IsAccepted(string yuk)
    {
        var fabrika = await BagliFabrikaAsync();
        var sonuc = Tur(fabrika, "takvim-ekle").Dogrula(Json(yuk));
        Assert.True(sonuc.Basarili, sonuc.Mesaj);
    }

    [Theory]
    [InlineData("""{"baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", "yuk")]
    [InlineData("""{"baslik":"  ","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", "baslik")]
    [InlineData("""{"baslik":"x","baslangic":"2026-11-09T14:00:00","bitis":"2026-11-09T15:00:00"}""", "baslangic")]
    [InlineData("""{"baslik":"x","baslangic":"yarın 14:00","bitis":"2026-11-09T15:00:00+03:00"}""", "baslangic")]
    [InlineData("""{"baslik":"x","baslangic":"2026-11-09T15:00:00+03:00","bitis":"2026-11-09T14:00:00+03:00"}""", "bitis")]
    [InlineData("""{"baslik":"x","baslangic":"2026-11-09T15:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", "bitis")]
    [InlineData("""{"baslik":"x","baslangic":"2026-11-09T15:00:00+03:00","bitis":"2026-11-30T15:00:00+03:00"}""", "bitis")]
    [InlineData("""{"baslik":"x","baslangic":"1999-11-09T15:00:00+03:00","bitis":"1999-11-09T16:00:00+03:00"}""", "baslangic")]
    [InlineData("""{"baslik":"x","baslangic":"2026-11-09T14:00:00+03:00"}""", "baslangic")]
    [InlineData("""{"baslik":"x","tumGun":true,"baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", "tumGun")]
    [InlineData("""{"baslik":"x","tumGun":true}""", "gun")]
    [InlineData("""{"baslik":"x","tumGun":true,"gun":"09.11.2026"}""", "gun")]
    [InlineData("""{"baslik":"x","tumGun":true,"gun":"2026-11-09","bitisGunu":"2026-11-08"}""", "bitisGunu")]
    [InlineData("""{"baslik":"x","tumGun":true,"gun":"2026-11-09","bitisGunu":"2026-12-30"}""", "bitisGunu")]
    [InlineData("""{"baslik":"x","gun":"2026-11-09","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", "gun")]
    [InlineData("""{"baslik":"x","takvim":"baska","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", "takvim")]
    [InlineData("""{"baslik":"x","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00","davetliler":["a@b.c"]}""", "yuk")]
    [InlineData("""["x"]""", "yuk")]
    [InlineData("""{"baslik":42,"baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", "yuk")]
    public async Task AnAddPayload_ThatIsWrong_IsRefused_NamingTheField(string yuk, string alan)
    {
        var fabrika = await BagliFabrikaAsync();
        var sonuc = Tur(fabrika, "takvim-ekle").Dogrula(Json(yuk));
        Assert.False(sonuc.Basarili);
        Assert.Equal(alan, sonuc.Alan);
    }

    [Fact]
    public async Task ATitleOrPlaceThatIsTooLong_IsRefused()
    {
        var fabrika = await BagliFabrikaAsync();
        var uzunBaslik = Yuk(new { baslik = new string('x', 201), baslangic = Pzt10, bitis = Pzt11 });
        var uzunYer = Yuk(new { baslik = "x", baslangic = Pzt10, bitis = Pzt11, yer = new string('y', 301) });
        Assert.Equal("baslik", Tur(fabrika, "takvim-ekle").Dogrula(uzunBaslik).Alan);
        Assert.Equal("yer", Tur(fabrika, "takvim-ekle").Dogrula(uzunYer).Alan);
    }

    [Theory]
    [InlineData("""{"kimlik":"ev1","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", true, "")]
    [InlineData("""{"kimlik":"ev1","tumGun":true,"gun":"2026-11-12"}""", true, "")]
    [InlineData("""{"kimlik":"ev1","takvim":"is","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", true, "")]
    [InlineData("""{"baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", false, "yuk")]
    [InlineData("""{"kimlik":"  ","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", false, "kimlik")]
    [InlineData("""{"kimlik":"ev1","baslangic":"2026-11-09T15:00:00+03:00","bitis":"2026-11-09T14:00:00+03:00"}""", false, "bitis")]
    [InlineData("""{"kimlik":"ev1"}""", false, "baslangic")]
    [InlineData("""{"kimlik":"ev1","takvim":"baska","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", false, "takvim")]
    [InlineData("""{"kimlik":"ev1","baslik":"yeni ad","baslangic":"2026-11-09T14:00:00+03:00","bitis":"2026-11-09T15:00:00+03:00"}""", false, "yuk")]
    public async Task AMovePayload_IsChecked_LikeAnAddPayload(string yuk, bool gecerli, string alan)
    {
        var fabrika = await BagliFabrikaAsync();
        var sonuc = Tur(fabrika, "takvim-tasi").Dogrula(Json(yuk));
        Assert.Equal(gecerli, sonuc.Basarili);
        if (!gecerli)
            Assert.Equal(alan, sonuc.Alan);
    }

    [Fact]
    public async Task WithTheModuleOff_BothKindsRefuseEveryPayload_AndNothingIsStored()
    {
        await TemizleAsync();
        var fabrika = Fabrika(google: false);
        var ekle = Yuk(new { baslik = "x", baslangic = Pzt10, bitis = Pzt11 });
        var tasi = Yuk(new { kimlik = "ev1", baslangic = Pzt10, bitis = Pzt11 });

        Assert.Equal("Google Takvim bağlı değil.", Tur(fabrika, "takvim-ekle").Dogrula(ekle).Mesaj);
        Assert.False(Tur(fabrika, "takvim-tasi").Dogrula(tasi).Basarili);

        using var kapsam = fabrika.Services.CreateScope();
        var sonuc = await kapsam.ServiceProvider.GetRequiredService<EylemServisi>().OnerAsync(new EylemOnerisi("takvim-ekle", ekle, "x", "test", false), Ct);
        Assert.Equal(EylemSonucuTuru.Gecersiz, sonuc.Tur);
        await using var db = YeniDb();
        Assert.Empty(await db.Eylemler.ToListAsync(Ct));
        Assert.Empty(Google.Cagrilar);
    }

    // The queue's rules

    [Fact]
    public async Task ASuggestion_IsNeverWrittenToGoogle_BeforeItIsApproved()
    {
        var fabrika = await BagliFabrikaAsync();

        var eylem = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "Diş randevusu", baslangic = Pzt10, bitis = Pzt11 });

        Assert.Equal(EylemDurumu.Bekliyor, eylem.Durum);
        Assert.Empty(Google.Canlilar("primary"));
        Assert.DoesNotContain("ekle", Google.Cagrilar);
    }

    [Fact]
    public async Task InKendinYapMode_AnAddIsAppliedAtOnce_ButNotWhenItCameFromOutside()
    {
        var fabrika = await BagliFabrikaAsync();
        using (var kapsam = fabrika.Services.CreateScope())
            await kapsam.ServiceProvider.GetRequiredService<EylemServisi>().KipAyarlaAsync("takvim-ekle", EylemKipi.KendinYap, null, Ct);

        var dis = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "Dışarıdan", baslangic = Pzt10, bitis = Pzt11 }, disKaynak: true);
        Assert.Equal(EylemDurumu.Bekliyor, dis.Durum);
        Assert.Empty(Google.Canlilar("primary"));

        var ic = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "İçeriden", baslangic = Pzt10, bitis = Pzt11 });
        Assert.Equal(EylemDurumu.Uygulandi, ic.Durum);
        Assert.Equal(["İçeriden"], Google.Canlilar("primary").Select(e => e.Baslik));
    }

    // takvim-ekle: apply

    [Fact]
    public async Task Approving_AnAdd_CreatesTheEventOnTheDefaultCalendar_WithTheTimeTheTitleAndThePlace()
    {
        var fabrika = await BagliFabrikaAsync();
        var eylem = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "Diş randevusu", baslangic = Pzt10, bitis = Pzt11, yer = "Klinik" });

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/uygula");

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var olusan = Assert.Single(Google.Canlilar("primary"));
        Assert.Equal("Diş randevusu", olusan.Baslik);
        Assert.Equal("Klinik", olusan.Yer);
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 10, 0, 0, TimeSpan.FromHours(3)), olusan.Baslangic!.An);
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 11, 0, 0, TimeSpan.FromHours(3)), olusan.Bitis!.An);
        Assert.Empty(Google.Canlilar("is"));

        var govde = await OkuAsync(yanit);
        Assert.Equal("uygulandi", govde.GetProperty("durum").GetString());
        var bilgi = govde.GetProperty("geriAlmaBilgisi");
        Assert.Equal("primary", bilgi.GetProperty("takvim").GetString());
        Assert.Equal(olusan.Kimlik, bilgi.GetProperty("kimlik").GetString());
        Assert.Equal(olusan.Etag, bilgi.GetProperty("etag").GetString());
    }

    [Fact]
    public async Task AnAllDayAdd_WithAnotherChosenCalendar_GoesThere_WithGoogleExclusiveEndDate()
    {
        var fabrika = await BagliFabrikaAsync();
        var eylem = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "Tatil", tumGun = true, gun = "2026-11-09", bitisGunu = "2026-11-11", takvim = "is" });

        await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/uygula");

        var olusan = Assert.Single(Google.Canlilar("is"));
        Assert.Equal(new DateOnly(2026, 11, 9), olusan.Baslangic!.Gun);
        // The 11th is the last day, so Google's end is the 12th.
        Assert.Equal(new DateOnly(2026, 11, 12), olusan.Bitis!.Gun);
        Assert.Empty(Google.Canlilar("primary"));
    }

    [Fact]
    public async Task Approving_AnAddWhileNoAccountIsConnected_FailsTheActionAndWritesNothing()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var eylem = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "x", baslangic = Pzt10, bitis = Pzt11 });

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/uygula");

        Assert.False(yanit.IsSuccessStatusCode);
        Assert.Equal(EylemDurumu.Hatali, (await EylemAlAsync(eylem.Id)).Durum);
        Assert.DoesNotContain("ekle", Google.Cagrilar);
    }

    [Fact]
    public async Task Approving_AnAddWhenGoogleRefusesTheToken_FailsTheAction_AndTheModuleAsksToReconnect()
    {
        var fabrika = await BagliFabrikaAsync();
        fabrika.Services.GetRequiredService<GoogleErisimi>().Unut();
        Google.YenilemeGecersiz = true;
        var eylem = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "x", baslangic = Pzt10, bitis = Pzt11 });

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/uygula");

        Assert.False(yanit.IsSuccessStatusCode);
        Assert.Equal(EylemDurumu.Hatali, (await EylemAlAsync(eylem.Id)).Durum);
        Assert.DoesNotContain("ekle", Google.Cagrilar);
        await using var db = YeniDb();
        Assert.Equal(GoogleBaglantiDurumu.YenidenBaglan, (await db.GoogleBaglantilari.SingleAsync(Ct)).Durum);
    }

    // takvim-ekle: undo

    private async Task<(Eylem Eylem, GoogleEtkinlik Olusan)> EkleVeUygulaAsync(WebApplicationFactory<Program> fabrika)
    {
        var eylem = await OnerAsync(fabrika, "takvim-ekle", new { baslik = "Diş randevusu", baslangic = Pzt10, bitis = Pzt11 });
        Assert.Equal(HttpStatusCode.OK, (await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/uygula")).StatusCode);
        return (eylem, Assert.Single(Google.Canlilar("primary")));
    }

    [Fact]
    public async Task UndoingAnAdd_DeletesTheEvent_AndTheSyncedCopy_WhileItIsAsTheActionMadeIt()
    {
        var fabrika = await BagliFabrikaAsync();
        var (eylem, olusan) = await EkleVeUygulaAsync(fabrika);
        // The sync has brought it into the database already.
        await using (var db = YeniDb())
        {
            db.TakvimEtkinlikleri.Add(new TakvimEtkinligi
            {
                TakvimKimligi = "primary", GoogleKimligi = olusan.Kimlik, Baslik = "Diş randevusu", Baslangic = Sabah.ToUniversalTime(), Bitis = Sabah.ToUniversalTime(),
            });
            await db.SaveChangesAsync(Ct);
        }

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/geri-al");

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Empty(Google.Canlilar("primary"));
        Assert.Equal(EylemDurumu.GeriAlindi, (await EylemAlAsync(eylem.Id)).Durum);
        await using var db2 = YeniDb();
        Assert.Empty(await db2.TakvimEtkinlikleri.ToListAsync(Ct));
    }

    [Fact]
    public async Task UndoingAnAdd_OfAnEventTheyEditedOnGoogle_DeletesNothing_Says409_AndTheActionStaysApplied()
    {
        var fabrika = await BagliFabrikaAsync();
        var (eylem, olusan) = await EkleVeUygulaAsync(fabrika);
        Google.Degistir("primary", olusan.Kimlik, "Bunu elle değiştirdim");

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/geri-al");

        Assert.Equal(HttpStatusCode.Conflict, yanit.StatusCode);
        Assert.Contains("sonradan değiştirilmiş", (await OkuAsync(yanit)).GetProperty("detail").GetString());
        Assert.Equal("Bunu elle değiştirdim", Assert.Single(Google.Canlilar("primary")).Baslik);
        Assert.DoesNotContain("sil", Google.Cagrilar);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAlAsync(eylem.Id)).Durum);
    }

    [Fact]
    public async Task UndoingAnAdd_WhenTheEventIsEditedBetweenTheReadAndTheDelete_IsStoppedByTheEtag()
    {
        var fabrika = await BagliFabrikaAsync();
        var (eylem, olusan) = await EkleVeUygulaAsync(fabrika);
        // The check passes (the etag still matches), then the person edits, then the delete arrives with the old etag.
        Google.YazmadanOnce = () =>
        {
            Google.YazmadanOnce = null;
            Google.Degistir("primary", olusan.Kimlik, "Tam o sırada değiştirdim");
        };

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/geri-al");

        Assert.Equal(HttpStatusCode.Conflict, yanit.StatusCode);
        Assert.Equal("Tam o sırada değiştirdim", Assert.Single(Google.Canlilar("primary")).Baslik);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAlAsync(eylem.Id)).Durum);
    }

    [Fact]
    public async Task UndoingAnAdd_OfAnEventThatIsAlreadyGone_IsDone_WithoutADeleteCall()
    {
        var fabrika = await BagliFabrikaAsync();
        var (eylem, olusan) = await EkleVeUygulaAsync(fabrika);
        Google.Kaldir("primary", olusan.Kimlik);

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/geri-al");

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.DoesNotContain("sil", Google.Cagrilar);
        Assert.Equal(EylemDurumu.GeriAlindi, (await EylemAlAsync(eylem.Id)).Durum);
    }

    // takvim-tasi

    private async Task<(Eylem Eylem, HttpResponseMessage Yanit)> TasiVeUygulaAsync(WebApplicationFactory<Program> fabrika, string kimlik, object zaman)
    {
        var yuk = JsonSerializer.SerializeToElement(zaman);
        var birlesik = new Dictionary<string, object?> { ["kimlik"] = kimlik };
        foreach (var o in yuk.EnumerateObject())
            birlesik[o.Name] = o.Value;
        var eylem = await OnerAsync(fabrika, "takvim-tasi", birlesik);
        return (eylem, await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/uygula"));
    }

    [Fact]
    public async Task Approving_AMove_PatchesTheEventToTheNewTime_AndUndoPutsTheOldTimeBack()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "ev1", "Toplantı", Ist(2026, 11, 9, 10), Ist(2026, 11, 9, 11));

        var (eylem, yanit) = await TasiVeUygulaAsync(fabrika, "ev1", new { baslangic = "2026-11-10T15:00:00+03:00", bitis = "2026-11-10T16:30:00+03:00" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var tasinan = Google.Bak("primary", "ev1")!;
        Assert.Equal(new DateTimeOffset(2026, 11, 10, 15, 0, 0, TimeSpan.FromHours(3)), tasinan.Baslangic!.An);
        Assert.Equal(new DateTimeOffset(2026, 11, 10, 16, 30, 0, TimeSpan.FromHours(3)), tasinan.Bitis!.An);
        Assert.Equal("Toplantı", tasinan.Baslik);

        var geriAl = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/geri-al");

        Assert.Equal(HttpStatusCode.OK, geriAl.StatusCode);
        var eski = Google.Bak("primary", "ev1")!;
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 10, 0, 0, TimeSpan.FromHours(3)), eski.Baslangic!.An);
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 11, 0, 0, TimeSpan.FromHours(3)), eski.Bitis!.An);
        Assert.Equal(EylemDurumu.GeriAlindi, (await EylemAlAsync(eylem.Id)).Durum);
    }

    [Fact]
    public async Task AnAllDayEvent_CanBeMovedToAnotherDay_AndBack()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "ev1", "Tatil", Gun(2026, 11, 9), Gun(2026, 11, 10));

        var (eylem, yanit) = await TasiVeUygulaAsync(fabrika, "ev1", new { tumGun = true, gun = "2026-11-12" });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Equal(new DateOnly(2026, 11, 12), Google.Bak("primary", "ev1")!.Baslangic!.Gun);
        Assert.Equal(new DateOnly(2026, 11, 13), Google.Bak("primary", "ev1")!.Bitis!.Gun);

        Assert.Equal(HttpStatusCode.OK, (await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/geri-al")).StatusCode);
        Assert.Equal(new DateOnly(2026, 11, 9), Google.Bak("primary", "ev1")!.Baslangic!.Gun);
    }

    [Fact]
    public async Task AMove_ThatWouldTurnATimedEventIntoAnAllDayOne_OrTargetsAMissingEvent_FailsAndChangesNothing()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "ev1", "Toplantı", Ist(2026, 11, 9, 10), Ist(2026, 11, 9, 11));

        var (tur, _) = await TasiVeUygulaAsync(fabrika, "ev1", new { tumGun = true, gun = "2026-11-12" });
        var (yok, _) = await TasiVeUygulaAsync(fabrika, "olmayan", new { baslangic = Pzt10, bitis = Pzt11 });

        Assert.Equal(EylemDurumu.Hatali, (await EylemAlAsync(tur.Id)).Durum);
        Assert.Equal(EylemDurumu.Hatali, (await EylemAlAsync(yok.Id)).Durum);
        Assert.DoesNotContain("tasi", Google.Cagrilar);
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 10, 0, 0, TimeSpan.FromHours(3)), Google.Bak("primary", "ev1")!.Baslangic!.An);
    }

    [Fact]
    public async Task AMove_OfAnEventEditedBetweenTheReadAndThePatch_IsStoppedByTheEtag_AndTheEditSurvives()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "ev1", "Toplantı", Ist(2026, 11, 9, 10), Ist(2026, 11, 9, 11));
        Google.YazmadanOnce = () =>
        {
            Google.YazmadanOnce = null;
            Google.Degistir("primary", "ev1", "Araya giren değişiklik");
        };

        var (eylem, _) = await TasiVeUygulaAsync(fabrika, "ev1", new { baslangic = "2026-11-10T15:00:00+03:00", bitis = "2026-11-10T16:00:00+03:00" });

        Assert.Equal(EylemDurumu.Hatali, (await EylemAlAsync(eylem.Id)).Durum);
        var olay = Google.Bak("primary", "ev1")!;
        Assert.Equal("Araya giren değişiklik", olay.Baslik);
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 10, 0, 0, TimeSpan.FromHours(3)), olay.Baslangic!.An);
    }

    [Fact]
    public async Task UndoingAMove_OfAnEventEditedOnGoogleSince_ChangesNothing_AndSays409()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "ev1", "Toplantı", Ist(2026, 11, 9, 10), Ist(2026, 11, 9, 11));
        var (eylem, _) = await TasiVeUygulaAsync(fabrika, "ev1", new { baslangic = "2026-11-10T15:00:00+03:00", bitis = "2026-11-10T16:00:00+03:00" });
        Google.Degistir("primary", "ev1", "Sonradan değişti");
        var tasiSayisi = Google.Cagrilar.Count(c => c == "tasi");

        var yanit = await SahipPostAsync(fabrika, $"/api/eylemler/{eylem.Id}/geri-al");

        Assert.Equal(HttpStatusCode.Conflict, yanit.StatusCode);
        Assert.Equal(tasiSayisi, Google.Cagrilar.Count(c => c == "tasi"));
        Assert.Equal(new DateTimeOffset(2026, 11, 10, 15, 0, 0, TimeSpan.FromHours(3)), Google.Bak("primary", "ev1")!.Baslangic!.An);
        Assert.Equal(EylemDurumu.Uygulandi, (await EylemAlAsync(eylem.Id)).Durum);
    }

    // The voice path

    [Fact]
    public async Task ByVoice_ACalendarSuggestion_NeedsTakvimYaz_AndTurnsIntoAnEventWhenHeld()
    {
        var fabrika = await BagliFabrikaAsync();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, fabrika);
        await IzinAsync(sahip, "hatirlatici.yaz", fabrika);
        var oneri = new { tur = "takvim-ekle", baslik = "Dişçi", gun = "2026-11-09", saat = "14:00", bitisSaati = "15:30", yer = "Klinik" };

        // Another write permission opens the endpoint, but not this kind.
        var yanit = await GonderAsync(HttpMethod.Post, "/api/is-cikar/uygula", asistan, fabrika, new { secilenler = new[] { oneri } });
        Assert.Equal((HttpStatusCode)207, yanit.StatusCode);
        Assert.Equal("izinYok", (await OkuAsync(yanit)).GetProperty("sonuclar")[0].GetProperty("durum").GetString());
        Assert.Empty(Google.Canlilar("primary"));

        await IzinAsync(sahip, "takvim.yaz", fabrika);
        yanit = await GonderAsync(HttpMethod.Post, "/api/is-cikar/uygula", asistan, fabrika, new { secilenler = new[] { oneri } });
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var olusan = Assert.Single(Google.Canlilar("primary"));
        Assert.Equal("Dişçi", olusan.Baslik);
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 14, 0, 0, TimeSpan.FromHours(3)), olusan.Baslangic!.An);
        Assert.Equal(new DateTimeOffset(2026, 11, 9, 15, 30, 0, TimeSpan.FromHours(3)), olusan.Bitis!.An);
        Assert.Equal("Klinik", olusan.Yer);
    }

    [Fact]
    public async Task ByVoice_WithoutAnHour_ItIsAnAllDayEvent_AndWithoutAnEndItLastsAnHour()
    {
        var fabrika = await BagliFabrikaAsync();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/is-cikar/uygula", sahip, fabrika, new
        {
            secilenler = new object[]
            {
                new { tur = "takvim-ekle", baslik = "Bayram", gun = "2026-11-10" },
                new { tur = "takvim-ekle", baslik = "Kısa", gun = "2026-11-10", saat = "9:00" },
            },
        });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var olaylar = Google.Canlilar("primary").ToDictionary(e => e.Baslik!);
        Assert.True(olaylar["Bayram"].Baslangic!.TumGun);
        Assert.Equal(new DateOnly(2026, 11, 11), olaylar["Bayram"].Bitis!.Gun);
        Assert.Equal(TimeSpan.FromHours(1), olaylar["Kısa"].Bitis!.An - olaylar["Kısa"].Baslangic!.An);
    }

    [Theory]
    [InlineData("""{"tur":"takvim-ekle","baslik":"x","gun":"2026-11-01","saat":"10:00"}""", "geçmişte")]
    [InlineData("""{"tur":"takvim-ekle","baslik":"x","saat":"10:00"}""", "Tarih belirtilmemiş")]
    [InlineData("""{"tur":"takvim-ekle","baslik":"x","gun":"2026-11-10","saat":"25:00"}""", "Saat")]
    [InlineData("""{"tur":"takvim-ekle","baslik":"x","gun":"2026-11-10","bitisSaati":"11:00"}""", "başlangıç saati")]
    [InlineData("""{"tur":"takvim-ekle","baslik":"x","gun":"2026-11-10","saat":"11:00","bitisSaati":"10:00"}""", "sonra olmalı")]
    [InlineData("""{"tur":"takvim-ekle","baslik":" ","gun":"2026-11-10","saat":"11:00"}""", "Başlık")]
    public async Task ByVoice_ABadCalendarSuggestion_IsRefused_AndNothingIsWritten(string oneri, string neden)
    {
        var fabrika = await BagliFabrikaAsync();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        var yanit = await GonderAsync(HttpMethod.Post, "/api/is-cikar/uygula", sahip, fabrika, new { secilenler = new[] { Json(oneri) } });

        Assert.Equal((HttpStatusCode)207, yanit.StatusCode);
        var sonuc = (await OkuAsync(yanit)).GetProperty("sonuclar")[0];
        Assert.Equal("gecersiz", sonuc.GetProperty("durum").GetString());
        Assert.Contains(neden, sonuc.GetProperty("mesaj").GetString());
        Assert.Empty(Google.Canlilar("primary"));
    }
}
