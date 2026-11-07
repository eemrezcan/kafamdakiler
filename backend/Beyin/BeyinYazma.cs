using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Kafamdakiler.Beyin;

public enum YazmaTuru
{
    // Written: 200.
    Tamam,
    // A run of several writes stopped half way: 207, what was written is in the answer.
    Kismi,
    // The brain did not answer in time or answered badly: the write may have happened. 202.
    Belirsiz,
    // Nothing was written (bad input, the brain refused, not connected). The same request may be tried again.
    Reddedildi,
}

// The outcome of a write before it becomes an HTTP answer. A written, partial or uncertain outcome has a JSON body (`Veri`)
// that the repeat guard keeps; a refusal is a ProblemDetails and is never kept.
public sealed record YazmaYaniti(
    int Durum, YazmaTuru Tur, object? Veri = null, string? Baslik = null, string? Ayrinti = null, Dictionary<string, string[]>? Alanlar = null)
{
    public bool Basarili => Tur == YazmaTuru.Tamam;

    // The three outcomes that must be remembered under an Idempotency-Key.
    public bool Hatirlanir => Tur != YazmaTuru.Reddedildi;

    public static YazmaYaniti Tamam(object veri) => new(StatusCodes.Status200OK, YazmaTuru.Tamam, veri);

    public static YazmaYaniti Kismi(object veri) => new(StatusCodes.Status207MultiStatus, YazmaTuru.Kismi, veri);

    public static YazmaYaniti Belirsiz(string ayrinti) => new(
        StatusCodes.Status202Accepted, YazmaTuru.Belirsiz,
        new BelirsizYazmaDto(true, true, "Sonuç belli değil", ayrinti));

    public static YazmaYaniti Red(int durum, string baslik, string ayrinti) =>
        new(durum, YazmaTuru.Reddedildi, Baslik: baslik, Ayrinti: ayrinti);

    public static YazmaYaniti Sorun(string alan, string mesaj) =>
        new(StatusCodes.Status400BadRequest, YazmaTuru.Reddedildi, Alanlar: new Dictionary<string, string[]> { [alan] = [mesaj] });

    public string Json() => JsonSerializer.Serialize(Veri, BeyinYazma.JsonSecenekleri);

    public IResult Sonuc() =>
        Hatirlanir ? new JsonCevabi(Durum, Json())
        : Alanlar is not null ? Results.ValidationProblem(Alanlar)
        : Results.Problem(title: Baslik, detail: Ayrinti, statusCode: Durum);
}

// A JSON answer that is already text: the first answer and a repeated one are the same bytes.
public sealed class JsonCevabi(int durum, string json, bool tekrar = false) : IResult
{
    public const string TekrarBasligi = "Idempotent-Replayed";

    public Task ExecuteAsync(HttpContext baglam)
    {
        baglam.Response.StatusCode = durum;
        baglam.Response.ContentType = "application/json; charset=utf-8";
        if (tekrar)
            baglam.Response.Headers[TekrarBasligi] = "true";
        return baglam.Response.WriteAsync(json, baglam.RequestAborted);
    }
}

// The write side of the brain (K2.3a): plan items and tasks. Each method checks its input, calls beyin.py through
// BeyinIstemcisi and turns the answer into a YazmaYaniti. The date always goes to the command as `--tarih=` (the brain's
// own "today" is never relied on), the plan item's id and any free text go after `--`, and a value that starts with a dash
// is never read as an option. The web pages and the API both go through here.
public static partial class BeyinYazma
{
    public const int EnUzunMetin = 300;
    public const int EnUzunBolum = 60;
    public const int EnUzunNot = 500;
    public const int EnUzunBaslik = 200;
    public const int EnUzunAyrinti = 300;
    public const int EnCokBolmeGunu = 14;

    internal static readonly JsonSerializerOptions JsonSecenekleri = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    // How a refusal of the brain becomes an HTTP status. The brain's own code decides; the generic `hata` is a refusal of
    // the request ("not found" in the message is a 404, anything else a 409). Nothing was written in any of these.
    private static readonly Dictionary<string, int> KodDurumlari = new()
    {
        ["gecersiz-arguman"] = StatusCodes.Status400BadRequest,
        ["yasak-yol"] = StatusCodes.Status400BadRequest,
        ["bulunamadi"] = StatusCodes.Status404NotFound,
        ["gizli"] = StatusCodes.Status404NotFound,
        ["gun-kapali"] = StatusCodes.Status409Conflict,
    };

    // `hata` is not a bare success: it carries the brain's own message, which may hold paths, so it goes to the log only.
    public static YazmaYaniti Esle(BeyinSonucu sonuc, ILogger log)
    {
        log.LogWarning("Brain write did not succeed ({Durum}, {Kod}): {Mesaj}", sonuc.Durum, sonuc.HataKodu, sonuc.Mesaj);

        // The command may have written before it timed out or printed something we cannot read: never call it a failure.
        if (!sonuc.GuvenleTekrarlanir)
            return YazmaYaniti.Belirsiz("Beyin zamanında ya da anlaşılır cevap vermedi; yazılmış olabilir. Tekrar denemeden önce günün planına bak.");

        if (sonuc.Durum == BeyinDurumu.BagliDegil)
            return YazmaYaniti.Red(StatusCodes.Status503ServiceUnavailable, "Beyin bağlı değil", "Bu makinede beyin ayarlı değil ya da komutu bulunamadı.");

        var kod = sonuc.HataKodu ?? "";
        var durum = KodDurumlari.TryGetValue(kod, out var bilinen) ? bilinen
            : kod == "hata" ? ((sonuc.Mesaj ?? "").Contains("bulunamadı", StringComparison.OrdinalIgnoreCase) ? StatusCodes.Status404NotFound : StatusCodes.Status409Conflict)
            : StatusCodes.Status502BadGateway;

        return durum switch
        {
            StatusCodes.Status400BadRequest => YazmaYaniti.Red(durum, "Geçersiz istek", "Beyin isteği kabul etmedi. Hiçbir şey yazılmadı."),
            StatusCodes.Status404NotFound => YazmaYaniti.Red(durum, "Bulunamadı", "Madde ya da görev bulunamadı. Hiçbir şey yazılmadı."),
            StatusCodes.Status409Conflict when kod == "gun-kapali" => YazmaYaniti.Red(durum, "Gün kapandı", "Kapanmış güne yazılmaz."),
            StatusCodes.Status409Conflict => YazmaYaniti.Red(durum, "İşlem uygulanamadı", "Beyin işlemi uygulamadı: madde ya da görev bu işleme uygun değil. Hiçbir şey yazılmadı."),
            _ => YazmaYaniti.Red(durum, "Beyin cevabı anlaşılamadı", "Beyin hata verdi ya da beklenmeyen bir cevap döndü. Hiçbir şey yazılmadı."),
        };
    }

    // A read that fails on the way to a write (looking up a task): nothing was written, so it is a plain refusal, as on the read side.
    private static YazmaYaniti OkumaHatasi(BeyinSonucu sonuc, ILogger log)
    {
        var yanit = BeyinOkuma.Hata<object>(sonuc, log);
        return YazmaYaniti.Red(yanit.Durum, yanit.Baslik!, yanit.Ayrinti!);
    }

    private static async Task<YazmaYaniti> YazAsync(
        BeyinIstemcisi beyin, ILogger log, IEnumerable<string> komut, IEnumerable<string>? konumsal,
        Func<JsonElement, object> donustur, CancellationToken ct)
    {
        var sonuc = await beyin.CalistirAsync(komut, ct, konumsal);
        if (!sonuc.Basarili)
            return Esle(sonuc, log);

        try
        {
            return YazmaYaniti.Tamam(donustur(sonuc.Veri!.Value));
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            // The command succeeded (exit 0) but the answer is not the shape we know: it wrote, we cannot tell what.
            log.LogWarning("Brain write answered in an unexpected shape: {Mesaj}", e.Message);
            return YazmaYaniti.Belirsiz("Beyin yazdı ama cevabı anlaşılamadı. Günün planına bak.");
        }
    }

    // Plan items

    public static async Task<YazmaYaniti> MaddeEkle(string tarih, MaddeEkleGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (TarihDenetle(tarih, out var gun) is { } tarihHatasi) return tarihHatasi;
        if (MetinDenetle(girdi.Metin, "metin", EnUzunMetin, out var metin) is { } metinHatasi) return metinHatasi;
        if (Istege(girdi.Bolum, "bolum", EnUzunBolum, out var bolum) is { } bolumHatasi) return bolumHatasi;
        if (bolum is not null && bolum.Equals("Kapanış", StringComparison.OrdinalIgnoreCase))
            return YazmaYaniti.Sorun("bolum", "Kapanış bölümüne madde eklenmez.");

        string? gorev = null;
        if (!string.IsNullOrWhiteSpace(girdi.Gorev))
        {
            gorev = girdi.Gorev.Trim();
            if (!GorevKimligiGecerli(gorev))
                return YazmaYaniti.Sorun("gorev", "Görev kimliği küçük harf, rakam ve tire olmalı.");
            // A hidden task, or one in a closed folder, must look like one that does not exist.
            var bulunan = await GorevBulAsync(gorev, beyin, log, ct);
            if (bulunan.Hata is not null) return bulunan.Hata;
        }

        return await MaddeYazAsync(gun, metin!, bolum, gorev, beyin, log, ct);
    }

    internal static Task<YazmaYaniti> MaddeYazAsync(DateOnly gun, string metin, string? bolum, string? gorev, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var komut = new List<string> { "gun", "ekle", $"--tarih={gun:yyyy-MM-dd}" };
        if (bolum is not null) komut.Add($"--bolum={bolum}");
        if (gorev is not null) komut.Add($"--gorev={gorev}");

        return YazAsync(beyin, log, komut, [metin], r => new MaddeEklendiDto(
            BeyinOkuma.Tarih(r, "tarih") ?? throw new InvalidDataException("tarih yok"),
            Madde(Nesne(r, "madde")),
            r.TryGetProperty("tahmin_onerisi", out var t) && t.ValueKind == JsonValueKind.Object ? BeyinOkuma.Sayi(t, "oneri_dk") : null), ct);
    }

    public static Task<YazmaYaniti> MaddeIsaretle(string tarih, MaddeIsaretleGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (TarihDenetle(tarih, out var gun) is { } tarihHatasi) return Task.FromResult(tarihHatasi);
        if (MaddeDenetle(girdi.Madde, out var madde) is { } maddeHatasi) return Task.FromResult(maddeHatasi);

        var komut = new List<string> { "gun", "isaretle", $"--tarih={gun:yyyy-MM-dd}" };
        if (girdi.Geri) komut.Add("--geri");

        return YazAsync(beyin, log, komut, [madde!], r => new MaddeIsaretlendiDto(
            BeyinOkuma.Tarih(r, "tarih") ?? throw new InvalidDataException("tarih yok"),
            Madde(Nesne(r, "madde")),
            r.TryGetProperty("gorev_kapandi", out var k) && k.ValueKind == JsonValueKind.True), ct);
    }

    public static Task<YazmaYaniti> MaddeDevret(string tarih, MaddeDevretGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (TarihDenetle(tarih, out var gun) is { } tarihHatasi) return Task.FromResult(tarihHatasi);
        if (MaddeDenetle(girdi.Madde, out var madde) is { } maddeHatasi) return Task.FromResult(maddeHatasi);

        return YazAsync(beyin, log, ["gun", "devret", $"--tarih={gun:yyyy-MM-dd}"], [madde!], r => new MaddeDevredildiDto(
            BeyinOkuma.Tarih(r, "tarih") ?? throw new InvalidDataException("tarih yok"),
            BeyinOkuma.Tarih(r, "devredilen_gun") ?? throw new InvalidDataException("devredilen_gun yok"),
            Madde(Nesne(r, "madde"))), ct);
    }

    public static Task<YazmaYaniti> MaddeNotu(string tarih, MaddeNotGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (TarihDenetle(tarih, out var gun) is { } tarihHatasi) return Task.FromResult(tarihHatasi);
        if (MaddeDenetle(girdi.Madde, out var madde) is { } maddeHatasi) return Task.FromResult(maddeHatasi);
        if (MetinDenetle(girdi.Metin, "metin", EnUzunNot, out var metin) is { } metinHatasi) return Task.FromResult(metinHatasi);

        return YazAsync(beyin, log, ["gun", "not", $"--tarih={gun:yyyy-MM-dd}"], [madde!, metin!], r => new MaddeNotuDto(
            BeyinOkuma.Tarih(r, "tarih") ?? throw new InvalidDataException("tarih yok"),
            Madde(Nesne(r, "madde"))), ct);
    }

    // Tasks

    public static async Task<YazmaYaniti> GorevEkle(GorevEkleGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (GorevEkleKomutu(girdi, out var komut) is { } hata)
            return hata;

        return await YazAsync(beyin, log, komut, null, r => new GorevEklendiDto(BeyinOkuma.Gerekli(r, "kimlik")), ct);
    }

    // The checks of a new task and the `gorev ekle` command that follows from them: the refusal, or null with the command.
    // Shared with the approval queue's "gorev-ekle" kind, so a task made from a voice note passes the same rules.
    internal static YazmaYaniti? GorevEkleKomutu(GorevEkleGirdi girdi, out List<string> komut)
    {
        komut = [];
        if (MetinDenetle(girdi.Baslik, "baslik", EnUzunBaslik, out var baslik) is { } baslikHatasi) return baslikHatasi;
        if (Istege(girdi.Proje, "proje", 100, out var proje) is { } projeHatasi) return projeHatasi;
        if (Istege(girdi.Alan, "alan", 100, out var alan) is { } alanHatasi) return alanHatasi;
        if ((proje is null) == (alan is null))
            return YazmaYaniti.Sorun("proje", "Proje ya da alandan tam biri verilmeli.");
        if (proje is not null && !GorevKimligiGecerli(proje))
            return YazmaYaniti.Sorun("proje", "Proje kimliği küçük harf, rakam ve tire olmalı.");
        // Finance and personal notes stay in the brain: the API puts nothing there (and the brain refuses projects/ and sistem/ itself).
        if (alan is not null && (!GorevKimligiGecerli(alan) || KapaliAlanlar.Contains(alan)))
            return YazmaYaniti.Sorun("alan", "Alan küçük harf, rakam ve tire olmalı; bu alan API'ye kapalı.");
        if (Istege(girdi.Bitis, "bitis", 10, out var bitis) is { } bitisHatasi) return bitisHatasi;
        if (bitis is not null && TarihDenetle(bitis, out _, "bitis") is { } bitisTarihHatasi) return bitisTarihHatasi;
        if (Istege(girdi.SonrakiAdim, "sonrakiAdim", EnUzunAyrinti, out var sonraki) is { } sonrakiHatasi) return sonrakiHatasi;
        if (Istege(girdi.Olcut, "olcut", EnUzunAyrinti, out var olcut) is { } olcutHatasi) return olcutHatasi;

        komut = ["gorev", "ekle", $"--baslik={baslik}"];
        if (proje is not null) komut.Add($"--proje={proje}");
        if (alan is not null) komut.Add($"--alan={alan}");
        if (bitis is not null) komut.Add($"--bitis={bitis}");
        if (sonraki is not null) komut.Add($"--sonraki-adim={sonraki}");
        if (olcut is not null) komut.Add($"--olcut={olcut}");
        return null;
    }

    // The user's own "done" in the app is the proof the brain asks of a project task (`onay:` is checked for its shape only).
    // The proof is never taken from the request: nobody can pass a file path or an address through here.
    public static async Task<YazmaYaniti> GorevBitir(string kimlik, BeyinIstemcisi beyin, ILogger log, TimeProvider saat, CancellationToken ct)
    {
        if (!GorevKimligiGecerli(kimlik))
            return YazmaYaniti.Sorun("kimlik", "Görev kimliği küçük harf, rakam ve tire olmalı.");

        var bulunan = await GorevBulAsync(kimlik, beyin, log, ct);
        if (bulunan.Hata is not null) return bulunan.Hata;

        var bugun = GunSiniri.Bugun(saat.GetUtcNow());
        return await YazAsync(beyin, log, ["gorev", "bitir", $"--kanit=onay:uygulama-{bugun:yyyy-MM-dd}"], [kimlik], r => new GorevBitirildiDto(
            BeyinOkuma.Gerekli(r, "kimlik"),
            r.TryGetProperty("plan", out var p) && p.ValueKind == JsonValueKind.Object), ct);
    }

    // Split a task over days: `gun ekle --tarih` for each day, in order, the last one with `--gorev`. The brain is not a transaction: when a day
    // fails the run stops, nothing is undone, and the answer says which days were written.
    public static async Task<YazmaYaniti> GunlereBol(string kimlik, GunlereBolGirdi girdi, BeyinIstemcisi beyin, ILogger log, TimeProvider saat, CancellationToken ct)
    {
        if (!GorevKimligiGecerli(kimlik))
            return YazmaYaniti.Sorun("kimlik", "Görev kimliği küçük harf, rakam ve tire olmalı.");
        if (girdi.GunSayisi is < 1 or > EnCokBolmeGunu)
            return YazmaYaniti.Sorun("gunSayisi", $"Gün sayısı 1 ile {EnCokBolmeGunu} arasında olmalı.");

        var baslangic = GunSiniri.Bugun(saat.GetUtcNow());
        if (!string.IsNullOrWhiteSpace(girdi.Baslangic) && TarihDenetle(girdi.Baslangic, out baslangic, "baslangic") is { } baslangicHatasi)
            return baslangicHatasi;
        if (Istege(girdi.Metin, "metin", EnUzunMetin - 20, out var ozelMetin) is { } metinHatasi) return metinHatasi;
        if (Istege(girdi.Bolum, "bolum", EnUzunBolum, out var bolum) is { } bolumHatasi) return bolumHatasi;
        if (bolum is not null && bolum.Equals("Kapanış", StringComparison.OrdinalIgnoreCase))
            return YazmaYaniti.Sorun("bolum", "Kapanış bölümüne madde eklenmez.");

        var bulunan = await GorevBulAsync(kimlik, beyin, log, ct);
        if (bulunan.Hata is not null) return bulunan.Hata;

        var temel = ozelMetin ?? Kisalt(bulunan.Baslik!, EnUzunMetin - 20);
        var yazilanlar = new List<BolmeGunuDto>();
        for (var i = 0; i < girdi.GunSayisi; i++)
        {
            var gun = baslangic.AddDays(i);
            var metin = girdi.GunSayisi == 1 ? temel : $"{temel} ({i + 1}/{girdi.GunSayisi})";
            // Only the last day's item is linked to the task: a tick on a linked item finishes the whole task (the brain's
            // rule), so the earlier days carry just the (1/3) count in their text and ticking them closes nothing.
            var baglanacak = i == girdi.GunSayisi - 1 ? kimlik : null;
            var yanit = await MaddeYazAsync(gun, metin, bolum, baglanacak, beyin, log, ct);

            if (yanit.Basarili)
            {
                yazilanlar.Add(new BolmeGunuDto(gun, ((MaddeEklendiDto)yanit.Veri!).Madde));
                continue;
            }

            if (yazilanlar.Count == 0)
                return yanit;

            var baslik = yanit.Baslik ?? (yanit.Veri as BelirsizYazmaDto)?.Baslik;
            var ayrinti = yanit.Ayrinti ?? (yanit.Veri as BelirsizYazmaDto)?.Ayrinti;
            var hata = new BolmeHatasiDto(gun, yanit.Durum, baslik, ayrinti, yanit.Tur == YazmaTuru.Belirsiz);
            return YazmaYaniti.Kismi(new GunlereBolSonucuDto(kimlik, girdi.GunSayisi, false, yazilanlar, hata));
        }

        return YazmaYaniti.Tamam(new GunlereBolSonucuDto(kimlik, girdi.GunSayisi, true, yazilanlar, null));
    }

    // The task, if the API may see it: open, not hidden, not in a closed folder. Anything else looks like it does not exist.
    private static async Task<(YazmaYaniti? Hata, string? Baslik)> GorevBulAsync(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var sonuc = await beyin.CalistirAsync(["gorev", "liste"], ct);
        if (!sonuc.Basarili)
            return (OkumaHatasi(sonuc, log), null);

        try
        {
            var gorev = BeyinOkuma.Dizi(sonuc.Veri!.Value)
                .FirstOrDefault(g => BeyinOkuma.Metin(g, "kimlik") == kimlik && BeyinOkuma.Gorunur(g) && BeyinOkuma.AcikYol(g));
            return gorev.ValueKind == JsonValueKind.Object
                ? (null, BeyinOkuma.Gerekli(gorev, "baslik"))
                : (YazmaYaniti.Red(StatusCodes.Status404NotFound, "Bulunamadı", "İstenen görev bulunamadı. Hiçbir şey yazılmadı."), null);
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException)
        {
            return (OkumaHatasi(new BeyinSonucu(BeyinDurumu.BozukCikti, Mesaj: "Beklenmeyen biçim: " + e.Message), log), null);
        }
    }

    // Input checks. Each returns the refusal, or null when the value is fine.

    private static readonly HashSet<string> KapaliAlanlar = ["finans", "kisisel", "projects", "sistem"];

    internal static YazmaYaniti? TarihDenetle(string? tarih, out DateOnly gun, string alan = "tarih")
    {
        if (DateOnly.TryParseExact(tarih, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out gun))
            return null;
        return YazmaYaniti.Sorun(alan, "Tarih yyyy-MM-dd biçiminde olmalı.");
    }

    // Only the permanent id of a plan item (six hex digits, at least one a letter: a number alone is a list position to the
    // brain) or `g:<task>` for an item that exists only as a task. A title fragment or a position never gets through.
    // For the pages: show a tick or carry-over button only for an id the writes would accept.
    public static bool MaddeKimligiGecerli(string? madde) => MaddeDenetle(madde, out _) is null;

    internal static YazmaYaniti? MaddeDenetle(string? madde, out string? temiz)
    {
        temiz = madde?.Trim();
        if (temiz is { Length: > 0 and <= 120 } && MaddeKalibi().IsMatch(temiz))
            return null;
        return YazmaYaniti.Sorun("madde", "Madde, kalıcı kimliğiyle (ör. a3f09c) verilmeli.");
    }

    internal static YazmaYaniti? MetinDenetle(string? deger, string alan, int enUzun, out string? temiz)
    {
        temiz = deger?.Trim();
        if (string.IsNullOrEmpty(temiz))
            return YazmaYaniti.Sorun(alan, "Boş olamaz.");
        return UzunlukVeKarakter(temiz, alan, enUzun);
    }

    // An optional text: empty means "not given".
    internal static YazmaYaniti? Istege(string? deger, string alan, int enUzun, out string? temiz)
    {
        temiz = string.IsNullOrWhiteSpace(deger) ? null : deger.Trim();
        return temiz is null ? null : UzunlukVeKarakter(temiz, alan, enUzun);
    }

    private static YazmaYaniti? UzunlukVeKarakter(string temiz, string alan, int enUzun)
    {
        if (temiz.Length > enUzun)
            return YazmaYaniti.Sorun(alan, $"En çok {enUzun} karakter olabilir.");
        // A line break would split a plan line in two; the brain would fold it, but the answer should be a clear refusal.
        if (temiz.Any(c => char.IsControl(c) || c is '\u2028' or '\u2029'))
            return YazmaYaniti.Sorun(alan, "Denetim karakteri ya da satır sonu olamaz.");
        return null;
    }

    internal static bool GorevKimligiGecerli(string kimlik) => kimlik.Length <= 100 && BeyinOkuma.KimlikKalibi().IsMatch(kimlik);

    private static string Kisalt(string metin, int enUzun) => metin.Length <= enUzun ? metin : metin[..enUzun].TrimEnd();

    // Conversions

    private static JsonElement Nesne(JsonElement e, string ad) =>
        e.TryGetProperty(ad, out var d) && d.ValueKind == JsonValueKind.Object ? d : throw new InvalidDataException($"'{ad}' alanı yok");

    private static YazilanMaddeDto Madde(JsonElement m) => new(
        BeyinOkuma.Gerekli(m, "id"), BeyinOkuma.Gerekli(m, "baslik"), BeyinOkuma.Metin(m, "bolum"), BeyinOkuma.Metin(m, "durum"),
        BeyinOkuma.Sayi(m, "tahmin_dk"), BeyinOkuma.Sayi(m, "sure_dk"), BeyinOkuma.Metin(m, "proje"), BeyinOkuma.Metin(m, "gorev"));

    [GeneratedRegex(@"^(?:(?=[0-9a-f]*[a-f])[0-9a-f]{6}|g:[a-z0-9]+(?:-[a-z0-9]+)*)\z", RegexOptions.CultureInvariant)]
    private static partial Regex MaddeKalibi();
}
