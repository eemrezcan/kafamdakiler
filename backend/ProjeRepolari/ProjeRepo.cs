using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace Kafamdakiler.ProjeRepolari;

// The link between a project of the brain (its id) and a GitHub repository (`owner/repo`), set by the Sahip (K2.5).
public class ProjeRepo
{
    public string ProjeKimligi { get; set; } = "";
    public string Depo { get; set; } = "";
    public DateTimeOffset GuncellendiAt { get; set; } = DateTimeOffset.UtcNow;
}

// The shape of `owner/repo` is checked before it goes into a URL path: GitHub's own limits on the owner (letters, digits and single
// hyphens, 39 at most) and the repository name (letters, digits, `.`, `_`, `-`, 100 at most; `.` and `..` are not names).
public static partial class DepoAdi
{
    public const string Mesaj = "Depo owner/repo biçiminde olmalı (ör. emre/kafamdakiler).";

    [GeneratedRegex(@"^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}/[A-Za-z0-9._-]{1,100}\z", RegexOptions.CultureInvariant)]
    private static partial Regex Kalip();

    public static bool Gecerli(string? depo) =>
        depo is { Length: > 0 and <= 140 } && Kalip().IsMatch(depo) && depo.Split('/')[1] is not ("." or "..");
}

public class ProjeRepoYazDto
{
    [Required(ErrorMessage = "Depo zorunlu.")]
    [StringLength(140, ErrorMessage = "Depo en çok 140 karakter olabilir.")]
    public string? Depo { get; set; }
}

public record ProjeRepoDto(string Proje, string Depo, string Baglanti);

public record RepoCommitDto(string Hash, string Mesaj, string? Yazar, DateTimeOffset? Tarih);

// `Durum`: tamam, tokenYok (only the link is shown), depoYok (404), oranSiniri, yetkiYok (the token is refused) or hata.
// `Commitler` and `AcikPrSayisi` are null unless `Durum` is tamam.
public record ProjeRepoOzetiDto(
    string Proje, string Depo, string Baglanti, string Durum, string? Mesaj,
    List<RepoCommitDto>? Commitler, int? AcikPrSayisi);
