using System.Net;
using System.Text.RegularExpressions;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The web pages of K-0024 (Bugün's one list, Takvim, the day capacity, the shelf inside the habit page) in a browser's shoes: cookies,
// antiforgery tokens, no automatic redirects. A fake beyin.py behind them and a clock the test owns (Monday 2026-11-09, 07:00 in Istanbul:
// the brain's day is 2026-11-09, yesterday was a Sunday). What they hold on to: every way of finishing an item runs the chain with its
// reminder, a refusal is said on the page, and a page that is not the Sahip's stays closed.
public sealed partial class GunSayfalariTests(UygulamaFabrikasi uygulama) : GunTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    private const string Proje = """[{"kimlik": "kitap-kulubu", "baslik": "Kitap Kulübü", "yol": "projects/kitap-kulubu/index.md"}]""";

    [GeneratedRegex("name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"")]
    private static partial Regex TokenDeseni();

    private async Task<(WebApplicationFactory<Program> Fabrika, HttpClient Tarayici)> HazirlaAsync(string? kapasiteSaat = null)
    {
        await GunTemizleAsync();
        await using (var db = YeniDb())
        {
            await db.Oturumlar.ExecuteDeleteAsync(Ct);
            await db.Ogeler.ExecuteDeleteAsync(Ct);
            await db.Aliskanliklar.ExecuteDeleteAsync(Ct);
        }

        Beyin.Cikti("[]");
        Beyin.Cikti("proje liste", Proje);
        Beyin.Cikti("gorev liste", GorevListesi);
        var fabrika = GunFabrikasi(kapasiteSaat: kapasiteSaat);
        return (fabrika, await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct));
    }

    private async Task<string> HamAsync(HttpClient tarayici, string yol)
    {
        var yanit = await tarayici.GetAsync(yol, Ct);
        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        return await WebOturumu.HamAsync(yanit, Ct);
    }

    private static string Metin(string ham) => WebUtility.HtmlDecode(ham);

    // Posts the fields to the handler of a page; the token comes from that page. The answer is the redirect, not followed.
    private async Task<HttpResponseMessage> PostAsync(HttpClient tarayici, string sayfa, string islem, Dictionary<string, string> alanlar)
    {
        var token = TokenDeseni().Match(await tarayici.GetStringAsync(sayfa.Split('?')[0], Ct)).Groups[1].Value;
        Assert.NotEmpty(token);
        var govde = new Dictionary<string, string>(alanlar) { ["__RequestVerificationToken"] = token };
        var ayrac = sayfa.Contains('?') ? "&" : "?";
        var adres = islem.Length == 0 ? sayfa : $"{sayfa}{ayrac}handler={islem}";
        return await tarayici.PostAsync(adres, new FormUrlEncodedContent(govde), Ct);
    }

    private async Task<string> SonrakiAsync(HttpClient tarayici, HttpResponseMessage yonlendirme)
    {
        Assert.Equal(HttpStatusCode.Redirect, yonlendirme.StatusCode);
        var yanit = await tarayici.GetAsync(yonlendirme.Headers.Location, Ct);
        return Metin(await yanit.Content.ReadAsStringAsync(Ct));
    }

    // The part of the page that belongs to one row of the day list.
    private static string Satir(string ham, string kimlik)
    {
        var bas = ham.IndexOf($"data-kd-oge=\"{kimlik}\"", StringComparison.Ordinal);
        Assert.True(bas >= 0, $"row {kimlik} is not on the page");
        var son = ham.IndexOf("data-kd-oge=\"", bas + 10, StringComparison.Ordinal);
        return son < 0 ? ham[bas..] : ham[bas..son];
    }

    private string[][] Cagrilar(string komut, string alt) =>
        Beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(c => c[0] == komut && c[1] == alt).ToArray();

    private const string MaddeSonucu = """{"id": "a3f09c", "baslik": "Rapor yaz", "bolum": "Yapılacaklar", "durum": "yapildi"}""";

    private void BugunPlani(string[] maddeler, string geciken = "[]") => Beyin.Cikti("gun goster", GunJson(BugunMetni, maddeler, geciken));

    // Bugün: the one list

    [Fact]
    public async Task Bugun_ShowsTheSummary_TheWeightOfTheDay_AndOneListByTheClock()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([Madde("a3f09c", "Rapor yaz ~30dk", tahmin: 30), Madde("b4e1d2", "Mail cevapla ~15dk", tahmin: 15)]);
        await EtkinlikEkleAsync("Toplantı", IstAn(2026, 11, 9, 10), IstAn(2026, 11, 9, 11), yer: "Ofis");
        var bagli = await HatirlaticiEkleAsync("Rapor için hatırlat", BugunGunu, new TimeOnly(14, 0), maddeId: "a3f09c", maddeTarihi: BugunGunu);
        var bagsiz = await HatirlaticiEkleAsync("Eczaneye uğra", BugunGunu, new TimeOnly(16, 30));

        var ham = await HamAsync(tarayici, "/");
        var metin = Metin(ham);

        Assert.Contains("<title>Bugün - Kafamdakiler", metin);
        Assert.Contains("Bugün 2 açık iş var", metin);
        // The weight: 45 min of work and the 60 min event against the default day.
        Assert.Contains("kd-yuk", ham);
        Assert.Contains("1 sa 45 dk", metin);
        Assert.Contains("boşluk var", metin);
        // The list by the clock: the event, the item with its reminder's 14:00, the free reminder, then the item without an hour.
        var sira = new[] { "e:", "m:a3f09c", $"h:{bagsiz.Id}", "m:b4e1d2" }
            .Select(k => ham.IndexOf($"data-kd-oge=\"{k}", StringComparison.Ordinal)).ToList();
        Assert.All(sira, i => Assert.True(i >= 0));
        Assert.Equal(sira.Order().ToList(), sira);
        // A reminder tied to an item is not a row of its own: it is a chip on the item.
        Assert.DoesNotContain($"data-kd-oge=\"h:{bagli.Id}\"", ham);
        var rapor = Satir(ham, "m:a3f09c");
        Assert.Contains("14:00", rapor);
        Assert.Contains("title=\"Hatırlatıcı\"", rapor);
        // An event has no "yaptım".
        Assert.DoesNotContain("handler=Yaptim", Satir(ham, ham[ham.IndexOf("data-kd-oge=\"e:", StringComparison.Ordinal)..].Split('"')[1]));
    }

    [Fact]
    public async Task Bugun_Yaptim_OnATaskWithAReminder_FinishesTheTask_AndClosesTheReminder()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([], geciken: "[" + Geciken("uye-girisi", "Üye girişi", "2026-11-07", 2) + "]");
        Beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");
        var h = await HatirlaticiEkleAsync("Üye girişini hatırlat", BugunGunu, new TimeOnly(15, 0), gorev: "uye-girisi");

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Yaptim", new() { ["kimlik"] = "g:uye-girisi", ["geri"] = "false" }));

        Assert.Single(Cagrilar("gorev", "bitir"));
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);
        Assert.Contains("bağlı 1 iş de kapandı", sonraki);
    }

    [Fact]
    public async Task Bugun_Yaptim_OnAnItemWithAReminder_TicksTheItem_AndClosesTheReminder()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([Madde("a3f09c", "Rapor yaz")]);
        Beyin.Cikti("gun isaretle", IsaretlendiJson(BugunMetni, MaddeSonucu));
        var h = await HatirlaticiEkleAsync("Rapor için hatırlat", BugunGunu, new TimeOnly(14, 0), maddeId: "a3f09c", maddeTarihi: BugunGunu);

        await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Yaptim", new() { ["kimlik"] = "m:a3f09c", ["geri"] = "false" }));

        Assert.Equal(["gun", "isaretle", $"--tarih={BugunMetni}", "--json", "--vault", Beyin.Vault, "--", "a3f09c"], Cagrilar("gun", "isaretle").Single());
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);
    }

    [Fact]
    public async Task Bugun_Yaptim_OnAFreeReminder_ClosesIt_AndUndoOpensItAgain()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([]);
        var h = await HatirlaticiEkleAsync("Eczaneye uğra", BugunGunu, new TimeOnly(16, 30));

        await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Yaptim", new() { ["kimlik"] = $"h:{h.Id}", ["geri"] = "false" }));
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);

        var geri = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Yaptim", new() { ["kimlik"] = $"h:{h.Id}", ["geri"] = "true" }));
        Assert.Equal(HatirlaticiDurumu.Acik, (await HatirlaticiOkuAsync(h.Id)).Durum);
        Assert.Contains("Yeniden açıldı", geri);
    }

    [Fact]
    public async Task Hatirlaticilar_Yaptim_TicksTheItemTiedToTheReminder()
    {
        var (_, tarayici) = await HazirlaAsync();
        Beyin.Cikti("gun isaretle", IsaretlendiJson(BugunMetni, MaddeSonucu));
        var h = await HatirlaticiEkleAsync("Rapor için hatırlat", BugunGunu, new TimeOnly(14, 0), maddeId: "a3f09c", maddeTarihi: BugunGunu);

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, $"/Hatirlaticilar?id={h.Id}", "Yaptim", new()));

        Assert.Equal(["gun", "isaretle", $"--tarih={BugunMetni}", "--json", "--vault", Beyin.Vault, "--", "a3f09c"], Cagrilar("gun", "isaretle").Single());
        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);
        Assert.Contains("bağlı iş de işaretlendi", sonraki);
    }

    [Fact]
    public async Task Hatirlaticilar_Yaptim_SaysAFailedChainStep_AndTheReminderStaysDone()
    {
        var (_, tarayici) = await HazirlaAsync();
        Beyin.Cikti("gun isaretle", """{"hata": {"kod": "gun-kapali", "mesaj": "kapandı"}}""", cikis: 1);
        var h = await HatirlaticiEkleAsync("Rapor için hatırlat", BugunGunu, new TimeOnly(14, 0), maddeId: "a3f09c", maddeTarihi: BugunGunu);

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, $"/Hatirlaticilar?id={h.Id}", "Yaptim", new()));

        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);
        Assert.Contains("Bağlı madde işaretlenemedi", sonraki);
    }

    [Fact]
    public async Task ProjectPage_FinishingATask_ClosesTheReminderTiedToIt()
    {
        var (_, tarayici) = await HazirlaAsync();
        Beyin.Cikti("proje goster", """{"kimlik": "kitap-kulubu", "baslik": "Kitap Kulübü", "yol": "projects/kitap-kulubu/index.md", "durum": "d", "siradaki_adim": "s", "acik_gorevler": [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md"}], "son_gunluk": []}""");
        Beyin.Cikti("gorev bitir", """{"yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "kimlik": "uye-girisi", "degisen": ["durum"]}""");
        var h = await HatirlaticiEkleAsync("Üye girişini hatırlat", BugunGunu, new TimeOnly(15, 0), gorev: "uye-girisi");

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/Beyin/Proje/kitap-kulubu", "GorevBitir", new() { ["gorev"] = "uye-girisi" }));

        Assert.Equal(HatirlaticiDurumu.Tamam, (await HatirlaticiOkuAsync(h.Id)).Durum);
        Assert.Contains("bağlı hatırlatıcı da kapandı", sonraki);
    }

    // Bugün: carry over, split, the reminder of a row

    [Fact]
    public async Task Bugun_Devret_OfATask_PutsItOnTomorrowsPlan_AndOfAReminder_SnoozesItToTomorrow()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([], geciken: "[" + Geciken("uye-girisi", "Üye girişi", "2026-11-07", 2) + "]");
        Beyin.Cikti("gun ekle", $$"""{"tarih": "2026-11-10", "madde": {{MaddeSonucu}}, "tahmin_onerisi": null}""");
        var h = await HatirlaticiEkleAsync("Eczaneye uğra", BugunGunu, new TimeOnly(16, 30));

        var gorev = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Devret", new() { ["kimlik"] = "g:uye-girisi" }));
        var hatirlatici = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Devret", new() { ["kimlik"] = $"h:{h.Id}" }));

        var ekle = Cagrilar("gun", "ekle").Single();
        Assert.Contains("--tarih=2026-11-10", ekle);
        Assert.Contains("--gorev=uye-girisi", ekle);
        Assert.Contains("Ertesi güne devredildi", gorev);
        Assert.Contains("Yarına ertelendi", hatirlatici);
        var yarin = (await HatirlaticiOkuAsync(h.Id)).ErteleAn;
        Assert.NotNull(yarin);
        Assert.Equal(new DateOnly(2026, 11, 10), Kafamdakiler.Beyin.GunSiniri.Bugun(yarin!.Value));
    }

    [Fact]
    public async Task Bugun_AReminderIsSetChangedAndRemoved_OnAnItem()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([Madde("a3f09c", "Rapor yaz")]);
        var alanlar = new Dictionary<string, string> { ["kimlik"] = "m:a3f09c", ["h.Saat"] = "09:30", ["h.Tekrar"] = "gunluk", ["h.OnceGun"] = "1", ["h.Acil"] = "true" };

        var kur = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "HatirlaticiKur", alanlar));
        Assert.Contains("Hatırlatıcı kuruldu", kur);
        await using (var db = YeniDb())
        {
            var h = await db.Hatirlaticilar.SingleAsync(Ct);
            Assert.Equal(("a3f09c", BugunGunu, Tekrar.Gunluk, new TimeOnly(9, 30), 1, true), (h.MaddeId, h.MaddeTarihi, h.Tekrar, h.Saat, h.OnceGun, h.Acil));
        }

        // The row now shows it, and the same form changes it.
        var satir = Satir(await HamAsync(tarayici, "/"), "m:a3f09c");
        Assert.Contains("09:30", satir);
        Assert.Contains("handler=HatirlaticiDegistir", satir);
        Assert.Contains("handler=HatirlaticiKaldir", satir);
        alanlar["h.Tekrar"] = "haftalik";
        alanlar["h.Gunler"] = "pzt";
        var degistir = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "HatirlaticiDegistir", alanlar));
        Assert.Contains("Hatırlatıcı güncellendi", degistir);
        await using (var db = YeniDb())
            Assert.Equal(Gunler.Pzt, (await db.Hatirlaticilar.SingleAsync(Ct)).Gunler);

        var kaldir = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "HatirlaticiKaldir", new() { ["kimlik"] = "m:a3f09c" }));
        Assert.Contains("Hatırlatıcı kaldırıldı", kaldir);
        await using (var db = YeniDb())
            Assert.Empty(await db.Hatirlaticilar.ToListAsync(Ct));
    }

    [Fact]
    public async Task Bugun_AReminderForm_SaysWhatIsWrong_AndWritesNothing()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([Madde("a3f09c", "Rapor yaz")]);

        var saat = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "HatirlaticiKur", new() { ["kimlik"] = "m:a3f09c", ["h.Saat"] = "yarım" }));
        var gun = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "HatirlaticiKur",
            new() { ["kimlik"] = "m:a3f09c", ["h.Tekrar"] = "haftalik", ["h.Gunler"] = "salı" }));
        var onceGun = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "HatirlaticiKur", new() { ["kimlik"] = "m:a3f09c", ["h.OnceGun"] = "99" }));
        var etkinlik = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "HatirlaticiKur", new() { ["kimlik"] = "e:" + Guid.NewGuid() }));

        Assert.Contains("SS:DD biçiminde", saat);
        Assert.Contains("yalnız pzt, sal, car, per, cum, cmt, paz", gun);
        Assert.Contains("0 ile 60", onceGun);
        Assert.Contains("yalnız plan maddesine ya da göreve", etkinlik);
        await using var db = YeniDb();
        Assert.Empty(await db.Hatirlaticilar.ToListAsync(Ct));
    }

    [Fact]
    public async Task Bugun_TheNewItemForm_AddsToThePlan_WithItsReminderWhenAsked()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([]);
        Beyin.Cikti("gun ekle", $$"""{"tarih": "{{BugunMetni}}", "madde": {"id": "a3f09c", "baslik": "Rapor yaz ~30dk", "bolum": "Yapılacaklar", "durum": "acik", "tahmin_dk": 30}, "tahmin_onerisi": null}""");

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Ekle", new()
        {
            ["yeni.Baslik"] = "Rapor yaz", ["yeni.TahminDk"] = "30", ["h.Var"] = "true", ["h.Saat"] = "14:00", ["h.Tekrar"] = "yok",
        }));

        Assert.Contains("Eklendi", sonraki);
        var ekle = Cagrilar("gun", "ekle").Single();
        Assert.Contains($"--tarih={BugunMetni}", ekle);
        Assert.Contains("30", ekle.Last());
        await using var db = YeniDb();
        var h = await db.Hatirlaticilar.SingleAsync(Ct);
        Assert.Equal(("a3f09c", new TimeOnly(14, 0)), (h.MaddeId, h.Saat));
    }

    [Fact]
    public async Task Bugun_TheNewItemForm_WithoutTheReminderCheckbox_IgnoresTheReminderFields()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([]);
        Beyin.Cikti("gun ekle", $$"""{"tarih": "{{BugunMetni}}", "madde": {"id": "a3f09c", "baslik": "Rapor yaz", "bolum": "Yapılacaklar", "durum": "acik"}, "tahmin_onerisi": null}""");

        await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "Ekle", new() { ["yeni.Baslik"] = "Rapor yaz", ["h.Saat"] = "14:00", ["h.Tekrar"] = "gunluk" }));

        await using var db = YeniDb();
        Assert.Empty(await db.Hatirlaticilar.ToListAsync(Ct));
    }

    // Bugün: what yesterday left

    [Fact]
    public async Task Bugun_LeftoversOfYesterday_CanBeCarried_OrLetGo_AndLettingGoIsTheRowThePhoneShares()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([]);
        Beyin.CiktiTarihli("gun goster", DunMetni, GunJson(DunMetni, [Madde("d1d1d1", "Dünden iş", tahmin: 20), Madde("d2d2d2", "Öteki iş")]));
        Beyin.Cikti("gun devret", $$"""{"tarih": "{{DunMetni}}", "devredilen_gun": "{{BugunMetni}}", "madde": {{MaddeSonucu}}}""");

        var ham = Metin(await HamAsync(tarayici, "/"));
        Assert.Contains("Dünden kalanlar", ham);
        Assert.Contains("Dünden iş", ham);

        var tasi = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "SabahTasi", new() { ["madde"] = "d1d1d1" }));
        Assert.Contains("Bugüne taşındı", tasi);
        Assert.Equal(["gun", "devret", $"--tarih={DunMetni}", "--json", "--vault", Beyin.Vault, "--", "d1d1d1"], Cagrilar("gun", "devret").Single());

        var birak = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "SabahBirak", new() { ["madde"] = "d2d2d2" }));
        // The "Dünden kalanlar" section lost the item it let go of and kept the other (the briefing's own text is the API's business).
        var kalanlar = birak[birak.IndexOf("Dünden kalanlar", StringComparison.Ordinal)..];
        kalanlar = kalanlar[..kalanlar.IndexOf("</section>", StringComparison.Ordinal)];
        Assert.DoesNotContain("Öteki iş", kalanlar);
        Assert.Contains("Dünden iş", kalanlar);
        await using var db = YeniDb();
        var satir = await db.BirakilanMaddeler.SingleAsync(Ct);
        Assert.Equal((BugunGunu, "d2d2d2"), (satir.Tarih, satir.MaddeId));

        // Letting go twice changes nothing.
        await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "SabahBirak", new() { ["madde"] = "d2d2d2" }));
        await using var db2 = YeniDb();
        Assert.Single(await db2.BirakilanMaddeler.ToListAsync(Ct));
    }

    [Fact]
    public async Task Bugun_LettingGoOfSomethingThatIsNotAnId_IsRefused_AndWritesNothing()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([]);

        var sonraki = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/", "SabahBirak", new() { ["madde"] = "3" }));

        Assert.Contains("kalıcı kimliğiyle", sonraki);
        await using var db = YeniDb();
        Assert.Empty(await db.BirakilanMaddeler.ToListAsync(Ct));
    }

    [Fact]
    public async Task Bugun_TheCapacitySetting_ChangesTheBarAndTheOverflowMessage()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([Madde("a3f09c", "Büyük iş ~4s", tahmin: 240)]);

        var once = Metin(await HamAsync(tarayici, "/"));
        Assert.DoesNotContain("taşıyor", once);

        var kaydet = await SonrakiAsync(tarayici, await PostAsync(tarayici, "/Ayarlar/Gun", "", new() { ["Input.HaftaIciDk"] = "120", ["Input.HaftaSonuDk"] = "60" }));
        Assert.Contains("Kapasite kaydedildi", kaydet);

        var sonra = Metin(await HamAsync(tarayici, "/"));
        // Monday: 4 h of work against 2 h.
        Assert.Contains("kd-yuk-cubuk is-asim", sonra);
        Assert.Contains("Gün 2 sa taşıyor", sonra);
    }

    // The capacity page

    [Fact]
    public async Task CapacityPage_ShowsTheFallback_SavesBothValues_AndRefusesNonsense()
    {
        var (_, tarayici) = await HazirlaAsync(kapasiteSaat: "5");

        var ilk = Metin(await HamAsync(tarayici, "/Ayarlar/Gun"));
        Assert.Contains("yapılandırmadaki varsayılan", ilk);
        Assert.Contains("value=\"300\"", await HamAsync(tarayici, "/Ayarlar/Gun"));

        var kotu = await PostAsync(tarayici, "/Ayarlar/Gun", "", new() { ["Input.HaftaIciDk"] = "0", ["Input.HaftaSonuDk"] = "60" });
        Assert.Equal(HttpStatusCode.OK, kotu.StatusCode);
        Assert.Contains("1 ile 1440", Metin(await kotu.Content.ReadAsStringAsync(Ct)));
        await using (var db = YeniDb())
            Assert.Empty(await db.GunAyarlari.ToListAsync(Ct));

        await SonrakiAsync(tarayici, await PostAsync(tarayici, "/Ayarlar/Gun", "", new() { ["Input.HaftaIciDk"] = "420", ["Input.HaftaSonuDk"] = "90" }));
        await using (var db = YeniDb())
        {
            var satir = await db.GunAyarlari.SingleAsync(Ct);
            Assert.Equal((420, 90), (satir.HaftaIciDk, satir.HaftaSonuDk));
        }

        var sonra = await HamAsync(tarayici, "/Ayarlar/Gun");
        Assert.Contains("value=\"420\"", sonra);
        Assert.DoesNotContain("yapılandırmadaki varsayılan", Metin(sonra));
    }

    [Theory]
    [InlineData("/Takvim")]
    [InlineData("/Ayarlar/Gun")]
    public async Task TheNewPages_AreClosedToVisitorsAndToTheAsistan(string yol)
    {
        var (fabrika, _) = await HazirlaAsync();

        var anonim = await fabrika.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false }).GetAsync(yol, Ct);
        Assert.Equal(HttpStatusCode.Redirect, anonim.StatusCode);
        Assert.Equal("/Hesap/Giris", anonim.Headers.Location!.AbsolutePath);

        var asistan = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.AsistanEposta, Ct);
        var yanit = await asistan.GetAsync(yol, Ct);
        Assert.Equal(HttpStatusCode.Redirect, yanit.StatusCode);
        Assert.Equal("/Hesap/Erisim", yanit.Headers.Location!.AbsolutePath);
    }

    // Takvim

    [Fact]
    public async Task Takvim_ShowsTheMonthGrid_WithTodayChosen_AndTheCountsOfEachDay()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([Madde("a3f09c", "Rapor yaz ~30dk", tahmin: 30)]);
        await EtkinlikEkleAsync("Dişçi", IstAn(2026, 11, 12, 10), IstAn(2026, 11, 12, 11));
        await HatirlaticiEkleAsync("Eczaneye uğra", new DateOnly(2026, 11, 13), new TimeOnly(16, 30));
        await TumGunEtkinligiEkleAsync("Konferans", new DateOnly(2026, 11, 14), new DateOnly(2026, 11, 14));

        var ham = await HamAsync(tarayici, "/Takvim");
        var metin = Metin(ham);

        Assert.Contains("Kasım 2026", metin);
        // Monday 2026-11-09 is today and the chosen day; November 2026 starts on a Sunday, so the grid begins on Monday 26 October.
        Assert.Contains("kd-ay-gun is-bugun is-secili", ham);
        Assert.Equal(6 * 7, Regex.Matches(ham, "class=\"kd-ay-gun[ \"]").Count);
        var on2 = Metin(Regex.Match(ham, "<a class=\"kd-ay-gun[^\"]*\" href=\"[^\"]*gun=2026-11-12\"[^>]*aria-label=\"([^\"]*)\"").Groups[1].Value);
        Assert.Contains("1 etkinlik", on2);
        var on3 = Metin(Regex.Match(ham, "<a class=\"kd-ay-gun[^\"]*\" href=\"[^\"]*gun=2026-11-13\"[^>]*aria-label=\"([^\"]*)\"").Groups[1].Value);
        Assert.Contains("1 hatırlatıcı", on3);
        // The chosen day's list is the same list as Bugün's, with the same "yaptım".
        Assert.Contains("data-kd-oge=\"m:a3f09c\"", ham);
        Assert.Contains("handler=Yaptim", ham);
        // The new-item form is here, with the reminder options, and the coming list names the days.
        Assert.Contains("handler=Ekle", ham);
        Assert.Contains("name=\"h.Tekrar\"", ham);
        // (the coming list holds reminders, tasks with a due day and all-day events; a timed event is only in the grid and its day)
        var yaklasan = metin[metin.LastIndexOf("Yaklaşan", StringComparison.Ordinal)..];
        Assert.Contains("Eczaneye uğra", yaklasan);
        Assert.Contains("13 Kas Cum", yaklasan);
        Assert.Contains("Konferans", yaklasan);
        Assert.Contains("14 Kas Cmt", yaklasan);
        Assert.DoesNotContain("Dişçi", yaklasan);
    }

    [Fact]
    public async Task Takvim_AnotherDayAndMonth_AreAskedForInTheAddress_AndABadOneFallsBackToToday()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([]);
        await EtkinlikEkleAsync("Dişçi", IstAn(2026, 12, 3, 10), IstAn(2026, 12, 3, 11));

        var aralik = Metin(await HamAsync(tarayici, "/Takvim?ay=2026-12&gun=2026-12-03"));
        Assert.Contains("Aralık 2026", aralik);
        Assert.Contains("3 Aralık 2026 Perşembe", aralik);
        Assert.Contains("Dişçi", aralik);

        var bozuk = await HamAsync(tarayici, "/Takvim?ay=bozuk&gun=yok");
        Assert.Contains("Kasım 2026", Metin(bozuk));
        Assert.Contains("kd-ay-gun is-bugun is-secili", bozuk);
    }

    [Fact]
    public async Task Takvim_TheNewItemForm_AddsToTheChosenDay_AndComesBackToIt()
    {
        var (_, tarayici) = await HazirlaAsync();
        BugunPlani([]);
        Beyin.Cikti("gun ekle", $$"""{"tarih": "2026-11-12", "madde": {"id": "a3f09c", "baslik": "Rapor yaz", "bolum": "Yapılacaklar", "durum": "acik"}, "tahmin_onerisi": null}""");

        var yanit = await PostAsync(tarayici, "/Takvim?ay=2026-11&gun=2026-11-12&tarih=2026-11-12", "Ekle", new()
        {
            ["yeni.Baslik"] = "Rapor yaz", ["donus"] = "/Takvim?ay=2026-11&gun=2026-11-12",
        });

        Assert.Equal("/Takvim?ay=2026-11&gun=2026-11-12", yanit.Headers.Location!.OriginalString);
        Assert.Contains("--tarih=2026-11-12", Cagrilar("gun", "ekle").Single());
        Assert.Contains("Eklendi", await SonrakiAsync(tarayici, yanit));
    }

    [Fact]
    public async Task Takvim_WithNoBrain_StillShowsRemindersAndEvents_AndSaysThePlanIsMissing()
    {
        await GunTemizleAsync();
        await EtkinlikEkleAsync("Dişçi", IstAn(2026, 11, 9, 10), IstAn(2026, 11, 9, 11));
        // The plain fixture has no brain: the app is built without a fake one.
        var fabrika = Fabrika(Pazartesi, google: false);
        var tarayici = await WebOturumu.GirisliAsync(fabrika, UygulamaFabrikasi.SahipEposta, Ct);

        var metin = Metin(await HamAsync(tarayici, "/Takvim"));

        Assert.Contains("beyin ayarlı değil", metin);
        Assert.Contains("Dişçi", metin);
    }

    // Habits: the shelf inside the habit's page, and the reading log

    private async Task<(Guid AliskanlikId, Guid OgeId)> RafAliskanligiAsync(string kitap = "Suç ve Ceza", decimal toplam = 600)
    {
        await using var db = YeniDb();
        var a = new Aliskanlik
        {
            Ad = "Okuma", Tur = AliskanlikTuru.Raf, Ikon = "book-open", Renk = "violet", Olcu = Olcu.Sayili, HedefYonu = HedefYonu.EnAz,
            GunlukHedef = 20, Birim = "sayfa", OgeEtiketi = "Kitap", Siklik = Siklik.HerGun,
        };
        var o = new Oge { Ad = kitap, Toplam = toplam, Durum = OgeDurumu.Devam };
        a.Ogeler.Add(o);
        a.Ogeler.Add(new Oge { Ad = "Sıradaki kitap", Toplam = 200, Durum = OgeDurumu.Siradaki });
        db.Aliskanliklar.Add(a);
        await db.SaveChangesAsync(Ct);
        return (a.Id, o.Id);
    }

    [Fact]
    public async Task ShelfHabit_ShowsItsShelfOnItsOwnPage_AndTheOldShelfAddressRedirectsThere()
    {
        var (_, tarayici) = await HazirlaAsync();
        var (id, _) = await RafAliskanligiAsync();

        var ham = await HamAsync(tarayici, $"/Aliskanliklar/Detay/{id}");

        Assert.Contains("id=\"raf\"", ham);
        Assert.Contains("Suç ve Ceza", Metin(ham));
        Assert.Contains("Sıradaki kitap", Metin(ham));
        Assert.Contains("Devam · 1", Metin(ham));
        Assert.Contains("data-bs-target=\"#okuma-modal\"", ham);
        Assert.Contains("id=\"okuma-modal\"", ham);
        Assert.Contains("name=\"bitisKonum\"", ham);
        Assert.Contains("name=\"dakika\"", ham);

        var eski = await tarayici.GetAsync($"/Aliskanliklar/Raf/{id}", Ct);
        Assert.Equal(HttpStatusCode.Redirect, eski.StatusCode);
        Assert.Equal($"/Aliskanliklar/Detay/{id}#raf", eski.Headers.Location!.OriginalString);
    }

    [Fact]
    public async Task APlainHabit_HasNoShelfNoModal_AndItsOldShelfAddressGoesToItsPage()
    {
        var (_, tarayici) = await HazirlaAsync();
        Guid id;
        await using (var db = YeniDb())
        {
            var a = new Aliskanlik
            {
                Ad = "Su", Tur = AliskanlikTuru.Sayac, Ikon = "book", Renk = "blue", Olcu = Olcu.EvetHayir, HedefYonu = HedefYonu.EnAz, GunlukHedef = 1, Siklik = Siklik.HerGun,
            };
            db.Aliskanliklar.Add(a);
            await db.SaveChangesAsync(Ct);
            id = a.Id;
        }

        var ham = await HamAsync(tarayici, $"/Aliskanliklar/Detay/{id}");
        var eski = await tarayici.GetAsync($"/Aliskanliklar/Raf/{id}", Ct);

        Assert.DoesNotContain("id=\"raf\"", ham);
        Assert.DoesNotContain("okuma-modal", ham);
        Assert.Equal($"/Aliskanliklar/Detay/{id}", eski.Headers.Location!.OriginalString);
    }

    [Fact]
    public async Task ReadingLog_FromTheModal_AddsASession_AndComesBackToTheShelf()
    {
        var (_, tarayici) = await HazirlaAsync();
        var (id, ogeId) = await RafAliskanligiAsync();

        var yanit = await PostAsync(tarayici, $"/Aliskanliklar/Detay/{id}", "Okuma", new() { ["ogeId"] = ogeId.ToString(), ["bitisKonum"] = "35", ["dakika"] = "40" });

        Assert.Equal($"/Aliskanliklar/Detay/{id}#raf", yanit.Headers.Location!.OriginalString);
        Assert.Contains("Okuma kaydedildi", await SonrakiAsync(tarayici, yanit));
        await using var db = YeniDb();
        var oturum = await db.Oturumlar.SingleAsync(Ct);
        Assert.Equal((ogeId, 0m, 35m, 40), (oturum.OgeId, oturum.BaslangicKonum, oturum.BitisKonum, oturum.Dakika));
    }

    [Fact]
    public async Task ReadingLog_SaysWhatIsWrong_AndRefusesABookOfAnotherHabit()
    {
        var (_, tarayici) = await HazirlaAsync();
        var (id, ogeId) = await RafAliskanligiAsync();

        var eksik = await SonrakiAsync(tarayici, await PostAsync(tarayici, $"/Aliskanliklar/Detay/{id}", "Okuma", new() { ["ogeId"] = ogeId.ToString() }));
        var tasan = await SonrakiAsync(tarayici, await PostAsync(tarayici, $"/Aliskanliklar/Detay/{id}", "Okuma", new() { ["ogeId"] = ogeId.ToString(), ["bitisKonum"] = "700" }));
        var baska = await PostAsync(tarayici, $"/Aliskanliklar/Detay/{id}", "Okuma", new() { ["ogeId"] = Guid.NewGuid().ToString(), ["bitisKonum"] = "10" });

        Assert.Contains("Nereye kadar geldiğini yaz", eksik);
        Assert.Contains("aşamaz", tasan);
        Assert.Equal(HttpStatusCode.NotFound, baska.StatusCode);
        await using var db = YeniDb();
        Assert.Empty(await db.Oturumlar.ToListAsync(Ct));
    }

    // Beyin

    [Fact]
    public async Task Beyin_HasTheSearchOnTop_AndTheProjectsBelow()
    {
        var (_, tarayici) = await HazirlaAsync();

        var ham = await HamAsync(tarayici, "/Beyin");
        var metin = Metin(ham);

        Assert.Contains("<title>Beyin - Kafamdakiler", metin);
        Assert.Contains("action=\"/Beyin/Ara\"", ham);
        Assert.Contains("name=\"q\"", ham);
        Assert.Contains("Kitap Kulübü", metin);
        // The search comes before the projects.
        Assert.True(ham.IndexOf("name=\"q\"", StringComparison.Ordinal) < ham.IndexOf("href=\"/Beyin/Proje/kitap-kulubu\"", StringComparison.Ordinal));
        Assert.Contains("href=\"/Beyin/Proje/kitap-kulubu\"", ham);
    }
}
