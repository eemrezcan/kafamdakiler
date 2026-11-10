using System.Net;
using Kafamdakiler.Dosyalar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Kafamdakiler.Tests;

// The ground the assistant tests stand on (K-0024, §7): the whole app with a fake claude, a fake beyin.py, a fake Google and a clock the test owns
// (Monday 2026-11-09, 07:00 in Istanbul: today is the 9th, tomorrow the 10th).
public abstract class AsistanTestTabani(UygulamaFabrikasi uygulama) : GunTestTabani(uygulama), IDisposable
{
    protected const string Yarin = "2026-11-10";

    protected const string Projeler = """[{"kimlik": "kitap-kulubu", "yol": "projects/kitap-kulubu/index.md", "baslik": "Kitap Kulübü Sitesi", "gizli": false}]""";

    protected const string AsistanMaddesi = """{"no": 4, "id": "a3f09c", "baslik": "Raporu bitir", "bolum": "Yapılacaklar", "durum": "acik", "tahmin_dk": 30, "sure_dk": 0}""";

    protected SahteClaude AsistanClaude { get; } = new();

    public new void Dispose()
    {
        base.Dispose();
        AsistanClaude.Dispose();
    }

    protected WebApplicationFactory<Program> AsistanFabrikasi(bool claude = true, bool beyin = true, bool google = true, int? claudeSinir = null, DateTimeOffset? an = null) =>
        Fabrika(an ?? Pazartesi, google: google, ek: b =>
        {
            if (beyin)
                b.UseSetting("Beyin:Komut", Beyin.Komut).UseSetting("Beyin:Vault", Beyin.Vault);
            if (claude)
                b.UseSetting("Claude:Komut", AsistanClaude.Komut);
            if (claudeSinir is { } sinir)
                b.UseSetting("Claude:ModelSiniri:sonnet", sinir.ToString());
        });

    // Clean tables, the brain's answers the tests rely on, the app signed in as the Sahip (and Google connected when it is on).
    protected async Task<(WebApplicationFactory<Program> Fabrika, string Sahip)> HazirlaAsync(bool claude = true, bool beyin = true, bool google = true, int? claudeSinir = null)
    {
        await GunTemizleAsync();
        await using (var db = YeniDb())
        {
            await db.AsistanMesajlari.ExecuteDeleteAsync(Ct);
            await db.Bildirimler.ExecuteDeleteAsync(Ct);
            await db.Yakalamalar.ExecuteDeleteAsync(Ct);
            await db.EylemIzinleri.ExecuteDeleteAsync(Ct);
            // The permissions granted to the Asistan by a test before this one.
            await db.UserClaims.Where(c => c.ClaimType == "izin").ExecuteDeleteAsync(Ct);
        }

        Beyin.Cikti("proje liste", Projeler);
        Beyin.Cikti("gun ekle", $$"""{"tarih": "{{BugunMetni}}", "madde": {{AsistanMaddesi}}, "tahmin_onerisi": null}""");
        Beyin.Cikti("gorev ekle", """{"yol": "projects/kitap-kulubu/gorevler/yeni.md", "kimlik": "yeni"}""");
        Beyin.Cikti("is ekle", SahteIsKarti.Kart("takvim-sayfasi", asama: "talep", sahip: "vps", tip: "kod"));
        Beyin.Cikti("is liste", SahteIsKarti.Liste());
        var fabrika = AsistanFabrikasi(claude, beyin, google, claudeSinir);
        if (google)
            await BaglaAsync(fabrika);
        return (fabrika, await GirisAsync(UygulamaFabrikasi.SahipEposta, fabrika));
    }

    // What the fake claude answers (the checked part): suggestions, and optionally the one question.
    protected static string Oneri(
        string tur, string baslik, string? gun = null, string? saat = null, string? proje = null, string? alan = null, double guven = 0.9,
        string? kaynakParca = null, string? tip = null, int? tahmin = null, string? bitis = null, string? tekrar = null)
    {
        var alanlar = new List<string> { $"\"tur\":\"{tur}\"", $"\"baslik\":{System.Text.Json.JsonSerializer.Serialize(baslik)}", $"\"kaynakParca\":{System.Text.Json.JsonSerializer.Serialize(kaynakParca ?? baslik)}", $"\"guven\":{guven.ToString(System.Globalization.CultureInfo.InvariantCulture)}" };
        void Ekle(string ad, string? deger) { if (deger is not null) alanlar.Add($"\"{ad}\":{System.Text.Json.JsonSerializer.Serialize(deger)}"); }
        Ekle("gun", gun); Ekle("saat", saat); Ekle("proje", proje); Ekle("alan", alan); Ekle("tip", tip); Ekle("bitis", bitis); Ekle("tekrar", tekrar);
        if (tahmin is { } t)
            alanlar.Add($"\"tahminDk\":{t}");
        return "{" + string.Join(",", alanlar) + "}";
    }

    protected static string Cevap(params string[] oneriler) => "{\"oneriler\":[" + string.Join(",", oneriler) + "]}";

    protected static string SoruluCevap(string soru, params string[] secenekler) =>
        "{\"oneriler\":[],\"soru\":{\"metin\":" + System.Text.Json.JsonSerializer.Serialize(soru) + ",\"secenekler\":" + System.Text.Json.JsonSerializer.Serialize(secenekler) + "}}";

    protected async Task<HttpResponseMessage> GirdiGonderAsync(
        WebApplicationFactory<Program> fabrika, string? token, Guid id, string? metin, string kaynak = "yazi", Guid? fotografId = null, string? bugun = null) =>
        await GonderAsync(HttpMethod.Post, "/api/asistan/girdi", token, fabrika, new { id, metin, kaynak, fotografId, bugun });

    protected async Task<System.Text.Json.JsonElement> GirdiAsync(WebApplicationFactory<Program> fabrika, string token, Guid id, string? metin, string kaynak = "yazi", Guid? fotografId = null)
    {
        var yanit = await GirdiGonderAsync(fabrika, token, id, metin, kaynak, fotografId);
        Assert.True(yanit.StatusCode == HttpStatusCode.OK, await yanit.Content.ReadAsStringAsync(Ct));
        return await OkuAsync(yanit);
    }

    protected async Task<Guid> FotografEkleAsync()
    {
        await using var db = YeniDb();
        var dosya = new Dosya { DiskAdi = Guid.NewGuid().ToString("N") + ".jpg", IcerikTuru = "image/jpeg", Boyut = 3, YuklenmeAni = DateTimeOffset.UtcNow };
        db.Dosyalar.Add(dosya);
        await db.SaveChangesAsync(Ct);

        // The bytes too: taking a note back deletes the file along with the row.
        using var kapsam = Uygulama.Services.CreateScope();
        var yol = kapsam.ServiceProvider.GetRequiredService<DosyaDeposu>().YolBul(dosya);
        Directory.CreateDirectory(Path.GetDirectoryName(yol)!);
        await File.WriteAllBytesAsync(yol, [0xFF, 0xD8, 0xFF], Ct);
        return dosya.Id;
    }

    // The calls the fake claude got, and what each was told: the fixed instruction (--system-prompt) and the data (stdin).
    protected List<(string Talimat, string Veri, string[] Arguman)> ClaudeCagrilari() =>
        AsistanClaude.Cagrilar().Select(c =>
        {
            var a = SahteClaude.Argumanlar(c);
            return (a[Array.IndexOf(a, "--system-prompt") + 1], c.GetProperty("stdin").GetString()!, a);
        }).ToList();
}
