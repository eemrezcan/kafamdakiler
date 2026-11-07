using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Gelen;

namespace Kafamdakiler.Eylemler;

// The payload of "yerlestir": which inbox card goes where. `Tur` is the note kind the brain writes (default "not").
public record YerlestirYuku(string Kart, string Yol, string Baslik, List<string> Etiketler, string? Tur = null);

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

    // What only the brain knows: the project exists and is not hidden, every tag is in the dictionary.
    // Shared with the hand-made placement (GelenIslemleri.Isle), so both go through the same lock.
    public static Sonuc BeyinleDenetle(YerlestirYuku y, IReadOnlySet<string> projeler, EtiketSozlugu sozluk)
    {
        if (GelenYolu.Denetle(y.Yol, projeler) is { } yolHatasi)
            return Sonuc.Gecersiz("yol", yolHatasi);
        if (y.Etiketler.FirstOrDefault(e => sozluk.Coz(e) is null) is { } bilinmeyen)
            return Sonuc.Gecersiz("etiketler", $"'{bilinmeyen}' etiket sözlüğünde yok; yeni etiket önce laptopta eklenir.");

        return Sonuc.Tamam;
    }

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var y);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        var yanit = await beyin.CalistirAsync(Komut(y!), ct, Konumsal(y!));
        if (!yanit.Basarili)
        {
            // The brain's message can hold paths: it goes to the log, the queue shows a fixed text.
            gunluk.LogWarning("Placing card {Kart} failed ({Durum}, {Kod}): {Mesaj}", y!.Kart, yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            throw new InvalidOperationException($"Beyin kartı yerleştirmedi ({yanit.Durum}).");
        }

        return JsonSerializer.SerializeToElement(new { yol = y!.Yol, kart = y.Kart }, JsonSerializerOptions.Web);
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

        temiz = y with { Baslik = baslik };
        return Sonuc.Tamam;
    }
}
