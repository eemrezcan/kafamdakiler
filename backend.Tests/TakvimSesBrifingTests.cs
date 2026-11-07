using System.Net;
using System.Text.Json;
using Kafamdakiler.Brifing;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The calendar in the two modules that read from it or suggest into it: the voice preview (K2.4: Claude may suggest "takvim-ekle", and
// every suggestion is checked as if a stranger wrote it) and the morning briefing (K2.7: today's events go into its input and its cards).
public sealed class TakvimSesBrifingTests(UygulamaFabrikasi uygulama) : TakvimTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>, IDisposable
{
    private const string Projeler = """[{"kimlik": "kitap-kulubu", "yol": "projects/kitap-kulubu/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false}]""";

    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahteClaude _claude = new();

    public new void Dispose()
    {
        base.Dispose();
        _beyin.Dispose();
        _claude.Dispose();
    }

    private Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> SesFabrikasi(bool google = true)
    {
        _beyin.Cikti("proje liste", Projeler);
        return Fabrika(google: google, ek: b =>
            b.UseSetting("Beyin:Komut", _beyin.Komut).UseSetting("Beyin:Vault", _beyin.Vault).UseSetting("Claude:Komut", _claude.Komut));
    }

    private void ClaudeCevabi(params object[] oneriler) => _claude.YapiliYanit(JsonSerializer.Serialize(new { oneriler }));

    private static object Takvim(string baslik, string? gun = "2026-11-09", string? saat = "14:00", string? bitisSaati = null, string? yer = null) =>
        new { tur = "takvim-ekle", baslik, gun, saat, bitisSaati, yer, kaynakParca = $"{baslik} dedi", guven = 0.9 };

    private string Arguman(string ad)
    {
        var a = SahteClaude.Argumanlar(_claude.Cagrilar().Last());
        return a[Array.IndexOf(a, ad) + 1];
    }

    // The voice preview

    [Fact]
    public async Task ClaudeMaySuggestACalendarEvent_TheSchemaAndTheInstructionOfferIt_AndTheAnswerIsNormalised()
    {
        await TemizleAsync();
        var fabrika = SesFabrikasi();
        ClaudeCevabi(
            Takvim("Dişçi", saat: "9:30", bitisSaati: "10:30", yer: "  Klinik  "),
            Takvim("Bayram", gun: "2026-11-10", saat: null));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/is-cikar", sahip, fabrika, new { metin = "Pazartesi dişçiye gidiyorum, salı bayram." });

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var oneriler = (await OkuAsync(yanit)).GetProperty("oneriler");
        Assert.Equal(2, oneriler.GetArrayLength());
        Assert.Equal("takvim-ekle", oneriler[0].GetProperty("tur").GetString());
        Assert.Equal("2026-11-09", oneriler[0].GetProperty("gun").GetString());
        Assert.Equal("09:30", oneriler[0].GetProperty("saat").GetString());
        Assert.Equal("10:30", oneriler[0].GetProperty("bitisSaati").GetString());
        Assert.Equal("Klinik", oneriler[0].GetProperty("yer").GetString());
        // No hour: an all-day event, and the preview says so by having none.
        Assert.Equal(JsonValueKind.Null, oneriler[1].GetProperty("saat").ValueKind);

        // The call: the kind is among the allowed values of the answer shape, and the instruction explains it.
        using var sema = JsonDocument.Parse(Arguman("--json-schema"));
        var turler = sema.RootElement.GetProperty("properties").GetProperty("oneriler").GetProperty("items").GetProperty("properties");
        Assert.Contains("takvim-ekle", turler.GetProperty("tur").GetProperty("enum").EnumerateArray().Select(t => t.GetString()));
        Assert.True(turler.TryGetProperty("bitisSaati", out _));
        Assert.True(turler.TryGetProperty("yer", out _));
        Assert.Contains("takvim-ekle", Arguman("--system-prompt"));
    }

    [Theory]
    [InlineData("2026-11-01", "14:00", null, "geçmişte")]
    [InlineData("2026-11-09", "14:00", "13:00", "sonra olmalı")]
    [InlineData("2026-11-09", "14:00", "zaman", "HH:mm")]
    [InlineData(null, "14:00", null, "belirtilmemiş")]
    public async Task ABadCalendarSuggestionOfClaude_IsLeftOutOfThePreview_WithItsReason(string? gun, string saat, string? bitisSaati, string neden)
    {
        await TemizleAsync();
        var fabrika = SesFabrikasi();
        ClaudeCevabi(Takvim("Kötü", gun: gun, saat: saat, bitisSaati: bitisSaati), Takvim("İyi"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var govde = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/is-cikar", sahip, fabrika, new { metin = "bir şey" }));

        Assert.Equal(["İyi"], govde.GetProperty("oneriler").EnumerateArray().Select(o => o.GetProperty("baslik").GetString()));
        var atlanan = Assert.Single(govde.GetProperty("atlananlar").EnumerateArray());
        Assert.Equal("Kötü", atlanan.GetProperty("baslik").GetString());
        Assert.Contains(neden, atlanan.GetProperty("neden").GetString());
    }

    [Fact]
    public async Task WithTheModuleOff_ACalendarSuggestionIsLeftOut_AndSaysWhy()
    {
        await TemizleAsync();
        var fabrika = SesFabrikasi(google: false);
        ClaudeCevabi(Takvim("Dişçi"));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var govde = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/is-cikar", sahip, fabrika, new { metin = "dişçi" }));

        Assert.Equal(0, govde.GetProperty("oneriler").GetArrayLength());
        Assert.Equal("Google Takvim bağlı değil.", Assert.Single(govde.GetProperty("atlananlar").EnumerateArray()).GetProperty("neden").GetString());
    }

    // The briefing

    private async Task<BrifingGirdisi> GirdiAsync(Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> fabrika)
    {
        using var kapsam = fabrika.Services.CreateScope();
        var sonuc = await kapsam.ServiceProvider.GetRequiredService<BrifingGirdiOkuyucu>().OkuAsync(Bugun, Ct);
        return sonuc.Girdi ?? throw new InvalidOperationException(sonuc.Mesaj);
    }

    [Fact]
    public async Task TheBriefingsInput_HoldsTodaysEvents_AllDayFirst_ThenByTheClock_AndNotOtherDays()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        await EtkinlikEkleAsync("Öğleden sonra", IstAn(2026, 11, 7, 14), IstAn(2026, 11, 7, 15));
        await EtkinlikEkleAsync("Sabah", IstAn(2026, 11, 7, 9, 30), IstAn(2026, 11, 7, 10, 15));
        await TumGunEtkinligiEkleAsync("Tatil", Bugun, Bugun);
        await EtkinlikEkleAsync("Dünkü", IstAn(2026, 11, 6, 10), IstAn(2026, 11, 6, 11));
        await EtkinlikEkleAsync("Yarınki", IstAn(2026, 11, 8, 10), IstAn(2026, 11, 8, 11));
        await EtkinlikEkleAsync("Gece 04:59", IstAn(2026, 11, 7, 4, 59), IstAn(2026, 11, 7, 5, 30));

        var girdi = await GirdiAsync(fabrika);

        Assert.Equal(["Tatil", "Sabah", "Öğleden sonra"], girdi.Takvim.Select(t => t.Baslik));
        Assert.Equal(["Tüm gün", "09:30–10:15", "14:00–15:00"], girdi.Takvim.Select(t => t.Saat));
        Assert.False(girdi.Bos);
        Assert.Contains("takvim", girdi.DesteklenenTurler());
        Assert.Contains("Sabah", girdi.Metin());
        Assert.Equal(girdi.Takvim.Select(t => t.Kimlik).Order(), girdi.Havuz("takvim").Order());
    }

    [Fact]
    public async Task TheBriefingsInput_CutsTheEventsAtAFixedNumber()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        for (var i = 0; i < BrifingGirdiOkuyucu.EnCokTakvim + 5; i++)
            await EtkinlikEkleAsync($"E{i:00}", IstAn(2026, 11, 7, 6, i), IstAn(2026, 11, 7, 6, i + 1));

        var girdi = await GirdiAsync(fabrika);

        Assert.Equal(BrifingGirdiOkuyucu.EnCokTakvim, girdi.Takvim.Count);
        Assert.Equal("E00", girdi.Takvim[0].Baslik);
    }

    [Fact]
    public async Task ADayWithOnlyEvents_IsNotAnEmptyDay_AndTheRulesMakeACalendarCardThatLinksToThem()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var e1 = await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 7, 10), IstAn(2026, 11, 7, 11));
        var e2 = await EtkinlikEkleAsync("Randevu", IstAn(2026, 11, 7, 15), IstAn(2026, 11, 7, 16));
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var govde = await OkuAsync(yanit);
        Assert.Equal("hesap", govde.GetProperty("yontem").GetString());
        var kart = Assert.Single(govde.GetProperty("kartlar").EnumerateArray(), k => k.GetProperty("tur").GetString() == "takvim");
        Assert.Contains("2 takvim etkinliği", kart.GetProperty("baslik").GetString());
        Assert.Equal(
            new[] { e1.Id.ToString(), e2.Id.ToString() }.Order(),
            kart.GetProperty("bagliKimlikler").EnumerateArray().Select(k => k.GetString()!).Order());
        Assert.Contains("10:00", kart.GetProperty("metin").GetString());
    }

    [Fact]
    public async Task WithNoEventsAndNothingElse_TheBriefingIsStillTheEmptyDayOne()
    {
        await TemizleAsync();
        var fabrika = Fabrika();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);

        var govde = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/brifing/bugun", sahip, fabrika));

        var kart = Assert.Single(govde.GetProperty("kartlar").EnumerateArray());
        Assert.Equal("bos", kart.GetProperty("tur").GetString());
    }
}
