using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Brifing;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Isler;
using Kafamdakiler.Yakalamalar;

namespace Kafamdakiler.Asistan;

// The assistant's single entry and its feed (K-0024, API sözleşmesi §7). Names and shapes are the contract's.

public enum AsistanKaynagi { Yazi, Ses, Paylas, Widget }

// `Id` is made by the client: the same id again is the same answer. Text or photo is required; the text is at most 4000 characters.
// `Bugun` (yyyy-MM-dd) is what "today" means for the dates in the text; it may differ from the server's day by one at most.
public class AsistanGirdisiDto : IValidatableObject
{
    public const int EnUzunMetin = 4000;

    [Required(ErrorMessage = "Id zorunlu.")]
    public Guid? Id { get; set; }

    [StringLength(EnUzunMetin, ErrorMessage = "Metin en çok 4000 karakter olabilir.")]
    public string? Metin { get; set; }

    public Guid? FotografId { get; set; }

    [Required(ErrorMessage = "Kaynak zorunlu (yazi, ses, paylas ya da widget).")]
    public AsistanKaynagi? Kaynak { get; set; }

    public DateOnly? Bugun { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Id == Guid.Empty)
            yield return new("Id boş olamaz.", ["id"]);
        if (string.IsNullOrWhiteSpace(Metin) && FotografId is null)
            yield return new("Metin ya da fotoğraftan en az biri dolu olmalı.", ["metin"]);
        if (Kaynak is { } k && !Enum.IsDefined(k))
            yield return new("Kaynak yazi, ses, paylas ya da widget olmalı.", ["kaynak"]);
    }
}

public class AsistanCevabiDto
{
    public const int EnUzunCevap = 500;

    [Required(ErrorMessage = "Cevap zorunlu.")]
    [StringLength(EnUzunCevap, ErrorMessage = "Cevap en çok 500 karakter olabilir.")]
    public string? Cevap { get; set; }
}

// `Uygulandi`: done. `IzinYok`: the person (or the kind's mode) does not allow it. `Hata`: tried and failed. `Gecersiz`: broke a rule
// (a date in the past, a project that does not exist...), nothing was tried.
public enum AsistanDurumu { Uygulandi, IzinYok, Hata, Gecersiz }

// Where a tap on the result goes: the id of what was made as the day list knows it ("m:", "g:", "h:"; a capture's or a card's own id) and a
// route of the app. Either may be null.
public record AsistanHedefiDto(string? Kimlik, string? Rota);

// `Tur`: hatirlatici-kur, plan-ekle, gorev-ekle, takvim-ekle, not or is. `GeriAlinabilir`: the kind can be undone and it is applied now
// (undo: POST /api/eylemler/{eylemId}/geri-al; for a note, DELETE /api/yakalamalar/{kimlik} while it is waiting; a card cannot be undone).
public record AsistanSonucuDto(
    string Tur, string Baslik, string Ozet, AsistanDurumu Durum, Guid? EylemId, AsistanHedefiDto Hedef, bool GeriAlinabilir, string? Mesaj);

public record AsistanSorusuDto(Guid Id, string Metin, List<string> Secenekler);

public record AsistanYanitiDto(Guid GirdiId, Guid MesajId, List<AsistanSonucuDto> Sonuclar, AsistanSorusuDto? Soru);

public enum AkisTuru { Kullanici, Sonuc, Soru, Onay, Is, Brifing, Not }

// One item of the feed. Only the fields of its kind are set: `Metin` for a message, a question and the briefing's summary, `Sonuclar` for a
// result, `Soru` for a question not answered yet, `Eylem` for an action waiting for approval, `Is` for an open card, `Brifing` for today's
// briefing, `Yakalama` for a capture of the last week.
public record AkisOgesiDto(
    string Id, DateTimeOffset Zaman, AkisTuru Tur, string? Metin, string? FotografUrl, List<AsistanSonucuDto>? Sonuclar, AsistanSorusuDto? Soru,
    EylemDto? Eylem, IsKartiDto? Is, BrifingDto? Brifing, YakalamaDto? Yakalama);

public record AsistanSayisiDto(int Bekleyen);
