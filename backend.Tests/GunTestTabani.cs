using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Tests;

// The ground the day and calendar view tests (K-0024) stand on: the whole app with a fake beyin.py and a clock the test owns
// (Monday 2026-11-09, 07:00 in Istanbul: the brain's day is 2026-11-09, yesterday was a Sunday).
public abstract class GunTestTabani(UygulamaFabrikasi uygulama) : TakvimTestTabani(uygulama), IDisposable
{
    protected static readonly DateTimeOffset Pazartesi = IstAn(2026, 11, 9, 7);
    protected static readonly DateOnly BugunGunu = new(2026, 11, 9);
    protected const string BugunMetni = "2026-11-09";
    protected const string DunMetni = "2026-11-08";

    protected SahteBeyin Beyin { get; } = new("ok");

    public new void Dispose()
    {
        base.Dispose();
        Beyin.Dispose();
    }

    protected WebApplicationFactory<Program> GunFabrikasi(DateTimeOffset? an = null, string? kapasiteSaat = null) =>
        Fabrika(an ?? Pazartesi, google: false, kapasiteSaat: kapasiteSaat,
            ek: b => b.UseSetting("Beyin:Komut", Beyin.Komut).UseSetting("Beyin:Vault", Beyin.Vault));

    // The database is shared by the tests of a class: each starts clean.
    protected async Task GunTemizleAsync()
    {
        await TemizleAsync();
        await using var db = YeniDb();
        await db.HatirlaticiOlaylari.ExecuteDeleteAsync(Ct);
        await db.BirakilanMaddeler.ExecuteDeleteAsync(Ct);
        await db.GunAyarlari.ExecuteDeleteAsync(Ct);
        await db.BeyinIslemleri.ExecuteDeleteAsync(Ct);
    }

    protected async Task<Hatirlatici> HatirlaticiEkleAsync(
        string baslik, DateOnly gun, TimeOnly? saat = null, Tekrar tekrar = Tekrar.Yok, string? maddeId = null, DateOnly? maddeTarihi = null,
        string? gorev = null, Gunler gunler = Gunler.Yok, HatirlaticiDurumu durum = HatirlaticiDurumu.Acik)
    {
        var h = new Hatirlatici
        {
            Baslik = baslik, Gun = gun, Saat = saat, Tekrar = tekrar, MaddeId = maddeId, MaddeTarihi = maddeTarihi, GorevKimligi = gorev,
            Gunler = gunler, Durum = durum,
        };
        h.SonrakiAn = HatirlaticiHesap.Sonraki(tekrar, gun, saat ?? new TimeOnly(9, 0), Pazartesi.ToUniversalTime().AddHours(-1), gunler);
        await using var db = YeniDb();
        db.Hatirlaticilar.Add(h);
        await db.SaveChangesAsync(Ct);
        return h;
    }

    protected async Task<Hatirlatici> HatirlaticiOkuAsync(Guid id)
    {
        await using var db = YeniDb();
        return await db.Hatirlaticilar.AsNoTracking().SingleAsync(h => h.Id == id, Ct);
    }

    // What the fake brain prints. A plan item as `gun goster` shows it.
    protected static string Madde(string id, string baslik, string durum = "acik", int? tahmin = null, string? gorev = null, string? proje = null) =>
        $$"""{"no": 1, "id": "{{id}}", "baslik": "{{baslik}}", "bolum": "Yapılacaklar", "durum": "{{durum}}", "tahmin_dk": {{(tahmin is null ? "null" : tahmin.ToString())}}, "sure_dk": 0, "proje": {{(proje is null ? "null" : $"\"{proje}\"")}}, "gorev": {{(gorev is null ? "null" : $"\"{gorev}\"")}}}""";

    protected static string GunJson(string tarih, string[] maddeler, string geciken = "[]", bool kapandi = false) =>
        $$"""{"tarih": "{{tarih}}", "gun_adi": "x", "hafta_gunu": "y", "bugun": true, "plan_var": true, "kapandi": {{(kapandi ? "true" : "false")}}, "bolumler": [{"ad": "Yapılacaklar", "maddeler": [{{string.Join(", ", maddeler)}}]}], "geciken": {{geciken}}, "toplam": {"madde": {{maddeler.Length}}, "yapildi": 0, "acik": {{maddeler.Length}} } }""";

    protected static string Geciken(string kimlik, string baslik, string bitis, int gun) =>
        $$"""{"kimlik": "{{kimlik}}", "baslik": "{{baslik}}", "bitis": "{{bitis}}", "gun": {{gun}}, "proje": "kitap-kulubu", "oncelik": "orta"}""";

    protected static string IsaretlendiJson(string tarih, string madde, bool gorevKapandi = false) =>
        $$"""{"tarih": "{{tarih}}", "madde": {{madde}}, "gorev_kapandi": {{(gorevKapandi ? "true" : "false")}}}""";

    protected const string GorevListesi =
        """[{"kimlik": "uye-girisi", "baslik": "Üye girişi", "durum": "aktif", "proje": "kitap-kulubu", "yol": "projects/kitap-kulubu/gorevler/uye-girisi.md", "gizli": false, "bitis": "2026-11-12"},""" +
        """ {"kimlik": "rapor", "baslik": "Rapor", "durum": "aktif", "proje": null, "alan": "ogrenme", "yol": "ogrenme/gorevler/rapor.md", "gizli": false, "bitis": null}]""";

    protected int BeyinCagrisi(string komut, string alt) =>
        Beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Count(a => a[0] == komut && a[1] == alt);

    protected static string Anahtar() => "k-" + Guid.NewGuid().ToString("N");

    protected async Task<HttpResponseMessage> AnahtarliGonderAsync(
        HttpMethod yontem, string yol, string? token, WebApplicationFactory<Program> fabrika, object? govde, string? anahtar)
    {
        using var istek = new HttpRequestMessage(yontem, yol);
        if (token is not null)
            istek.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        if (anahtar is not null)
            istek.Headers.Add("Idempotency-Key", anahtar);
        if (govde is not null)
            istek.Content = System.Net.Http.Json.JsonContent.Create(govde);
        return await fabrika.CreateClient().SendAsync(istek, Ct);
    }

    protected async Task IzinKapatAsync(string sahip, string izin, WebApplicationFactory<Program> fabrika)
    {
        var yanit = await GonderAsync(HttpMethod.Put, $"/api/yonetim/izinler/{izin}", sahip, fabrika, new { acik = false });
        Assert.True(yanit.IsSuccessStatusCode, await yanit.Content.ReadAsStringAsync(Ct));
    }
}
