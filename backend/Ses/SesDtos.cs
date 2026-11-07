using Kafamdakiler.Eylemler;

namespace Kafamdakiler.Ses;

// What the voice endpoints take and return (K2.4). The phone turns speech into text; the server never sees audio.

// Requests

// `Bugun` (yyyy-MM-dd) is optional: it is what "today" means when Claude turns "yarın" into a date. Left out, the server's day
// counts, by the 05:00 rule. It may differ from the server's day by one at most.
public record IsCikarGirdi(string? Metin, string? Bugun = null);

public record IsCikarUygulaGirdi(List<IsOnerisi>? Secilenler);

// `Kip` is "ozet" or "madde".
public record YenidenYazGirdi(string? Metin, string? Kip);

// One suggestion, in the shape of the preview and of the apply request alike: the person may correct any field in between.
// `Tur` is hatirlatici-kur, plan-ekle or gorev-ekle; `Baslik` is the reminder's title, the plan item's text or the task's title.
// Dates are yyyy-MM-dd, `Saat` is HH:mm, `Tekrar` is yok, gunluk, haftalik, aylik or yillik.
//   hatirlatici-kur: Gun (required), Saat, Tekrar
//   plan-ekle:       Gun (required), Bolum, TahminDk
//   gorev-ekle:      Proje or Alan (exactly one), Bitis
// `KaynakParca` (the sentence it came from) and `Guven` (0 to 1) only travel along.
public record IsOnerisi(
    string Tur, string Baslik, string? Gun = null, string? Saat = null, string? Tekrar = null, string? Bolum = null,
    int? TahminDk = null, string? Proje = null, string? Alan = null, string? Bitis = null, string? KaynakParca = null, double? Guven = null);

// Answers

// The preview. Nothing was saved. `Atlananlar` are the suggestions Claude made that broke a rule (a date in the past, a project
// that does not exist...), with the reason, so a missing suggestion is never silent.
public record IsCikarYaniti(string Bugun, string HaftaninGunu, List<IsOnerisi> Oneriler, List<AtlananOneri> Atlananlar);

public record AtlananOneri(string? Tur, string? Baslik, string? KaynakParca, string Neden);

// `Durum` is uygulandi, hata (tried and failed: the action is kept as Hatali in the queue), gecersiz (broke a rule, nothing was
// tried) or izinYok (the person may not do what this kind does).
public record IsUygulaSonucu(int Sira, string Durum, EylemDto? Eylem, string? Alan, string? Mesaj);

// 200 when every suggestion was applied, 207 when some were not. The ones that were applied stay applied.
public record IsCikarUygulaYaniti(int Uygulanan, int Basarisiz, List<IsUygulaSonucu> Sonuclar);

public record YenidenYazYaniti(string Metin);

// What Claude is asked for.

public record ClaudeIsCikarCevabi(List<IsOnerisi> Oneriler);

public record ClaudeYenidenYazCevabi(string Metin);
