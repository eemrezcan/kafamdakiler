using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Asistan;
using Kafamdakiler.Brifing;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The Asistan page of the web (K-0024, W2) in a browser's shoes: cookies, antiforgery tokens, no automatic redirects. The whole app with a fake claude,
// a fake beyin.py and a clock the test owns (Monday 2026-11-09, 07:00 in Istanbul). What they hold on to: the box is the same entry as the API
// (the same id runs once), every kind of result and every item of the stream shows, every button on it does what the API's does, a failure is said
// on the page, and the page stays the Sahip's.
public sealed partial class AsistanSayfalariTests(UygulamaFabrikasi uygulama) : AsistanTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    private async Task<(WebApplicationFactory<Program> Fabrika, HttpClient Tarayici)> SayfaHazirlaAsync(bool claude = true)
    {
        var (fabrika, _) = await HazirlaAsync(claude: claude, google: false);
        return (fabrika, await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct));
    }

    private async Task<string> HamAsync(HttpClient tarayici, string yol = "/Asistan")
    {
        var yanit = await tarayici.GetAsync(yol, Ct);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return await WebOturumu.HamAsync(yanit, Ct);
    }

    private static string Metin(string ham) => WebUtility.HtmlDecode(ham);

    // Posts the fields to a handler of the page; the token comes from the page. The answer is the redirect, not followed.
    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string islem, Dictionary<string, string> alanlar, string sayfa = "/Asistan")
    {
        var token = TokenDeseni().Match(await tarayici.GetStringAsync(sayfa, Ct)).Groups[1].Value;
        Assert.NotEmpty(token);
        var govde = new Dictionary<string, string>(alanlar) { ["__RequestVerificationToken"] = token };
        // The id of what a button is on travels in the address, as the page's forms send it.
        var id = govde.Remove("id", out var deger) ? $"id={deger}&" : "";
        return await tarayici.PostAsync($"{sayfa}?{id}handler={islem}", new FormUrlEncodedContent(govde), Ct);
    }

    private async Task<string> SonrakiAsync(HttpClient tarayici, HttpResponseMessage yonlendirme)
    {
        Assert.Equal(HttpStatusCode.Redirect, yonlendirme.StatusCode);
        return Metin(await tarayici.GetStringAsync(yonlendirme.Headers.Location, Ct));
    }

    // What the box sends: the page's own id for the input, and the words.
    private async Task<HttpResponseMessage> GonderAsync(HttpClient tarayici, string metin, Guid? girdiId = null) =>
        await PostAsync(tarayici, "Girdi", new() { ["girdiId"] = (girdiId ?? Guid.NewGuid()).ToString(), ["metin"] = metin });

    private async Task<List<T>> SatirlarAsync<T>(Func<Kafamdakiler.Data.AppDbContext, IQueryable<T>> sorgu) where T : class
    {
        await using var db = YeniDb();
        return await sorgu(db).AsNoTracking().ToListAsync(Ct);
    }

    // The part of the page of one stream item (the first one of that kind, up to the next one).
    private static List<string> Ogeler(string ham, string tur) =>
        Regex.Matches(ham, $"data-kd-akis=\"{tur}\".*?(?=data-kd-akis=\"|</section>)", RegexOptions.Singleline).Select(m => m.Value).ToList();

    private static string Duz(string html) => Regex.Replace(Regex.Replace(Metin(html), "<[^>]+>", " "), "\\s+", " ").Trim();

    private async Task BekleyenEylemAsync(string baslik, string tur = "hatirlatici-kur", bool disKaynak = false)
    {
        using var kapsam = Uygulama.Services.CreateScope();
        var servis = kapsam.ServiceProvider.GetRequiredService<EylemServisi>();
        var sonuc = await servis.OnerAsync(new EylemOnerisi(tur,
            JsonSerializer.SerializeToElement(new { baslik, gun = "2030-01-01" }), baslik, "gelen", disKaynak, "Mailde yazıyor", null), Ct);
        Assert.Equal(EylemDurumu.Bekliyor, sonuc.Eylem!.Durum);
    }

    // Who may open it

    [Fact]
    public async Task ThePage_IsClosedToVisitors_AndToTheAsistanEvenWithItsPermission()
    {
        var (fabrika, _) = await SayfaHazirlaAsync();
        var anonim = fabrika.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        var asistan = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.AsistanEposta, Ct);

        var a = await anonim.GetAsync("/Asistan", Ct);
        Assert.Equal(("/Hesap/Giris", HttpStatusCode.Redirect), (a.Headers.Location!.AbsolutePath, a.StatusCode));

        // Without the permission, and with `asistan.kullan` too: the web is the Sahip's; the Asistan account has the API.
        var sahipToken = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        await IzinAsync(sahipToken, "asistan.kullan", fabrika);
        foreach (var _ in new[] { 1, 2 })
        {
            var b = await asistan.GetAsync("/Asistan", Ct);
            Assert.Equal(("/Hesap/Erisim", HttpStatusCode.Redirect), (b.Headers.Location!.AbsolutePath, b.StatusCode));
        }

        var yazma = await asistan.PostAsync("/Asistan?handler=Girdi", new FormUrlEncodedContent(new Dictionary<string, string> { ["metin"] = "x" }), Ct);
        Assert.NotEqual(HttpStatusCode.OK, yazma.StatusCode);
        Assert.Empty(AsistanClaude.Cagrilar());
    }

    [Fact]
    public async Task APostWithoutTheAntiforgeryToken_IsRefused_AndNothingRuns()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();

        var yanit = await tarayici.PostAsync("/Asistan?handler=Girdi", new FormUrlEncodedContent(new Dictionary<string, string> { ["girdiId"] = Guid.NewGuid().ToString(), ["metin"] = "Yarın Ali" }), Ct);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.Empty(AsistanClaude.Cagrilar());
    }

    // The box

    [Fact]
    public async Task TheBox_RunsTheSameEntryAsTheApi_AndTheStreamShowsTheWordsAndEveryResult()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        AsistanClaude.YapiliYanit(Cevap(
            Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00", kaynakParca: "Yarın 9'da Ali'yi ara."),
            Oneri("plan-ekle", "Raporu bitir", gun: BugunMetni, tahmin: 30, kaynakParca: "Raporu bugün bitir."),
            Oneri("not", "Fikir", kaynakParca: "Bir fikir: aylık tema.")));

        var yanit = await GonderAsync(tarayici, "Yarın 9'da Ali'yi ara. Raporu bugün bitir. Bir fikir: aylık tema.");
        var sonraki = await SonrakiAsync(tarayici, yanit);

        Assert.Equal("/Asistan", yanit.Headers.Location!.OriginalString);
        Assert.Contains("3 sonuç", sonraki);
        // What the API would have made, made.
        var hatirlatici = Assert.Single(await SatirlarAsync(db => db.Hatirlaticilar));
        Assert.Equal(("Ali'yi ara", new TimeOnly(9, 0)), (hatirlatici.Baslik, hatirlatici.Saat));
        Assert.Single(await SatirlarAsync(db => db.Yakalamalar));
        Assert.Equal(1, BeyinCagrisi("gun", "ekle"));

        var ham = await HamAsync(tarayici);
        // The person's words, then one card per result with what it said.
        var kullanici = Assert.Single(Ogeler(ham, "kullanici"));
        Assert.Contains("Yarın 9'da Ali'yi ara. Raporu bugün bitir.", Duz(kullanici));
        var sonuclar = Ogeler(ham, "sonuc");
        var tur = Regex.Matches(sonuclar[0], "data-kd-sonuc=\"([^\"]+)\"").Select(m => m.Groups[1].Value).ToList();
        Assert.Equal(["hatirlatici-kur", "plan-ekle", "not"], tur);
        var metin = Duz(sonuclar[0]);
        Assert.Contains("Ali'yi ara", metin);
        Assert.Contains("yarın 09:00 · 🔔", metin);
        Assert.Contains("bugün · plana eklendi · ~30 dk", metin);
        Assert.Contains("Yakalamaya eklendi", metin);
    }

    [Fact]
    public async Task TheBox_PressingSendTwice_RunsTheInputOnce()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        AsistanClaude.YapiliYanit(Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00")));
        var id = Guid.NewGuid();

        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Yarın 9'da Ali'yi ara", id));
        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Yarın 9'da Ali'yi ara", id));

        Assert.Single(AsistanClaude.Cagrilar());
        Assert.Single(await SatirlarAsync(db => db.Hatirlaticilar));
        Assert.Single(Ogeler(await HamAsync(tarayici), "kullanici"));
    }

    [Fact]
    public async Task TheBox_HasAFreshIdEachTimeThePageIsMade()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();

        var bir = Regex.Match(await HamAsync(tarayici), "name=\"girdiId\" value=\"([^\"]+)\"").Groups[1].Value;
        var iki = Regex.Match(await HamAsync(tarayici), "name=\"girdiId\" value=\"([^\"]+)\"").Groups[1].Value;

        Assert.True(Guid.TryParse(bir, out _));
        Assert.NotEqual(bir, iki);
    }

    [Fact]
    public async Task TheBox_EmptyOrTooLongText_IsSaidOnThePage_AndNothingRuns()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();

        var bos = await SonrakiAsync(tarayici, await GonderAsync(tarayici, "   "));
        var uzun = await SonrakiAsync(tarayici, await GonderAsync(tarayici, new string('a', 4001)));

        Assert.Contains("Metin ya da fotoğraftan en az biri dolu olmalı.", bos);
        Assert.Contains("en çok 4000 karakter", uzun);
        Assert.Empty(AsistanClaude.Cagrilar());
        Assert.Empty(await SatirlarAsync(db => db.AsistanMesajlari));
    }

    [Fact]
    public async Task TheBox_WithoutClaude_KeepsTheTextAsANote_AndSaysSo()
    {
        var (_, tarayici) = await SayfaHazirlaAsync(claude: false);

        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Yarın 9'da Ali'yi ara"));

        var yakalama = Assert.Single(await SatirlarAsync(db => db.Yakalamalar));
        Assert.Equal("Yarın 9'da Ali'yi ara", yakalama.Metin);
        var ham = await HamAsync(tarayici);
        Assert.Single(Ogeler(ham, "sonuc"));
        Assert.Contains("Yakalamaya eklendi", Duz(Ogeler(ham, "sonuc")[0]));
    }

    // The kinds of result

    [Fact]
    public async Task Results_ShowWhatWasForbidden_WhatBrokeARule_AndWhereATapGoes()
    {
        var (fabrika, tarayici) = await SayfaHazirlaAsync();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        await GonderAsync(HttpMethod.Put, "/api/yonetim/eylem-izinleri/gorev-ekle", sahip, fabrika, new { kip = "yasak" });
        AsistanClaude.YapiliYanit(Cevap(
            Oneri("hatirlatici-kur", "Geçmişte", gun: "2026-11-01", saat: "09:00"),
            Oneri("gorev-ekle", "Üye girişi", proje: "kitap-kulubu"),
            Oneri("plan-ekle", "Raporu bitir", gun: Yarin),
            Oneri("is", "Takvim sayfası", proje: "kitap-kulubu", tip: "kod")));

        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "dört şey"));

        var kartlar = Regex.Matches(Ogeler(await HamAsync(tarayici), "sonuc")[0], "<article class=\"kd-akis-oge kd-akis-kart ([^\"]*)\" data-kd-sonuc=\"([^\"]+)\".*?</article>", RegexOptions.Singleline)
            .Select(m => (Sinif: m.Groups[1].Value, Tur: m.Groups[2].Value, Metin: Duz(m.Value), Ham: m.Value)).ToList();
        Assert.Equal(4, kartlar.Count);
        // (the service puts what did not work after what did; the cards are read by their kind)
        var gecersiz = kartlar.Single(k => k.Tur == "hatirlatici-kur");
        var yasak = kartlar.Single(k => k.Tur == "gorev-ekle");
        var plan = kartlar.Single(k => k.Tur == "plan-ekle");
        var kart = kartlar.Single(k => k.Tur == "is");
        // Broke a rule (a day in the past): nothing was done, and it is said, with no "geri al".
        Assert.Equal("is-sorun", gecersiz.Sinif);
        Assert.Contains("Geçersiz", gecersiz.Metin);
        Assert.DoesNotContain("handler=GeriAl", gecersiz.Ham);
        // Forbidden: said so, with the reason.
        Assert.Equal("is-sorun", yasak.Sinif);
        Assert.Contains("İzin yok", yasak.Metin);
        Assert.Contains("yasak", yasak.Metin);
        Assert.DoesNotContain("handler=GeriAl", yasak.Ham);
        // Done: a link to the day it went to (E8: /gun/{tarih} is the calendar of that day), and a work card links to its page.
        Assert.Equal("is-ok", plan.Sinif);
        Assert.Contains("href=\"/Takvim?ay=2026-11&amp;gun=2026-11-10\"", plan.Ham);
        Assert.Equal("is-ok", kart.Sinif);
        Assert.Contains("href=\"/Isler/Detay/takvim-sayfasi\"", kart.Ham);
        // A plan item and a card cannot be taken back.
        Assert.DoesNotContain("handler=GeriAl", plan.Ham);
        Assert.DoesNotContain("handler=GeriAl", kart.Ham);
    }

    [Fact]
    public async Task UndoOnAReminder_TakesItBack_AndTheButtonIsGone()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        AsistanClaude.YapiliYanit(Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00")));
        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Yarın 9'da Ali'yi ara"));
        var ham = await HamAsync(tarayici);
        Assert.Contains("handler=GeriAl", ham);
        var eylemId = Regex.Match(ham, "id=([0-9a-f-]{36})&amp;handler=GeriAl").Groups[1].Value;
        Assert.NotEmpty(eylemId);

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "GeriAl", new() { ["id"] = eylemId }));

        Assert.Contains("Geri alındı", sonraki);
        Assert.Equal(HatirlaticiDurumu.Arsiv, Assert.Single(await SatirlarAsync(db => db.Hatirlaticilar)).Durum);
        Assert.DoesNotContain("handler=GeriAl", await HamAsync(tarayici));
    }

    [Fact]
    public async Task UndoOnANote_DeletesTheCaptureWhileItWaits_AndRefusesOnceItIsOnItsWay()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        AsistanClaude.YapiliSirali(
            Cevap(Oneri("not", "Bir", kaynakParca: "Birinci not")),
            Cevap(Oneri("not", "İki", kaynakParca: "İkinci not")));
        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Birinci not"));
        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "İkinci not"));
        var yakalamalar = await SatirlarAsync(db => db.Yakalamalar.OrderBy(y => y.CreatedAt));
        Assert.Equal(2, yakalamalar.Count);

        // The second one is already sent to the brain: it cannot be taken back (the stream does not even offer it).
        await using (var db = YeniDb())
            await db.Yakalamalar.Where(y => y.Id == yakalamalar[1].Id).ExecuteUpdateAsync(s => s.SetProperty(y => y.Durum, YakalamaDurumu.BeyneGitti), Ct);
        var ham = await HamAsync(tarayici);
        Assert.Single(Regex.Matches(ham, "handler=NotuGeriAl"));
        Assert.Contains($"id={yakalamalar[0].Id}&amp;handler=NotuGeriAl", ham);

        var geri = await SonrakiAsync(tarayici, await PostAsync(tarayici, "NotuGeriAl", new() { ["id"] = yakalamalar[0].Id.ToString() }));
        Assert.Contains("Not geri alındı", geri);
        Assert.DoesNotContain(await SatirlarAsync(db => db.Yakalamalar), y => y.Id == yakalamalar[0].Id);

        var gonderilmis = await SonrakiAsync(tarayici, await PostAsync(tarayici, "NotuGeriAl", new() { ["id"] = yakalamalar[1].Id.ToString() }));
        Assert.Contains("artık geri alınamaz", gonderilmis);
        Assert.Contains(await SatirlarAsync(db => db.Yakalamalar), y => y.Id == yakalamalar[1].Id);

        var yok = await SonrakiAsync(tarayici, await PostAsync(tarayici, "NotuGeriAl", new() { ["id"] = Guid.NewGuid().ToString() }));
        Assert.Contains("Not bulunamadı", yok);
    }

    // The question

    [Fact]
    public async Task AQuestion_ShowsItsOptionsAndTheOwnAnswerField_AndAnOptionAppliesTheInput()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        AsistanClaude.YapiliSirali(
            SoruluCevap("Bu bir hatırlatıcı mı, plan mı?", "Hatırlatıcı", "Plan"),
            Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00")));
        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Yarın Ali"));
        Assert.Empty(await SatirlarAsync(db => db.Hatirlaticilar));

        var ham = await HamAsync(tarayici);
        var soru = Assert.Single(Ogeler(ham, "soru"));
        Assert.Contains("Bu bir hatırlatıcı mı, plan mı?", Duz(soru));
        Assert.Contains("name=\"cevap\" value=\"Hatırlatıcı\"", Metin(soru));
        Assert.Contains("name=\"cevap\" value=\"Plan\"", soru);
        Assert.Contains("placeholder=\"Kendi cevabın\"", soru);
        var soruId = Regex.Match(soru, "id=([0-9a-f-]{36})&amp;handler=Cevap").Groups[1].Value;
        // The filter "Bekleyen" counts it.
        Assert.Matches("Bekleyen\\s*<span class=\"kd-akis-sayi\">1</span>", ham);

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Cevap", new() { ["id"] = soruId, ["cevap"] = "Hatırlatıcı" }));

        Assert.Contains("Cevap gönderildi", sonraki);
        Assert.Single(await SatirlarAsync(db => db.Hatirlaticilar));
        // Answered: nothing more to press, and the count is gone.
        var sonra = await HamAsync(tarayici);
        Assert.Contains("Cevaplandı.", Duz(Ogeler(sonra, "soru")[0]));
        Assert.DoesNotContain("placeholder=\"Kendi cevabın\"", sonra);
        Assert.Matches("Bekleyen\\s*<span class=\"kd-akis-sayi\">0</span>", sonra);
    }

    [Fact]
    public async Task AQuestion_CanBeAnsweredInTheOwnWords_AnEmptyOrUnknownAnswerIsSaid()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        AsistanClaude.YapiliSirali(
            SoruluCevap("Hangisi?", "Biri", "Öteki"),
            Cevap(Oneri("plan-ekle", "Raporu bitir", gun: BugunMetni)));
        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Belirsiz bir şey"));
        var soruId = Regex.Match(await HamAsync(tarayici), "id=([0-9a-f-]{36})&amp;handler=Cevap").Groups[1].Value;

        var bos = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Cevap", new() { ["id"] = soruId, ["cevap"] = "  " }));
        var yok = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Cevap", new() { ["id"] = Guid.NewGuid().ToString(), ["cevap"] = "Biri" }));
        Assert.Contains("Cevap zorunlu.", bos);
        Assert.Contains("Bulunamadı", yok);
        Assert.Single(AsistanClaude.Cagrilar());

        var kendi = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Cevap", new() { ["id"] = soruId, ["cevap"] = "İkisi de değil, plana ekle" }));
        Assert.Contains("Cevap gönderildi", kendi);
        Assert.Equal(2, AsistanClaude.Cagrilar().Count);
        Assert.Contains("İkisi de değil, plana ekle", ClaudeCagrilari()[1].Veri);
        Assert.Equal(1, BeyinCagrisi("gun", "ekle"));
    }

    // The approval card

    [Fact]
    public async Task AnActionWaitingForApproval_IsACard_EkleAppliesIt_GecRefusesIt()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        await BekleyenEylemAsync("Mailden gelen işi hatırla", disKaynak: true);
        await BekleyenEylemAsync("İkinci öneri");

        var ham = await HamAsync(tarayici);
        var onaylar = Ogeler(ham, "onay");
        Assert.Equal(2, onaylar.Count);
        Assert.Contains("Onayını bekliyor", Duz(onaylar[0]));
        Assert.Contains("Dış kaynak", Duz(onaylar.First(o => o.Contains("Mailden"))));
        Assert.Matches("Bekleyen\\s*<span class=\"kd-akis-sayi\">2</span>", ham);
        var idler = Regex.Matches(ham, "id=([0-9a-f-]{36})&amp;handler=Uygula").Select(m => m.Groups[1].Value).ToList();
        Assert.Equal(2, idler.Count);

        var ekle = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Uygula", new() { ["id"] = idler[0] }));
        var gec = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Reddet", new() { ["id"] = idler[1] }));

        Assert.Contains("Eklendi", ekle);
        Assert.Contains("Geçildi", gec);
        var eylemler = await SatirlarAsync(db => db.Eylemler);
        Assert.Equal(EylemDurumu.Uygulandi, eylemler.Single(e => e.Id == Guid.Parse(idler[0])).Durum);
        Assert.Equal(EylemDurumu.Reddedildi, eylemler.Single(e => e.Id == Guid.Parse(idler[1])).Durum);
        Assert.Empty(Ogeler(await HamAsync(tarayici), "onay"));
        Assert.Single(await SatirlarAsync(db => db.Hatirlaticilar));
    }

    [Fact]
    public async Task ApprovingSomethingThatIsGone_IsSaid_NotASilentSuccess()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Uygula", new() { ["id"] = Guid.NewGuid().ToString() }));

        Assert.Contains("Eylem bulunamadı", sonraki);
        Assert.DoesNotContain("Eklendi", sonraki);
    }

    // The stream: work cards, notes, the briefing, the filters, the paging

    private async Task<string> HikayeKurAsync(WebApplicationFactory<Program> fabrika, HttpClient tarayici)
    {
        Beyin.Cikti("is liste", SahteIsKarti.Liste(
            SahteIsKarti.Kart("kart-a", asama: "karar", bekleyenSoru: 1, guncelleme: "2026-11-09T07:30", baslik: "Soru bekleyen kart"),
            SahteIsKarti.Kart("kart-b", asama: "yapim", guncelleme: "2026-11-09T07:40", baslik: "Yapımdaki kart")));
        AsistanClaude.YapiliSirali(SoruluCevap("Hangisi?", "Biri", "Öteki"));
        await SonrakiAsync(tarayici, await GonderAsync(tarayici, "Belirsiz bir şey"));
        await BekleyenEylemAsync("Bekleyen öneri");
        await using (var db = YeniDb())
        {
            db.Yakalamalar.Add(new Yakalama { Metin = "Elle yakalanan not", YakalandiAt = Pazartesi.ToUniversalTime().AddMinutes(-5), Durum = YakalamaDurumu.Bekliyor });
            await db.SaveChangesAsync(Ct);
        }

        // A stored briefing for today.
        await using (var db = YeniDb())
        {
            db.Brifingler.Add(new GunlukBrifing
            {
                Gun = BugunGunu, UretimAni = Pazartesi.ToUniversalTime().AddMinutes(-1), Yontem = BrifingYontemi.Hesap,
                Kartlar = JsonSerializer.Serialize(new[] { new BrifingKarti("plan", "Bugün", "Sakin bir gün.", []) }, new JsonSerializerOptions(JsonSerializerDefaults.Web)),
            });
            await db.SaveChangesAsync(Ct);
        }

        return await HamAsync(tarayici);
    }

    [Fact]
    public async Task TheStream_ShowsCardsNotesAndTheBriefing_AndTheChipsCountThem()
    {
        var (fabrika, tarayici) = await SayfaHazirlaAsync();

        var ham = await HikayeKurAsync(fabrika, tarayici);
        var metin = Metin(ham);

        // The work cards: each a link to its page, with its open question counted.
        var isler = Ogeler(ham, "is");
        Assert.Equal(2, isler.Count);
        Assert.Contains("href=\"/Isler/Detay/kart-a\"", isler[0] + isler[1]);
        Assert.Contains("1 cevapsız soru", Duz(string.Concat(isler)));
        // The note by hand, the briefing with its votes, the waiting action and the question.
        Assert.Contains("Elle yakalanan not", Duz(Assert.Single(Ogeler(ham, "not"))));
        var brifing = Assert.Single(Ogeler(ham, "brifing"));
        Assert.Contains("Sakin bir gün.", Duz(brifing));
        Assert.Equal(2, Regex.Matches(brifing, "handler=BrifingOy").Count);
        Assert.Single(Ogeler(ham, "onay"));
        Assert.Single(Ogeler(ham, "soru"));
        // The chips: waiting = the question, the action and the card with a question; cards = 2; notes = 1.
        Assert.Matches("Bekleyen\\s*<span class=\"kd-akis-sayi\">3</span>", ham);
        Assert.Matches("İşler\\s*<span class=\"kd-akis-sayi\">2</span>", metin);
        Assert.Matches("Notlar\\s*<span class=\"kd-akis-sayi\">1</span>", ham);
        Assert.Contains("aria-current=\"true\"", ham);
        Assert.DoesNotContain("Bu gün için bir şey yok", metin);
    }

    [Fact]
    public async Task TheFilters_ShowOnlyWhatTheyName_AndABadOneFallsBackToAll()
    {
        var (fabrika, tarayici) = await SayfaHazirlaAsync();
        await HikayeKurAsync(fabrika, tarayici);

        var bekleyen = await HamAsync(tarayici, "/Asistan?suzgec=bekleyen");
        Assert.Single(Ogeler(bekleyen, "soru"));
        Assert.Single(Ogeler(bekleyen, "onay"));
        // Of the two cards only the one with a question open.
        Assert.Single(Ogeler(bekleyen, "is"));
        Assert.Contains("kart-a", Ogeler(bekleyen, "is")[0]);
        Assert.Empty(Ogeler(bekleyen, "brifing"));
        Assert.Empty(Ogeler(bekleyen, "not"));
        Assert.Empty(Ogeler(bekleyen, "kullanici"));

        var isler = await HamAsync(tarayici, "/Asistan?suzgec=isler");
        Assert.Equal(2, Ogeler(isler, "is").Count);
        Assert.Empty(Ogeler(isler, "soru"));
        Assert.Empty(Ogeler(isler, "onay"));

        var notlar = await HamAsync(tarayici, "/Asistan?suzgec=notlar");
        Assert.Single(Ogeler(notlar, "not"));
        Assert.Empty(Ogeler(notlar, "is"));

        var bozuk = await HamAsync(tarayici, "/Asistan?suzgec=baska");
        Assert.NotEmpty(Ogeler(bozuk, "brifing"));
        Assert.NotEmpty(Ogeler(bozuk, "is"));
    }

    [Fact]
    public async Task AFilterIsKept_WhenAButtonOnItIsPressed()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        await BekleyenEylemAsync("Bekleyen öneri");
        var id = Regex.Match(await HamAsync(tarayici, "/Asistan?suzgec=bekleyen"), "id=([0-9a-f-]{36})&amp;handler=Reddet").Groups[1].Value;

        var yanit = await PostAsync(tarayici, "Reddet", new() { ["id"] = id, ["suzgec"] = "bekleyen" });

        Assert.Equal("/Asistan?suzgec=bekleyen", yanit.Headers.Location!.OriginalString);
    }

    [Fact]
    public async Task BriefingVote_IsKept_AndPressingTheSameVoteAgainTakesItBack()
    {
        var (fabrika, tarayici) = await SayfaHazirlaAsync();
        await HikayeKurAsync(fabrika, tarayici);

        await SonrakiAsync(tarayici, await PostAsync(tarayici, "BrifingOy", new() { ["sira"] = "0", ["oy"] = "1" }));
        await using (var db = YeniDb())
            Assert.Equal(1, Assert.Single(await db.BrifingOylari.ToListAsync(Ct)).Oy);
        var ham = await HamAsync(tarayici);
        Assert.Contains("aria-pressed=\"true\"", Assert.Single(Ogeler(ham, "brifing")));

        // The pressed thumb now carries 0: pressing it takes the vote back.
        Assert.Matches("name=\"oy\" value=\"0\"", ham);
        await SonrakiAsync(tarayici, await PostAsync(tarayici, "BrifingOy", new() { ["sira"] = "0", ["oy"] = "0" }));
        await using var db2 = YeniDb();
        Assert.DoesNotContain(await db2.BrifingOylari.ToListAsync(Ct), o => o.Oy != 0);
    }

    [Fact]
    public async Task TheStream_PagesBackwards_FromTheOldestItemShown()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        var sahip = await SahipKimligiAsync(Uygulama.WithWebHostBuilder(_ => { }));
        await using (var db = YeniDb())
        {
            for (var i = 0; i < 45; i++)
                db.AsistanMesajlari.Add(new AsistanMesaji
                {
                    KullaniciId = sahip, Zaman = Pazartesi.ToUniversalTime().AddMinutes(-i), Tur = AsistanMesajTuru.Kullanici, Metin = $"Mesaj {i:00}",
                    Kaynak = "yazi", GirdiId = Guid.NewGuid(),
                });
            await db.SaveChangesAsync(Ct);
        }

        var ilk = await HamAsync(tarayici);
        Assert.Equal(40, Ogeler(ilk, "kullanici").Count);
        Assert.Contains("Mesaj 00", ilk);
        Assert.DoesNotContain("Mesaj 40", ilk);
        var baglanti = WebUtility.HtmlDecode(Regex.Match(ilk, "href=\"([^\"]*once=[^\"]*)\"").Groups[1].Value);
        Assert.NotEmpty(baglanti);

        var ikinci = await HamAsync(tarayici, baglanti);
        Assert.Equal(5, Ogeler(ikinci, "kullanici").Count);
        Assert.Contains("Mesaj 44", ikinci);
        Assert.DoesNotContain("once=", ikinci);
    }

    [Fact]
    public async Task AnEmptyStream_SaysSo_PerFilter()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();

        Assert.Contains("Henüz bir şey yok", Metin(await HamAsync(tarayici)));
        Assert.Contains("Bekleyen bir şey yok", Metin(await HamAsync(tarayici, "/Asistan?suzgec=bekleyen")));
        Assert.Contains("Açık iş kartı yok", Metin(await HamAsync(tarayici, "/Asistan?suzgec=isler")));
        Assert.Contains("Son bir haftada not yok", Metin(await HamAsync(tarayici, "/Asistan?suzgec=notlar")));
    }

    [Fact]
    public async Task WhateverTheTextHolds_NeverReachesThePageAsMarkup()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        const string kotu = "<script>alert('xss')</script>";
        AsistanClaude.YapiliYanit(Cevap(Oneri("hatirlatici-kur", kotu, gun: Yarin, saat: "09:00", kaynakParca: kotu)));

        await SonrakiAsync(tarayici, await GonderAsync(tarayici, kotu));

        var ham = await HamAsync(tarayici);
        Assert.DoesNotContain("<script>alert", ham, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("&lt;script&gt;alert", ham);
    }

    // The menu

    [Fact]
    public async Task TheMenuEntry_GoesToTheAsistanPage_AndCarriesTheNumberOfWhatWaits()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        var temiz = await HamAsync(tarayici, "/Takvim");
        var giris = Regex.Match(temiz, "<a (?:b-[a-z0-9]+ )?class=\"kd-nav-link[^\"]*\"[^>]*href=\"/Asistan\"[^>]*>(.*?)</a>", RegexOptions.Singleline);
        Assert.True(giris.Success);
        Assert.DoesNotContain("kd-badge", giris.Groups[1].Value);

        await BekleyenEylemAsync("Bekleyen öneri");
        var ham = await HamAsync(tarayici, "/Takvim");
        var dolu = Regex.Match(ham, "<a (?:b-[a-z0-9]+ )?class=\"kd-nav-link[^\"]*\"[^>]*href=\"/Asistan\"[^>]*>(.*?)</a>", RegexOptions.Singleline).Groups[1].Value;
        Assert.Matches("kd-badge[^>]*>1<", dolu);
        // The page's own chip says the same number, and the page being open lights the entry.
        var sayfa = await HamAsync(tarayici);
        Assert.Matches("Bekleyen\\s*<span class=\"kd-akis-sayi\">1</span>", sayfa);
        Assert.Contains("class=\"kd-nav-link active\"", sayfa);
    }

    // W3: what came from the share menu waits for approval (E7), the box is one row, a photo is a small preview

    [Fact]
    public async Task SharedContent_WaitsForApproval_AsAResultCardAndAnApprovalCard_AndEkleAppliesIt()
    {
        var (fabrika, tarayici) = await SayfaHazirlaAsync();
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika);
        AsistanClaude.YapiliYanit(Cevap(Oneri("plan-ekle", "Raporu bitir", gun: BugunMetni, kaynakParca: "Raporu bugün bitir.")));
        var yanit = await GirdiGonderAsync(fabrika, sahip, Guid.NewGuid(), "Başka uygulamadan: Raporu bugün bitir.", "paylas");
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        // Nothing was written to the plan: it is an action in the queue.
        Assert.Equal(0, BeyinCagrisi("gun", "ekle"));

        var ham = await HamAsync(tarayici);
        var sonuc = Assert.Single(Regex.Matches(Ogeler(ham, "sonuc")[0], "<article class=\"kd-akis-oge kd-akis-kart ([^\"]*)\" data-kd-sonuc=\"plan-ekle\".*?</article>", RegexOptions.Singleline));
        Assert.Contains("is-onay", sonuc.Groups[1].Value);
        Assert.Contains("Onayını bekliyor", Duz(sonuc.Value));
        Assert.DoesNotContain("handler=GeriAl", sonuc.Value);
        var onay = Assert.Single(Ogeler(ham, "onay"));
        Assert.Contains("Dış kaynak", Duz(onay));
        var id = Regex.Match(onay, "id=([0-9a-f-]{36})&amp;handler=Uygula").Groups[1].Value;
        Assert.NotEmpty(id);

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "Uygula", new() { ["id"] = id }));

        Assert.Contains("Eklendi", sonraki);
        Assert.Equal(1, BeyinCagrisi("gun", "ekle"));
        Assert.Empty(Ogeler(await HamAsync(tarayici), "onay"));
    }

    [Fact]
    public async Task TheBox_IsOneRow_TheTextFirstAndSendAfterIt_InTheSameColumnAsTheStream()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();

        var ham = await HamAsync(tarayici);

        // One column holds the head, the box, the chips and the stream, so they share a width.
        var kolon = ham[ham.IndexOf("class=\"kd-asistan-kolon\"", StringComparison.Ordinal)..];
        Assert.True(kolon.IndexOf("kd-asistan-girdi-alan", StringComparison.Ordinal) < kolon.IndexOf("kd-asistan-gonder", StringComparison.Ordinal));
        Assert.True(kolon.IndexOf("kd-asistan-gonder", StringComparison.Ordinal) < kolon.IndexOf("kd-akis-suzgec", StringComparison.Ordinal));
        Assert.True(kolon.IndexOf("kd-akis-suzgec", StringComparison.Ordinal) < kolon.IndexOf("aria-label=\"Akış\"", StringComparison.Ordinal));
        var form = Regex.Match(kolon, "<form[^>]*kd-asistan-girdi.*?</form>", RegexOptions.Singleline).Value;
        Assert.Contains("<textarea", form);
        Assert.Contains(">Gönder</button>", form);
        Assert.Contains("is-active", Regex.Match(ham, "<a class=\"kd-filter-chip [^\"]*\"[^>]*>Hepsi", RegexOptions.Singleline).Value);
    }

    [Fact]
    public async Task APhotoNote_IsASmallPreview_ThatOpensFullSize()
    {
        var (_, tarayici) = await SayfaHazirlaAsync();
        var foto = await FotografEkleAsync();
        await using (var db = YeniDb())
        {
            db.Yakalamalar.Add(new Yakalama { Metin = "Fotoğraflı not", FotografId = foto, YakalandiAt = Pazartesi.ToUniversalTime().AddMinutes(-5), Durum = YakalamaDurumu.Bekliyor });
            await db.SaveChangesAsync(Ct);
        }

        var not = Assert.Single(Ogeler(await HamAsync(tarayici), "not"));

        var baglanti = Regex.Match(not, "<a class=\"kd-akis-foto-baglanti\" href=\"([^\"]+)\" target=\"_blank\" rel=\"noopener\"[^>]*>\\s*<img class=\"kd-akis-foto\" src=\"([^\"]+)\"", RegexOptions.Singleline);
        Assert.True(baglanti.Success);
        Assert.Equal(baglanti.Groups[1].Value, baglanti.Groups[2].Value);
        Assert.Contains(foto.ToString(), baglanti.Groups[1].Value);
    }
}
