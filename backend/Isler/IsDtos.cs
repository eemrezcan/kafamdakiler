namespace Kafamdakiler.Isler;

// Work cards of the brain (`beyin.py is ...`, brain README "İş kartı"). Built field by field from the brain's `--json`;
// the path of the card file never leaves (`yol`), nor does anything else the screens do not need.
// Times stay as the brain writes them ("2026-11-10T14:30", Istanbul, no zone): the phone only shows them.

public record IsKartiDto(
    string Kimlik, string Baslik, string Tip, string Asama, string Sahip, string? Kilit, string? Proje, string? Alan, string Kaynak,
    string? Olusma, string? Guncelleme, int BekleyenSoru, List<string> Gecisler, bool Acik);

public record IsSorusuDto(int No, string Soru, List<string> Secenekler, string? Onerilen, string? Neden, string? Cevap);

public record IsGecmisiDto(string Zaman, string Olay, string Kim);

public record IsAyrintiDto(
    string Kimlik, string Baslik, string Tip, string Asama, string Sahip, string? Kilit, string? Proje, string? Alan, string Kaynak,
    string? Olusma, string? Guncelleme, int BekleyenSoru, List<string> Gecisler, bool Acik,
    string Talep, string Plan, List<IsSorusuDto> Sorular, List<IsGecmisiDto> Gecmis);

// `Tip`: kod | genel | yeni-proje. Exactly one of Proje and Alan.
public record IsAcGirdi(string? Baslik, string? Talep, string? Proje, string? Alan, string? Tip);

public record IsCevapGirdi(int SoruNo, string? Cevap);

// `Gerekce` only goes with "iptal". `Not` is optional and lands in the card's history.
public record IsAsamaGirdi(string? Asama, string? Gerekce, string? Not);

public record IsNotGirdi(string? Metin);

// A button on the notification of a card. "cevap": answer question `SoruNo` with `Cevap`. "asama": move the card to `Asama`.
public record BildirimSecenegiDto(string Etiket, string Eylem, int? SoruNo = null, string? Cevap = null, string? Asama = null);
