using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Gelen;

// The inbox reads and the hand-made writes. The API handlers go through here, so the checks sit in one place
// (and a page of the web can use the same methods). A hidden card is never reachable: every card is looked up in
// `gelen liste`, which leaves hidden ones out, before anything is done to it.
public static class GelenIslemleri
{
    // The suggestions waiting in the queue, by card name. Newest wins when a card has more than one.
    public static async Task<Dictionary<string, Eylem>> BekleyenOnerilerAsync(AppDbContext db, CancellationToken ct)
    {
        var bekleyenler = await db.Eylemler.AsNoTracking()
            .Where(e => e.Tur == YerlestirTuru.Anahtar && e.Durum == EylemDurumu.Bekliyor)
            .OrderBy(e => e.CreatedAt).ToListAsync(ct);

        var sonuc = new Dictionary<string, Eylem>(StringComparer.Ordinal);
        foreach (var eylem in bekleyenler)
        {
            using var belge = JsonDocument.Parse(eylem.Yuk);
            if (BeyinOkuma.Metin(belge.RootElement, "kart") is { Length: > 0 } kart)
                sonuc[kart] = eylem;
        }

        return sonuc;
    }

    public static async Task<BeyinYaniti<List<GelenKartDto>>> ListeAl(BeyinIstemcisi beyin, AppDbContext db, ILogger log, CancellationToken ct)
    {
        var kartlar = await GelenBeyin.KartlariAlAsync(beyin, log, ct);
        if (!kartlar.Basarili)
            return new BeyinYaniti<List<GelenKartDto>>(kartlar.Durum, Baslik: kartlar.Baslik, Ayrinti: kartlar.Ayrinti, Alanlar: kartlar.Alanlar);

        var bekleyenler = await BekleyenOnerilerAsync(db, ct);
        var satirlar = await db.GelenKartlari.AsNoTracking().ToDictionaryAsync(r => r.Kart, ct);

        var liste = kartlar.Veri!.Select(k =>
        {
            var satir = satirlar.GetValueOrDefault(k.Kimlik);
            return new GelenKartDto(
                k.Kimlik, k.Baslik, k.GorselVar, k.Hedef, k.Yakalandi,
                satir?.LaptoptaIslenecek ?? false, satir?.LaptoptaIslenecek == true ? satir.LaptopNotu : null,
                bekleyenler.TryGetValue(k.Kimlik, out var eylem) ? OneriDto(eylem) : null);
        }).ToList();
        return new BeyinYaniti<List<GelenKartDto>>(StatusCodes.Status200OK, liste);
    }

    private static GelenOneriDto OneriDto(Eylem e)
    {
        using var belge = JsonDocument.Parse(e.Yuk);
        var yuk = belge.RootElement;
        return new GelenOneriDto(
            e.Id, BeyinOkuma.Metin(yuk, "yol") ?? "", BeyinOkuma.Metin(yuk, "baslik") ?? "",
            BeyinOkuma.DiziAlani(yuk, "etiketler").Where(x => x.ValueKind == JsonValueKind.String).Select(x => x.GetString()!).ToList(),
            e.Gerekce, e.Guven, e.DisKaynak, YukuOku(yuk)?.YeniEtiket);
    }

    private static readonly JsonSerializerOptions YukAyari = new(JsonSerializerDefaults.Web);

    private static YerlestirYuku? YukuOku(JsonElement yuk)
    {
        try
        {
            return yuk.Deserialize<YerlestirYuku>(YukAyari);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    // The payload of a waiting suggestion without its new tag: the card is placed with the existing tags alone. Null when the
    // suggestion has no new tag or no other tag would be left (the person then picks tags by hand).
    public static JsonElement? YeniEtiketsizYuk(Eylem eylem)
    {
        using var belge = JsonDocument.Parse(eylem.Yuk);
        if (YukuOku(belge.RootElement) is not { YeniEtiket: { } yeni } yuk)
            return null;

        var kalan = yuk.Etiketler.Where(e => e != yeni.Ad).ToList();
        return kalan.Count == 0 ? null : JsonSerializer.SerializeToElement(yuk with { Etiketler = kalan, YeniEtiket = null }, YukAyari);
    }

    public static async Task<BeyinYaniti<List<GelenEtiketDto>>> EtiketleriAl(BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var sozluk = await GelenBeyin.SozluguAlAsync(beyin, log, ct);
        return sozluk.Basarili
            ? new BeyinYaniti<List<GelenEtiketDto>>(StatusCodes.Status200OK,
                sozluk.Veri!.AnaAdlar.Select(a => new GelenEtiketDto(a, [.. sozluk.Veri.Esler[a]])).ToList())
            : new BeyinYaniti<List<GelenEtiketDto>>(sozluk.Durum, Baslik: sozluk.Baslik, Ayrinti: sozluk.Ayrinti, Alanlar: sozluk.Alanlar);
    }

    public static async Task<BeyinYaniti<List<GelenKlasorDto>>> KlasorleriAl(BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var projeler = await BeyinOkuma.ProjelerAl(beyin, log, ct);
        if (!projeler.Basarili)
            return new BeyinYaniti<List<GelenKlasorDto>>(projeler.Durum, Baslik: projeler.Baslik, Ayrinti: projeler.Ayrinti, Alanlar: projeler.Alanlar);

        var liste = projeler.Veri!.OrderBy(p => p.Kimlik, StringComparer.Ordinal)
            .Select(p => new GelenKlasorDto($"projects/{p.Kimlik}/notlar/", p.Baslik, "proje", p.Kimlik)).ToList();
        liste.AddRange(GelenYolu.AcikKokler.Select(k => new GelenKlasorDto($"{k}/", k, "kok", null)));
        return new BeyinYaniti<List<GelenKlasorDto>>(StatusCodes.Status200OK, liste);
    }

    // A placement the user types: same shape checks as a suggestion, then the project and the tags against the brain.
    public static async Task<YazmaYaniti> Isle(string kimlik, GelenIsleGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (!GelenBeyin.KartKimligiGecerli(kimlik))
            return YazmaYaniti.Sorun("kart", "Kart adı geçerli değil.");

        var sekil = YerlestirTuru.Denetle(new YerlestirYuku(kimlik, girdi.Yol ?? "", girdi.Baslik ?? "", girdi.Etiketler ?? [], girdi.Tur), out var yuk);
        if (!sekil.Basarili)
            return YazmaYaniti.Sorun(sekil.Alan ?? "yuk", sekil.Mesaj!);

        var (_, bulunamadi) = await KartBulAsync(kimlik, beyin, log, ct);
        if (bulunamadi is not null)
            return bulunamadi;

        var projeler = await GelenBeyin.ProjeleriAlAsync(beyin, log, ct);
        if (!projeler.Basarili)
            return OkumaHatasi(projeler.Durum, projeler.Baslik, projeler.Ayrinti);
        var sozluk = await GelenBeyin.SozluguAlAsync(beyin, log, ct);
        if (!sozluk.Basarili)
            return OkumaHatasi(sozluk.Durum, sozluk.Baslik, sozluk.Ayrinti);

        var beyinKurali = YerlestirTuru.BeyinleDenetle(yuk!, projeler.Veri!, sozluk.Veri!);
        if (!beyinKurali.Basarili)
            return YazmaYaniti.Sorun(beyinKurali.Alan ?? "yuk", beyinKurali.Mesaj!);

        // The tags go to the brain as the dictionary knows them.
        yuk = yuk! with { Etiketler = yuk.Etiketler.Select(e => sozluk.Veri!.Coz(e)!).ToList() };
        var sonuc = await beyin.CalistirAsync(YerlestirTuru.Komut(yuk), ct, YerlestirTuru.Konumsal(yuk));
        if (!sonuc.Basarili)
            return BeyinYazma.Esle(sonuc, log);

        return YazmaYaniti.Tamam(new GelenIslendiDto(BeyinOkuma.Metin(sonuc.Veri!.Value, "yol") ?? yuk.Yol, kimlik));
    }

    // Deleting a card (and its image). The API leaves this to the Sahip.
    public static async Task<YazmaYaniti> Sil(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (!GelenBeyin.KartKimligiGecerli(kimlik))
            return YazmaYaniti.Sorun("kart", "Kart adı geçerli değil.");

        var (_, bulunamadi) = await KartBulAsync(kimlik, beyin, log, ct);
        if (bulunamadi is not null)
            return bulunamadi;

        var sonuc = await beyin.CalistirAsync(["gelen", "sil", "--onay"], ct, [GelenBeyin.KartYolu(kimlik)]);
        return sonuc.Basarili ? YazmaYaniti.Tamam(new GelenSilindiDto(kimlik)) : BeyinYazma.Esle(sonuc, log);
    }

    // The card, if the visible list has it. A hidden card, or one that is not there, is a plain 404.
    private static async Task<(BeyinKarti?, YazmaYaniti?)> KartBulAsync(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var kartlar = await GelenBeyin.KartlariAlAsync(beyin, log, ct);
        if (!kartlar.Basarili)
            return (null, OkumaHatasi(kartlar.Durum, kartlar.Baslik, kartlar.Ayrinti));

        return kartlar.Veri!.FirstOrDefault(k => k.Kimlik == kimlik) is { } kart
            ? (kart, null)
            : (null, YazmaYaniti.Red(StatusCodes.Status404NotFound, "Bulunamadı", "İstenen kart bulunamadı. Hiçbir şey yazılmadı."));
    }

    // A read that fails on the way to a write: nothing was written, so it is a plain refusal.
    private static YazmaYaniti OkumaHatasi(int durum, string? baslik, string? ayrinti) =>
        YazmaYaniti.Red(durum, baslik ?? "Beyin cevabı anlaşılamadı", ayrinti ?? "Beyin hata verdi ya da beklenmeyen bir cevap döndü. Hiçbir şey yazılmadı.");
}
