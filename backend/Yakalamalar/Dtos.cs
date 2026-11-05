using System.ComponentModel.DataAnnotations;

namespace Kafamdakiler.Yakalamalar;

public class YakalamaYazDto : IValidatableObject
{
    // Only lowercase words after "projects/", so the hint cannot walk out of the folder.
    // (?![\s\S]) is "end of text" in .NET and in the browser's JS (the form reuses this pattern); $ would let a trailing newline through in .NET.
    public const string HedefKalibi = @"^projects/[a-z0-9]+(-[a-z0-9]+)*(?![\s\S])";

    public Guid? Id { get; set; }

    [StringLength(5000, ErrorMessage = "Metin en çok 5000 karakter olabilir.")]
    public string? Metin { get; set; }

    public Guid? FotografId { get; set; }

    [StringLength(100, ErrorMessage = "Hedef en çok 100 karakter olabilir.")]
    [RegularExpression(HedefKalibi, ErrorMessage = "Hedef 'projects/proje-adi' biçiminde olmalı.")]
    public string? Hedef { get; set; }

    [Required(ErrorMessage = "Yakalanma zamanı zorunlu.")]
    public DateTimeOffset? YakalandiAt { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (string.IsNullOrWhiteSpace(Metin) && FotografId is null)
            yield return new("Metin ya da fotoğraftan en az biri dolu olmalı.", ["metin"]);
    }
}

public record YakalamaDto(
    Guid Id, string? Metin, Guid? FotografId, string? FotografUrl, string? Hedef, YakalamaDurumu Durum,
    DateTimeOffset YakalandiAt, DateTimeOffset Olusturulma);
