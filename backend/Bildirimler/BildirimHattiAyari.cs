using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Kafamdakiler.Bildirimler;

// The "BildirimHatti" settings: the one server-side timer behind the reminders and the brain's tasks.
public class BildirimHattiAyari
{
    // How often the reminders are looked at, and how long after start-up the first look comes.
    public TimeSpan KontrolAraligi { get; init; } = TimeSpan.FromMinutes(1);

    public TimeSpan IlkGecikme { get; init; } = TimeSpan.FromSeconds(30);

    // A reminder whose moment passed while the server was down is still sent if it is this late at most; an older one is skipped
    // (a "call Ali" at 09:00 that arrives at 15:00 would only confuse).
    public TimeSpan EnGecGecikme { get; init; } = TimeSpan.FromMinutes(15);

    // The hours (Istanbul) the brain's tasks are looked at, and how long after the hour a late round still counts as that hour's.
    public IReadOnlyList<TimeOnly> GorevSaatleri { get; init; } = [new(9, 0), new(14, 0), new(19, 0)];

    public TimeSpan GorevPenceresi { get; init; } = TimeSpan.FromMinutes(30);

    // Where the read-only clones of the project repositories are: `<RepoKlasoru>/<project id>`. A project without a clone has no
    // commit evidence.
    public string RepoKlasoru { get; init; } = "/srv/repolar";

    public static BildirimHattiAyari Oku(IConfiguration config)
    {
        var bolum = config.GetSection("BildirimHatti");
        var saatler = (bolum["GorevSaatleri"] ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => TimeOnly.TryParseExact(s, "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var t) ? t : (TimeOnly?)null)
            .OfType<TimeOnly>().Distinct().Order().ToList();

        var varsayilan = new BildirimHattiAyari();
        return new BildirimHattiAyari
        {
            KontrolAraligi = TimeSpan.FromMinutes(Math.Max(0.05, bolum.GetValue("KontrolDakika", 1.0))),
            IlkGecikme = TimeSpan.FromSeconds(Math.Max(0, bolum.GetValue("IlkGecikmeSaniye", 30.0))),
            EnGecGecikme = TimeSpan.FromMinutes(Math.Max(1, bolum.GetValue("EnGecGecikmeDakika", 15.0))),
            GorevSaatleri = saatler.Count > 0 ? saatler : varsayilan.GorevSaatleri,
            GorevPenceresi = TimeSpan.FromMinutes(Math.Max(1, bolum.GetValue("GorevPenceresiDakika", 30.0))),
            RepoKlasoru = bolum["RepoKlasoru"] is { Length: > 0 } klasor ? klasor : varsayilan.RepoKlasoru,
        };
    }
}

// The last commits of a project's clone. Behind an interface so the tests never run git.
public interface IKomitOkuyucu
{
    // Newest first; empty when the project has no clone (or git failed): no evidence, never an error.
    Task<IReadOnlyList<GitKomiti>> SonKomitlerAsync(string proje, CancellationToken ct);
}

// `git log` on the clone, as a child process. No shell: every argument is one list item. The project id has been checked by the
// caller (lower case, digits, dashes), so it cannot leave the folder.
public partial class GitKomitOkuyucu(BildirimHattiAyari ayar, ILogger<GitKomitOkuyucu> log) : IKomitOkuyucu
{
    public const int KomitSayisi = 50;

    private static readonly TimeSpan ZamanAsimi = TimeSpan.FromSeconds(10);

    [GeneratedRegex(@"^[a-z0-9]+(-[a-z0-9]+)*\z", RegexOptions.CultureInvariant)]
    private static partial Regex ProjeKalibi();

    public async Task<IReadOnlyList<GitKomiti>> SonKomitlerAsync(string proje, CancellationToken ct)
    {
        if (!ProjeKalibi().IsMatch(proje) || proje.Length > 100)
            return [];

        var klasor = Path.Combine(ayar.RepoKlasoru, proje);
        if (!Directory.Exists(klasor))
            return [];

        var bilgi = new ProcessStartInfo("git")
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            StandardOutputEncoding = Encoding.UTF8,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        // The clone belongs to another user (the sync job), so git would refuse it as "dubious ownership" without this.
        foreach (var arguman in new[] { "-c", "safe.directory=*", "-C", klasor, "log", $"-n{KomitSayisi}", "--no-color", "--format=%H%x1f%B%x1e" })
            bilgi.ArgumentList.Add(arguman);

        try
        {
            using var surec = Process.Start(bilgi)!;
            surec.StandardInput.Close();
            var cikti = surec.StandardOutput.ReadToEndAsync(CancellationToken.None);
            _ = surec.StandardError.ReadToEndAsync(CancellationToken.None);
            using var sure = CancellationTokenSource.CreateLinkedTokenSource(ct);
            sure.CancelAfter(ZamanAsimi);
            try
            {
                await surec.WaitForExitAsync(sure.Token);
            }
            catch (OperationCanceledException)
            {
                surec.Kill(entireProcessTree: true);
                ct.ThrowIfCancellationRequested();
                log.LogWarning("git log on the clone of {Proje} did not finish in time.", proje);
                return [];
            }

            if (surec.ExitCode != 0)
            {
                log.LogWarning("git log on the clone of {Proje} exited with {Kod}.", proje, surec.ExitCode);
                return [];
            }

            return (await cikti).Split('\u001e', StringSplitOptions.RemoveEmptyEntries)
                .Select(blok => blok.Trim().Split('\u001f', 2))
                .Where(parca => parca.Length == 2 && parca[0].Length >= 7)
                .Select(parca => new GitKomiti(parca[0], parca[1].Trim()))
                .ToList();
        }
        catch (Exception e) when (e is System.ComponentModel.Win32Exception or InvalidOperationException)
        {
            log.LogWarning(e, "git could not be started for the clone of {Proje}.", proje);
            return [];
        }
    }
}
