using System.Net;
using System.Text.Json;
using Kafamdakiler.Brifing;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The assistant's feed and its badge (K-0024, sözleşme §7.3) through the whole app: what was said and done, the questions, the actions waiting for
// approval, the open cards, the briefing and the captures in one list, newest first, paged by time and filtered; what waits for the person is
// counted by one rule for the badge and for the filter; each source is shown only to a person who may read it.
public sealed class AsistanAkisApiTests(UygulamaFabrikasi uygulama) : AsistanTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private static DateTimeOffset An(int saat, int dakika) => IstAn(2026, 11, 9, saat, dakika).ToUniversalTime();

    private record Ortam(WebApplicationFactory<Program> Fabrika, string Sahip, Guid Bekleyen, Guid ManuelNot);

    // The story the tests read: eleven items on the feed, in this order, newest first:
    // is-kart-b 07:40, is-kart-a 07:30 (a question open), the result of "Bir fikir" 07:20, the words "Bir fikir" 07:20, the capture made by hand 07:15,
    // the question 07:10, "Belirsiz" 07:10, the action waiting 07:05, the briefing 07:01, the reminder's result 07:00, the words 07:00.
    private async Task<Ortam> HikayeAsync()
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        Beyin.Cikti("is liste", SahteIsKarti.Liste(
            SahteIsKarti.Kart("kart-a", asama: "karar", bekleyenSoru: 1, guncelleme: "2026-11-09T07:30"),
            SahteIsKarti.Kart("kart-b", asama: "yapim", guncelleme: "2026-11-09T07:40")));
        AsistanClaude.YapiliSirali(
            Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00")),
            SoruluCevap("Hangisi?", "Biri", "Öteki"),
            Cevap(Oneri("not", "Fikir", kaynakParca: "Bir fikir")));

        Saat.Simdi = An(7, 0);
        await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Yarın 9'da Ali'yi ara");

        Guid bekleyen;
        await using (var db = YeniDb())
        {
            var eylem = new Eylem { Tur = "hatirlatici-kur", Yuk = "{}", Ozet = "Bekleyen öneri", Kaynak = "gelen", DisKaynak = true, CreatedAt = An(7, 5) };
            db.Eylemler.Add(eylem);
            db.Brifingler.Add(new GunlukBrifing
            {
                Gun = BugunGunu, UretimAni = An(7, 1), Yontem = BrifingYontemi.Hesap,
                Kartlar = JsonSerializer.Serialize(new[] { new BrifingKarti("plan", "Bugün", "Sakin bir gün.", []) }, new JsonSerializerOptions(JsonSerializerDefaults.Web)),
            });
            await db.SaveChangesAsync(Ct);
            bekleyen = eylem.Id;
        }

        Saat.Simdi = An(7, 10);
        await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Belirsiz");

        Guid manuel;
        await using (var db = YeniDb())
        {
            var elle = new Yakalama { Metin = "Elle yakalama", YakalandiAt = An(7, 15), CreatedAt = An(7, 15), GuncellendiAt = An(7, 15) };
            // A week and a day old: no longer on the feed.
            var eski = new Yakalama { Metin = "Eski yakalama", YakalandiAt = An(7, 15).AddDays(-8), CreatedAt = An(7, 15).AddDays(-8), GuncellendiAt = An(7, 15).AddDays(-8) };
            db.Yakalamalar.AddRange(elle, eski);
            await db.SaveChangesAsync(Ct);
            manuel = elle.Id;
        }

        Saat.Simdi = An(7, 20);
        await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Bir fikir");

        // Still inside the hour a sign-in lasts (the token counts by the same clock).
        Saat.Simdi = An(7, 50);
        return new Ortam(fabrika, sahip, bekleyen, manuel);
    }

    private async Task<List<JsonElement>> AkisAsync(Ortam o, string sorgu = "", string? token = null)
    {
        var yanit = await GonderAsync(HttpMethod.Get, "/api/asistan/akis" + sorgu, token ?? o.Sahip, o.Fabrika);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return (await OkuAsync(yanit)).EnumerateArray().ToList();
    }

    private static List<string> Turler(IEnumerable<JsonElement> akis) => akis.Select(a => a.GetProperty("tur").GetString()!).ToList();

    [Fact]
    public async Task Feed_JoinsEverySourceInOneListNewestFirst_WithTheFieldsOfEachKind()
    {
        var o = await HikayeAsync();

        var akis = await AkisAsync(o);

        Assert.Equal(["is", "is", "sonuc", "kullanici", "not", "soru", "kullanici", "onay", "brifing", "sonuc", "kullanici"], Turler(akis));
        var zamanlar = akis.Select(a => a.GetProperty("zaman").GetDateTimeOffset()).ToList();
        Assert.Equal(zamanlar.OrderByDescending(z => z), zamanlar);
        Assert.Equal(akis.Count, akis.Select(a => a.GetProperty("id").GetString()).Distinct().Count());

        // The cards: the one with a question open and the other, with their time from the card.
        Assert.Equal(["kart-b", "kart-a"], akis.Take(2).Select(a => a.GetProperty("is").GetProperty("kimlik").GetString()));
        Assert.Equal(IstAn(2026, 11, 9, 7, 40), akis[0].GetProperty("zaman").GetDateTimeOffset());
        // The words and the result of an input.
        Assert.Equal("Bir fikir", akis[3].GetProperty("metin").GetString());
        var sonuc = Assert.Single(akis[2].GetProperty("sonuclar").EnumerateArray());
        Assert.Equal(("not", "uygulandi"), (sonuc.GetProperty("tur").GetString(), sonuc.GetProperty("durum").GetString()));
        // The capture made by hand (the one the assistant made is already told by its result; the old one is gone).
        Assert.Equal("Elle yakalama", akis[4].GetProperty("yakalama").GetProperty("metin").GetString());
        Assert.Equal(o.ManuelNot.ToString(), akis[4].GetProperty("yakalama").GetProperty("id").GetString());
        Assert.DoesNotContain(akis, a => a.GetProperty("id").GetString()!.StartsWith("not:") && a.GetProperty("metin").GetString() == "Eski yakalama");
        // The unanswered question, in full.
        var soru = akis[5].GetProperty("soru");
        Assert.Equal(["Biri", "Öteki"], soru.GetProperty("secenekler").EnumerateArray().Select(s => s.GetString()));
        Assert.Equal("Hangisi?", akis[5].GetProperty("metin").GetString());
        // The action waiting, the briefing and the first message.
        Assert.Equal(o.Bekleyen.ToString(), akis[7].GetProperty("eylem").GetProperty("id").GetString());
        Assert.Equal("Sakin bir gün.", akis[8].GetProperty("metin").GetString());
        Assert.Equal("Sakin bir gün.", akis[8].GetProperty("brifing").GetProperty("kartlar")[0].GetProperty("metin").GetString());
        Assert.Equal("Yarın 9'da Ali'yi ara", akis[10].GetProperty("metin").GetString());
        // A field of another kind is not there.
        Assert.Equal(JsonValueKind.Null, akis[10].GetProperty("eylem").ValueKind);
        Assert.Equal(JsonValueKind.Null, akis[0].GetProperty("soru").ValueKind);
    }

    [Fact]
    public async Task Feed_TheFiltersKeepWhatTheyNameAndTheWaitingOnesAreCountedByTheBadgeToo()
    {
        var o = await HikayeAsync();

        var bekleyen = await AkisAsync(o, "?suzgec=bekleyen");
        Assert.Equal(["is", "soru", "onay"], Turler(bekleyen));
        Assert.Equal("kart-a", bekleyen[0].GetProperty("is").GetProperty("kimlik").GetString());
        // The badge and the filter are the same rule.
        var sayi = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/asistan/sayi", o.Sahip, o.Fabrika))).GetProperty("bekleyen").GetInt32();
        Assert.Equal((3, bekleyen.Count), (sayi, sayi));

        var isler = await AkisAsync(o, "?suzgec=isler");
        Assert.Equal(["kart-b", "kart-a"], isler.Select(a => a.GetProperty("is").GetProperty("kimlik").GetString()));

        var notlar = await AkisAsync(o, "?suzgec=notlar");
        Assert.Equal(["not"], Turler(notlar));
        Assert.Equal("Elle yakalama", notlar[0].GetProperty("yakalama").GetProperty("metin").GetString());

        Assert.Equal(11, (await AkisAsync(o, "?suzgec=hepsi")).Count);
        Assert.Equal(11, (await AkisAsync(o)).Count);

        // Answering the question takes it off the waiting list and the badge, and the question stays in the story as words.
        var soruId = bekleyen[1].GetProperty("soru").GetProperty("id").GetGuid();
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/asistan/sorular/{soruId}/cevap", o.Sahip, o.Fabrika, new { cevap = "Biri" })).StatusCode);
        Assert.Equal(["is", "onay"], Turler(await AkisAsync(o, "?suzgec=bekleyen")));
        Assert.Equal(2, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/asistan/sayi", o.Sahip, o.Fabrika))).GetProperty("bekleyen").GetInt32());
        var yazilmis = (await AkisAsync(o)).Single(a => a.GetProperty("tur").GetString() == "soru");
        Assert.Equal(JsonValueKind.Null, yazilmis.GetProperty("soru").ValueKind);
        Assert.Equal("Hangisi?", yazilmis.GetProperty("metin").GetString());
    }

    [Fact]
    public async Task Feed_PagesByTimeWithoutLosingOrRepeatingAnything()
    {
        var o = await HikayeAsync();
        var hepsi = (await AkisAsync(o)).Select(a => a.GetProperty("id").GetString()!).ToList();

        var sayfalar = new List<string>();
        string? once = null;
        for (var tur = 0; tur < 20; tur++)
        {
            var sayfa = await AkisAsync(o, "?limit=3" + (once is null ? "" : $"&once={Uri.EscapeDataString(once)}"));
            if (sayfa.Count == 0)
                break;

            Assert.True(sayfa.Count <= 3);
            sayfalar.AddRange(sayfa.Select(a => a.GetProperty("id").GetString()!));
            once = sayfa[^1].GetProperty("zaman").GetDateTimeOffset().ToString("O");
        }

        Assert.Equal(hepsi, sayfalar);
        // A cursor older than everything gives an empty page; the limit has bounds; so does the filter.
        Assert.Empty(await AkisAsync(o, $"?once={Uri.EscapeDataString(An(0, 0).AddYears(-1).ToString("O"))}"));
        foreach (var kotu in new[] { "limit=0", "limit=101", "suzgec=hepsini", "once=dun" })
            Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, $"/api/asistan/akis?{kotu}", o.Sahip, o.Fabrika)).StatusCode);
        Assert.Equal(11, (await AkisAsync(o, "?limit=100")).Count);
    }

    [Fact]
    public async Task Feed_EachSourceIsShownOnlyToAPersonWhoMayReadIt_AndAnotherPersonsWordsAreNeverSeen()
    {
        var o = await HikayeAsync();
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta, o.Fabrika);
        await IzinAsync(o.Sahip, "asistan.kullan", o.Fabrika);

        // The Asistan with only the right to use the assistant: no actions, cards, briefing or captures, and a badge that counts none of them.
        Assert.Empty(await AkisAsync(o, token: asistan));
        Assert.Equal(0, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/asistan/sayi", asistan, o.Fabrika))).GetProperty("bekleyen").GetInt32());

        // Each read permission opens its own source.
        await IzinAsync(o.Sahip, "eylem.oku", o.Fabrika);
        Assert.Equal(["onay"], Turler(await AkisAsync(o, token: asistan)));
        await IzinAsync(o.Sahip, "isler.oku", o.Fabrika);
        Assert.Equal(["is", "is", "onay"], Turler(await AkisAsync(o, token: asistan)));
        await IzinAsync(o.Sahip, "yakalama.oku", o.Fabrika);
        await IzinAsync(o.Sahip, "brifing.oku", o.Fabrika);
        Assert.Equal(["is", "is", "not", "onay", "brifing"], Turler(await AkisAsync(o, token: asistan)));
        Assert.Equal(2, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/asistan/sayi", asistan, o.Fabrika))).GetProperty("bekleyen").GetInt32());

        // What the Asistan says is its own: the Sahip's feed has none of it.
        await IzinAsync(o.Sahip, "yakalama.yaz", o.Fabrika);
        await GirdiAsync(o.Fabrika, asistan, Guid.NewGuid(), "Asistanın kendi sözü");
        Assert.DoesNotContain(await AkisAsync(o), a => a.GetProperty("metin").ValueKind == JsonValueKind.String && a.GetProperty("metin").GetString() == "Asistanın kendi sözü");
        Assert.Contains(await AkisAsync(o, token: asistan), a => a.GetProperty("metin").ValueKind == JsonValueKind.String && a.GetProperty("metin").GetString() == "Asistanın kendi sözü");
    }

    [Fact]
    public async Task Feed_TheUndoFlagsOfAResultAreReadFromWhatTheThingsAreNow()
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        AsistanClaude.YapiliSirali(
            Cevap(Oneri("hatirlatici-kur", "Ali'yi ara", gun: Yarin, saat: "09:00"), Oneri("not", "Fikir", kaynakParca: "Bir fikir"), Oneri("plan-ekle", "Rapor", gun: BugunMetni)));
        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Yarın 9'da Ali'yi ara. Bir fikir. Raporu yap.");
        var sonuclar = yanit.GetProperty("sonuclar").EnumerateArray().ToList();
        var eylemId = sonuclar[0].GetProperty("eylemId").GetGuid();
        var notId = sonuclar[1].GetProperty("hedef").GetProperty("kimlik").GetString();
        var o = new Ortam(fabrika, sahip, Guid.Empty, Guid.Empty);

        async Task<List<JsonElement>> Sonuclar() =>
            (await AkisAsync(o)).Single(a => a.GetProperty("tur").GetString() == "sonuc").GetProperty("sonuclar").EnumerateArray().ToList();

        Assert.Equal([true, true, false], (await Sonuclar()).Select(s => s.GetProperty("geriAlinabilir").GetBoolean()));

        // The reminder is undone with the queue's endpoint: the flag goes. The note is taken back by deleting the capture: so does its flag.
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/eylemler/{eylemId}/geri-al", sahip, fabrika)).StatusCode);
        Assert.Equal([false, true, false], (await Sonuclar()).Select(s => s.GetProperty("geriAlinabilir").GetBoolean()));
        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Delete, $"/api/yakalamalar/{notId}", sahip, fabrika)).StatusCode);
        Assert.Equal([false, false, false], (await Sonuclar()).Select(s => s.GetProperty("geriAlinabilir").GetBoolean()));
    }

    [Fact]
    public async Task Feed_APhotoShowsWithItsInput_AndGoesWhenTheNoteIsTakenBack()
    {
        var (fabrika, sahip) = await HazirlaAsync(google: false);
        var fotograf = await FotografEkleAsync();
        var yanit = await GirdiAsync(fabrika, sahip, Guid.NewGuid(), null, "paylas", fotograf);
        var o = new Ortam(fabrika, sahip, Guid.Empty, Guid.Empty);

        var kullanici = (await AkisAsync(o)).Single(a => a.GetProperty("tur").GetString() == "kullanici");
        Assert.EndsWith(fotograf.ToString(), kullanici.GetProperty("fotografUrl").GetString());

        var notId = Assert.Single(yanit.GetProperty("sonuclar").EnumerateArray()).GetProperty("hedef").GetProperty("kimlik").GetString();
        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Delete, $"/api/yakalamalar/{notId}", sahip, fabrika)).StatusCode);

        var sonra = (await AkisAsync(o)).Single(a => a.GetProperty("tur").GetString() == "kullanici");
        Assert.Equal(JsonValueKind.Null, sonra.GetProperty("fotografUrl").ValueKind);
    }

    [Fact]
    public async Task Feed_WithoutABrain_StillAnswers_WithoutTheCards()
    {
        var (fabrika, sahip) = await HazirlaAsync(beyin: false, google: false);
        AsistanClaude.YapiliYanit(Cevap());
        await GirdiAsync(fabrika, sahip, Guid.NewGuid(), "Bir düşünce");

        var yanit = await GonderAsync(HttpMethod.Get, "/api/asistan/akis", sahip, fabrika);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        Assert.DoesNotContain((await OkuAsync(yanit)).EnumerateArray(), a => a.GetProperty("tur").GetString() == "is");
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Get, "/api/asistan/sayi", sahip, fabrika)).StatusCode);
    }
}
