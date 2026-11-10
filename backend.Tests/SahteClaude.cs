using System.Text.Json;
using Kafamdakiler.Claude;
using Microsoft.Extensions.Logging;

namespace Kafamdakiler.Tests;

// A fake `claude`: an executable Python script in a temp folder, so the client starts a real child process with its
// real arguments and stdin. It logs every call (arguments, working folder and what is in it, stdin, start and end
// times) to log.jsonl and then behaves as mod.txt says: ok | uyku | yavas | cikti. No real Claude is ever called.
public sealed class SahteClaude : IDisposable
{
    private const string Betik = """
        #!/usr/bin/env python3
        import sys, json, os, time
        d = os.path.dirname(os.path.abspath(__file__))
        mod = open(os.path.join(d, "mod.txt")).read().strip()
        basla = time.time()
        kayit = {"argv": sys.argv[1:], "cwd": os.getcwd(), "cwd_icerik": os.listdir(os.getcwd()), "stdin": sys.stdin.read(), "basla": basla}
        if mod == "uyku":
            with open(os.path.join(d, "log.jsonl"), "a", encoding="utf-8") as f:
                f.write(json.dumps(kayit) + "\n")
            time.sleep(60)
        if mod == "yavas":
            time.sleep(1)
        kayit["bitis"] = time.time()
        with open(os.path.join(d, "log.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(kayit) + "\n")
        if "--model" in sys.argv and "haiku" in sys.argv[sys.argv.index("--model") + 1] and "=== MAIL " in kayit["stdin"] and mod != "ham":
            import re
            hp = os.path.join(d, "haiku.json")
            ayar = json.load(open(hp, encoding="utf-8")) if os.path.exists(hp) else {}
            mailler = [{"kimlik": k, "onemli": k not in ayar.get("onemsiz", []), "gerekce": "kisa"} for k in re.findall(r"=== MAIL (\S+) ===", kayit["stdin"]) if k not in ayar.get("atla", [])]
            print(json.dumps({"type": "result", "is_error": False, "result": "tamam", "structured_output": {"mailler": mailler}, "usage": {"input_tokens": 10, "output_tokens": 5}}))
            sys.exit(0)
        sirap = os.path.join(d, "sira.json")
        if os.path.exists(sirap):
            adimlar = json.load(open(sirap, encoding="utf-8"))
            n = sum(1 for _ in open(os.path.join(d, "log.jsonl"), encoding="utf-8"))
            print(adimlar[min(n, len(adimlar)) - 1])
            sys.exit(0)
        print(open(os.path.join(d, "cikti.json"), encoding="utf-8").read())
        sys.exit(int(open(os.path.join(d, "cikis.txt")).read()) if os.path.exists(os.path.join(d, "cikis.txt")) else 0)
        """;

    public SahteClaude(string structuredOutput = """{"baslik":"x"}""")
    {
        Klasor = Path.Combine(Path.GetTempPath(), "kd-sahte-claude-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Klasor);
        Komut = Path.Combine(Klasor, "claude");
        File.WriteAllText(Komut, Betik);
        // The fake is a script with a shebang line, so it needs the execute bit (these tests run on Linux).
        if (!OperatingSystem.IsWindows())
            File.SetUnixFileMode(Komut, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);
        Mod("ok");
        YapiliYanit(structuredOutput);
    }

    public string Klasor { get; }
    public string Komut { get; }

    public void Mod(string mod) => File.WriteAllText(Path.Combine(Klasor, "mod.txt"), mod);

    // The envelope `claude -p --output-format json` prints, with a checked answer in structured_output.
    public void YapiliYanit(string structuredOutput, int girdiToken = 10, int cikisToken = 5) => Cikti(
        $$$"""{"type":"result","subtype":"success","is_error":false,"result":"tamam","structured_output":{{{structuredOutput}}},"usage":{"input_tokens":{{{girdiToken}}},"output_tokens":{{{cikisToken}}}}}""");

    // The 1st call prints the 1st answer, the 2nd the 2nd... (the last one repeats). Each is the checked answer of a call (structured_output).
    public void YapiliSirali(params string[] structuredOutputs) => File.WriteAllText(
        Path.Combine(Klasor, "sira.json"),
        JsonSerializer.Serialize(structuredOutputs.Select(o =>
            $$$"""{"type":"result","subtype":"success","is_error":false,"result":"tamam","structured_output":{{{o}}},"usage":{"input_tokens":10,"output_tokens":5}}""")));

    // From now on the fake prints this text as is and exits with this code.
    public void Cikti(string metin, int cikis = 0)
    {
        File.WriteAllText(Path.Combine(Klasor, "cikti.json"), metin);
        File.WriteAllText(Path.Combine(Klasor, "cikis.txt"), cikis.ToString());
    }

    // What the cheap "important?" call (a haiku call with mails in its data) answers: every mail important, except the ones named
    // in `onemsiz`; the ones in `atla` are left out of the answer.
    public void HaikuCevabi(string[]? onemsiz = null, string[]? atla = null) => File.WriteAllText(
        Path.Combine(Klasor, "haiku.json"), JsonSerializer.Serialize(new { onemsiz = onemsiz ?? [], atla = atla ?? [] }));

    public ClaudeAyari Ayar(TimeSpan? zamanAsimi = null, int esZamanli = 1, int gunluk = 50) => new()
    {
        Komut = Komut,
        Model = "sonnet",
        ZamanAsimi = zamanAsimi ?? TimeSpan.FromSeconds(20),
        EsZamanliEnCok = esZamanli,
        GunlukEnCokCagri = gunluk,
    };

    public ClaudeIstemcisi Istemci(TimeSpan? zamanAsimi = null, int esZamanli = 1, int gunluk = 50, TimeProvider? saat = null, ILogger<ClaudeIstemcisi>? kayit = null) =>
        new(Ayar(zamanAsimi, esZamanli, gunluk), saat ?? TimeProvider.System, kayit ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<ClaudeIstemcisi>.Instance);

    // One entry per call of the fake command.
    public List<JsonElement> Cagrilar()
    {
        var yol = Path.Combine(Klasor, "log.jsonl");
        return File.Exists(yol)
            ? File.ReadAllLines(yol).Select(s => JsonDocument.Parse(s).RootElement.Clone()).ToList()
            : [];
    }

    // The calls made with a model whose name holds `model`.
    public List<JsonElement> Cagrilar(string model) =>
        Cagrilar().Where(c => Argumanlar(c) is var a && a[Array.IndexOf(a, "--model") + 1].Contains(model, StringComparison.OrdinalIgnoreCase)).ToList();

    public static string[] Argumanlar(JsonElement cagri) =>
        cagri.GetProperty("argv").EnumerateArray().Select(a => a.GetString()!).ToArray();

    public void Dispose()
    {
        if (Directory.Exists(Klasor))
            Directory.Delete(Klasor, recursive: true);
    }
}

// A clock the test moves by hand.
public sealed class ElleSaat(DateTimeOffset baslangic) : TimeProvider
{
    public DateTimeOffset Simdi { get; set; } = baslangic;

    public override DateTimeOffset GetUtcNow() => Simdi;
}

// Collects the formatted log lines so a test can check what is (not) written.
public sealed class ToplayanGunluk : ILogger<ClaudeIstemcisi>
{
    public List<string> Satirlar { get; } = [];

    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;

    public bool IsEnabled(LogLevel logLevel) => true;

    public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
        Satirlar.Add(formatter(state, exception));
}
