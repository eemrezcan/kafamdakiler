using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Kafamdakiler.Bildirimler;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Kafamdakiler.Tests;

// The first real run showed `IX_BildirimCihazlari_Token` errors in the log when the phone sent its token twice at once (start-up and
// "token renewed"). The request itself already recovered; the error line was the failed insert. The register is now one statement, so
// there is no failed insert at all.
public sealed class CihazKayitYarisiTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    // Collects every line the app logs at Error or worse, with its category.
    private sealed class HataToplayici : ILoggerProvider
    {
        public List<string> Satirlar { get; } = [];

        public ILogger CreateLogger(string kategori) => new Gunluk(kategori, Satirlar);

        public void Dispose()
        {
        }

        private sealed class Gunluk(string kategori, List<string> satirlar) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

            public bool IsEnabled(LogLevel logLevel) => logLevel >= LogLevel.Error;

            public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
            {
                if (logLevel >= LogLevel.Error)
                {
                    lock (satirlar)
                        satirlar.Add($"{kategori}: {formatter(state, exception)} {exception?.Message}");
                }
            }
        }
    }

    [Fact]
    public async Task TheSameNewTokenSentManyTimesAtOnce_IsOneRow_AllAnswersAre204_AndNothingIsLoggedAsAnError()
    {
        var toplayici = new HataToplayici();
        using var fabrika = uygulama.WithWebHostBuilder(b => b.ConfigureLogging(l => l.AddProvider(toplayici)));
        var yanit = await fabrika.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = UygulamaFabrikasi.SahipEposta, password = UygulamaFabrikasi.Parola }, Ct);
        yanit.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        var erisim = json.RootElement.GetProperty("accessToken").GetString()!;
        var token = "fcm-yaris-" + Guid.NewGuid().ToString("N");

        // Every request starts together, so several of them see "no such token yet".
        var baslangic = new TaskCompletionSource();
        var istekler = Enumerable.Range(0, 12).Select(async i =>
        {
            await baslangic.Task;
            using var istek = new HttpRequestMessage(HttpMethod.Post, "/api/bildirim/cihaz") { Content = JsonContent.Create(new { token, cihazAdi = $"Telefon {i}" }) };
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", erisim);
            return (await fabrika.CreateClient().SendAsync(istek, Ct)).StatusCode;
        }).ToList();
        baslangic.SetResult();
        var durumlar = await Task.WhenAll(istekler);

        Assert.All(durumlar, d => Assert.Equal(HttpStatusCode.NoContent, d));
        await using var db = uygulama.YeniDb();
        Assert.Equal(1, await db.BildirimCihazlari.CountAsync(c => c.Token == token, Ct));
        lock (toplayici.Satirlar)
            Assert.Empty(toplayici.Satirlar);
    }

    [Fact]
    public async Task ATokenThatComesAgain_IsRefreshedInPlace_NotAddedTwice()
    {
        using var fabrika = uygulama.WithWebHostBuilder(_ => { });
        var yanit = await fabrika.CreateClient().PostAsJsonAsync("/api/hesap/login", new { email = UygulamaFabrikasi.SahipEposta, password = UygulamaFabrikasi.Parola }, Ct);
        using var json = JsonDocument.Parse(await yanit.Content.ReadAsStringAsync(Ct));
        var erisim = json.RootElement.GetProperty("accessToken").GetString()!;
        var token = "fcm-tekrar-" + Guid.NewGuid().ToString("N");

        foreach (var ad in new[] { "Eski ad", "Yeni ad", (string?)null })
        {
            using var istek = new HttpRequestMessage(HttpMethod.Post, "/api/bildirim/cihaz") { Content = JsonContent.Create(new { token, cihazAdi = ad }) };
            istek.Headers.Authorization = new AuthenticationHeaderValue("Bearer", erisim);
            Assert.Equal(HttpStatusCode.NoContent, (await fabrika.CreateClient().SendAsync(istek, Ct)).StatusCode);
        }

        await using var db = uygulama.YeniDb();
        var cihaz = await db.BildirimCihazlari.SingleAsync(c => c.Token == token, Ct);
        Assert.Null(cihaz.CihazAdi);
        Assert.True(cihaz.GuncellemeAni >= cihaz.KayitAni);
    }
}
