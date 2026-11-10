using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;

namespace Kafamdakiler.Yapilacaklar;

// The day and calendar views of K-0024 (API sözleşmesi §1-§4): one list of what a day holds, whatever it is made of. The names and shapes
// are the contract's; enums travel as camelCase text ("plan", "yapildi").

public enum YapilacakTuru { Plan, Gorev, Hatirlatici, Etkinlik }

public enum YapilacakDurumu { Acik, Yapildi }

// "2 günden 1." Known only when the item's title says so ("(1/3)", which splitting a task over days writes).
public record BolunmusDto(int Sira, int Toplam);

// The reminder tied to an item. `Gunler` is set only for a weekly reminder that names days.
public record HatirlaticiOzetDto(Guid Id, string? Saat, Tekrar Tekrar, List<Gunler>? Gunler, bool Acil, bool Israrli, int OnceGun);

// `Kimlik` is typed and unique: "m:<maddeId>", "g:<gorevKimligi>", "h:<hatirlaticiGuid>", "e:<etkinlikGuid>".
// `Tarih` is the day of the item (E1): the day of the list for a plan item and an event, the moment's day for a reminder, the due day
// for a task (a late one keeps its old day: `GecikmeGun` says how late), and the day it is coming on for a row of `yaklasan`.
public record YapilacakDto(
    string Kimlik, YapilacakTuru Tur, string Baslik, string? Saat, string? BitisSaati, bool TumGun, int? TahminDk, int? SureDk,
    YapilacakDurumu Durum, string? Proje, string? Bolum, int? GecikmeGun, BolunmusDto? Bolunmus, HatirlaticiOzetDto? Hatirlatici,
    string? MaddeId, string? GorevKimligi, Guid? HatirlaticiId, Guid? EtkinlikId, string? Yer, DateOnly Tarih);

public record GunYukuDto(int AcikTahminDk, int EtkinlikDk, int KapasiteDk, int AsimDk, int BosDk, int TahminsizSayi);

public record DundenKalanDto(string MaddeId, string Baslik, int? TahminDk, string? Proje);

// `Plan`: yok (no brain here), tamam or okunamadi. `Google`: kapali, bagliDegil, bagli or yenidenBaglan.
public record GunKaynaklariDto(string Plan, string Google, DateTimeOffset? SonEsitleme);

public record GunGorunumuDto(
    DateOnly Tarih, bool Bugun, bool Kapandi, string? Ozet, GunYukuDto Yuk, List<DundenKalanDto> DundenKalanlar,
    List<YapilacakDto> Ogeler, GunKaynaklariDto Kaynaklar);

// Calendar range (§3)
public record TakvimSayilariDto(int Plan, int Gorev, int Hatirlatici, int Etkinlik);

public record TakvimGunuDto(DateOnly Tarih, TakvimSayilariDto Sayilar, bool YukAsimi);

public record TakvimAraligiDto(List<TakvimGunuDto> Gunler, List<YapilacakDto> Yaklasan);

// "Yaptım" (§1.1). `Zincir` lists the other ids that closed along the way; `ZincirHatasi` is set when a step of the chain did not go through
// (what was done is not undone).
public class YaptimGirdisi
{
    [Required(ErrorMessage = "Kimlik zorunlu.")]
    [StringLength(140, ErrorMessage = "Kimlik en çok 140 karakter olabilir.")]
    public string? Kimlik { get; set; }

    public bool Geri { get; set; }
}

public class DevretGirdisi
{
    [Required(ErrorMessage = "Kimlik zorunlu.")]
    [StringLength(140, ErrorMessage = "Kimlik en çok 140 karakter olabilir.")]
    public string? Kimlik { get; set; }
}

public record YaptimYanitiDto(YapilacakDto Oge, List<string> Zincir, string? ZincirHatasi);

// Carrying an item to another day (E2): the item as it is on its new day.
public record DevretYanitiDto(YapilacakDto Oge);

// The reminder part of a new item and of the "set a reminder on this item" shortcut (§2, §4). Same words as the reminder itself.
public class OgeHatirlaticiDto : IValidatableObject
{
    public TimeOnly? Saat { get; set; }

    public Tekrar Tekrar { get; set; } = Tekrar.Yok;

    public List<Gunler>? Gunler { get; set; }

    public bool Acil { get; set; }

    public bool Israrli { get; set; }

    [Range(0, 60, ErrorMessage = "Kaç gün önce uyarılacağı 0 ile 60 arasında olmalı.")]
    public int OnceGun { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Gunler is not null && Gunler.Any(g => g == Aliskanliklar.Gunler.Yok || !Enum.IsDefined(g)))
            yield return new("Gün listesi yalnız pzt, sal, car, per, cum, cmt, paz içerebilir.", ["gunler"]);
    }
}

// A new item (§4). The plan has no hour of its own: `Saat` is the hour of the reminder when there is one (and the reminder has none of its own).
public class YeniOgeGirdisi
{
    [Required(ErrorMessage = "Başlık zorunlu.")]
    [StringLength(200, ErrorMessage = "Başlık en çok 200 karakter olabilir.")]
    public string? Baslik { get; set; }

    public TimeOnly? Saat { get; set; }

    [Range(1, 720, ErrorMessage = "Tahmin 1 ile 720 dakika arasında olmalı.")]
    public int? TahminDk { get; set; }

    [StringLength(100, ErrorMessage = "Proje en çok 100 karakter olabilir.")]
    public string? Proje { get; set; }

    [StringLength(60, ErrorMessage = "Bölüm en çok 60 karakter olabilir.")]
    public string? Bolum { get; set; }

    public OgeHatirlaticiDto? Hatirlatici { get; set; }
}
