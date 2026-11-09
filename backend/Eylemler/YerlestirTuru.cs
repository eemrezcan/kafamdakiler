using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Gelen;

namespace Kafamdakiler.Eylemler;

// A tag the dictionary does not have yet: its main name, synonyms and the `##` section of etiketler.md it goes under.
public record YeniEtiket(string Ad, List<string> Esler, string Bolum);

// The payload of "yerlestir": which inbox card goes where. `Tur` is the note kind the brain writes (default "not").
// `YeniEtiket` is set when `Etiketler` holds a tag the dictionary lacks: applying adds it to the dictionary first (K-0023), and
// only then places the card. Removing it from `Etiketler` and from here places the card with the existing tags alone.
public record YerlestirYuku(string Kart, string Yol, string Baslik, List<string> Etiketler, string? Tur = null, YeniEtiket? YeniEtiket = null);

// "yerlestir": turns an inbox card into a note (`gelen isle`). The brain has no way to put a card back, so this kind
// cannot be undone, and so it is never applied by itself either (EylemServisi).
public class YerlestirTuru(BeyinIstemcisi beyin, ILogger<YerlestirTuru> gunluk) : IEylemTuru
{
    public const string Anahtar = "yerlestir";

    public const int EnUzunBaslik = 200;
    public const int EnCokEtiket = 8;

    private static readonly string[] Turler = ["not", "kaynak"];

    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public string Ad => Anahtar;

    public string GorunenAd => "Gelen kartını yerleştir";

    public bool GeriAlinabilir => false;

    // The shape. Whether the project exists and the tags are in the dictionary needs the brain: DogrulaAsync.
    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _);

    public async Task<Sonuc> DogrulaAsync(JsonElement yuk, CancellationToken ct)
    {
        var sekil = Coz(yuk, out var y);
        if (!sekil.Basarili)
            return sekil;

        var projeler = await GelenBeyin.ProjeleriAlAsync(beyin, gunluk, ct);
        var sozluk = await GelenBeyin.SozluguAlAsync(beyin, gunluk, ct);
        if (!projeler.Basarili || !sozluk.Basarili)
            return Sonuc.Gecersiz("yuk", "Beyin cevap vermedi: yol ve etiketler doğrulanamadı.");

        return BeyinleDenetle(y!, projeler.Veri!, sozluk.Veri!);
    }

    // What only the brain knows: the project exists and is not hidden, every tag is in the dictionary, and the new tag (if any)
    // is really new and has a section to go under. A new tag that is already a main name is accepted: an earlier try added it
    // and then failed at the placement, so only the placement is left.
    // Shared with the hand-made placement (GelenIslemleri.Isle), so both go through the same lock.
    public static Sonuc BeyinleDenetle(YerlestirYuku y, IReadOnlySet<string> projeler, EtiketSozlugu sozluk)
    {
        if (GelenYolu.Denetle(y.Yol, projeler) is { } yolHatasi)
            return Sonuc.Gecersiz("yol", yolHatasi);
        var yeni = y.YeniEtiket;
        if (y.Etiketler.FirstOrDefault(e => e != yeni?.Ad && sozluk.Coz(e) is null) is { } bilinmeyen)
            return Sonuc.Gecersiz("etiketler", $"'{bilinmeyen}' etiket sözlüğünde yok; yeni etiket 'yeniEtiket' alanıyla önerilir.");
        if (yeni is null || sozluk.AnaAdMi(yeni.Ad))
            return Sonuc.Tamam;

        if (sozluk.Coz(yeni.Ad) is not null)
            return Sonuc.Gecersiz("yeniEtiket", $"'{yeni.Ad}' sözlükte başka bir etiketin eş sözcüğü olarak var; var olan etiketi kullan.");
        if (yeni.Esler.FirstOrDefault(e => sozluk.Coz(e) is not null) is { } varOlan)
            return Sonuc.Gecersiz("yeniEtiket", $"'{varOlan}' eş sözcüğü sözlükte zaten var.");
        if (sozluk.BolumAdi(yeni.Bolum) is null)
            return Sonuc.Gecersiz("yeniEtiket", $"'{yeni.Bolum}' sözlükte böyle bir bölüm yok (bölümler: {string.Join(", ", sozluk.Bolumler)}).");

        return Sonuc.Tamam;
    }

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var y);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        // The tag first: when it cannot be added the card is not placed, and the failure is the action's error.
        if (y!.YeniEtiket is { } yeni)
            await EtiketiEkleAsync(yeni, ct);

        var yanit = await beyin.CalistirAsync(Komut(y), ct, Konumsal(y));
        if (!yanit.Basarili)
        {
            // The brain's message can hold paths: it goes to the log, the queue shows a fixed text.
            gunluk.LogWarning("Placing card {Kart} failed ({Durum}, {Kod}): {Mesaj}", y!.Kart, yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            throw new InvalidOperationException($"Beyin kartı yerleştirmedi ({yanit.Durum}).");
        }

        return JsonSerializer.SerializeToElement(new { yol = y!.Yol, kart = y.Kart }, JsonSerializerOptions.Web);
    }

    // `etiket ekle`: the main name goes after `--`, the values are glued to their options. The brain refuses a name the
    // dictionary has and a section it lacks, and writes nothing then.
    private async Task EtiketiEkleAsync(YeniEtiket yeni, CancellationToken ct)
    {
        var sozluk = await GelenBeyin.SozluguAlAsync(beyin, gunluk, ct);
        if (!sozluk.Basarili)
            throw new EylemHatasi("Etiket sözlüğü okunamadı; kart işlenmedi.");
        if (sozluk.Veri!.AnaAdMi(yeni.Ad))
            return;

        var komut = new List<string> { "etiket", "ekle", $"--bolum={yeni.Bolum}" };
        if (yeni.Esler.Count > 0)
            komut.Add($"--es={string.Join(',', yeni.Esler)}");
        var yanit = await beyin.CalistirAsync(komut, ct, [yeni.Ad]);
        if (!yanit.Basarili)
        {
            gunluk.LogWarning("Adding tag {Etiket} failed ({Durum}, {Kod}): {Mesaj}", yeni.Ad, yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            throw new EylemHatasi($"Etiket sözlüğe eklenemedi ({yanit.Durum}); kart işlenmedi.");
        }
    }

    public Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct) =>
        throw new NotSupportedException("Kart yerleştirmesi geri alınamaz.");

    // `gelen isle`: every value is glued to its option with `=`, so a value that starts with a dash is never read as an option.
    // The text is the card's own body (the command takes it when none is given).
    public static List<string> Komut(YerlestirYuku y)
    {
        var komut = new List<string> { "gelen", "isle", $"--yol={y.Yol}", $"--baslik={y.Baslik}", $"--tags={string.Join(',', y.Etiketler)}" };
        if (y.Tur is not null)
            komut.Add($"--tur={y.Tur}");
        return komut;
    }

    // The card name goes after `--`.
    public static string[] Konumsal(YerlestirYuku y) => [GelenBeyin.KartYolu(y.Kart)];

    private static Sonuc Coz(JsonElement yuk, out YerlestirYuku? y)
    {
        try
        {
            y = yuk.Deserialize<YerlestirYuku>(Secenekler);
        }
        catch (JsonException e)
        {
            y = null;
            return Sonuc.Gecersiz("yuk", $"Yük yerleştirme biçimine uymuyor ({e.Path}).");
        }

        return Denetle(y, out y);
    }

    // The shape of a placement, whoever made it (Claude, a person correcting it, the manual form). `temiz` has the title trimmed.
    public static Sonuc Denetle(YerlestirYuku? y, out YerlestirYuku? temiz)
    {
        temiz = null;
        if (y is null || y.Kart is null || y.Yol is null || y.Baslik is null || y.Etiketler is null)
            return Sonuc.Gecersiz("yuk", "Yük kart, yol, baslik ve etiketler içermeli.");

        if (!GelenBeyin.KartKimligiGecerli(y.Kart))
            return Sonuc.Gecersiz("kart", "Kart adı geçerli değil.");
        if (GelenYolu.Denetle(y.Yol, null) is { } yolHatasi)
            return Sonuc.Gecersiz("yol", yolHatasi);

        var baslik = y.Baslik.Trim();
        if (baslik.Length is 0 or > EnUzunBaslik || GelenKurallari.DenetimKarakteriVar(baslik))
            return Sonuc.Gecersiz("baslik", $"Başlık boş olamaz, en çok {EnUzunBaslik} karakter olabilir, satır sonu içeremez.");

        if (y.Etiketler.Count is 0 or > EnCokEtiket
            || y.Etiketler.Any(e => string.IsNullOrWhiteSpace(e) || e.Any(char.IsWhiteSpace) || e.Contains(',') || e.StartsWith('-'))
            || y.Etiketler.Distinct(StringComparer.Ordinal).Count() != y.Etiketler.Count)
            return Sonuc.Gecersiz("etiketler", $"1 ile {EnCokEtiket} arasında, boşluksuz ve birbirinden farklı etiket olmalı.");

        if (y.Tur is not null && !Turler.Contains(y.Tur, StringComparer.Ordinal))
            return Sonuc.Gecersiz("tur", "Tür not ya da kaynak olabilir.");

        if (y.YeniEtiket is { } yeni)
        {
            if (YeniEtiketHatasi(yeni) is { } yeniHatasi)
                return Sonuc.Gecersiz("yeniEtiket", yeniHatasi);
            if (!y.Etiketler.Contains(yeni.Ad, StringComparer.Ordinal))
                return Sonuc.Gecersiz("yeniEtiket", "Yeni etiket etiketler arasında da olmalı; istemiyorsan ikisinden de çıkar.");
        }

        temiz = y with { Baslik = baslik, YeniEtiket = y.YeniEtiket is { } e ? e with { Bolum = e.Bolum.Trim() } : null };
        return Sonuc.Tamam;
    }

    public const int EnUzunEtiket = 40;
    public const int EnCokEs = 6;
    public const int EnUzunBolum = 60;

    // The shape of a new tag, whoever proposed it: the rules `etiket ekle` has (lowercase, no space, none of `: , #`), checked
    // here so a bad name is refused before it reaches the brain. Null when it is fine.
    public static string? YeniEtiketHatasi(YeniEtiket? yeni)
    {
        if (yeni is null || yeni.Ad is null || yeni.Esler is null || yeni.Bolum is null)
            return "Yeni etiketin adı, eş sözcükleri ve bölümü olmalı.";
        if (AdHatasi(yeni.Ad) is { } adHatasi)
            return $"Etiket adı: {adHatasi}";
        if (yeni.Esler.Count > EnCokEs || yeni.Esler.Distinct(StringComparer.Ordinal).Count() != yeni.Esler.Count || yeni.Esler.Contains(yeni.Ad))
            return $"En çok {EnCokEs} eş sözcük olabilir; birbirinden ve etiketin kendisinden farklı olmalı.";
        if (yeni.Esler.Select(AdHatasi).FirstOrDefault(h => h is not null) is { } esHatasi)
            return $"Eş sözcük: {esHatasi}";

        var bolum = yeni.Bolum.Trim();
        if (bolum.Length is 0 or > EnUzunBolum || GelenKurallari.DenetimKarakteriVar(bolum))
            return $"Bölüm boş olamaz, en çok {EnUzunBolum} karakter olabilir, satır sonu içeremez.";

        return null;
    }

    private static string? AdHatasi(string? ad)
    {
        if (string.IsNullOrWhiteSpace(ad) || ad.Length > EnUzunEtiket)
            return $"boş olamaz, en çok {EnUzunEtiket} karakter olabilir.";
        if (ad.Any(char.IsWhiteSpace) || ad.IndexOfAny([',', ':', '#']) >= 0 || ad.StartsWith('-'))
            return "boşluk, ':' ',' '#' içeremez, '-' ile başlayamaz (çok sözcük tireyle yazılır).";
        if (ad != ad.ToLowerInvariant())
            return "küçük harf olmalı.";

        return null;
    }
}
