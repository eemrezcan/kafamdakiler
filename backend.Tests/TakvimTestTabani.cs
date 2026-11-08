using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Data;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The ground the Google Calendar tests stand on (K2.3c): the whole app (real pipeline, Identity, PostgreSQL) with a fake Google in place
// of the real client and a clock the test moves. Nothing here reaches Google.
public abstract class TakvimTestTabani(UygulamaFabrikasi uygulama) : IDisposable
{
    public const string DonusAdresi = "https://kafamdakiler.test/google/donus";

    // 07:00 in Istanbul on a Saturday: the day is 2026-11-07.
    protected static readonly DateTimeOffset Sabah = new(2026, 11, 7, 7, 0, 0, TimeSpan.FromHours(3));
    protected static readonly DateOnly Bugun = new(2026, 11, 7);

    private readonly List<WebApplicationFactory<Program>> _fabrikalar = [];

    protected UygulamaFabrikasi Uygulama => uygulama;

    protected SahteGoogle Google { get; } = new();

    protected static CancellationToken Ct => TestContext.Current.CancellationToken;

    public void Dispose()
    {
        foreach (var f in _fabrikalar)
            f.Dispose();
    }

    protected ElleSaat Saat { get; private set; } = new(Sabah.ToUniversalTime());

    // `google` false leaves the Google settings out: the module is off. `takvimler` is Google:Takvimler. `kapasiteSaat` is Gun:KapasiteSaat.
    // `ek` adds more to the host (a fake brain's settings, say).
    protected WebApplicationFactory<Program> Fabrika(
        DateTimeOffset? an = null, bool google = true, string takvimler = "primary,is", string? kapasiteSaat = null,
        Action<IWebHostBuilder>? ek = null)
    {
        var saat = Saat = new ElleSaat((an ?? Sabah).ToUniversalTime());
        var fabrika = uygulama.WithWebHostBuilder(b =>
        {
            b.UseSetting("Beyin:GonderimAraligiSaniye", "3600").UseSetting("Gelen:OneriAraligiDakika", "600");
            if (google)
            {
                b.UseSetting("Google:ClientId", "test-istemci").UseSetting("Google:ClientSecret", "test-gizli")
                    .UseSetting("Google:DonusAdresi", DonusAdresi).UseSetting("Google:Takvimler", takvimler)
                    .UseSetting("Google:EsitlemeDakika", "600");
            }

            if (kapasiteSaat is not null)
                b.UseSetting("Gun:KapasiteSaat", kapasiteSaat);
            ek?.Invoke(b);

            b.ConfigureTestServices(s =>
            {
                s.AddSingleton<TimeProvider>(saat);
                s.AddSingleton<IGoogleTakvimIstemcisi>(Google);
            });
        });
        _fabrikalar.Add(fabrika);
        return fabrika;
    }

    // The database is shared by the tests of a class: each starts without the calendar and the queue rows of the one before.
    protected async Task TemizleAsync()
    {
        await using var db = uygulama.YeniDb();
        await db.EylemGunlukleri.ExecuteDeleteAsync(Ct);
        await db.Eylemler.ExecuteDeleteAsync(Ct);
        await db.EylemIzinleri.ExecuteDeleteAsync(Ct);
        await db.TakvimEtkinlikleri.ExecuteDeleteAsync(Ct);
        await db.TakvimEsitlemeleri.ExecuteDeleteAsync(Ct);
        await db.GoogleBaglantilari.ExecuteDeleteAsync(Ct);
        await db.GoogleYetkilendirmeleri.ExecuteDeleteAsync(Ct);
        await db.Hatirlaticilar.ExecuteDeleteAsync(Ct);
        await db.BrifingOylari.ExecuteDeleteAsync(Ct);
        await db.Brifingler.ExecuteDeleteAsync(Ct);
        await db.GmailMesajlari.ExecuteDeleteAsync(Ct);
    }

    protected async Task<string> GirisAsync(string eposta, WebApplicationFactory<Program> fabrika)
    {
        var yanit = await fabrika.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    protected async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string? token, WebApplicationFactory<Program> fabrika, object? govde = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await fabrika.CreateClient().SendAsync(istek, Ct);
    }

    protected static async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    protected async Task IzinAsync(string sahip, string izin, WebApplicationFactory<Program> fabrika)
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, fabrika, new { acik = true });
        Assert.True(yanit.IsSuccessStatusCode, await yanit.Content.ReadAsStringAsync(Ct));
    }

    protected async Task<Guid> SahipKimligiAsync(WebApplicationFactory<Program> fabrika)
    {
        using var kapsam = fabrika.Services.CreateScope();
        var kullanicilar = kapsam.ServiceProvider.GetRequiredService<UserManager<IdentityUser<Guid>>>();
        return (await kullanicilar.FindByEmailAsync(UygulamaFabrikasi.SahipEposta))!.Id;
    }

    // The state parameter of a consent address.
    protected static string QueryDegeri(string adres, string ad)
    {
        var sorgu = System.Web.HttpUtility.ParseQueryString(new Uri(adres).Query);
        return sorgu[ad] ?? throw new InvalidOperationException($"{ad} is not in the address.");
    }

    // The whole connect, minus the browser: start (as the Sahip), then the callback with a code. Returns the state it used.
    protected async Task<string> BaglaAsync(WebApplicationFactory<Program> fabrika)
    {
        var sahipId = await SahipKimligiAsync(fabrika);
        using var kapsam = fabrika.Services.CreateScope();
        var baglanti = kapsam.ServiceProvider.GetRequiredService<GoogleBaglanti>();
        var adres = await baglanti.BaslatAsync(sahipId, Ct) ?? throw new InvalidOperationException("The module is off.");
        var state = QueryDegeri(adres.AbsoluteUri, "state");
        var sonuc = await baglanti.TamamlaAsync(sahipId, state, "kod-1", null, Ct);
        Assert.True(sonuc.Basarili, sonuc.Tur.ToString());
        return state;
    }

    protected async Task<TakvimEtkinligi> EtkinlikEkleAsync(
        string baslik, DateTimeOffset bas, DateTimeOffset bit, string takvim = "primary", string? yer = null)
    {
        var e = new TakvimEtkinligi
        {
            TakvimKimligi = takvim, GoogleKimligi = "g-" + Guid.NewGuid().ToString("N"), Baslik = baslik, Yer = yer,
            Baslangic = bas.ToUniversalTime(), Bitis = bit.ToUniversalTime(), TumGun = false,
            BaslangicGunu = DateOnly.FromDateTime(bas.UtcDateTime), BitisGunu = DateOnly.FromDateTime(bit.UtcDateTime),
            Etag = "\"x\"", GuncellemeAni = Sabah.ToUniversalTime(),
        };
        await using var db = uygulama.YeniDb();
        db.TakvimEtkinlikleri.Add(e);
        await db.SaveChangesAsync(Ct);
        return e;
    }

    protected async Task<TakvimEtkinligi> TumGunEtkinligiEkleAsync(string baslik, DateOnly ilk, DateOnly sonGun)
    {
        var e = new TakvimEtkinligi
        {
            TakvimKimligi = "primary", GoogleKimligi = "g-" + Guid.NewGuid().ToString("N"), Baslik = baslik, TumGun = true,
            BaslangicGunu = ilk, BitisGunu = sonGun.AddDays(1), GuncellemeAni = Sabah.ToUniversalTime(),
            Baslangic = Kafamdakiler.Hatirlaticilar.HatirlaticiHesap.An(ilk, TimeOnly.MinValue),
            Bitis = Kafamdakiler.Hatirlaticilar.HatirlaticiHesap.An(sonGun.AddDays(1), TimeOnly.MinValue),
        };
        await using var db = uygulama.YeniDb();
        db.TakvimEtkinlikleri.Add(e);
        await db.SaveChangesAsync(Ct);
        return e;
    }

    protected AppDbContext YeniDb() => uygulama.YeniDb();

    // A moment in Istanbul time (UTC+3). (SahteGoogle.Ist is the same moment in Google's own shape.)
    protected static DateTimeOffset IstAn(int yil, int ay, int gun, int saat, int dakika = 0) =>
        new(yil, ay, gun, saat, dakika, 0, TimeSpan.FromHours(3));
}
