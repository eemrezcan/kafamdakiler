using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The persistent-reminder fields (H4): the server stores and returns them and checks them (K-0017). A body that leaves them out is
// not persistent; an old row in the database is covered by IsrarProjeRepoGocTests, which runs the real migration.
public class HatirlaticiIsrarTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static string Gun => DateOnly.FromDateTime(DateTime.UtcNow).AddDays(10).ToString("yyyy-MM-dd");

    private async Task<string> SahipAsync()
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = UygulamaFabrikasi.SahipEposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.GetProperty("accessToken").GetString()!;
    }

    private async Task<HttpResponseMessage> GonderAsync(HttpMethod yontem, string yol, string token, object? govde = null)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (govde is not null)
            istek.Content = JsonContent.Create(govde);
        return await uygulama.CreateClient().SendAsync(istek, Ct);
    }

    private static async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    private static void Esit(JsonElement h, bool israrli, int aralik, int enCok, bool acil)
    {
        Assert.Equal(israrli, h.GetProperty("israrli").GetBoolean());
        Assert.Equal(aralik, h.GetProperty("israrAraligiDakika").GetInt32());
        Assert.Equal(enCok, h.GetProperty("israrEnCok").GetInt32());
        Assert.Equal(acil, h.GetProperty("acil").GetBoolean());
    }

    [Fact]
    public async Task ABodyWithoutTheNewFields_IsNotPersistent_WithTheDefaults()
    {
        var sahip = await SahipAsync();

        var olustur = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "Eski istemci", gun = Gun });

        Assert.Equal(HttpStatusCode.Created, olustur.StatusCode);
        Esit(await OkuAsync(olustur), israrli: false, aralik: 15, enCok: 3, acil: false);
    }

    [Fact]
    public async Task ThePersistentFields_AreStored_ReturnedAndChangedOnEdit()
    {
        var sahip = await SahipAsync();

        var olustur = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "İlaç", gun = Gun, israrli = true, israrAraligiDakika = 5, israrEnCok = 4, acil = true });
        Assert.Equal(HttpStatusCode.Created, olustur.StatusCode);
        var h = await OkuAsync(olustur);
        Esit(h, israrli: true, aralik: 5, enCok: 4, acil: true);
        var id = h.GetProperty("id").GetGuid();

        Esit(await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/hatirlaticilar/{id}", sahip)), true, 5, 4, true);
        var liste = (await OkuAsync(await GonderAsync(HttpMethod.Get, "/api/hatirlaticilar", sahip))).EnumerateArray();
        Esit(liste.Single(x => x.GetProperty("id").GetGuid() == id), true, 5, 4, true);

        var degistir = await GonderAsync(HttpMethod.Put, $"/api/hatirlaticilar/{id}", sahip,
            new { baslik = "İlaç", gun = Gun, israrli = true, israrAraligiDakika = 60, israrEnCok = 1, acil = false });
        Assert.Equal(HttpStatusCode.OK, degistir.StatusCode);
        Esit(await OkuAsync(degistir), true, 60, 1, false);

        // The marks and the snooze leave the fields alone.
        Esit(await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{id}/ertele", sahip, new { sure = "1s" })), true, 60, 1, false);
        Esit(await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{id}/yaptim", sahip)), true, 60, 1, false);
    }

    [Theory]
    [InlineData(10, 3, "israrAraligiDakika")]
    [InlineData(0, 3, "israrAraligiDakika")]
    [InlineData(120, 3, "israrAraligiDakika")]
    [InlineData(15, 0, "israrEnCok")]
    [InlineData(15, 5, "israrEnCok")]
    [InlineData(15, -1, "israrEnCok")]
    public async Task ABadInterval_OrCount_Is400_WithTheFieldName_AndNothingIsStored(int aralik, int enCok, string alan)
    {
        var sahip = await SahipAsync();
        var baslik = "Reddedilecek-" + Guid.NewGuid().ToString("N");

        var yanit = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik, gun = Gun, israrli = true, israrAraligiDakika = aralik, israrEnCok = enCok });

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        var hatalar = (await OkuAsync(yanit)).GetProperty("errors");
        Assert.True(hatalar.EnumerateObject().Any(p => string.Equals(p.Name, alan, StringComparison.OrdinalIgnoreCase)), hatalar.ToString());
        await using var db = uygulama.YeniDb();
        Assert.DoesNotContain(await db.Hatirlaticilar.ToListAsync(Ct), h => h.Baslik == baslik);
    }

    [Theory]
    [InlineData(5)]
    [InlineData(15)]
    [InlineData(60)]
    public async Task EveryAllowedInterval_IsAccepted(int aralik)
    {
        var sahip = await SahipAsync();

        var yanit = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "Aralık", gun = Gun, israrli = true, israrAraligiDakika = aralik });

        Assert.Equal(HttpStatusCode.Created, yanit.StatusCode);
        Esit(await OkuAsync(yanit), true, aralik, 3, false);
    }
}
