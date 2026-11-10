using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Gelen;
using Kafamdakiler.Isler;

namespace Kafamdakiler.Eylemler;

// The payload of "is-ac": a work card to open. Exactly one of Proje and Alan; Tip is kod, genel or yeni-proje (left out: kod).
public record IsAcYuku(string Baslik, string? Talep = null, string? Proje = null, string? Alan = null, string? Tip = null);

// "is-ac": opens a work card in the brain (`is ekle`). It exists for the assistant's entry: a request that came from the share menu may be
// another app's text, so a card made of it waits here for approval instead of being opened at once. A card cannot be taken back (it is
// cancelled with a reason on its own screen), so this kind is never applied by itself, whatever its mode says.
public class IsAcTuru(BeyinIstemcisi beyin, ILogger<IsAcTuru> gunluk) : IEylemTuru
{
    public const string Anahtar = "is-ac";

    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public string Ad => Anahtar;

    public string GorunenAd => "İş kartı aç";

    public bool GeriAlinabilir => false;

    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _);

    public async Task<Sonuc> DogrulaAsync(JsonElement yuk, CancellationToken ct)
    {
        var sekil = Coz(yuk, out var girdi);
        if (!sekil.Basarili || girdi!.Proje is null)
            return sekil;

        var projeler = await GelenBeyin.ProjeleriAlAsync(beyin, gunluk, ct);
        if (!projeler.Basarili)
            return Sonuc.Gecersiz("yuk", "Beyin cevap vermedi: proje doğrulanamadı.");

        return projeler.Veri!.Contains(girdi.Proje.Trim()) ? Sonuc.Tamam : Sonuc.Gecersiz("proje", "Böyle bir proje yok.");
    }

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var girdi);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        var yanit = await IsKartlari.Ac(girdi!, beyin, gunluk, ct);
        if (yanit.Basarili)
            return JsonSerializer.SerializeToElement(new { kimlik = ((IsKartiDto)yanit.Veri!).Kimlik }, JsonSerializerOptions.Web);

        // The brain's own words can hold paths: the queue shows a fixed sentence, the log has the rest.
        gunluk.LogWarning("Opening a work card did not succeed ({Tur}): {Baslik}", yanit.Tur, yanit.Baslik);
        throw new EylemHatasi(yanit.Tur == YazmaTuru.Belirsiz
            ? "Beyin zamanında cevap vermedi; kart açılmış olabilir, iş kartlarına bak."
            : "Beyin iş kartını açmadı.");
    }

    public Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct) =>
        throw new NotSupportedException("Açılan iş kartı geri alınamaz.");

    private static Sonuc Coz(JsonElement yuk, out IsAcGirdi? girdi)
    {
        girdi = null;
        IsAcYuku? y;
        try
        {
            y = yuk.Deserialize<IsAcYuku>(Secenekler);
        }
        catch (JsonException e)
        {
            return Sonuc.Gecersiz("yuk", $"Yük iş kartı biçimine uymuyor ({e.Path}).");
        }

        if (y is null || y.Baslik is null)
            return Sonuc.Gecersiz("yuk", "Yük baslik içermeli.");

        girdi = new IsAcGirdi(y.Baslik, y.Talep, y.Proje, y.Alan, y.Tip);
        if (IsKartlari.AcDenetle(girdi, out _, out _, out _, out _, out _) is { } hata)
        {
            var alan = hata.Alanlar?.Keys.FirstOrDefault() ?? "yuk";
            return Sonuc.Gecersiz(alan, hata.Alanlar?.Values.FirstOrDefault()?.FirstOrDefault() ?? "Geçersiz iş kartı.");
        }

        return Sonuc.Tamam;
    }
}
