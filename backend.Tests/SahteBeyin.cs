using System.Text.Json;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Tests;

// A fake beyin.py: a small Python script in a temp folder. It logs every call (arguments, the text file's content,
// the first bytes of the image) to log.jsonl and then behaves as mod.txt says: ok | hata | bozuk | yavas | uyku.
public sealed class SahteBeyin : IDisposable
{
    private const string Betik = """
        import sys, json, os, time
        d = os.path.dirname(os.path.abspath(__file__))
        mod = open(os.path.join(d, "mod.txt")).read().strip()
        argv = sys.argv[1:]
        kayit = {"argv": argv}
        for a in argv:
            if a.startswith("--metin-dosya="):
                kayit["metin"] = open(a.split("=", 1)[1], encoding="utf-8").read()
            if a.startswith("--gorsel="):
                p = a.split("=", 1)[1]
                kayit["gorsel"] = p
                kayit["gorsel_bas"] = open(p, "rb").read(3).hex()
        with open(os.path.join(d, "log.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(kayit) + "\n")
        gecikme = os.path.join(d, "gecikme.txt")
        if os.path.exists(gecikme):
            time.sleep(float(open(gecikme).read()))
        if mod == "uyku":
            time.sleep(60)
        if mod == "yavas":
            time.sleep(1)
        if mod == "hata":
            print(json.dumps({"hata": {"kod": "gecersiz", "mesaj": "kötü istek"}}, ensure_ascii=False))
            sys.exit(1)
        if mod == "bozuk":
            print("???")
            sys.exit(0)
        if mod == "cikti":
            onek = "-".join(argv[:2])
            sira = os.path.join(d, "sira-" + onek + ".json")
            if os.path.exists(sira):
                adimlar = json.load(open(sira, encoding="utf-8"))
                n = sum(1 for satir in open(os.path.join(d, "log.jsonl"), encoding="utf-8") if json.loads(satir)["argv"][:2] == argv[:2])
                adim = adimlar[min(n, len(adimlar)) - 1]
                print(adim["cikti"])
                sys.exit(adim["cikis"])
            konum = argv[argv.index("--") + 1:] if "--" in argv else []
            if konum:
                konumlu = os.path.join(d, "cikti-" + onek + "@" + konum[0].replace("/", "_") + ".json")
                if os.path.exists(konumlu):
                    print(open(konumlu, encoding="utf-8").read())
                    konumlu_cikis = os.path.join(d, "cikis-" + onek + "@" + konum[0].replace("/", "_") + ".txt")
                    sys.exit(int(open(konumlu_cikis).read()) if os.path.exists(konumlu_cikis) else 0)
            ozel = os.path.join(d, "cikti-" + onek + ".json")
            if os.path.exists(ozel):
                print(open(ozel, encoding="utf-8").read())
                ozel_cikis = os.path.join(d, "cikis-" + onek + ".txt")
                sys.exit(int(open(ozel_cikis).read()) if os.path.exists(ozel_cikis) else 0)
            print(open(os.path.join(d, "cikti.json"), encoding="utf-8").read())
            sys.exit(int(open(os.path.join(d, "cikis.txt")).read()) if os.path.exists(os.path.join(d, "cikis.txt")) else 0)
        print(json.dumps({"yol": "gelen/x.md"}))
        """;

    public SahteBeyin(string mod = "ok")
    {
        Klasor = Path.Combine(Path.GetTempPath(), "kd-sahte-" + Guid.NewGuid().ToString("N"));
        Vault = Path.Combine(Klasor, "vault");
        Directory.CreateDirectory(Vault);
        Komut = Path.Combine(Klasor, "beyin.py");
        File.WriteAllText(Komut, Betik);
        Mod = mod;
    }

    public string Klasor { get; }
    public string Vault { get; }
    public string Komut { get; }

    public string Mod
    {
        set => File.WriteAllText(Path.Combine(Klasor, "mod.txt"), value);
    }

    // From now on the fake prints this JSON and exits with this code (mod "cikti").
    public void Cikti(string json, int cikis = 0)
    {
        File.WriteAllText(Path.Combine(Klasor, "cikti.json"), json);
        File.WriteAllText(Path.Combine(Klasor, "cikis.txt"), cikis.ToString());
        Mod = "cikti";
    }

    // Every call waits this long before it answers (whatever the mode): to have two requests in flight at once.
    public void Gecikme(double saniye) => File.WriteAllText(Path.Combine(Klasor, "gecikme.txt"), saniye.ToString(System.Globalization.CultureInfo.InvariantCulture));

    // From now on this command (its first two words, e.g. "gun ekle") prints this JSON, whatever Cikti says for the others.
    public void Cikti(string komut, string json, int cikis = 0)
    {
        var onek = komut.Replace(' ', '-');
        File.WriteAllText(Path.Combine(Klasor, $"cikti-{onek}.json"), json);
        File.WriteAllText(Path.Combine(Klasor, $"cikis-{onek}.txt"), cikis.ToString());
        Mod = "cikti";
    }

    // From now on this command prints this JSON when its first positional value (the one after `--`, e.g. a note path) is `konumsal`.
    public void CiktiKonumsal(string komut, string konumsal, string json, int cikis = 0)
    {
        var anahtar = $"{komut.Replace(' ', '-')}@{konumsal.Replace('/', '_')}";
        File.WriteAllText(Path.Combine(Klasor, $"cikti-{anahtar}.json"), json);
        File.WriteAllText(Path.Combine(Klasor, $"cikis-{anahtar}.txt"), cikis.ToString());
        Mod = "cikti";
    }

    // The 1st call of this command prints the 1st step, the 2nd the 2nd... (the last step repeats).
    public void Sirali(string komut, params (string Json, int Cikis)[] adimlar)
    {
        var liste = adimlar.Select(a => new { cikti = a.Json, cikis = a.Cikis });
        File.WriteAllText(Path.Combine(Klasor, $"sira-{komut.Replace(' ', '-')}.json"), JsonSerializer.Serialize(liste));
        Mod = "cikti";
    }

    public BeyinAyari Ayar(TimeSpan? zamanAsimi = null) => new()
    {
        Komut = Komut,
        Vault = Vault,
        ZamanAsimi = zamanAsimi ?? TimeSpan.FromSeconds(20),
        GonderimGecikmesi = TimeSpan.FromMinutes(10),
    };

    public BeyinIstemcisi Istemci(TimeSpan? zamanAsimi = null) => new(Ayar(zamanAsimi));

    // One entry per call of the fake command.
    public List<JsonElement> Cagrilar()
    {
        var yol = Path.Combine(Klasor, "log.jsonl");
        return File.Exists(yol)
            ? File.ReadAllLines(yol).Select(s => JsonDocument.Parse(s).RootElement.Clone()).ToList()
            : [];
    }

    public static string[] Argumanlar(JsonElement cagri) =>
        cagri.GetProperty("argv").EnumerateArray().Select(a => a.GetString()!).ToArray();

    public void Dispose()
    {
        if (Directory.Exists(Klasor))
            Directory.Delete(Klasor, recursive: true);
    }
}
