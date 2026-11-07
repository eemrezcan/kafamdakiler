using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using Microsoft.Extensions.Validation;

namespace Kafamdakiler.Eylemler;

public record EylemDto(
    Guid Id, string Tur, string TurAdi, JsonElement Yuk, string Ozet, string Kaynak, bool DisKaynak, string? Gerekce, double? Guven,
    EylemDurumu Durum, JsonElement? GeriAlmaBilgisi, string? HataMesaji, DateTimeOffset CreatedAt, DateTimeOffset? KararAni,
    DateTimeOffset? UygulamaAni, DateTimeOffset? GeriAlmaAni, Guid? KararVerenId);

// A person may correct the payload before approving; left out, the suggested payload is applied.
public class EylemUygulaDto
{
    // Checked by the kind itself (IEylemTuru.Dogrula); the generic validator crashes trying to walk a JsonElement.
    // SkipValidation is marked evaluation-only in .NET 10 (ASP0029); if it goes away, read the body by hand instead.
#pragma warning disable ASP0029
    [SkipValidation]
#pragma warning restore ASP0029
    public JsonElement? Yuk { get; set; }
}

public class EylemReddetDto
{
    // Also makes the kind Yasak for good.
    public bool BirDahaOnerme { get; set; }
}

public class EylemKipYazDto
{
    [Required(ErrorMessage = "Kip zorunlu (sor, kendinYap ya da yasak).")]
    public EylemKipi? Kip { get; set; }
}

public record EylemKipiDto(string Tur, string TurAdi, EylemKipi Kip, int ArdArdaRed);

// A suggestion as the other modules hand it to EylemServisi.OnerAsync.
public record EylemOnerisi(
    string Tur, JsonElement Yuk, string Ozet, string Kaynak, bool DisKaynak, string? Gerekce = null, double? Guven = null);
