using System.Net;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.KeyManagement;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Kafamdakiler.Tests;

// Production settings (K2.1): VeriKoruma:Klasor (persistent Data Protection keys) and Vekil:GuvenilenAglar
// (trusting X-Forwarded-* from the reverse proxy). Both off by default.
public class UretimAyarlariTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private const string Vekilden = "X-Test-Uzak-Ip";
    private CancellationToken Ct => TestContext.Current.CancellationToken;

    // Fakes the TCP peer (a test server has none) and answers GET /test-baglanti after the whole app pipeline,
    // so it reports what the app sees once the forwarded headers middleware (if any) has run.
    private sealed class BaglantiFiltresi : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
        {
            app.Use((context, sonraki) =>
            {
                if (context.Request.Headers.TryGetValue(Vekilden, out var ip))
                    context.Connection.RemoteIpAddress = IPAddress.Parse(ip.ToString());
                return sonraki();
            });
            next(app);
            app.Run(context => context.Response.WriteAsync(
                $"{context.Request.IsHttps}|{context.Connection.RemoteIpAddress}"));
        };
    }

    private WebApplicationFactory<Program> Ozel(params (string Anahtar, string Deger)[] ayarlar) =>
        uygulama.WithWebHostBuilder(b =>
        {
            foreach (var (anahtar, deger) in ayarlar)
                b.UseSetting(anahtar, deger);
            b.ConfigureServices(s => s.AddSingleton<IStartupFilter, BaglantiFiltresi>());
        });

    private async Task<string> BaglantiAsync(WebApplicationFactory<Program> fabrika, string uzakIp, string? xff = null)
    {
        using var istek = new HttpRequestMessage(HttpMethod.Get, "/test-baglanti");
        istek.Headers.Add(Vekilden, uzakIp);
        istek.Headers.Add("X-Forwarded-Proto", "https");
        if (xff is not null)
            istek.Headers.Add("X-Forwarded-For", xff);
        var yanit = await fabrika.CreateClient().SendAsync(istek, Ct);
        return await yanit.Content.ReadAsStringAsync(Ct);
    }

    [Fact]
    public async Task Ayarlar_bosken_yonlendirilen_basliklar_yok_sayilir_ve_anahtar_klasoru_yazilmaz()
    {
        using var ozel = Ozel();

        // No middleware: even a request from a private network cannot make itself HTTPS.
        Assert.Equal("False|172.18.0.2", await BaglantiAsync(ozel, "172.18.0.2", "203.0.113.5"));
        // Data Protection stays on the framework default: no file repository configured.
        Assert.Null(ozel.Services.GetRequiredService<IOptions<KeyManagementOptions>>().Value.XmlRepository);
    }

    [Fact]
    public async Task Bos_veya_bosluk_degerler_ayar_sayilmaz()
    {
        using var ozel = Ozel(("VeriKoruma:Klasor", "  "), ("Vekil:GuvenilenAglar:0", " "));

        Assert.Equal("False|172.18.0.2", await BaglantiAsync(ozel, "172.18.0.2"));
        Assert.Null(ozel.Services.GetRequiredService<IOptions<KeyManagementOptions>>().Value.XmlRepository);
    }

    [Fact]
    public void Klasor_verilince_anahtar_dosyasi_olusur()
    {
        // A folder that does not exist yet: the app creates it.
        var klasor = Path.Combine(Path.GetTempPath(), "kd-anahtar-" + Guid.NewGuid().ToString("N"), "ic");
        try
        {
            using var ozel = Ozel(("VeriKoruma:Klasor", klasor));

            var koruyucu = ozel.Services.GetRequiredService<IDataProtectionProvider>().CreateProtector("test");
            Assert.Equal("gizli", koruyucu.Unprotect(koruyucu.Protect("gizli")));

            Assert.Contains(Directory.GetFiles(klasor), dosya =>
                Path.GetFileName(dosya).StartsWith("key-", StringComparison.Ordinal) && dosya.EndsWith(".xml", StringComparison.Ordinal));
        }
        finally
        {
            var kok = Path.GetDirectoryName(klasor)!;
            if (Directory.Exists(kok))
                Directory.Delete(kok, recursive: true);
        }
    }

    [Fact]
    public void Ayni_klasorle_yeniden_acilan_uygulama_eski_veriyi_cozer()
    {
        var klasor = Path.Combine(Path.GetTempPath(), "kd-anahtar-" + Guid.NewGuid().ToString("N"));
        try
        {
            string korunmus;
            using (var birinci = Ozel(("VeriKoruma:Klasor", klasor)))
                korunmus = birinci.Services.GetRequiredService<IDataProtectionProvider>().CreateProtector("test").Protect("gizli");

            using var ikinci = Ozel(("VeriKoruma:Klasor", klasor));
            Assert.Equal("gizli", ikinci.Services.GetRequiredService<IDataProtectionProvider>().CreateProtector("test").Unprotect(korunmus));
        }
        finally
        {
            if (Directory.Exists(klasor))
                Directory.Delete(klasor, recursive: true);
        }
    }

    [Fact]
    public async Task Guvenilen_agdan_gelen_istek_https_sayilir_ve_istemci_ip_si_gorunur()
    {
        using var ozel = Ozel(("Vekil:GuvenilenAglar:0", "172.16.0.0/12"));

        Assert.Equal("True|203.0.113.5", await BaglantiAsync(ozel, "172.18.0.2", "203.0.113.5"));
    }

    [Fact]
    public async Task Guvenilmeyen_adresten_gelen_baslik_yok_sayilir()
    {
        using var ozel = Ozel(("Vekil:GuvenilenAglar:0", "172.16.0.0/12"));

        Assert.Equal("False|10.1.1.1", await BaglantiAsync(ozel, "10.1.1.1", "203.0.113.5"));
    }

    [Fact]
    public async Task Varsayilan_loopback_guveni_kaldirilir()
    {
        // Only the configured networks are trusted, not the framework's default loopback.
        using var ozel = Ozel(("Vekil:GuvenilenAglar:0", "172.16.0.0/12"));

        Assert.Equal("False|127.0.0.1", await BaglantiAsync(ozel, "127.0.0.1"));
    }

    [Theory]
    [InlineData("172.16.0.0")]
    [InlineData("172.16.0.0/40")]
    [InlineData("bu-bir-ag-degil")]
    public void Gecersiz_cidr_acilisi_durdurur(string deger)
    {
        using var ozel = Ozel(("Vekil:GuvenilenAglar:0", "10.0.0.0/8"), ("Vekil:GuvenilenAglar:1", deger));

        var hata = Assert.ThrowsAny<Exception>(() => ozel.Services);

        for (var e = hata; e is not null; e = e.InnerException)
            if (e.Message.Contains("Vekil:GuvenilenAglar") && e.Message.Contains(deger))
                return;
        Assert.Fail("No exception in the chain names the setting and the bad value: " + hata);
    }
}
