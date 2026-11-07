namespace Kafamdakiler.Beyin;

// What the write endpoints take and return (K2.3a). The plan item is named by its permanent id (`a3f09c`), never by its
// place in the list: a new item can come in between and the tick would land on the wrong one (K-0023 eki).

// Requests

public record MaddeEkleGirdi(string? Metin, string? Bolum, string? Gorev);

public record MaddeIsaretleGirdi(string? Madde, bool Geri = false);

public record MaddeDevretGirdi(string? Madde);

public record MaddeNotGirdi(string? Madde, string? Metin);

// Exactly one of Proje and Alan. Bitis is yyyy-MM-dd.
public record GorevEkleGirdi(string? Baslik, string? Proje, string? Alan, string? Bitis, string? SonrakiAdim, string? Olcut);

// Splits a task over days: one plan item per day (only the last is linked to the task), from Baslangic (default: today by the day-turn rule).
public record GunlereBolGirdi(int GunSayisi, string? Baslangic, string? Metin, string? Bolum);

// Answers

public record YazilanMaddeDto(string Id, string Baslik, string? Bolum, string? Durum, int? TahminDk, int? SureDk, string? Proje, string? Gorev);

public record MaddeEklendiDto(DateOnly Tarih, YazilanMaddeDto Madde, int? OnerilenTahminDk);

public record MaddeIsaretlendiDto(DateOnly Tarih, YazilanMaddeDto Madde, bool GorevKapandi);

public record MaddeDevredildiDto(DateOnly Tarih, DateOnly DevredilenGun, YazilanMaddeDto Madde);

public record MaddeNotuDto(DateOnly Tarih, YazilanMaddeDto Madde);

public record GorevEklendiDto(string Kimlik);

public record GorevBitirildiDto(string Kimlik, bool PlanMaddesiYapildi);

public record BolmeGunuDto(DateOnly Tarih, YazilanMaddeDto Madde);

public record BolmeHatasiDto(DateOnly Tarih, int Durum, string? Baslik, string? Ayrinti, bool YazilmisOlabilir);

// 200 when every day was written, 207 when the run stopped half way: `Yazilanlar` are the days that were written (the
// brain is not a transaction, nothing is rolled back) and `Hata` is the day that stopped it.
public record GunlereBolSonucuDto(string Gorev, int IstenenGun, bool Tamamlandi, List<BolmeGunuDto> Yazilanlar, BolmeHatasiDto? Hata);

// 202: the brain did not answer in time or answered badly after the command may have written. Look at the day before trying again.
public record BelirsizYazmaDto(bool Belirsiz, bool YazilmisOlabilir, string Baslik, string Ayrinti);
