namespace Kafamdakiler.Beyin;

// What the read endpoints return. Each one is built field by field from beyin.py's output (BeyinDonusumleri);
// the raw JSON is never passed through, so a field the screens do not need cannot leak.
// The names carry a "Beyin" prefix where the habit module already has the same name (OpenAPI schema names must differ).

public record BeyinDurumDto(bool Bagli, string? Vault, int BekleyenYakalama, int HataliYakalama);

public record ProjeOzetDto(string Kimlik, string Baslik);

public record ProjeDto(
    string Kimlik, string Baslik, string? Durum, string? SiradakiAdim,
    List<ProjeGorevDto> AcikGorevler, List<GunlukSatiriDto> SonGunluk);

public record ProjeGorevDto(string Kimlik, string Baslik, string? Durum, DateOnly? Bitis, string? Oncelik, string? SonrakiAdim);

public record GunlukSatiriDto(string? Zaman, string? Baslik, string? Metin);

public record BeyinGunDto(
    DateOnly Tarih, string? GunAdi, string? HaftaGunu, bool Bugun, bool PlanVar, bool Kapandi,
    List<BeyinGunBolumuDto> Bolumler, List<GecikenGorevDto> Geciken, BeyinGunToplamiDto? Toplam);

public record BeyinGunBolumuDto(string Ad, List<BeyinGunMaddesiDto> Maddeler);

public record BeyinGunMaddesiDto(string Id, string Baslik, string? Durum, int? TahminDk, int? SureDk, string? Proje, string? Gorev);

public record GecikenGorevDto(string Kimlik, string Baslik, DateOnly? Bitis, int? Gun, string? Proje, string? Oncelik);

public record BeyinGunToplamiDto(int Madde, int Yapildi, int Acik);

public record AramaSonucuDto(string Yol, string Baslik, string? Proje, string? Alan, string? Alinti);

public record NotDto(string Yol, string Baslik, List<string> Etiketler, string Govde);
