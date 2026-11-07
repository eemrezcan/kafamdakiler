using System.Text;

namespace Kafamdakiler.Brifing;

// What the briefing is made from. The server works out every number and date; Claude is only handed them ready-made
// and never asked to count or to add up days. `Kimlik` is the id the card may link to.
public record BrifingMaddesi(string Kimlik, string Baslik, string? Bolum, int? TahminDk, string? Proje);

// `Gun` is the brain's day of the moment the reminder fires; `KalanGun` counts from the briefing's day (0 is today).
public record BrifingHatirlaticisi(string Kimlik, string Baslik, DateOnly Gun, string Saat, int KalanGun);

public record BrifingOnayi(string Kimlik, string Tur, string Ozet);

public record BrifingKapasitesi(int AcikDk, int KapasiteDk, int AsimDk);

// Calendar events of the day (K2.3c). Nothing fills this yet.
public record BrifingTakvimi(string Kimlik, string Baslik, string Saat);

public record BrifingGirdisi(
    DateOnly Gun, int PlanToplam, int PlanYapildi, List<BrifingMaddesi> Plan, List<BrifingMaddesi> Kalan,
    List<BrifingHatirlaticisi> Hatirlaticilar, int OnayBekleyen, List<BrifingOnayi> Onaylar,
    BrifingKapasitesi? Kapasite, List<BrifingTakvimi> Takvim)
{
    private static readonly string[] GunAdlari = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];

    // Nothing to say about the day. Then Claude is not asked at all: an empty-day card needs no model.
    public bool Bos =>
        Plan.Count == 0 && Kalan.Count == 0 && Hatirlaticilar.Count == 0 && Onaylar.Count == 0 && Kapasite is null && Takvim.Count == 0;

    // The kinds this input can back up. A card of any other kind is made up.
    public List<string> DesteklenenTurler()
    {
        var turler = new List<string>();
        if (Plan.Count > 0)
            turler.Add(BrifingTurleri.Plan);
        if (Kalan.Count > 0)
            turler.Add(BrifingTurleri.Kalan);
        if (Hatirlaticilar.Count > 0)
            turler.Add(BrifingTurleri.Hatirlatici);
        if (Onaylar.Count > 0)
            turler.Add(BrifingTurleri.Onay);
        if (Takvim.Count > 0)
            turler.Add(BrifingTurleri.Takvim);
        if (Kapasite is not null)
            turler.Add(BrifingTurleri.Kapasite);
        return turler;
    }

    // The ids a card of this kind may link to. Each kind has its own pool: a reminder card cannot point at a plan item.
    public HashSet<string> Havuz(string tur) => (tur switch
    {
        BrifingTurleri.Plan => Plan.Select(m => m.Kimlik),
        BrifingTurleri.Kalan => Kalan.Select(m => m.Kimlik),
        BrifingTurleri.Hatirlatici => Hatirlaticilar.Select(h => h.Kimlik),
        BrifingTurleri.Onay => Onaylar.Select(o => o.Kimlik),
        BrifingTurleri.Takvim => Takvim.Select(t => t.Kimlik),
        _ => [],
    }).ToHashSet(StringComparer.Ordinal);

    // The kinds that are about particular things; the capacity and empty-day cards are about the day as a whole.
    public static bool KimlikGerekir(string tur) => tur is not (BrifingTurleri.Kapasite or BrifingTurleri.Bos);

    public IEnumerable<string> TumKimlikler() =>
        Plan.Select(m => m.Kimlik).Concat(Kalan.Select(m => m.Kimlik)).Concat(Hatirlaticilar.Select(h => h.Kimlik))
            .Concat(Onaylar.Select(o => o.Kimlik)).Concat(Takvim.Select(t => t.Kimlik)).Distinct(StringComparer.Ordinal);

    public static string GunAdi(DateOnly gun) => GunAdlari[(int)gun.DayOfWeek];

    // "2 sa 30 dk", "45 dk", "3 sa".
    public static string Sure(int dakika)
    {
        var sa = dakika / 60;
        var dk = dakika % 60;
        return sa == 0 ? $"{dk} dk" : dk == 0 ? $"{sa} sa" : $"{sa} sa {dk} dk";
    }

    public static string GunAnlatimi(int kalanGun) => kalanGun switch
    {
        0 => "bugün",
        1 => "yarın",
        _ => $"{kalanGun} gün sonra",
    };

    // The data part of the call (it goes to Claude as untrusted text between the client's delimiters). A line is `id=<id> | ...`.
    // Titles and summaries can hold anything someone typed or a mail said, so each is flattened to one line.
    public string Metin()
    {
        var s = new StringBuilder();
        s.AppendLine($"Bugün: {Gun:yyyy-MM-dd} {GunAdi(Gun)}");

        if (Plan.Count > 0 || PlanToplam > 0)
        {
            s.AppendLine($"Bugünün planı: {PlanToplam} madde, {PlanYapildi} yapıldı, {Plan.Count} açık.");
            foreach (var m in Plan)
                s.AppendLine(Madde(m));
        }

        if (Kapasite is { } k)
            s.AppendLine($"Kapasite uyarısı: açık maddelerin tahmini {Sure(k.AcikDk)}, günün kapasitesi {Sure(k.KapasiteDk)}; {Sure(k.AsimDk)} fazla.");

        if (Kalan.Count > 0)
        {
            s.AppendLine($"Dünden kalan açık maddeler ({Kalan.Count}):");
            foreach (var m in Kalan)
                s.AppendLine(Madde(m));
        }

        if (Hatirlaticilar.Count > 0)
        {
            s.AppendLine($"Önümüzdeki günlerin hatırlatıcıları ({Hatirlaticilar.Count}):");
            foreach (var h in Hatirlaticilar)
                s.AppendLine($"- id={h.Kimlik} | {Satir(h.Baslik)} | {GunAnlatimi(h.KalanGun)} {h.Saat} ({h.Gun:yyyy-MM-dd} {GunAdi(h.Gun)})");
        }

        if (OnayBekleyen > 0)
        {
            s.AppendLine($"Onay bekleyen eylem sayısı: {OnayBekleyen}. En uzun bekleyenlerden {Onaylar.Count} tanesi:");
            foreach (var o in Onaylar)
                s.AppendLine($"- id={o.Kimlik} | {Satir(o.Tur)} | {Satir(o.Ozet)}");
        }

        if (Takvim.Count > 0)
        {
            s.AppendLine($"Bugünün takvim etkinlikleri ({Takvim.Count}):");
            foreach (var t in Takvim)
                s.AppendLine($"- id={t.Kimlik} | {Satir(t.Baslik)} | {Satir(t.Saat)}");
        }

        return s.ToString().TrimEnd();
    }

    private static string Madde(BrifingMaddesi m) =>
        $"- id={m.Kimlik} | {Satir(m.Baslik)}" +
        (m.Bolum is { Length: > 0 } ? $" | bölüm: {Satir(m.Bolum)}" : "") +
        (m.TahminDk is { } dk ? $" | tahmin: {Sure(dk)}" : "") +
        (m.Proje is { Length: > 0 } ? $" | proje: {Satir(m.Proje)}" : "");

    // One line, and the " | " the lines are split by cannot appear inside a value.
    internal static string Satir(string metin)
    {
        var tek = BrifingKartlari.Duzelt(metin).Replace('|', '/');
        return tek.Length <= 160 ? tek : tek[..160].TrimEnd();
    }
}
