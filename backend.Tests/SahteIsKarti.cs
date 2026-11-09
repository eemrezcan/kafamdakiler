using System.Text.Json;

namespace Kafamdakiler.Tests;

// What the real `beyin.py is ... --json` prints for a work card (brain README "İş kartı"), for the fake brain. The shape is the one
// read off the real command in GercekBeyinIsTests; the fake only fills in the fields the tests care about.
internal static class SahteIsKarti
{
    public record Soru(int No, string Metin, string[]? Secenekler = null, string? Onerilen = null, string? Neden = null, string? Cevap = null);

    public static string Kart(
        string kimlik, string asama = "karar", string sahip = "kullanici", string? baslik = null, string? proje = "kitap-kulubu", string? alan = null,
        string guncelleme = "2026-11-10T09:00", int bekleyenSoru = 0, bool gizli = false, string? yol = null, string? hata = null, string tip = "kod",
        string[]? gecisler = null)
    {
        var acik = asama is not ("bitti" or "iptal");
        return JsonSerializer.Serialize(Nesne(kimlik, asama, sahip, baslik, proje, alan, guncelleme, bekleyenSoru, gizli, yol, hata, tip, gecisler, acik));
    }

    public static string Liste(params string[] kartlar) => "[" + string.Join(",", kartlar) + "]";

    public static string Ayrinti(
        string kimlik, string asama = "karar", string sahip = "kullanici", string? baslik = null, string talep = "Talep metni", string plan = "## Adımlar\n- bir",
        Soru[]? sorular = null, string[]? gecmis = null, string guncelleme = "2026-11-10T09:00", string tip = "kod")
    {
        sorular ??= [];
        var kart = Nesne(kimlik, asama, sahip, baslik, "kitap-kulubu", null, guncelleme, sorular.Count(s => s.Cevap is null), false, null, null, tip, null, asama is not ("bitti" or "iptal"));
        kart["talep"] = talep;
        kart["plan"] = plan;
        kart["sorular"] = sorular.Select(s => new Dictionary<string, object?>
        {
            ["no"] = s.No, ["soru"] = s.Metin, ["secenekler"] = s.Secenekler ?? [], ["onerilen"] = s.Onerilen, ["neden"] = s.Neden, ["cevap"] = s.Cevap,
        }).ToList();
        // Each history line is "kim: olay"; the last one is the card's latest event.
        kart["gecmis"] = (gecmis ?? ["vps: plan yazıldı"]).Select(g =>
        {
            var parca = g.Split(": ", 2);
            return new Dictionary<string, object?> { ["zaman"] = "2026-11-10 09:00", ["olay"] = parca[1], ["kim"] = parca[0] };
        }).ToList();
        return JsonSerializer.Serialize(kart);
    }

    private static Dictionary<string, object?> Nesne(
        string kimlik, string asama, string sahip, string? baslik, string? proje, string? alan, string guncelleme, int bekleyenSoru, bool gizli,
        string? yol, string? hata, string tip, string[]? gecisler, bool acik) => new()
    {
        ["kimlik"] = kimlik,
        ["baslik"] = baslik ?? "Kart " + kimlik,
        ["yol"] = yol ?? (proje is not null ? $"projects/{proje}/isler/{kimlik}.md" : $"{alan}/isler/{kimlik}.md"),
        ["tip"] = tip,
        ["asama"] = asama,
        ["sahip"] = sahip,
        ["kilit"] = null,
        ["kilit_ani"] = null,
        ["kilit_gecerli"] = false,
        ["oturum"] = null,
        ["kaynak"] = "telefon",
        ["gorev"] = null,
        ["proje"] = proje,
        ["alan"] = alan,
        ["olusma"] = "2026-11-09T08:00",
        ["guncelleme"] = guncelleme,
        ["tags"] = Array.Empty<string>(),
        ["acik"] = acik,
        ["gizli"] = gizli,
        ["bekleyen_soru"] = bekleyenSoru,
        ["gecisler"] = gecisler ?? (acik ? new[] { "plan", "iptal" } : []),
        ["hata"] = hata,
    };

    // The brain's refusal: the JSON on stdout (and exit code 1). The message holds a path on purpose: it must never reach a client.
    public static string Hata(string kod, string mesaj = "ayrıntı /home/biri/vault/projects/x/isler/y.md") =>
        JsonSerializer.Serialize(new { hata = new { kod, mesaj } });
}
