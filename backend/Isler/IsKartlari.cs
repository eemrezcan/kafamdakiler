using System.Globalization;
using System.Text;
using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.OpenApi;

namespace Kafamdakiler.Isler;

// Work cards (brain README "İş kartı"): the read and write side the phone, the notification line and the web page share.
// Same rules as the rest of the brain module: every call goes through BeyinIstemcisi (no shell), values that could start with a
// dash go after `--`, free text goes through a file, the brain's own message is never shown (it can hold paths), and a card in a
// hidden project or a closed folder looks like one that does not exist. The writer's name in the card's history is always
// `kullanici` (the person at the phone), whatever account is signed in.
public static class IsKartlari
{
    public const string Kim = "kullanici";
    public const int EnUzunBaslik = 200;
    public const int EnUzunTalep = 4000;
    public const int EnUzunCevap = 500;
    public const int EnUzunNot = 500;
    public const int EnUzunGerekce = 300;

    public static readonly IReadOnlyList<string> Asamalar =
        ["talep", "plan", "karar", "kod-onayi", "yapim", "push-onayi", "deploy-onayi", "bitti", "iptal"];

    // The three gates. Leaving one forward needs the person's approval, which the server adds (`--onay`); the brain asks for it.
    public static readonly IReadOnlyList<string> Kapilar = ["kod-onayi", "push-onayi", "deploy-onayi"];

    public static readonly IReadOnlyList<string> Tipler = ["kod", "genel", "yeni-proje"];

    // Areas the API puts nothing in (finance and personal notes stay in the brain; the brain refuses projects/ and sistem/ itself).
    private static readonly HashSet<string> KapaliAlanlar = ["finans", "kisisel", "projects", "sistem"];

    // Reads

    // Open cards, newest update first. `kapali` adds the cards finished (bitti) this week; asking for a closed stage by name
    // shows that stage's cards of this week. Cards the brain could not read (`hata`) are left out: nothing can be done with them.
    public static async Task<BeyinYaniti<List<IsKartiDto>>> ListeAl(
        string? asama, string? proje, bool kapali, BeyinIstemcisi beyin, ILogger log, TimeProvider saat, CancellationToken ct)
    {
        if (asama is not null && !Asamalar.Contains(asama))
            return BeyinOkuma.Sorun<List<IsKartiDto>>("asama", "Bilinmeyen aşama.");
        if (proje is not null && !GecerliKimlik(proje))
            return BeyinOkuma.Sorun<List<IsKartiDto>>("proje", "Proje kimliği küçük harf, rakam ve tire olmalı.");

        var kapaliIstendi = kapali || asama is "bitti" or "iptal";
        var komut = new List<string> { "is", "liste" };
        if (!kapaliIstendi)
            komut.Add("--acik");
        if (asama is not null)
            komut.Add($"--asama={asama}");
        if (proje is not null)
            komut.Add($"--proje={proje}");

        var haftaBasi = HaftaBasi(saat.GetUtcNow());
        return await OkuAsync(beyin, log, komut, null, veri => BeyinOkuma.Dizi(veri)
            .Where(BeyinOkuma.Gorunur).Where(BeyinOkuma.AcikYol).Where(k => BeyinOkuma.Metin(k, "hata") is null)
            .Select(Kart)
            .Where(k => k.Acik || (kapaliIstendi && (asama is not null || k.Asama == "bitti") && Gun(k.Guncelleme) >= haftaBasi))
            .ToList(), ct);
    }

    // One card with its request, plan, questions and history.
    public static Task<BeyinYaniti<IsAyrintiDto>> Al(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (!GecerliKimlik(kimlik))
            return Task.FromResult(BeyinOkuma.Sorun<IsAyrintiDto>("kimlik", "Kart kimliği küçük harf, rakam ve tire olmalı."));

        return OkuAsync(beyin, log, ["is", "goster"], [kimlik], Ayrinti, ct);
    }

    // The Monday of the week of `an` (the week the day panel counts: Monday to Sunday), by the 05:00 day-turn rule.
    public static DateOnly HaftaBasi(DateTimeOffset an)
    {
        var bugun = GunSiniri.Bugun(an);
        return bugun.AddDays(-(((int)bugun.DayOfWeek + 6) % 7));
    }

    // Writes

    public static async Task<YazmaYaniti> Ac(IsAcGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (BeyinYazma.MetinDenetle(girdi.Baslik, "baslik", EnUzunBaslik, out var baslik) is { } baslikHatasi) return baslikHatasi;
        if (Cok(girdi.Talep, "talep", EnUzunTalep, out var talep) is { } talepHatasi) return talepHatasi;
        if (BeyinYazma.Istege(girdi.Proje, "proje", 100, out var proje) is { } projeHatasi) return projeHatasi;
        if (BeyinYazma.Istege(girdi.Alan, "alan", 100, out var alan) is { } alanHatasi) return alanHatasi;
        if ((proje is null) == (alan is null))
            return YazmaYaniti.Sorun("proje", "Proje ya da alandan tam biri verilmeli.");
        if (proje is not null && !GecerliKimlik(proje))
            return YazmaYaniti.Sorun("proje", "Proje kimliği küçük harf, rakam ve tire olmalı.");
        if (alan is not null && (!GecerliKimlik(alan) || KapaliAlanlar.Contains(alan)))
            return YazmaYaniti.Sorun("alan", "Alan küçük harf, rakam ve tire olmalı; bu alan API'ye kapalı.");
        var tip = string.IsNullOrWhiteSpace(girdi.Tip) ? "kod" : girdi.Tip.Trim();
        if (!Tipler.Contains(tip))
            return YazmaYaniti.Sorun("tip", "Tip kod, genel ya da yeni-proje olmalı.");

        var talepDosyasi = Path.Combine(Path.GetTempPath(), "kd-is-" + Guid.NewGuid().ToString("N") + ".md");
        try
        {
            await File.WriteAllTextAsync(talepDosyasi, talep ?? "", new UTF8Encoding(false), ct);
            var komut = new List<string>
            {
                "is", "ekle", $"--kim={Kim}", $"--baslik={baslik}", $"--tip={tip}", "--kaynak=telefon", "--sahip=vps", $"--metin-dosya={talepDosyasi}",
                proje is not null ? $"--proje={proje}" : $"--alan={alan}",
            };
            return await YazAsync(beyin, log, komut, null, ct);
        }
        finally
        {
            File.Delete(talepDosyasi);
        }
    }

    public static async Task<YazmaYaniti> Cevapla(string kimlik, IsCevapGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (KimlikDenetle(kimlik) is { } kimlikHatasi) return kimlikHatasi;
        if (girdi.SoruNo < 1)
            return YazmaYaniti.Sorun("soruNo", "Soru numarası 1 ya da daha büyük olmalı.");
        if (BeyinYazma.MetinDenetle(girdi.Cevap, "cevap", EnUzunCevap, out var cevap) is { } cevapHatasi) return cevapHatasi;

        var kart = await GorunurKartAsync(kimlik, beyin, log, ct);
        if (kart.Hata is not null) return kart.Hata;
        var soru = kart.Ayrinti!.Sorular.FirstOrDefault(s => s.No == girdi.SoruNo);
        if (soru is null)
            return YazmaYaniti.Red(StatusCodes.Status404NotFound, "Soru bulunamadı", "Kartta bu numaralı bir soru yok. Hiçbir şey yazılmadı.");
        // The brain would overwrite an answer; an answered question is locked. The same answer again (a request repeated after a
        // timeout) is not an error: the card is already as the person wanted it.
        if (soru.Cevap is not null)
            return soru.Cevap == cevap
                ? YazmaYaniti.Tamam(KartOzeti(kart.Ayrinti))
                : YazmaYaniti.Red(StatusCodes.Status409Conflict, "Soru zaten cevaplanmış", "Bu soruya başka bir cevap yazılmış; cevap değiştirilmez. Hiçbir şey yazılmadı.");

        return await YazAsync(beyin, log, ["is", "cevapla", $"--kim={Kim}"], [kimlik, girdi.SoruNo.ToString(CultureInfo.InvariantCulture), cevap!], ct);
    }

    // Moves the card. Leaving a gate forward carries the person's approval, written here (`onay:telefon-<day>`), never taken from
    // the request. Going back to "plan" (refusing the gate) and cancelling need none.
    public static async Task<YazmaYaniti> AsamaDegistir(
        string kimlik, IsAsamaGirdi girdi, BeyinIstemcisi beyin, ILogger log, TimeProvider saat, CancellationToken ct)
    {
        if (KimlikDenetle(kimlik) is { } kimlikHatasi) return kimlikHatasi;
        var asama = girdi.Asama?.Trim();
        if (asama is null || !Asamalar.Contains(asama) || asama == "talep")
            return YazmaYaniti.Sorun("asama", "Aşama plan, karar, kod-onayi, yapim, push-onayi, deploy-onayi, bitti ya da iptal olmalı.");
        if (BeyinYazma.Istege(girdi.Gerekce, "gerekce", EnUzunGerekce, out var gerekce) is { } gerekceHatasi) return gerekceHatasi;
        if (BeyinYazma.Istege(girdi.Not, "not", EnUzunNot, out var not) is { } notHatasi) return notHatasi;
        if (asama == "iptal" && gerekce is null)
            return YazmaYaniti.Sorun("gerekce", "İptal için gerekçe yaz.");
        if (asama != "iptal" && gerekce is not null)
            return YazmaYaniti.Sorun("gerekce", "Gerekçe yalnız iptalle verilir.");

        var kart = await GorunurKartAsync(kimlik, beyin, log, ct);
        if (kart.Hata is not null) return kart.Hata;

        // Going back to "plan" from any later stage is a revision: the plan session reads the note as its input, so it is asked for here
        // and the brain is not called without one (moving a new card on from "talep" to "plan" is the plain forward step and needs none).
        if (asama == "plan" && kart.Ayrinti!.Acik && kart.Ayrinti.Asama != "talep" && not is null)
            return YazmaYaniti.Sorun(HataAnahtarlari.NotGerekli, HataAnahtarlari.NotGerekliMetni);

        var komut = new List<string> { "is", "asama", $"--kim={Kim}" };
        if (Kapilar.Contains(kart.Ayrinti!.Asama) && asama is not ("plan" or "iptal"))
            komut.Add($"--onay=onay:telefon-{GunSiniri.Bugun(saat.GetUtcNow()):yyyy-MM-dd}");
        if (gerekce is not null)
            komut.Add($"--gerekce={gerekce}");
        if (not is not null)
            komut.Add($"--not={not}");

        return await YazAsync(beyin, log, komut, [kimlik, asama], ct);
    }

    public static async Task<YazmaYaniti> NotYaz(string kimlik, IsNotGirdi girdi, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        if (KimlikDenetle(kimlik) is { } kimlikHatasi) return kimlikHatasi;
        if (BeyinYazma.MetinDenetle(girdi.Metin, "metin", EnUzunNot, out var metin) is { } metinHatasi) return metinHatasi;

        var kart = await GorunurKartAsync(kimlik, beyin, log, ct);
        if (kart.Hata is not null) return kart.Hata;

        return await YazAsync(beyin, log, ["is", "not", $"--kim={Kim}"], [kimlik, metin!], ct);
    }

    // Notification buttons

    // What the notification of a card can offer as one tap, by what the card is now (read when the notification is opened, so a
    // card that has moved on offers nothing). A decision with one unanswered question and up to three options: the options.
    // A code gate: "Onayla" and "Plana dön". The push and deploy gates have no button: their approval is given on the screen,
    // after the plan and the history have been seen.
    public static List<BildirimSecenegiDto> BildirimSecenekleri(IsAyrintiDto kart)
    {
        if (!kart.Acik || kart.Sahip != "kullanici")
            return [];

        if (kart.Asama == "kod-onayi")
            return [new("Onayla", "asama", Asama: "yapim"), new("Plana dön", "asama", Asama: "plan")];

        if (kart.Asama == "karar")
        {
            var cevapsiz = kart.Sorular.Where(s => s.Cevap is null).ToList();
            if (cevapsiz is [{ Secenekler.Count: >= 1 and <= 3 } soru])
                return soru.Secenekler.Select(s => new BildirimSecenegiDto(Kisalt(s, 40), "cevap", SoruNo: soru.No, Cevap: s)).ToList();
        }

        return [];
    }

    // Helpers

    public static bool GecerliKimlik(string kimlik) => kimlik.Length <= 100 && BeyinOkuma.KimlikKalibi().IsMatch(kimlik);

    private static YazmaYaniti? KimlikDenetle(string kimlik) =>
        GecerliKimlik(kimlik) ? null : YazmaYaniti.Sorun("kimlik", "Kart kimliği küçük harf, rakam ve tire olmalı.");

    // A text that may have line breaks (a request): control characters other than \n \r \t are refused.
    private static YazmaYaniti? Cok(string? deger, string alan, int enUzun, out string? temiz)
    {
        temiz = string.IsNullOrWhiteSpace(deger) ? null : deger.Trim();
        if (temiz is null)
            return null;
        if (temiz.Length > enUzun)
            return YazmaYaniti.Sorun(alan, $"En çok {enUzun} karakter olabilir.");
        if (temiz.Any(c => char.IsControl(c) && c is not ('\n' or '\r' or '\t')))
            return YazmaYaniti.Sorun(alan, "Denetim karakteri olamaz.");
        return null;
    }

    // The card as the API may show it, or the refusal that stops a write: an unknown, hidden or closed-folder card is a 404.
    private static async Task<(YazmaYaniti? Hata, IsAyrintiDto? Ayrinti)> GorunurKartAsync(string kimlik, BeyinIstemcisi beyin, ILogger log, CancellationToken ct)
    {
        var yanit = await Al(kimlik, beyin, log, ct);
        return yanit.Basarili
            ? (null, yanit.Veri)
            : (YazmaYaniti.Red(yanit.Durum, yanit.Baslik ?? "Okunamadı", (yanit.Ayrinti ?? "Kart okunamadı.") + " Hiçbir şey yazılmadı."), null);
    }

    private static async Task<BeyinYaniti<T>> OkuAsync<T>(
        BeyinIstemcisi beyin, ILogger log, IEnumerable<string> komut, IEnumerable<string>? konumsal, Func<JsonElement, T> donustur, CancellationToken ct)
    {
        var sonuc = await beyin.CalistirAsync(komut, ct, konumsal);
        if (!sonuc.Basarili)
            return BeyinOkuma.Hata<T>(sonuc, log);

        try
        {
            return new BeyinYaniti<T>(StatusCodes.Status200OK, donustur(sonuc.Veri!.Value));
        }
        catch (GizliKart)
        {
            return BeyinOkuma.Hata<T>(new BeyinSonucu(BeyinDurumu.BeyinHatasi, HataKodu: "gizli"), log);
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            return BeyinOkuma.Hata<T>(new BeyinSonucu(BeyinDurumu.BozukCikti, Mesaj: "Beklenmeyen biçim: " + e.Message), log);
        }
    }

    private sealed class GizliKart : Exception;

    // Runs a write and answers with the card the brain prints back.
    private static async Task<YazmaYaniti> YazAsync(
        BeyinIstemcisi beyin, ILogger log, IEnumerable<string> komut, IEnumerable<string>? konumsal, CancellationToken ct)
    {
        var sonuc = await beyin.CalistirAsync(komut, ct, konumsal);
        if (!sonuc.Basarili)
            return Esle(sonuc, log);

        try
        {
            return YazmaYaniti.Tamam(Kart(sonuc.Veri!.Value));
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            // Exit 0 but not the shape we know: it wrote, we cannot tell what.
            log.LogWarning("Brain card write answered in an unexpected shape: {Mesaj}", e.Message);
            return YazmaYaniti.Belirsiz("Beyin yazdı ama cevabı anlaşılamadı. Kartı açıp bak.");
        }
    }

    // How a refusal of the brain becomes words. The brain's code decides; its own message goes to the log only. Nothing was
    // written in any of these. Not an answer in time, a missing brain or unreadable output: the same rules as every brain write.
    internal static YazmaYaniti Esle(BeyinSonucu sonuc, ILogger log)
    {
        if (sonuc.Durum != BeyinDurumu.BeyinHatasi)
            return BeyinYazma.Esle(sonuc, log);

        log.LogWarning("Brain card write refused ({Kod}): {Mesaj}", sonuc.HataKodu, sonuc.Mesaj);
        const string Yazilmadi = " Hiçbir şey yazılmadı.";
        return sonuc.HataKodu switch
        {
            "cevapsiz-soru" => YazmaYaniti.Red(409, "Cevapsız soru var", "Karar aşamasından çıkmadan önce bütün soruları cevapla." + Yazilmadi),
            "onay-gerekli" => YazmaYaniti.Red(409, "Onay gerekli", "Bu aşamadan ilerlemek için onay gerekir." + Yazilmadi),
            "gecersiz-gecis" => YazmaYaniti.Red(409, "Aşama değiştirilemedi", "Kart bu aşamadan oraya geçemez: sıradaki aşamaya geçebilir, plana dönebilir ya da iptal edilebilir." + Yazilmadi),
            "gerekce-gerekli" => YazmaYaniti.Red(400, "Gerekçe gerekli", "İptal için gerekçe yaz." + Yazilmadi),
            "not-gerekli" => YazmaYaniti.Sorun(HataAnahtarlari.NotGerekli, HataAnahtarlari.NotGerekliMetni),
            "kilitli" => YazmaYaniti.Red(409, "Kart kilitli", "Kart şu an bir oturumda çalışılıyor; oturum bırakınca tekrar dene." + Yazilmadi),
            "kapali" => YazmaYaniti.Red(409, "Kart kapalı", "Bitmiş ya da iptal edilmiş karta yazılmaz." + Yazilmadi),
            "bozuk-kart" => YazmaYaniti.Red(409, "Kart bozuk", "Kartın dosyası okunamıyor; beyinde elle düzeltilmeli." + Yazilmadi),
            "bulunamadi" or "gizli" => YazmaYaniti.Red(404, "Bulunamadı", "İstenen kart bulunamadı." + Yazilmadi),
            "gecersiz-arguman" => YazmaYaniti.Red(400, "Geçersiz istek", "Beyin isteği kabul etmedi." + Yazilmadi),
            "hata" => YazmaYaniti.Red(409, "İşlem uygulanamadı", "Beyin işlemi uygulamadı: proje ya da alan bu işe uygun değil." + Yazilmadi),
            _ => YazmaYaniti.Red(502, "Beyin cevabı anlaşılamadı", "Beyin hata verdi ya da beklenmeyen bir cevap döndü." + Yazilmadi),
        };
    }

    // Conversions: the brain's card JSON -> our DTOs. A missing required field is an InvalidDataException (a 502).

    internal static IsKartiDto Kart(JsonElement k)
    {
        if (!BeyinOkuma.Gorunur(k) || !BeyinOkuma.AcikYol(k))
            throw new GizliKart();

        return new IsKartiDto(
            BeyinOkuma.Gerekli(k, "kimlik"), BeyinOkuma.Gerekli(k, "baslik"), BeyinOkuma.Gerekli(k, "tip"), BeyinOkuma.Gerekli(k, "asama"),
            BeyinOkuma.Gerekli(k, "sahip"), GecerliKilit(k), BeyinOkuma.Metin(k, "proje"), BeyinOkuma.Metin(k, "alan"), BeyinOkuma.Metin(k, "kaynak") ?? "",
            BeyinOkuma.Metin(k, "olusma"), BeyinOkuma.Metin(k, "guncelleme"), BeyinOkuma.Sayi(k, "bekleyen_soru") ?? 0,
            BeyinOkuma.DiziAlani(k, "gecisler").Where(e => e.ValueKind == JsonValueKind.String).Select(e => e.GetString()!).ToList(),
            BeyinOkuma.Bool(k, "acik"));
    }

    private static IsKartiDto KartOzeti(IsAyrintiDto k) => new(
        k.Kimlik, k.Baslik, k.Tip, k.Asama, k.Sahip, k.Kilit, k.Proje, k.Alan, k.Kaynak, k.Olusma, k.Guncelleme, k.BekleyenSoru, k.Gecisler, k.Acik);

    private static string? GecerliKilit(JsonElement k) => BeyinOkuma.Bool(k, "kilit_gecerli") ? BeyinOkuma.Metin(k, "kilit") : null;

    private static IsAyrintiDto Ayrinti(JsonElement k)
    {
        var kart = Kart(k);
        return new IsAyrintiDto(
            kart.Kimlik, kart.Baslik, kart.Tip, kart.Asama, kart.Sahip, kart.Kilit, kart.Proje, kart.Alan, kart.Kaynak,
            kart.Olusma, kart.Guncelleme, kart.BekleyenSoru, kart.Gecisler, kart.Acik,
            BeyinOkuma.Metin(k, "talep") ?? "", BeyinOkuma.Metin(k, "plan") ?? "",
            BeyinOkuma.DiziAlani(k, "sorular").Select(s => new IsSorusuDto(
                BeyinOkuma.Sayi(s, "no") ?? throw new InvalidDataException("'no' alanı yok"), BeyinOkuma.Gerekli(s, "soru"),
                BeyinOkuma.DiziAlani(s, "secenekler").Where(e => e.ValueKind == JsonValueKind.String).Select(e => e.GetString()!).ToList(),
                BeyinOkuma.Metin(s, "onerilen"), BeyinOkuma.Metin(s, "neden"), BeyinOkuma.Metin(s, "cevap"))).ToList(),
            BeyinOkuma.DiziAlani(k, "gecmis").Select(g => new IsGecmisiDto(
                BeyinOkuma.Metin(g, "zaman") ?? "", BeyinOkuma.Gerekli(g, "olay"), BeyinOkuma.Metin(g, "kim") ?? "")).ToList());
    }

    // The day of a time the brain wrote ("2026-11-10T14:30"); a card with no readable time counts as old.
    private static DateOnly Gun(string? zaman) =>
        zaman is { Length: >= 10 } && DateOnly.TryParseExact(zaman[..10], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun)
            ? gun
            : DateOnly.MinValue;

    private static string Kisalt(string metin, int enUzun) => metin.Length <= enUzun ? metin : metin[..(enUzun - 1)] + "…";
}
