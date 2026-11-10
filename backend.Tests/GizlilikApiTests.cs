using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// What the brain keeps private stays private in the new views (K-0024, E9): a task that is hidden, or lives in `kisisel/` or `finans/`, is not in the
// day, the calendar, the leftovers of yesterday or any answer of the new endpoints, and cannot be ticked, carried or given a reminder through them.
// The plan file does not say where a task lives, so the filter is the list of tasks the API may show (BeyinOkuma.IzinliGorevlerAl).
public sealed class GizlilikApiTests(UygulamaFabrikasi uygulama) : GunTestTabani(uygulama), IClassFixture<UygulamaFabrikasi>
{
    // The brain's own hidden task (`gizli-gorev`) is not in this list at all: it leaves hidden tasks out itself. The one marked `gizli` is, and is left out here.
    private const string Gorevler = """
        [{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "gizli": false, "bitis": "2026-11-10"},
         {"kimlik": "dis-randevusu-al", "baslik": "Diş randevusu al", "durum": "aktif", "alan": "kisisel", "yol": "kisisel/gorevler/dis-randevusu-al.md", "gizli": false, "bitis": "2026-11-10"},
         {"kimlik": "butce-planla", "baslik": "Bütçe planla", "durum": "aktif", "alan": "finans", "yol": "finans/gorevler/butce-planla.md", "gizli": false, "bitis": "2026-11-10"},
         {"kimlik": "isaretli-gizli", "baslik": "Gizli işaretli", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/isaretli-gizli.md", "gizli": true, "bitis": "2026-11-10"}]
        """;

    // The brain's day lists every one of them, the closed ones with 100 minutes each so that a leak shows in the weight of the day.
    private static string[] Maddeler() =>
    [
        Madde("a1b1c1", "Normal iş", tahmin: 30),
        Madde("g:uye-girisi", "Üye girişi", gorev: "uye-girisi", tahmin: 40),
        Madde("g:dis-randevusu-al", "Diş randevusu al", gorev: "dis-randevusu-al", tahmin: 100),
        Madde("f1f1f1", "Maliyet çıkar", gorev: "butce-planla", tahmin: 100),
        Madde("g:gizli-gorev", "Gizli görev", gorev: "gizli-gorev", tahmin: 100),
        Madde("d1d1d1", "Gizli işaretli bağlı", gorev: "isaretli-gizli", tahmin: 100),
        Madde("b2b2b2", "Bağsız iş", tahmin: 20),
    ];

    private async Task<(WebApplicationFactory<Program> Fabrika, string Sahip)> HazirlaAsync()
    {
        await GunTemizleAsync();
        Beyin.Cikti("gorev liste", Gorevler);
        var geciken = "[" + string.Join(",", Geciken("uye-girisi", "Üye girişi", "2026-11-05", 4), Geciken("dis-randevusu-al", "Diş randevusu al", "2026-11-04", 5), Geciken("gizli-gorev", "Gizli görev", "2026-11-03", 6)) + "]";
        Beyin.Cikti("gun goster", GunJson(BugunMetni, Maddeler(), geciken));
        Beyin.CiktiTarihli("gun goster", DunMetni, GunJson(DunMetni, Maddeler()));
        Beyin.Cikti("gun isaretle", IsaretlendiJson(BugunMetni, Madde("a1b1c1", "Normal iş", "yapildi")));
        Beyin.Cikti("gun devret", $$"""{"tarih": "{{BugunMetni}}", "devredilen_gun": "2026-11-10", "madde": {{Madde("a1b1c1", "Normal iş")}}}""");
        Beyin.Cikti("gorev bitir", """{"yol": "x", "kimlik": "x", "degisen": ["durum"]}""");
        var fabrika = GunFabrikasi();
        return (fabrika, await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika));
    }

    private static List<string> Kimlikler(JsonElement gun) => gun.GetProperty("ogeler").EnumerateArray().Select(o => o.GetProperty("kimlik").GetString()!).Order().ToList();

    private int Yazmalar() => BeyinCagrisi("gun", "isaretle") + BeyinCagrisi("gun", "devret") + BeyinCagrisi("gun", "ekle") + BeyinCagrisi("gorev", "bitir");

    [Fact]
    public async Task Day_LeavesOutTheItemsOfHiddenAndClosedFolderTasks_TheirWeightAndTheLateOnesToo()
    {
        var (fabrika, sahip) = await HazirlaAsync();

        var gun = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));

        // The plain item, the one of the task the API may show (with its lateness) and the one without a task: nothing else.
        Assert.Equal(["g:uye-girisi", "m:a1b1c1", "m:b2b2b2"], Kimlikler(gun));
        Assert.Equal(4, gun.GetProperty("ogeler").EnumerateArray().Single(o => o.GetProperty("kimlik").GetString() == "g:uye-girisi").GetProperty("gecikmeGun").GetInt32());
        // 30 + 40 + 20 minutes: the closed ones' 100 minutes each are not in the weight of the day.
        var yuk = gun.GetProperty("yuk");
        Assert.Equal((90, 0), (yuk.GetProperty("acikTahminDk").GetInt32(), yuk.GetProperty("tahminsizSayi").GetInt32()));
        Assert.DoesNotContain("randevusu", gun.GetRawText());
        Assert.DoesNotContain("Maliyet", gun.GetRawText());
        Assert.DoesNotContain("Gizli", gun.GetRawText());
    }

    [Fact]
    public async Task Leftovers_OfYesterdayDoNotShowTheClosedOnes()
    {
        var (fabrika, sahip) = await HazirlaAsync();

        var gun = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));

        // Yesterday's open items without the closed ones (and without the task that already shows as late today).
        Assert.Equal(["a1b1c1", "b2b2b2"], gun.GetProperty("dundenKalanlar").EnumerateArray().Select(d => d.GetProperty("maddeId").GetString()!).Order());
        Assert.DoesNotContain("randevusu", gun.GetProperty("dundenKalanlar").GetRawText());
    }

    [Fact]
    public async Task Calendar_CountsAndComingLeaveOutTheClosedOnes_AndTheyAreNotAnOverload()
    {
        var (fabrika, sahip) = await HazirlaAsync();

        var yanit = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/takvim?baslangic=2026-11-09&bitis=2026-11-12", sahip, fabrika));

        foreach (var gun in yanit.GetProperty("gunler").EnumerateArray())
        {
            var tarih = gun.GetProperty("tarih").GetString();
            // The plan: the plain item and the free one (the made-up item of a task is counted with the tasks); the weight is 90, not 490.
            Assert.Equal(2, gun.GetProperty("sayilar").GetProperty("plan").GetInt32());
            Assert.False(gun.GetProperty("yukAsimi").GetBoolean(), $"{tarih} is not overloaded");
            // The tasks due on the 10th: only the one the API may show.
            Assert.Equal(tarih == "2026-11-10" ? 1 : 0, gun.GetProperty("sayilar").GetProperty("gorev").GetInt32());
        }

        Assert.Equal(["g:uye-girisi"], yanit.GetProperty("yaklasan").EnumerateArray().Select(o => o.GetProperty("kimlik").GetString()!));
        Assert.DoesNotContain("randevusu", yanit.GetRawText());
        Assert.DoesNotContain("Bütçe", yanit.GetRawText());
    }

    [Fact]
    public async Task Writes_ThroughTheNewEndpoints_CannotReachTheClosedOnes()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        var kapali = new[] { "m:f1f1f1", "m:d1d1d1", "m:g:dis-randevusu-al", "g:dis-randevusu-al", "g:butce-planla", "g:gizli-gorev", "g:isaretli-gizli" };

        foreach (var kimlik in kapali)
        {
            Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/yaptim", sahip, fabrika, new { kimlik })).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/yaptim", sahip, fabrika, new { kimlik, geri = kimlik[0] == 'm' })).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/devret", sahip, fabrika, new { kimlik })).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/ogeler/{kimlik}/hatirlatici", sahip, fabrika, new { tekrar = "yok", saat = "10:00" })).StatusCode);
        }

        // Nothing reached the brain's writes, and no reminder was made for them.
        Assert.Equal(0, Yazmalar());
        await using (var db = YeniDb())
            Assert.Empty(await db.Hatirlaticilar.ToListAsync(Ct));

        // The plain item of the same day goes through (the same calls, so the 404s above are the filter and not a broken setup).
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/yaptim", sahip, fabrika, new { kimlik = "m:a1b1c1" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/devret", sahip, fabrika, new { kimlik = "m:a1b1c1" })).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await GonderAsync(HttpMethod.Post, $"/api/gun/{BugunMetni}/ogeler/g:uye-girisi/hatirlatici", sahip, fabrika, new { tekrar = "yok", saat = "10:00" })).StatusCode);
    }

    [Fact]
    public async Task WhenTheListOfAllowedTasksCannotBeRead_WhatCannotBeCheckedIsNotShown()
    {
        var (fabrika, sahip) = await HazirlaAsync();
        Beyin.Cikti("gorev liste", """{"hata": {"kod": "hata", "mesaj": "okunamadı"}}""", cikis: 1);

        var gun = await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/gun/bugun", sahip, fabrika));

        // The items that name a task are gone, all of them; the ones that name none stay; the day is still read ("tamam").
        Assert.Equal(["m:a1b1c1", "m:b2b2b2"], Kimlikler(gun));
        Assert.Equal("tamam", gun.GetProperty("kaynaklar").GetProperty("plan").GetString());
    }
}
