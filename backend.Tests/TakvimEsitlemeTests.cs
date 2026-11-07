using System.Net;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static Kafamdakiler.Tests.SahteGoogle;

namespace Kafamdakiler.Tests;

// The incremental sync (K2.3c), on a fake Google that behaves like the real one about sync tokens. What must not pass silently: a round
// that fails halfway changing anything or moving the token (that would be lost events), a full sync deleting what it could not re-read,
// a window sent with a token, a stale 410 token leaving the calendar behind, and a revoked token being hammered every round.
public sealed class TakvimEsitlemeTests(UygulamaFabrikasi uygulama) : TakvimTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private static async Task<EsitlemeOzeti> EsitleAsync(WebApplicationFactory<Program> fabrika)
    {
        using var kapsam = fabrika.Services.CreateScope();
        return await kapsam.ServiceProvider.GetRequiredService<TakvimEsitleyici>().TurAsync(Ct);
    }

    private async Task<WebApplicationFactory<Program>> BagliFabrikaAsync(string takvimler = "primary")
    {
        await TemizleAsync();
        var fabrika = Fabrika(takvimler: takvimler);
        await BaglaAsync(fabrika);
        return fabrika;
    }

    private async Task<List<TakvimEtkinligi>> SatirlarAsync(string takvim = "primary")
    {
        await using var db = YeniDb();
        return await db.TakvimEtkinlikleri.AsNoTracking().Where(e => e.TakvimKimligi == takvim).OrderBy(e => e.Baslangic).ThenBy(e => e.Baslik).ToListAsync(Ct);
    }

    private async Task<TakvimEsitlemeDurumu> DurumAsync(string takvim = "primary")
    {
        await using var db = YeniDb();
        return await db.TakvimEsitlemeleri.AsNoTracking().SingleAsync(e => e.TakvimKimligi == takvim, Ct);
    }

    [Fact]
    public async Task TheFirstSync_IsAFullOne_WithTheWindow_AndStoresTimedAndAllDayEventsOfEachChosenCalendar()
    {
        var fabrika = await BagliFabrikaAsync("primary,is");
        Google.Olustur("primary", "a", "Toplantı", Ist(2026, 11, 7, 10), Ist(2026, 11, 7, 11, 30), "Ofis");
        Google.Olustur("primary", "b", "Bayram", Gun(2026, 11, 10), Gun(2026, 11, 12));
        Google.Olustur("is", "c", "İş takvimi", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));
        Google.Olustur("baska", "d", "Seçilmemiş takvim", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));

        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(new EsitlemeOzeti(2, 3, 0, 0, 0), ozet);
        // Only the chosen calendars are asked, each with the window and no sync token.
        Assert.Equal(["primary", "is"], Google.ListeIstekleri.Select(i => i.Takvim));
        Assert.All(Google.ListeIstekleri, i =>
        {
            Assert.Null(i.SyncToken);
            Assert.Equal(Saat.Simdi.AddDays(-7), i.ZamanMin);
            Assert.Equal(Saat.Simdi.AddDays(60), i.ZamanMax);
        });

        var satirlar = await SatirlarAsync();
        var toplanti = Assert.Single(satirlar, s => s.GoogleKimligi == "a");
        Assert.Equal("Toplantı", toplanti.Baslik);
        Assert.Equal("Ofis", toplanti.Yer);
        Assert.False(toplanti.TumGun);
        Assert.Equal(IstAn(2026, 11, 7, 10).ToUniversalTime(), toplanti.Baslangic);
        Assert.Equal(IstAn(2026, 11, 7, 11, 30).ToUniversalTime(), toplanti.Bitis);
        Assert.Equal(new DateOnly(2026, 11, 7), toplanti.BaslangicGunu);
        Assert.False(string.IsNullOrEmpty(toplanti.Etag));

        // An all-day event keeps its civil dates, the end exclusive as Google has it.
        var bayram = Assert.Single(satirlar, s => s.GoogleKimligi == "b");
        Assert.True(bayram.TumGun);
        Assert.Equal(new DateOnly(2026, 11, 10), bayram.BaslangicGunu);
        Assert.Equal(new DateOnly(2026, 11, 12), bayram.BitisGunu);

        Assert.Single(await SatirlarAsync("is"));
        Assert.Empty(await SatirlarAsync("baska"));
        Assert.StartsWith("sync-", (await DurumAsync()).SyncToken);
        Assert.Equal(Saat.Simdi, (await DurumAsync()).SonTamEsitleme);
    }

    [Fact]
    public async Task AnswersInManyPages_AreReadToTheEnd()
    {
        var fabrika = await BagliFabrikaAsync();
        for (var i = 0; i < 5; i++)
            Google.Olustur("primary", $"e{i}", $"Etkinlik {i}", Ist(2026, 11, 8, 9 + i), Ist(2026, 11, 8, 10 + i));
        Google.SayfaBuyuklugu = 2;

        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(5, ozet.Eklenen);
        Assert.Equal(5, (await SatirlarAsync()).Count);
        Assert.Equal([null, "p2", "p4"], Google.ListeIstekleri.Select(i => i.SayfaToken));
    }

    [Fact]
    public async Task TheNextRound_IsIncremental_AppliesAdditionsChangesAndDeletions_AndSendsNoWindow()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "a", "Değişecek", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));
        Google.Olustur("primary", "b", "Silinecek", Ist(2026, 11, 8, 11), Ist(2026, 11, 8, 12));
        Google.Olustur("primary", "c", "Aynı kalacak", Ist(2026, 11, 8, 13), Ist(2026, 11, 8, 14));
        await EsitleAsync(fabrika);
        var ilkToken = (await DurumAsync()).SyncToken;
        var cEtag = (await SatirlarAsync()).Single(s => s.GoogleKimligi == "c").Etag;

        Saat.Simdi += TimeSpan.FromHours(1);
        Google.Degistir("primary", "a", "Değişti");
        Google.Kaldir("primary", "b");
        Google.Olustur("primary", "d", "Yeni", Ist(2026, 11, 9, 9), Ist(2026, 11, 9, 10));
        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(new EsitlemeOzeti(1, 1, 1, 1, 0), ozet);
        // The second request carries the token of the first answer, and not the window.
        var istek = Google.ListeIstekleri.Last();
        Assert.Equal(ilkToken, istek.SyncToken);
        Assert.Null(istek.ZamanMin);
        Assert.Null(istek.ZamanMax);

        var satirlar = await SatirlarAsync();
        Assert.Equal(["Değişti", "Aynı kalacak", "Yeni"], satirlar.Select(s => s.Baslik));
        Assert.Equal(cEtag, satirlar.Single(s => s.GoogleKimligi == "c").Etag);
        var durum = await DurumAsync();
        Assert.NotEqual(ilkToken, durum.SyncToken);
        // Only the full sync moves the mark of the last full one.
        Assert.Equal(Saat.Simdi - TimeSpan.FromHours(1), durum.SonTamEsitleme);
        Assert.Equal(Saat.Simdi, durum.SonEsitleme);
    }

    [Fact]
    public async Task ARoundWithNothingNew_ChangesNothing()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "a", "Tek", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));
        await EsitleAsync(fabrika);

        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(new EsitlemeOzeti(1, 0, 0, 0, 0), ozet);
        Assert.Single(await SatirlarAsync());
    }

    [Fact]
    public async Task AnExpiredSyncToken_410_StartsAFullSync_AndWhatIsGoneFromGoogleGoesToo()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "a", "Kalacak", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));
        Google.Olustur("primary", "b", "Gidecek", Ist(2026, 11, 8, 11), Ist(2026, 11, 8, 12));
        await EsitleAsync(fabrika);

        Saat.Simdi += TimeSpan.FromHours(1);
        Google.Kaldir("primary", "b");
        Google.Olustur("primary", "c", "Yeni", Ist(2026, 11, 9, 9), Ist(2026, 11, 9, 10));
        Google.SyncTokenEskidi = true;
        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(new EsitlemeOzeti(1, 1, 0, 1, 0), ozet);
        // First the full sync, then the token that was refused, then a full one again.
        Assert.Equal([false, true, false], Google.ListeIstekleri.Select(i => i.SyncToken is not null));
        Assert.Equal(Saat.Simdi.AddDays(60), Google.ListeIstekleri.Last().ZamanMax);
        Assert.Equal(["Kalacak", "Yeni"], (await SatirlarAsync()).Select(s => s.Baslik));
        Assert.Equal(Saat.Simdi, (await DurumAsync()).SonTamEsitleme);
    }

    [Fact]
    public async Task TheFullSync_RunsAtLeastOnceADay_SoTheWindowKeepsMoving()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "a", "Tek", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));
        await EsitleAsync(fabrika);

        Saat.Simdi += TimeSpan.FromHours(23);
        await EsitleAsync(fabrika);
        Assert.NotNull(Google.ListeIstekleri.Last().SyncToken);

        Saat.Simdi += TimeSpan.FromHours(2);
        await EsitleAsync(fabrika);
        var istek = Google.ListeIstekleri.Last();
        Assert.Null(istek.SyncToken);
        Assert.Equal(Saat.Simdi.AddDays(-7), istek.ZamanMin);
        Assert.Equal(Saat.Simdi.AddDays(60), istek.ZamanMax);
    }

    [Fact]
    public async Task AnIncrementalRoundThatFailsHalfway_ChangesNothing_KeepsTheOldToken_AndTheNextRoundCatchesUp()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "a", "Eski", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));
        await EsitleAsync(fabrika);
        var token = (await DurumAsync()).SyncToken;
        var esitleme = (await DurumAsync()).SonEsitleme;

        Saat.Simdi += TimeSpan.FromHours(1);
        Google.Degistir("primary", "a", "Eskinin yenisi");
        for (var i = 0; i < 3; i++)
            Google.Olustur("primary", $"n{i}", $"Yeni {i}", Ist(2026, 11, 9, 9 + i), Ist(2026, 11, 9, 10 + i));
        Google.SayfaBuyuklugu = 1;
        Google.HataSayfasi = 2;

        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(1, ozet.Basarisiz);
        Assert.Equal(0, ozet.Eklenen + ozet.Guncellenen + ozet.Silinen);
        // The first two pages were read and thrown away: not one row changed, and the token and the time stand.
        Assert.Equal(["Eski"], (await SatirlarAsync()).Select(s => s.Baslik));
        var durum = await DurumAsync();
        Assert.Equal(token, durum.SyncToken);
        Assert.Equal(esitleme, durum.SonEsitleme);

        Google.HataSayfasi = null;
        var sonraki = await EsitleAsync(fabrika);
        Assert.Equal(new EsitlemeOzeti(1, 3, 1, 0, 0), sonraki);
        Assert.Equal(["Eskinin yenisi", "Yeni 0", "Yeni 1", "Yeni 2"], (await SatirlarAsync()).Select(s => s.Baslik).Order());
    }

    [Fact]
    public async Task AFullSyncThatFailsHalfway_DoesNotDeleteTheRowsItHad()
    {
        var fabrika = await BagliFabrikaAsync();
        for (var i = 0; i < 3; i++)
            Google.Olustur("primary", $"e{i}", $"Etkinlik {i}", Ist(2026, 11, 8, 9 + i), Ist(2026, 11, 8, 10 + i));
        await EsitleAsync(fabrika);
        var token = (await DurumAsync()).SyncToken;

        // A day later the full sync is due, and the network breaks after its first page: with the old rows missing from the pages read so far.
        Saat.Simdi += TimeSpan.FromHours(25);
        Google.SayfaBuyuklugu = 1;
        Google.HataSayfasi = 1;
        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(1, ozet.Basarisiz);
        Assert.Equal(3, (await SatirlarAsync()).Count);
        Assert.Equal(token, (await DurumAsync()).SyncToken);
    }

    [Fact]
    public async Task ATitleThatCameFromOutside_IsMadeOneLine_Cut_AndGivenAPlaceholderWhenEmpty()
    {
        var fabrika = await BagliFabrikaAsync();
        Google.Olustur("primary", "a", "İki\nsatır\tbaşlık", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10), "Yer\r\nsatırı");
        Google.Olustur("primary", "b", new string('x', 800), Ist(2026, 11, 8, 11), Ist(2026, 11, 8, 12));
        Google.Olustur("primary", "c", "  ", Ist(2026, 11, 8, 13), Ist(2026, 11, 8, 14));

        await EsitleAsync(fabrika);

        var satirlar = await SatirlarAsync();
        Assert.Equal("İki satır başlık", satirlar.Single(s => s.GoogleKimligi == "a").Baslik);
        Assert.Equal("Yer satırı", satirlar.Single(s => s.GoogleKimligi == "a").Yer);
        Assert.Equal(500, satirlar.Single(s => s.GoogleKimligi == "b").Baslik.Length);
        Assert.Equal("(Başlıksız)", satirlar.Single(s => s.GoogleKimligi == "c").Baslik);
    }

    [Fact]
    public async Task ARefusedRefreshToken_StopsTheRound_WithoutAskingForEvents_AndMarksReconnect()
    {
        var fabrika = await BagliFabrikaAsync();
        fabrika.Services.GetRequiredService<GoogleErisimi>().Unut();
        Google.YenilemeGecersiz = true;

        var ozet = await EsitleAsync(fabrika);

        Assert.Equal(ErisimDurumu.YenidenBaglan, ozet.ErisimSorunu);
        Assert.Empty(Google.ListeIstekleri);
        await using var db = YeniDb();
        Assert.Equal(GoogleBaglantiDurumu.YenidenBaglan, (await db.GoogleBaglantilari.SingleAsync(Ct)).Durum);
    }

    [Fact]
    public async Task WithNoAccountConnectedOrTheModuleOff_TheRoundDoesNothing()
    {
        await TemizleAsync();
        var bagsiz = Fabrika();
        Assert.Equal(ErisimDurumu.BagliDegil, (await EsitleAsync(bagsiz)).ErisimSorunu);

        var kapali = Fabrika(google: false);
        Assert.Equal(ErisimDurumu.Kapali, (await EsitleAsync(kapali)).ErisimSorunu);

        Assert.Empty(Google.Cagrilar);
    }

    [Fact]
    public async Task TheSyncEndpoint_IsTheSahips_RunsARound_AndRefusesWhenNothingIsConnected()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var bagsiz = await GonderAsync(HttpMethod.Post, "/api/google/esitle", sahip, fabrika);
        Assert.Equal(HttpStatusCode.Conflict, bagsiz.StatusCode);

        await BaglaAsync(fabrika);
        Google.Olustur("primary", "a", "Tek", Ist(2026, 11, 8, 9), Ist(2026, 11, 8, 10));
        var yanit = await GonderAsync(HttpMethod.Post, "/api/google/esitle", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.Equal(1, (await OkuAsync(yanit)).GetProperty("eklenen").GetInt32());
    }
}
