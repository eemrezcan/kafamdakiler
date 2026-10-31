using System.ComponentModel.DataAnnotations;

namespace Kafamdakiler.Aliskanliklar;

// Habit

public class AliskanlikYazDto : IValidatableObject
{
    public Guid? Id { get; set; }

    [Required(ErrorMessage = "Ad zorunlu.")]
    [StringLength(100, ErrorMessage = "Ad en çok 100 karakter olabilir.")]
    public string Ad { get; set; } = "";

    [Required(ErrorMessage = "Tür zorunlu.")]
    public AliskanlikTuru? Tur { get; set; }

    [Required(ErrorMessage = "İkon zorunlu.")]
    [StringLength(50, ErrorMessage = "İkon en çok 50 karakter olabilir.")]
    public string Ikon { get; set; } = "";

    [Required(ErrorMessage = "Renk zorunlu.")]
    [StringLength(30, ErrorMessage = "Renk en çok 30 karakter olabilir.")]
    public string Renk { get; set; } = "";

    [Required(ErrorMessage = "Ölçü zorunlu.")]
    public Olcu? Olcu { get; set; }

    public HedefYonu HedefYonu { get; set; } = HedefYonu.EnAz;

    [Range(typeof(decimal), "0", "99999999", ConvertValueInInvariantCulture = true, ErrorMessage = "Günlük hedef 0 ile 99.999.999 arasında olmalı.")]
    public decimal? GunlukHedef { get; set; }

    [StringLength(30, ErrorMessage = "Birim en çok 30 karakter olabilir.")]
    public string? Birim { get; set; }

    [StringLength(30, ErrorMessage = "Öğe etiketi en çok 30 karakter olabilir.")]
    public string? OgeEtiketi { get; set; }

    [StringLength(30, ErrorMessage = "Alt başlık etiketi en çok 30 karakter olabilir.")]
    public string? AltBaslikEtiketi { get; set; }

    public Siklik Siklik { get; set; } = Siklik.HerGun;

    public int? HaftalikSayi { get; set; }

    public List<Gunler>? Gunler { get; set; }

    [Range(0, 10_000, ErrorMessage = "Sıra 0 ile 10.000 arasında olmalı.")]
    public int Sira { get; set; }

    public bool Arsivlendi { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Tur is null || Olcu is null)
            yield break;

        if (Tur == AliskanlikTuru.Raf)
        {
            if (Olcu != Aliskanliklar.Olcu.Sayili)
                yield return new("Raf alışkanlığında ölçü sayılı olmalı.", ["olcu"]);
            if (HedefYonu != HedefYonu.EnAz)
                yield return new("Raf alışkanlığında hedef yönü enAz olmalı.", ["hedefYonu"]);
            if (string.IsNullOrWhiteSpace(OgeEtiketi))
                yield return new("Raf alışkanlığında öğe etiketi zorunlu.", ["ogeEtiketi"]);
        }

        if (Olcu == Aliskanliklar.Olcu.Sayili)
        {
            if (string.IsNullOrWhiteSpace(Birim))
                yield return new("Sayılı ölçüde birim zorunlu.", ["birim"]);

            if (GunlukHedef is null)
                yield return new("Sayılı ölçüde günlük hedef zorunlu.", ["gunlukHedef"]);
            else if (HedefYonu == HedefYonu.EnAz && GunlukHedef <= 0)
                yield return new("enAz hedefi 0'dan büyük olmalı.", ["gunlukHedef"]);
        }
        else if (GunlukHedef is not null)
        {
            yield return new("Evet/hayır ölçüsünde günlük hedef boş olmalı.", ["gunlukHedef"]);
        }

        if (Siklik == Siklik.HaftadaN && HaftalikSayi is not (>= 1 and <= 6))
            yield return new("Haftalık sayı 1 ile 6 arasında olmalı.", ["haftalikSayi"]);

        if (Siklik == Siklik.BelirliGunler && (Gunler is null || Gunler.Count == 0 || Gunler.Contains(Aliskanliklar.Gunler.Yok)))
            yield return new("En az bir gün seçilmeli.", ["gunler"]);
    }
}

public record BugunDto(DateOnly Tarih, decimal Miktar, int? Dakika, double Deger, bool Planli);

public record DevamEdenDto(Guid Id, string Ad, string? AltBaslik, string? FotografUrl, decimal GuncelKonum, decimal? Toplam, double? Ilerleme);

public record AliskanlikDto(
    Guid Id, string Ad, AliskanlikTuru Tur, string Ikon, string Renk, Olcu Olcu, HedefYonu HedefYonu,
    decimal? GunlukHedef, string? Birim, string? OgeEtiketi, string? AltBaslikEtiketi,
    Siklik Siklik, int? HaftalikSayi, List<Gunler> Gunler, int Sira, bool Arsivlendi, DateTimeOffset Olusturulma,
    BugunDto Bugun, double Guc, int Seri, int EnUzunSeri, List<DevamEdenDto> DevamEdenler);

// Daily entry (Sayac) and days

public class KayitYazDto
{
    [Range(typeof(decimal), "0", "99999999", ConvertValueInInvariantCulture = true, ErrorMessage = "Miktar 0 ile 99.999.999 arasında olmalı.")]
    public decimal Miktar { get; set; }

    [Range(0, 1440, ErrorMessage = "Dakika 0 ile 1440 arasında olmalı.")]
    public int? Dakika { get; set; }
}

public record GunDto(DateOnly Tarih, decimal Miktar, int? Dakika, double Deger, bool Planli, double Guc);

// Item (Raf)

public class OgeYazDto : IValidatableObject
{
    public Guid? Id { get; set; }

    [Required(ErrorMessage = "Ad zorunlu.")]
    [StringLength(200, ErrorMessage = "Ad en çok 200 karakter olabilir.")]
    public string Ad { get; set; } = "";

    [StringLength(200, ErrorMessage = "Alt başlık en çok 200 karakter olabilir.")]
    public string? AltBaslik { get; set; }

    [Range(typeof(decimal), "0", "99999999", ConvertValueInInvariantCulture = true, ErrorMessage = "Toplam 0 ile 99.999.999 arasında olmalı.")]
    public decimal? Toplam { get; set; }

    [Range(typeof(decimal), "0", "99999999", ConvertValueInInvariantCulture = true, ErrorMessage = "Başlangıç konumu 0 ile 99.999.999 arasında olmalı.")]
    public decimal BaslangicKonumu { get; set; }

    public Guid? FotografId { get; set; }

    public OgeDurumu Durum { get; set; } = OgeDurumu.Siradaki;

    [Range(1, 5, ErrorMessage = "Puan 1 ile 5 arasında olmalı.")]
    public int? Puan { get; set; }

    [StringLength(2000, ErrorMessage = "Not en çok 2000 karakter olabilir.")]
    public string? Not { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Toplam is not null && Toplam <= BaslangicKonumu)
            yield return new("Toplam başlangıç konumundan büyük olmalı.", ["toplam"]);
    }
}

public record OgeDto(
    Guid Id, Guid AliskanlikId, string Ad, string? AltBaslik, decimal? Toplam, decimal BaslangicKonumu, decimal GuncelKonum,
    double? Ilerleme, Guid? FotografId, string? FotografUrl, OgeDurumu Durum, DateOnly? BaslamaTarihi,
    DateOnly? BitisTarihi, int? Puan, string? Not, decimal Hiz, DateOnly? TahminiBitis, int ToplamDakika,
    DateTimeOffset Olusturulma);

// Session (Raf)

public class OturumEkleDto
{
    public Guid? Id { get; set; }

    [Range(typeof(decimal), "0", "99999999", ConvertValueInInvariantCulture = true, ErrorMessage = "Bitiş konumu 0 ile 99.999.999 arasında olmalı.")]
    public decimal BitisKonum { get; set; }

    [Range(0, 1440, ErrorMessage = "Dakika 0 ile 1440 arasında olmalı.")]
    public int? Dakika { get; set; }

    [Range(typeof(decimal), "0","99999999", ConvertValueInInvariantCulture = true, ErrorMessage = "Başlangıç konumu 0 ya da büyük olmalı.")]
    public decimal? BaslangicKonum { get; set; }

    public DateTimeOffset? BaslangicAni { get; set; }
}

public class OturumGuncelleDto
{
    [Range(typeof(decimal), "0", "99999999", ConvertValueInInvariantCulture = true, ErrorMessage = "Bitiş konumu 0 ile 99.999.999 arasında olmalı.")]
    public decimal BitisKonum { get; set; }

    [Range(0, 1440, ErrorMessage = "Dakika 0 ile 1440 arasında olmalı.")]
    public int? Dakika { get; set; }
}

public record OturumDto(
    Guid Id, Guid OgeId, DateOnly Tarih, decimal BaslangicKonum, decimal BitisKonum, decimal Miktar, int? Dakika,
    DateTimeOffset Olusturulma, bool Son);
