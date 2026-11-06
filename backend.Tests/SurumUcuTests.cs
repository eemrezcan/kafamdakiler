using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace Kafamdakiler.Tests;

// GET /api/surum: anonymous, and the value comes from the Mobil:EnAzSurumKodu setting.
public class SurumUcuTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    [Fact]
    public async Task Anonim_cagri_varsayilan_degeri_verir()
    {
        var yanit = await uygulama.CreateClient().GetAsync("/api/surum", Ct);

        Assert.Equal(HttpStatusCode.OK, yanit.StatusCode);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        Assert.Equal(1, json.RootElement.GetProperty("enAzMobilSurumKodu").GetInt32());
    }

    [Fact]
    public async Task Deger_ayardan_okunur()
    {
        using var ozel = uygulama.WithWebHostBuilder(b => b.UseSetting("Mobil:EnAzSurumKodu", "7"));

        var yanit = await ozel.CreateClient().GetFromJsonAsync<JsonElement>("/api/surum", Ct);

        Assert.Equal(7, yanit.GetProperty("enAzMobilSurumKodu").GetInt32());
    }
}
