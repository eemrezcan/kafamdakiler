using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The new endpoints of the UI revision (K-0024) are in the OpenAPI document, with their methods: what the clients are written from.
// The document is made by the app's own generator (the one that serves /openapi/v1.json in development), asked for through the tooling
// interface, so nothing here depends on the development environment (which would read the developer's own secrets).
public sealed class OpenApiUclariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private async Task<JsonElement> BelgeAsync()
    {
        var saglayiciTuru = Type.GetType("Microsoft.Extensions.ApiDescriptions.IDocumentProvider, Microsoft.AspNetCore.OpenApi")
            ?? throw new InvalidOperationException("The document provider of the OpenAPI package is gone.");
        var saglayici = uygulama.Services.GetRequiredService(saglayiciTuru);
        using var yazici = new StringWriter();
        var gorev = (Task)saglayiciTuru.GetMethod("GenerateAsync", [typeof(string), typeof(TextWriter)])!.Invoke(saglayici, ["v1", yazici])!;
        await gorev;
        return JsonDocument.Parse(yazici.ToString()).RootElement.Clone();
    }

    [Fact]
    public async Task TheNewEndpointsAreInTheDocument()
    {
        var yollar = (await BelgeAsync()).GetProperty("paths");

        var beklenen = new (string Yol, string[] Yontemler)[]
        {
            ("/api/gun/{tarih}", ["get"]),
            ("/api/gun/{tarih}/yaptim", ["post"]),
            ("/api/gun/{tarih}/dunden/{maddeId}/birak", ["post"]),
            ("/api/gun/{tarih}/ogeler", ["post"]),
            ("/api/gun/{tarih}/ogeler/{kimlik}/hatirlatici", ["post", "put", "delete"]),
            ("/api/takvim", ["get"]),
            ("/api/ayarlar/gun", ["get", "put"]),
            ("/api/gun/{tarih}/devret", ["post"]),
            ("/api/bildirimler", ["get"]),
            ("/api/bildirimler/sayi", ["get"]),
            ("/api/bildirimler/{id}/okundu", ["post"]),
            ("/api/bildirimler/okundu", ["post"]),
            ("/api/asistan/girdi", ["post"]),
            ("/api/asistan/sorular/{id}/cevap", ["post"]),
            ("/api/asistan/akis", ["get"]),
            ("/api/asistan/sayi", ["get"]),
        };
        foreach (var (yol, yontemler) in beklenen)
        {
            Assert.True(yollar.TryGetProperty(yol, out var tanim), $"{yol} is not in the document");
            foreach (var yontem in yontemler)
                Assert.True(tanim.TryGetProperty(yontem, out _), $"{yontem} {yol} is not in the document");
        }
    }
}
