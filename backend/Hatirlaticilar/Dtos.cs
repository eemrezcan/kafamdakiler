using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Hatirlaticilar;

public class HatirlaticiYazDto : IValidatableObject
{
    public Guid? Id { get; set; }

    [Required(ErrorMessage = "Başlık zorunlu.")]
    [StringLength(200, ErrorMessage = "Başlık en çok 200 karakter olabilir.")]
    public string Baslik { get; set; } = "";

    [StringLength(2000, ErrorMessage = "Not en çok 2000 karakter olabilir.")]
    public string? Not { get; set; }

    public HatirlaticiTuru Tur { get; set; } = HatirlaticiTuru.Gorev;

    [StringLength(100, ErrorMessage = "Kime en çok 100 karakter olabilir.")]
    public string? Kime { get; set; }

    [Required(ErrorMessage = "Gün zorunlu.")]
    public DateOnly? Gun { get; set; }

    public TimeOnly? Saat { get; set; }

    public Tekrar Tekrar { get; set; } = Tekrar.Yok;

    [Range(0, 60, ErrorMessage = "Kaç gün önce uyarılacağı 0 ile 60 arasında olmalı.")]
    public int OnceGun { get; set; }

    public HatirlaticiDurumu Durum { get; set; } = HatirlaticiDurumu.Acik;

    public bool Israrli { get; set; }

    [AllowedValues(5, 15, 60, ErrorMessage = "Israr aralığı 5, 15 ya da 60 dakika olmalı.")]
    public int IsrarAraligiDakika { get; set; } = Hatirlatici.VarsayilanIsrarAraligi;

    [Range(1, 4, ErrorMessage = "Israr sayısı 1 ile 4 arasında olmalı.")]
    public int IsrarEnCok { get; set; } = Hatirlatici.VarsayilanIsrarEnCok;

    public bool Acil { get; set; }

    // The link to the plan (K-0024). A plan item is named by its permanent id and the day of its plan file; a task by its slug.
    [StringLength(120, ErrorMessage = "Madde kimliği en çok 120 karakter olabilir.")]
    public string? MaddeId { get; set; }

    public DateOnly? MaddeTarihi { get; set; }

    [StringLength(100, ErrorMessage = "Görev kimliği en çok 100 karakter olabilir.")]
    public string? GorevKimligi { get; set; }

    // The days of a weekly reminder ("pzt", "cum"...). Read only when Tekrar is haftalik; empty means the weekday of Gun.
    public List<Gunler>? Gunler { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (!string.IsNullOrWhiteSpace(MaddeId))
        {
            if (MaddeTarihi is null)
                yield return new("Madde bağlanırsa madde tarihi de verilmeli.", ["maddeTarihi"]);
            if (!BeyinYazma.MaddeKimligiGecerli(MaddeId))
                yield return new("Madde, kalıcı kimliğiyle (ör. a3f09c) verilmeli.", ["maddeId"]);
        }
        else if (MaddeTarihi is not null)
        {
            yield return new("Madde tarihi yalnız madde kimliğiyle birlikte verilir.", ["maddeTarihi"]);
        }

        if (!string.IsNullOrWhiteSpace(GorevKimligi) && !BeyinYazma.GorevKimligiGecerli(GorevKimligi.Trim()))
            yield return new("Görev kimliği küçük harf, rakam ve tire olmalı.", ["gorevKimligi"]);

        if (Gunler is not null && Gunler.Any(g => g == Aliskanliklar.Gunler.Yok || !Enum.IsDefined(g)))
            yield return new("Gün listesi yalnız pzt, sal, car, per, cum, cmt, paz içerebilir.", ["gunler"]);
    }
}

public class ErteleDto
{
    [Required(ErrorMessage = "Süre zorunlu.")]
    [RegularExpression("^(1s|yarin)$", ErrorMessage = "Süre 1s ya da yarin olmalı.")]
    public string? Sure { get; set; }
}

public record HatirlaticiDto(
    Guid Id, string Baslik, string? Not, HatirlaticiTuru Tur, string? Kime, DateOnly Gun, TimeOnly? Saat, Tekrar Tekrar,
    int OnceGun, HatirlaticiDurumu Durum, DateTimeOffset SonrakiAn, DateTimeOffset? ErteleAn, DateTimeOffset EtkinAn,
    DateTimeOffset? OnceAn, int KalanGun, DateTimeOffset CreatedAt,
    bool Israrli, int IsrarAraligiDakika, int IsrarEnCok, bool Acil,
    string? MaddeId, DateOnly? MaddeTarihi, string? GorevKimligi, List<Gunler> Gunler,
    // Only an answer of "yaptım" sets this: the step of the chain (the plan item or task) that did not go through. The reminder itself was done.
    string? ZincirHatasi = null);
