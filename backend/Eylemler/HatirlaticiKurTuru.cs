using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;

namespace Kafamdakiler.Eylemler;

// "hatirlatici-kur": creates a reminder. The payload is the body of POST /api/hatirlaticilar, checked by the same rules.
public class HatirlaticiKurTuru(HatirlaticiAyari ayar) : IEylemTuru
{
    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public const string Anahtar = "hatirlatici-kur";

    public string Ad => Anahtar;

    public string GorunenAd => "Hatırlatıcı kur";

    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _);

    public Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var dto);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        var h = new Hatirlatici();
        HatirlaticiIslemleri.Uygula(h, dto!, ayar.VarsayilanSaat, baglam.Simdi);
        baglam.Db.Hatirlaticilar.Add(h);
        return Task.FromResult(JsonSerializer.SerializeToElement(new HatirlaticiGeriAlmaBilgisi(h.Id), Secenekler));
    }

    // The undo archives the reminder, it does not delete it. A reminder the user has since finished or archived is left as it is.
    public async Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct)
    {
        var bilgi = geriAlmaBilgisi.Deserialize<HatirlaticiGeriAlmaBilgisi>(Secenekler)
            ?? throw new InvalidOperationException("Geri alma bilgisi okunamadı.");

        var h = await baglam.Db.Hatirlaticilar.FindAsync([bilgi.HatirlaticiId], ct);
        if (h is { Durum: HatirlaticiDurumu.Acik })
            h.Durum = HatirlaticiDurumu.Arsiv;
    }

    private static Sonuc Coz(JsonElement yuk, out HatirlaticiYazDto? dto)
    {
        dto = null;
        try
        {
            dto = yuk.Deserialize<HatirlaticiYazDto>(Secenekler);
        }
        catch (JsonException e)
        {
            return Sonuc.Gecersiz("yuk", $"Yük hatırlatıcı biçimine uymuyor ({e.Path}).");
        }

        if (dto is null)
            return Sonuc.Gecersiz("yuk", "Yük boş.");

        // The queue makes the id; a client id would let a suggestion collide with an existing reminder.
        dto.Id = null;
        var hatalar = new List<ValidationResult>();
        if (!Validator.TryValidateObject(dto, new ValidationContext(dto), hatalar, validateAllProperties: true))
            return Sonuc.Gecersiz("yuk", string.Join(" ", hatalar.Select(h => h.ErrorMessage)));

        return Sonuc.Tamam;
    }

    private record HatirlaticiGeriAlmaBilgisi(Guid HatirlaticiId);
}
