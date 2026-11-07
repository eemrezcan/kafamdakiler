using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Kafamdakiler.Data;
using Kafamdakiler.Yakalamalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Beyin;

// The read side of the brain (K-0023): each handler checks its input, calls beyin.py through BeyinIstemcisi and
// turns the answer into a DTO. `--gizli-dahil` is never passed: hidden notes and projects stay out of every answer.
public static partial class BeyinOkuma
{
    public const int EnUzunSorgu = 200;
    public const int EnCokSonuc = 50;
    public const int VarsayilanSonuc = 10;

    // How a failure of the brain becomes an HTTP status. One table: the brain's own error code (`hata.kod`) decides.
    // `gizli` is a 404 on purpose: a hidden note must look the same as one that does not exist.
    private static readonly Dictionary<string, int> KodDurumlari = new()
    {
        ["gecersiz-arguman"] = StatusCodes.Status400BadRequest,
        ["yasak-yol"] = StatusCodes.Status400BadRequest,
        ["bulunamadi"] = StatusCodes.Status404NotFound,
        ["gizli"] = StatusCodes.Status404NotFound,
    };

    // The status for a result that is not a success. Unknown brain codes, unreadable output: 502; no answer in time: 504.
    public static int DurumKodu(BeyinSonucu sonuc) => sonuc.Durum switch
    {
        BeyinDurumu.BagliDegil => StatusCodes.Status503ServiceUnavailable,
        BeyinDurumu.BeyinHatasi when KodDurumlari.TryGetValue(sonuc.HataKodu ?? "", out var kod) => kod,
        BeyinDurumu.ZamanAsimi => StatusCodes.Status504GatewayTimeout,
        _ => StatusCodes.Status502BadGateway,
    };

    // Fixed texts: the brain's own message can contain paths, so it goes to the log, not to the client.
    private static BeyinYaniti<T> Hata<T>(BeyinSonucu sonuc, ILogger log)
    {
        var durum = DurumKodu(sonuc);
        if (durum >= 500 && sonuc.Durum != BeyinDurumu.BagliDegil)
            log.LogWarning("Brain answered badly ({Durum}, {Kod}): {Mesaj}", sonuc.Durum, sonuc.HataKodu, sonuc.Mesaj);

        var (baslik, ayrinti) = durum switch
        {
            StatusCodes.Status400BadRequest => ("Geçersiz istek", "Beyin isteği kabul etmedi."),
            StatusCodes.Status404NotFound => ("Bulunamadı", "İstenen kayıt bulunamadı."),
            StatusCodes.Status503ServiceUnavailable => ("Beyin bağlı değil", "Bu makinede beyin ayarlı değil ya da komutu bulunamadı."),
            StatusCodes.Status504GatewayTimeout => ("Beyin zamanında cevap vermedi", "Biraz sonra tekrar dene."),
            _ => ("Beyin cevabı anlaşılamadı", "Beyin hata verdi ya da beklenmeyen bir cevap döndü."),
        };
        return new BeyinYaniti<T>(durum, Baslik: baslik, Ayrinti: ayrinti);
    }

    private static async Task<BeyinYaniti<T>> CalistirAsync<T>(
        BeyinIstemcisi beyin, ILogger log, IEnumerable<string> komut, IEnumerable<string>? konumsal,
        Func<JsonElement, T> donustur, CancellationToken ct)
    {
        var sonuc = await beyin.CalistirAsync(komut, ct, konumsal);
        if (!sonuc.Basarili)
            return Hata<T>(sonuc, log);

        try
        {
            return new BeyinYaniti<T>(StatusCodes.Status200OK, donustur(sonuc.Veri!.Value));
        }
        catch (GizliKayit)
        {
            // A record marked hidden that the brain should have left out: it looks like one that does not exist.
            return Hata<T>(new BeyinSonucu(BeyinDurumu.BeyinHatasi, HataKodu: "gizli"), log);
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            return Hata<T>(new BeyinSonucu(BeyinDurumu.BozukCikti, Mesaj: "Beklenmeyen biçim: " + e.Message), log);
        }
    }

    // Raised by a conversion that finds a single record marked hidden (a project or a note asked for by name).
    private sealed class GizliKayit : Exception;

    // Handlers

    public static async Task<IResult> Durum(BeyinIstemcisi beyin, BeyinAyari ayar, AppDbContext db, CancellationToken ct)
    {
        var bekleyen = await db.Yakalamalar.CountAsync(y => y.Durum == YakalamaDurumu.Bekliyor, ct);
        var hatali = await db.Yakalamalar.CountAsync(y => y.Durum == YakalamaDurumu.Bekliyor && y.SonHata != null, ct);
        return Results.Ok(new BeyinDurumDto(beyin.Bagli, VaultAdi(beyin, ayar), bekleyen, hatali));
    }

    // The folder name only: the full path is the server's business.
    internal static string? VaultAdi(BeyinIstemcisi beyin, BeyinAyari ayar) =>
        beyin.Bagli ? Path.GetFileName(Path.TrimEndingDirectorySeparator(ayar.Vault)) : null;

    // The /api handlers: the typed reads below, turned into an HTTP answer.

    public static async Task<IResult> Projeler(BeyinIstemcisi beyin, ILogger log, CancellationToken ct) =>
        (await ProjelerAl(beyin, log, ct)).Sonuc();

    public static async Task<IResult> Proje(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct) =>
        (await ProjeAl(kimlik, beyin, log, ct)).Sonuc();

    public static async Task<IResult> Gun(string tarih, BeyinIstemcisi beyin, ILogger log, CancellationToken ct) =>
        (await GunAl(tarih, beyin, log, ct)).Sonuc();

    public static async Task<IResult> Ara(string? q, string? proje, int? limit, BeyinIstemcisi beyin, ILogger log, CancellationToken ct) =>
        (await AraAl(q, proje, limit, beyin, log, ct)).Sonuc();

    public static async Task<IResult> Not(string? yol, BeyinIstemcisi beyin, ILogger log, CancellationToken ct) =>
        (await NotAl(yol, beyin, log, ct)).Sonuc();

    // The typed reads: the API handlers above and the web pages (Pages/Beyin) both go through these, so the input
    // checks, the error table and the hidden-record locks are the same for both and the web cannot go around them.

    public static Task<BeyinYaniti<List<ProjeOzetDto>>> ProjelerAl(BeyinIstemcisi beyin, ILogger log, CancellationToken ct) =>
        CalistirAsync(beyin, log, ["proje", "liste"], null, ProjeListesi, ct);

    public static Task<BeyinYaniti<ProjeDto>> ProjeAl(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (!KimlikKalibi().IsMatch(kimlik) || kimlik.Length > 100)
            return Task.FromResult(Sorun<ProjeDto>("kimlik", "Proje kimliği küçük harf, rakam ve tire olmalı."));

        return CalistirAsync(beyin, log, ["proje", "goster"], [kimlik], ProjeAyrintisi, ct);
    }

    public static Task<BeyinYaniti<BeyinGunDto>> GunAl(string tarih, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (!DateOnly.TryParseExact(tarih, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun))
            return Task.FromResult(Sorun<BeyinGunDto>("tarih", "Tarih yyyy-MM-dd biçiminde olmalı."));

        return CalistirAsync(beyin, log, ["gun", "goster", $"--tarih={gun:yyyy-MM-dd}"], null, GunAyrintisi, ct);
    }

    public static Task<BeyinYaniti<List<AramaSonucuDto>>> AraAl(string? q, string? proje, int? limit, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var sorgu = q?.Trim();
        if (string.IsNullOrEmpty(sorgu))
            return Task.FromResult(Sorun<List<AramaSonucuDto>>("q", "Arama sorgusu boş olamaz."));
        if (sorgu.Length > EnUzunSorgu)
            return Task.FromResult(Sorun<List<AramaSonucuDto>>("q", $"Arama sorgusu en çok {EnUzunSorgu} karakter olabilir."));
        if (sorgu.Any(char.IsControl))
            return Task.FromResult(Sorun<List<AramaSonucuDto>>("q", "Arama sorgusunda denetim karakteri olamaz."));
        if (proje is not null && (!KimlikKalibi().IsMatch(proje) || proje.Length > 100))
            return Task.FromResult(Sorun<List<AramaSonucuDto>>("proje", "Proje kimliği küçük harf, rakam ve tire olmalı."));
        if (limit is < 1 or > EnCokSonuc)
            return Task.FromResult(Sorun<List<AramaSonucuDto>>("limit", $"Sonuç sayısı 1 ile {EnCokSonuc} arasında olmalı."));

        var komut = new List<string> { "ara", $"--limit={limit ?? VarsayilanSonuc}" };
        if (proje is not null)
            komut.Add($"--proje={proje}");

        return CalistirAsync(beyin, log, komut, [sorgu], AramaSonuclari, ct);
    }

    public static Task<BeyinYaniti<NotDto>> NotAl(string? yol, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (!NotYolu.Gecerli(yol))
            return Task.FromResult(Sorun<NotDto>("yol", "Yol vault'a göreli, .md ile biten ve izinli bir not yolu olmalı."));

        return CalistirAsync(beyin, log, ["not", "oku"], [yol!], NotAyrintisi, ct);
    }

    private static BeyinYaniti<T> Sorun<T>(string alan, string mesaj) =>
        new(StatusCodes.Status400BadRequest, Alanlar: new Dictionary<string, string[]> { [alan] = [mesaj] });

    // Conversions: beyin.py's JSON -> our DTOs. A missing required field is an InvalidDataException (a 502).

    private static List<ProjeOzetDto> ProjeListesi(JsonElement veri) =>
        Dizi(veri).Where(Gorunur).Where(AcikYol).Select(p => new ProjeOzetDto(Gerekli(p, "kimlik"), Gerekli(p, "baslik"))).ToList();

    private static ProjeDto ProjeAyrintisi(JsonElement p)
    {
        if (!Gorunur(p) || !AcikYol(p))
            throw new GizliKayit();

        return new ProjeDto(
            Gerekli(p, "kimlik"), Gerekli(p, "baslik"), Metin(p, "durum"), Metin(p, "siradaki_adim"),
            DiziAlani(p, "acik_gorevler").Where(Gorunur).Where(AcikYol).Select(g => new ProjeGorevDto(
                Gerekli(g, "kimlik"), Gerekli(g, "baslik"), Metin(g, "durum"), Tarih(g, "bitis"), Metin(g, "oncelik"), Metin(g, "sonraki_adim"))).ToList(),
            DiziAlani(p, "son_gunluk").Select(s => new GunlukSatiriDto(Metin(s, "zaman"), Metin(s, "baslik"), Metin(s, "metin"))).ToList());
    }

    private static BeyinGunDto GunAyrintisi(JsonElement g) => new(
        Tarih(g, "tarih") ?? throw new InvalidDataException("tarih yok"), Metin(g, "gun_adi"), Metin(g, "hafta_gunu"),
        Bool(g, "bugun"), Bool(g, "plan_var"), Bool(g, "kapandi"),
        DiziAlani(g, "bolumler").Select(b => new BeyinGunBolumuDto(
            Gerekli(b, "ad"),
            DiziAlani(b, "maddeler").Where(Gorunur).Select(m => new BeyinGunMaddesiDto(
                Gerekli(m, "id"), Gerekli(m, "baslik"), Metin(m, "durum"), Sayi(m, "tahmin_dk"), Sayi(m, "sure_dk"),
                Metin(m, "proje"), Metin(m, "gorev"))).ToList())).ToList(),
        DiziAlani(g, "geciken").Where(Gorunur).Where(AcikYol).Select(x => new GecikenGorevDto(
            Gerekli(x, "kimlik"), Gerekli(x, "baslik"), Tarih(x, "bitis"), Sayi(x, "gun"), Metin(x, "proje"), Metin(x, "oncelik"))).ToList(),
        g.TryGetProperty("toplam", out var t) && t.ValueKind == JsonValueKind.Object
            ? new BeyinGunToplamiDto(Sayi(t, "madde") ?? 0, Sayi(t, "yapildi") ?? 0, Sayi(t, "acik") ?? 0)
            : null);

    private static List<AramaSonucuDto> AramaSonuclari(JsonElement veri) =>
        Dizi(veri).Where(Gorunur).Where(AcikYol).Select(s => new AramaSonucuDto(
            Gerekli(s, "yol"), Metin(s, "baslik") ?? Gerekli(s, "yol"), Metin(s, "proje"), Metin(s, "alan"), DuzMetin.Temizle(Metin(s, "alinti")))).ToList();

    private static NotDto NotAyrintisi(JsonElement n)
    {
        var ust = n.TryGetProperty("ustbilgi", out var u) && u.ValueKind == JsonValueKind.Object ? u : default;
        if (ust.ValueKind == JsonValueKind.Object && !Gorunur(ust))
            throw new GizliKayit();

        var yol = Gerekli(n, "yol");
        return new NotDto(
            yol, Metin(n, "baslik") ?? yol,
            ust.ValueKind == JsonValueKind.Object ? DiziAlani(ust, "tags").Where(e => e.ValueKind == JsonValueKind.String).Select(e => e.GetString()!).ToList() : [],
            Metin(n, "govde") ?? "");
    }

    // Fail closed: a record is shown only when it says it is not hidden or says nothing about it.
    // (`gizli` present and anything but false hides it; the brain already leaves hidden ones out.)
    private static bool Gorunur(JsonElement kayit) =>
        !kayit.TryGetProperty("gizli", out var g) || g.ValueKind == JsonValueKind.False || g.ValueKind == JsonValueKind.Null;

    // Whatever lives in `finans/` or `kisisel/` never leaves through this API, wherever it shows up (a search hit,
    // a project's task, an overdue task). A record that names no path is left alone: the day plan has none.
    private static bool AcikYol(JsonElement kayit) => !NotYolu.Kapali(Metin(kayit, "yol"));

    private static IEnumerable<JsonElement> Dizi(JsonElement e) =>
        e.ValueKind == JsonValueKind.Array ? e.EnumerateArray() : throw new InvalidDataException("liste bekleniyordu");

    private static IEnumerable<JsonElement> DiziAlani(JsonElement e, string ad) =>
        e.TryGetProperty(ad, out var d) && d.ValueKind == JsonValueKind.Array ? d.EnumerateArray() : [];

    private static string? Metin(JsonElement e, string ad) =>
        e.TryGetProperty(ad, out var d) && d.ValueKind == JsonValueKind.String ? d.GetString() : null;

    private static string Gerekli(JsonElement e, string ad) =>
        Metin(e, ad) is { Length: > 0 } m ? m : throw new InvalidDataException($"'{ad}' alanı yok");

    private static int? Sayi(JsonElement e, string ad) =>
        e.TryGetProperty(ad, out var d) && d.ValueKind == JsonValueKind.Number && d.TryGetInt32(out var n) ? n : null;

    private static bool Bool(JsonElement e, string ad) => e.TryGetProperty(ad, out var d) && d.ValueKind == JsonValueKind.True;

    private static DateOnly? Tarih(JsonElement e, string ad) =>
        DateOnly.TryParseExact(Metin(e, ad), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var t) ? t : null;

    [GeneratedRegex(@"^[a-z0-9]+(-[a-z0-9]+)*\z", RegexOptions.CultureInvariant)]
    private static partial Regex KimlikKalibi();
}

// The note path the API accepts (the brain checks again, this is the first lock): relative, ends in .md, no ".."
// and no dot-folders such as .beyin, and not in the closed folders (finance and personal notes stay in the brain).
public static partial class NotYolu
{
    public const int EnUzun = 300;

    // \z, not $: in .NET `$` also matches before a final newline.
    [GeneratedRegex(@"^[\p{L}\p{N}][\p{L}\p{N} _-]*(/[\p{L}\p{N}][\p{L}\p{N} _-]*)*\.md\z", RegexOptions.CultureInvariant)]
    private static partial Regex Kalip();

    private static readonly string[] KapaliKlasorler = ["finans/", "kisisel/"];

    public static bool Kapali(string? yol) =>
        yol is not null && KapaliKlasorler.Any(k => yol.StartsWith(k, StringComparison.OrdinalIgnoreCase));

    public static bool Gecerli(string? yol) =>
        yol is { Length: > 0 and <= EnUzun } && Kalip().IsMatch(yol) && !Kapali(yol);
}
