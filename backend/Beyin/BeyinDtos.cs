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

// An open task the screens may offer (not hidden, not from a closed folder): for the pick lists of the day page.
public record AcikGorevDto(string Kimlik, string Baslik, string? Proje, string? Alan, DateOnly? Bitis);

public record GunlukSatiriDto(string? Zaman, string? Baslik, string? Metin);

public record BeyinGunDto(
    DateOnly Tarih, string? GunAdi, string? HaftaGunu, bool Bugun, bool PlanVar, bool Kapandi,
    List<BeyinGunBolumuDto> Bolumler, List<GecikenGorevDto> Geciken, BeyinGunToplamiDto? Toplam,
    GunKapasiteUyarisi? KapasiteUyarisi = null);

// "Bugün sığmıyor": the estimates of the open items add up to more than a day holds (Gun:KapasiteSaat).
public record GunKapasiteUyarisi(int AcikTahminDk, int KapasiteDk, int AsimDk);

// The morning card: what yesterday's plan left open, and the day the app counts as today.
public record SabahKartiDto(DateOnly Bugun, DateOnly Dun, bool DunKapandi, List<SabahMaddesiDto> Maddeler);

public record SabahMaddesiDto(string Id, string Baslik, string Bolum, int? TahminDk, string? Proje, string? Gorev);

public record BeyinGunBolumuDto(string Ad, List<BeyinGunMaddesiDto> Maddeler);

public record BeyinGunMaddesiDto(string Id, string Baslik, string? Durum, int? TahminDk, int? SureDk, string? Proje, string? Gorev);

public record GecikenGorevDto(string Kimlik, string Baslik, DateOnly? Bitis, int? Gun, string? Proje, string? Oncelik);

public record BeyinGunToplamiDto(int Madde, int Yapildi, int Acik);

public record AramaSonucuDto(string Yol, string Baslik, string? Proje, string? Alan, string? Alinti);

public record NotDto(string Yol, string Baslik, List<string> Etiketler, string Govde);

// The outcome of a read before it becomes an HTTP answer. `Durum` is the HTTP status (200 = `Veri` is set).
// A failure carries fixed Turkish texts (`Baslik`, `Ayrinti`) or, for a bad input, the field messages (`Alanlar`).
// The API turns it into a response (Sonuc); the web pages read it directly.
public record BeyinYaniti<T>(int Durum, T? Veri = default, string? Baslik = null, string? Ayrinti = null, Dictionary<string, string[]>? Alanlar = null)
{
    public bool Basarili => Durum == StatusCodes.Status200OK;

    // The brain is not set up on this machine: the pages say so instead of failing.
    public bool BagliDegil => Durum == StatusCodes.Status503ServiceUnavailable;

    public IResult Sonuc() =>
        Basarili ? Results.Ok(Veri)
        : Alanlar is not null ? Results.ValidationProblem(Alanlar)
        : Results.Problem(title: Baslik, detail: Ayrinti, statusCode: Durum);
}
