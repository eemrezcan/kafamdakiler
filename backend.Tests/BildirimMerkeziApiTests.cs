using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Bildirimler;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The notification center (K-0024, sözleşme §6) through the whole app: the person's own rows newest first, paging by the moment of the
// oldest row, the unread count, marking one or all as read, and that somebody else's rows are never seen or touched.
public sealed class BildirimMerkeziApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static readonly DateTimeOffset Baslangic = new(2026, 11, 9, 8, 0, 0, TimeSpan.Zero);

    private async Task<string> GirisAsync(string eposta)
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string? token)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await uygulama.CreateClient().SendAsync(istek, Ct);
    }

    private static async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    private async Task<Guid> KullaniciAsync(string eposta)
    {
        using var kapsam = uygulama.Services.CreateScope();
        var yonetici = kapsam.ServiceProvider.GetRequiredService<UserManager<IdentityUser<Guid>>>();
        return (await yonetici.FindByEmailAsync(eposta))!.Id;
    }

    // The database is shared by the tests of this class: each starts with no notifications.
    private async Task TemizleAsync()
    {
        await using var db = uygulama.YeniDb();
        await db.Bildirimler.ExecuteDeleteAsync(Ct);
    }

    // `n` rows one minute apart, the first the oldest; `okunan` of the oldest ones are read already.
    private async Task<List<Guid>> EkleAsync(Guid kullaniciId, int n, int okunan = 0, string kaynak = "hatirlatici")
    {
        await using var db = uygulama.YeniDb();
        var kayitlar = Enumerable.Range(0, n).Select(i => new Bildirim
        {
            KullaniciId = kullaniciId, Baslik = $"B{i:00}", Metin = $"Metin {i}", KaynakTuru = kaynak, Rota = "/bugun", HedefKimligi = $"h{i}",
            Anahtar = $"{kaynak}:{kullaniciId}:{i}", OlusmaAni = Baslangic.AddMinutes(i), OkunmaAni = i < okunan ? Baslangic.AddMinutes(i + 1) : null,
        }).ToList();
        db.Bildirimler.AddRange(kayitlar);
        await db.SaveChangesAsync(Ct);
        return kayitlar.Select(k => k.Id).ToList();
    }

    [Fact]
    public async Task List_IsTheOwnRowsNewestFirst_WithTheirFieldsAndWhetherTheyWereRead()
    {
        await TemizleAsync();
        var sahipId = await KullaniciAsync(UygulamaFabrikasi.SahipEposta);
        var asistanId = await KullaniciAsync(UygulamaFabrikasi.AsistanEposta);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var kendi = await EkleAsync(sahipId, 3, okunan: 1);
        await EkleAsync(asistanId, 4);

        var yanit = await GonderAsync(HttpMethod.Get, "/api/bildirimler", sahip);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        var liste = (await OkuAsync(yanit)).EnumerateArray().ToList();
        Assert.Equal(["B02", "B01", "B00"], liste.Select(b => b.GetProperty("baslik").GetString()));
        Assert.Equal([kendi[2], kendi[1], kendi[0]], liste.Select(b => b.GetProperty("id").GetGuid()));
        Assert.Equal([false, false, true], liste.Select(b => b.GetProperty("okundu").GetBoolean()));
        var ilk = liste[0];
        Assert.Equal(("Metin 2", "/bugun", "h2", "hatirlatici"), (ilk.GetProperty("metin").GetString(), ilk.GetProperty("rota").GetString(), ilk.GetProperty("hedefKimligi").GetString(), ilk.GetProperty("kaynakTuru").GetString()));
        Assert.Equal(Baslangic.AddMinutes(2), ilk.GetProperty("olusmaAni").GetDateTimeOffset());
        Assert.False(ilk.TryGetProperty("secenekler", out _));
    }

    [Fact]
    public async Task List_HoldsThirtyByDefault_AndPagesBackFromTheOldestRowOfThePageBefore()
    {
        await TemizleAsync();
        var sahipId = await KullaniciAsync(UygulamaFabrikasi.SahipEposta);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        await EkleAsync(sahipId, 35);

        var ilkSayfa = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler", sahip))).EnumerateArray().ToList();
        Assert.Equal(30, ilkSayfa.Count);
        Assert.Equal("B34", ilkSayfa[0].GetProperty("baslik").GetString());
        Assert.Equal("B05", ilkSayfa[^1].GetProperty("baslik").GetString());

        var once = Uri.EscapeDataString(ilkSayfa[^1].GetProperty("olusmaAni").GetDateTimeOffset().ToString("O"));
        var ikinci = (await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/bildirimler?once={once}", sahip))).EnumerateArray().ToList();
        Assert.Equal(["B04", "B03", "B02", "B01", "B00"], ikinci.Select(b => b.GetProperty("baslik").GetString()));

        var kucuk = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler?limit=2", sahip))).EnumerateArray().ToList();
        Assert.Equal(["B34", "B33"], kucuk.Select(b => b.GetProperty("baslik").GetString()));
        var sonOnce = Uri.EscapeDataString(Baslangic.ToString("O"));
        Assert.Empty((await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/bildirimler?once={sonOnce}", sahip))).EnumerateArray());

        foreach (var kotu in new[] { "limit=0", "limit=101", "limit=-1" })
            Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, $"/api/bildirimler?{kotu}", sahip)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await GonderAsync(HttpMethod.Get, "/api/bildirimler?once=dun", sahip)).StatusCode);
        Assert.Equal(35, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler?limit=100", sahip))).GetArrayLength());
    }

    [Fact]
    public async Task Count_IsTheUnreadOnesOfTheSignedInPerson_Only()
    {
        await TemizleAsync();
        var sahipId = await KullaniciAsync(UygulamaFabrikasi.SahipEposta);
        var asistanId = await KullaniciAsync(UygulamaFabrikasi.AsistanEposta);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        await EkleAsync(sahipId, 5, okunan: 2);
        await EkleAsync(asistanId, 7);

        Assert.Equal(3, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler/sayi", sahip))).GetProperty("okunmamis").GetInt32());
        Assert.Equal(7, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler/sayi", asistan))).GetProperty("okunmamis").GetInt32());
    }

    [Fact]
    public async Task MarkOne_SetsTheFirstReading_AndSomebodyElsesRowIsA404ThatChangesNothing()
    {
        await TemizleAsync();
        var sahipId = await KullaniciAsync(UygulamaFabrikasi.SahipEposta);
        var asistanId = await KullaniciAsync(UygulamaFabrikasi.AsistanEposta);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var kendi = await EkleAsync(sahipId, 2);
        var baskasi = await EkleAsync(asistanId, 1);

        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Post, $"/api/bildirimler/{kendi[0]}/okundu", sahip)).StatusCode);
        DateTimeOffset? ilkOkuma;
        await using (var db = uygulama.YeniDb())
            ilkOkuma = (await db.Bildirimler.AsNoTracking().SingleAsync(b => b.Id == kendi[0], Ct)).OkunmaAni;
        Assert.NotNull(ilkOkuma);

        // Again: still fine, and the first reading stays.
        await Task.Delay(20, Ct);
        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Post, $"/api/bildirimler/{kendi[0]}/okundu", sahip)).StatusCode);
        await using (var db = uygulama.YeniDb())
        {
            Assert.Equal(ilkOkuma, (await db.Bildirimler.AsNoTracking().SingleAsync(b => b.Id == kendi[0], Ct)).OkunmaAni);
            Assert.Null((await db.Bildirimler.AsNoTracking().SingleAsync(b => b.Id == kendi[1], Ct)).OkunmaAni);
        }

        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/bildirimler/{baskasi[0]}/okundu", sahip)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await GonderAsync(HttpMethod.Post, $"/api/bildirimler/{Guid.NewGuid()}/okundu", sahip)).StatusCode);
        await using (var db = uygulama.YeniDb())
            Assert.Null((await db.Bildirimler.AsNoTracking().SingleAsync(b => b.Id == baskasi[0], Ct)).OkunmaAni);

        Assert.Equal(1, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler/sayi", sahip))).GetProperty("okunmamis").GetInt32());
    }

    [Fact]
    public async Task MarkAll_ReadsOnlyTheOwnRows_AndKeepsTheEarlierReadings()
    {
        await TemizleAsync();
        var sahipId = await KullaniciAsync(UygulamaFabrikasi.SahipEposta);
        var asistanId = await KullaniciAsync(UygulamaFabrikasi.AsistanEposta);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var asistan = await GirisAsync(UygulamaFabrikasi.AsistanEposta);
        var kendi = await EkleAsync(sahipId, 4, okunan: 1);
        await EkleAsync(asistanId, 3);

        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Post, "/api/bildirimler/okundu", sahip)).StatusCode);

        Assert.Equal(0, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler/sayi", sahip))).GetProperty("okunmamis").GetInt32());
        Assert.Equal(3, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler/sayi", asistan))).GetProperty("okunmamis").GetInt32());
        await using var db = uygulama.YeniDb();
        // The one that was read already keeps its own moment.
        Assert.Equal(Baslangic.AddMinutes(1), (await db.Bildirimler.AsNoTracking().SingleAsync(b => b.Id == kendi[0], Ct)).OkunmaAni);
        // Marking all again with nothing unread is fine.
        Assert.Equal(HttpStatusCode.NoContent, (await GonderAsync(HttpMethod.Post, "/api/bildirimler/okundu", sahip)).StatusCode);
    }

    [Fact]
    public async Task TheCenter_NeedsASignIn_AndTheSingleReadIsAsItWas()
    {
        await TemizleAsync();
        var sahipId = await KullaniciAsync(UygulamaFabrikasi.SahipEposta);
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var kimlik = (await EkleAsync(sahipId, 1))[0];

        foreach (var (yontem, yol) in new[]
        {
            (HttpMethod.Get, "/api/bildirimler"), (HttpMethod.Get, "/api/bildirimler/sayi"),
            (HttpMethod.Post, $"/api/bildirimler/{kimlik}/okundu"), (HttpMethod.Post, "/api/bildirimler/okundu"),
        })
            Assert.Equal(HttpStatusCode.Unauthorized, (await GonderAsync(yontem, yol, null)).StatusCode);

        // The one-notification read is unchanged: no `okundu` in it, and reading it does not mark it.
        var tek = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/bildirimler/{kimlik}", sahip));
        Assert.Equal("B00", tek.GetProperty("baslik").GetString());
        Assert.False(tek.TryGetProperty("okundu", out _));
        Assert.Equal(1, (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/bildirimler/sayi", sahip))).GetProperty("okunmamis").GetInt32());
    }
}
