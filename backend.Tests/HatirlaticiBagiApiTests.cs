using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Kafamdakiler.Tests;

// The new fields of the reminder (K-0024, sözleşme §2) through the whole app: the link to a plan item or task, and a weekly reminder that
// names several days. What the fields mean together is checked (400 ProblemDetails with the field), and the days work out the next moment.
public class HatirlaticiBagiApiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    private async Task<string> GirisAsync(string eposta)
    {
        var yanit = await uygulama.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = eposta, password = UygulamaFabrikasi.Parola }, Ct);
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

    private async Task<JsonElement> OkuAsync(HttpResponseMessage yanit)
    {
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        return json.RootElement.Clone();
    }

    // 2030-01-07 is a Monday: far enough ahead that the first moment of a rule is its own first day.

    [Fact]
    public async Task Weekly_WithDays_FindsTheFirstChosenDayFromTheStartDay_AndTheDaysComeBackAsNames()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var pazartesi = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "Spor", gun = "2030-01-07", saat = "09:00:00", tekrar = "haftalik", gunler = new[] { "pzt", "cum" } });
        Assert.Equal(HttpStatusCode.Created, pazartesi.StatusCode);
        var h = await OkuAsync(pazartesi);
        Assert.Equal(["pzt", "cum"], h.GetProperty("gunler").EnumerateArray().Select(g => g.GetString()));
        Assert.Equal(DateTimeOffset.Parse("2030-01-07T09:00:00+03:00"), h.GetProperty("sonrakiAn").GetDateTimeOffset());

        // Started on a Tuesday: the first firing is that week's Friday.
        var sali = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "Spor 2", gun = "2030-01-08", saat = "09:00:00", tekrar = "haftalik", gunler = new[] { "cum", "pzt" } }));
        Assert.Equal(DateTimeOffset.Parse("2030-01-11T09:00:00+03:00"), sali.GetProperty("sonrakiAn").GetDateTimeOffset());
        // Listed Monday first whatever the order sent.
        Assert.Equal(["pzt", "cum"], sali.GetProperty("gunler").EnumerateArray().Select(g => g.GetString()));

        // Read back, and changed.
        var id = h.GetProperty("id").GetGuid();
        var oku = await OkuAsync(await GonderAsync(HttpMethod.Get, $"/api/hatirlaticilar/{id}", sahip));
        Assert.Equal(["pzt", "cum"], oku.GetProperty("gunler").EnumerateArray().Select(g => g.GetString()));
        var degisti = await OkuAsync(await GonderAsync(HttpMethod.Put, $"/api/hatirlaticilar/{id}", sahip,
            new { baslik = "Spor", gun = "2030-01-07", saat = "09:00:00", tekrar = "haftalik", gunler = new[] { "sal", "per" } }));
        Assert.Equal(["sal", "per"], degisti.GetProperty("gunler").EnumerateArray().Select(g => g.GetString()));
        Assert.Equal(DateTimeOffset.Parse("2030-01-08T09:00:00+03:00"), degisti.GetProperty("sonrakiAn").GetDateTimeOffset());
    }

    [Fact]
    public async Task Weekly_DoneMovesToTheNextChosenDay_AndDaysOfAnyOtherRuleAreDropped()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var haftalik = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "Spor", gun = "2030-01-07", saat = "09:00:00", tekrar = "haftalik", gunler = new[] { "pzt", "car" } }));
        var id = haftalik.GetProperty("id").GetGuid();

        // Done on Monday: next is Wednesday, then (done again) next Monday.
        var yaptim = await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{id}/yaptim", sahip));
        Assert.Equal(DateTimeOffset.Parse("2030-01-09T09:00:00+03:00"), yaptim.GetProperty("sonrakiAn").GetDateTimeOffset());
        var yine = await OkuAsync(await GonderAsync(HttpMethod.Post, $"/api/hatirlaticilar/{id}/yaptim", sahip));
        Assert.Equal(DateTimeOffset.Parse("2030-01-14T09:00:00+03:00"), yine.GetProperty("sonrakiAn").GetDateTimeOffset());

        // Days sent with another rule mean nothing: they are not kept.
        var gunluk = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "Her gün", gun = "2030-01-07", saat = "09:00:00", tekrar = "gunluk", gunler = new[] { "cum" } }));
        Assert.Empty(gunluk.GetProperty("gunler").EnumerateArray());
        Assert.Equal(DateTimeOffset.Parse("2030-01-07T09:00:00+03:00"), gunluk.GetProperty("sonrakiAn").GetDateTimeOffset());
        var bos = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "Hafta", gun = "2030-01-09", saat = "09:00:00", tekrar = "haftalik" }));
        Assert.Empty(bos.GetProperty("gunler").EnumerateArray());
        Assert.Equal(DateTimeOffset.Parse("2030-01-09T09:00:00+03:00"), bos.GetProperty("sonrakiAn").GetDateTimeOffset());
    }

    [Fact]
    public async Task Link_TheItemAndTheTaskAreKeptAndShown_ThePlanItemNeedsItsDay()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "Rapor", gun = "2030-01-07", tekrar = "yok", maddeId = "a3f09c", maddeTarihi = "2030-01-07", gorevKimligi = "uye-girisi" });
        Assert.Equal(HttpStatusCode.Created, yanit.StatusCode);
        var h = await OkuAsync(yanit);
        Assert.Equal("a3f09c", h.GetProperty("maddeId").GetString());
        Assert.Equal("2030-01-07", h.GetProperty("maddeTarihi").GetString());
        Assert.Equal("uye-girisi", h.GetProperty("gorevKimligi").GetString());
        Assert.Equal(JsonValueKind.Null, h.GetProperty("zincirHatasi").ValueKind);

        // A task alone is fine; neither is fine too (a plain reminder).
        var gorevli = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "G", gun = "2030-01-07", gorevKimligi = "uye-girisi" }));
        Assert.Equal(JsonValueKind.Null, gorevli.GetProperty("maddeId").ValueKind);
        Assert.Equal(JsonValueKind.Null, gorevli.GetProperty("maddeTarihi").ValueKind);
        var duz = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new { baslik = "D", gun = "2030-01-07" }));
        Assert.Equal(JsonValueKind.Null, duz.GetProperty("gorevKimligi").ValueKind);
    }

    [Fact]
    public async Task Edit_WithoutTheLinkFields_KeepsTheLinkAndTheDays_AnEmptyTextTakesTheLinkAway()
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var kur = await OkuAsync(await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, new
        {
            baslik = "Rapor", gun = "2030-01-07", saat = "09:00:00", tekrar = "haftalik", gunler = new[] { "pzt", "cum" },
            maddeId = "a3f09c", maddeTarihi = "2030-01-07", gorevKimligi = "uye-girisi",
        }));
        var id = kur.GetProperty("id").GetGuid();

        // A form or an older client that sends none of the new fields (a title change only).
        var baslik = await OkuAsync(await GonderAsync(HttpMethod.Put, $"/api/hatirlaticilar/{id}", sahip,
            new { baslik = "Rapor yaz", gun = "2030-01-07", saat = "09:00:00", tekrar = "haftalik" }));
        Assert.Equal("Rapor yaz", baslik.GetProperty("baslik").GetString());
        Assert.Equal("a3f09c", baslik.GetProperty("maddeId").GetString());
        Assert.Equal("2030-01-07", baslik.GetProperty("maddeTarihi").GetString());
        Assert.Equal("uye-girisi", baslik.GetProperty("gorevKimligi").GetString());
        Assert.Equal(["pzt", "cum"], baslik.GetProperty("gunler").EnumerateArray().Select(g => g.GetString()));

        // An empty text unlinks (the item and its day together; the task alone); an empty list clears the days.
        var ayrildi = await OkuAsync(await GonderAsync(HttpMethod.Put, $"/api/hatirlaticilar/{id}", sahip,
            new { baslik = "Rapor yaz", gun = "2030-01-07", saat = "09:00:00", tekrar = "haftalik", gunler = Array.Empty<string>(), maddeId = "", gorevKimligi = "" }));
        Assert.Equal(JsonValueKind.Null, ayrildi.GetProperty("maddeId").ValueKind);
        Assert.Equal(JsonValueKind.Null, ayrildi.GetProperty("maddeTarihi").ValueKind);
        Assert.Equal(JsonValueKind.Null, ayrildi.GetProperty("gorevKimligi").ValueKind);
        Assert.Empty(ayrildi.GetProperty("gunler").EnumerateArray());
    }

    [Theory]
    [InlineData("maddeId", "a3f09c", "maddeTarihi")] // an item without its day
    [InlineData("maddeTarihi", "2030-01-07", "maddeTarihi")] // a day without an item
    [InlineData("maddeId", "yanlis", "maddeId")] // not the permanent id of an item
    [InlineData("maddeId", "123456", "maddeId")] // a number alone is a list position
    [InlineData("gorevKimligi", "Büyük Harf", "gorevKimligi")]
    [InlineData("gorevKimligi", "../yol", "gorevKimligi")]
    public async Task Link_WhatDoesNotFit_IsA400WithTheField(string alan, string deger, string hatali)
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);
        var govde = new Dictionary<string, object?> { ["baslik"] = "x", ["gun"] = "2030-01-07", [alan] = deger };

        var yanit = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip, govde);

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
        Assert.True((await OkuAsync(yanit)).GetProperty("errors").TryGetProperty(hatali, out _));
    }

    [Theory]
    [InlineData("yok")]
    [InlineData("pazartesi")]
    [InlineData("")]
    public async Task Days_AWeekdayThatIsNotOneOfTheSeven_IsRefused(string gun)
    {
        var sahip = await GirisAsync(UygulamaFabrikasi.SahipEposta);

        var yanit = await GonderAsync(HttpMethod.Post, "/api/hatirlaticilar", sahip,
            new { baslik = "x", gun = "2030-01-07", tekrar = "haftalik", gunler = new[] { gun } });

        Assert.Equal(HttpStatusCode.BadRequest, yanit.StatusCode);
    }
}
