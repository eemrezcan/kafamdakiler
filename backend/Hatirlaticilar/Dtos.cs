using System.ComponentModel.DataAnnotations;

namespace Kafamdakiler.Hatirlaticilar;

public class HatirlaticiYazDto
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
    bool Israrli, int IsrarAraligiDakika, int IsrarEnCok, bool Acil);
