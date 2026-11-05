using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;

namespace Kafamdakiler.Beyin;

public enum BeyinDurumu
{
    // The command ran and printed JSON.
    Tamam,
    // The brain is not configured, or its command or vault is missing on this machine.
    BagliDegil,
    // The command failed and said why: {"hata": {"kod", "mesaj"}}. Nothing was written.
    BeyinHatasi,
    // The command did not finish in time and was killed. It may or may not have written.
    ZamanAsimi,
    // The command exited without the JSON we expect. It may or may not have written.
    BozukCikti,
}

public record BeyinSonucu(BeyinDurumu Durum, JsonElement? Veri = null, string? HataKodu = null, string? Mesaj = null)
{
    public bool Basarili => Durum == BeyinDurumu.Tamam;

    // True when the command is known not to have changed anything, so the same call can be repeated safely.
    public bool GuvenleTekrarlanir => Durum is BeyinDurumu.BagliDegil or BeyinDurumu.BeyinHatasi;
}

// Calls `beyin.py <command> --json --vault <vault>` as a child process. No shell: every argument is one list item,
// so text and paths never get re-parsed.
public class BeyinIstemcisi(BeyinAyari ayar)
{
    public bool Bagli => ayar.Acik && File.Exists(ayar.Komut) && Directory.Exists(ayar.Vault);

    // `argumanlar` are the command words and options. `konumsal` are positional values (a search query, a note path):
    // they go last, after `--`, so a value that starts with a dash is never read as an option.
    public async Task<BeyinSonucu> CalistirAsync(IEnumerable<string> argumanlar, CancellationToken ct, IEnumerable<string>? konumsal = null)
    {
        if (!Bagli)
            return new BeyinSonucu(BeyinDurumu.BagliDegil, Mesaj: "Beyin bağlı değil.");

        var bilgi = new ProcessStartInfo(ayar.Python)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            RedirectStandardInput = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        bilgi.Environment["PYTHONIOENCODING"] = "utf-8";
        bilgi.ArgumentList.Add(ayar.Komut);
        foreach (var arguman in argumanlar)
            bilgi.ArgumentList.Add(arguman);
        bilgi.ArgumentList.Add("--json");
        bilgi.ArgumentList.Add("--vault");
        bilgi.ArgumentList.Add(ayar.Vault);
        if (konumsal is not null)
        {
            bilgi.ArgumentList.Add("--");
            foreach (var deger in konumsal)
                bilgi.ArgumentList.Add(deger);
        }

        using var surec = new Process { StartInfo = bilgi };
        try
        {
            surec.Start();
        }
        catch (Exception e) when (e is System.ComponentModel.Win32Exception or InvalidOperationException)
        {
            return new BeyinSonucu(BeyinDurumu.BagliDegil, Mesaj: $"Beyin komutu başlatılamadı: {e.Message}");
        }

        // The command never reads stdin for us (text goes through --metin-dosya); close it so it cannot wait on it.
        surec.StandardInput.Close();
        var cikti = surec.StandardOutput.ReadToEndAsync(CancellationToken.None);
        var hata = surec.StandardError.ReadToEndAsync(CancellationToken.None);

        using var sure = CancellationTokenSource.CreateLinkedTokenSource(ct);
        sure.CancelAfter(ayar.ZamanAsimi);
        try
        {
            await surec.WaitForExitAsync(sure.Token);
        }
        catch (OperationCanceledException)
        {
            surec.Kill(entireProcessTree: true);
            await surec.WaitForExitAsync(CancellationToken.None);
            ct.ThrowIfCancellationRequested();
            return new BeyinSonucu(BeyinDurumu.ZamanAsimi, Mesaj: $"Beyin komutu {ayar.ZamanAsimi.TotalSeconds:0} saniyede bitmedi.");
        }

        return Yorumla(surec.ExitCode, await cikti, await hata);
    }

    private static BeyinSonucu Yorumla(int cikisKodu, string cikti, string hata)
    {
        JsonElement govde;
        try
        {
            using var belge = JsonDocument.Parse(cikti);
            govde = belge.RootElement.Clone();
        }
        catch (JsonException)
        {
            return new BeyinSonucu(BeyinDurumu.BozukCikti, Mesaj: $"Beyin komutunun çıktısı JSON değil (çıkış kodu {cikisKodu}): {Kisalt(hata.Length > 0 ? hata : cikti)}");
        }

        if (govde.ValueKind == JsonValueKind.Object && govde.TryGetProperty("hata", out var h) && h.ValueKind == JsonValueKind.Object)
        {
            return new BeyinSonucu(BeyinDurumu.BeyinHatasi, HataKodu: Metin(h, "kod"), Mesaj: Metin(h, "mesaj") ?? "Beyin hata verdi.");
        }

        // A non-zero exit without the error JSON is not understood: do not call it a clean failure.
        return cikisKodu == 0
            ? new BeyinSonucu(BeyinDurumu.Tamam, govde)
            : new BeyinSonucu(BeyinDurumu.BozukCikti, Mesaj: $"Beyin komutu {cikisKodu} koduyla bitti: {Kisalt(hata.Length > 0 ? hata : cikti)}");
    }

    private static string? Metin(JsonElement nesne, string ad) =>
        nesne.TryGetProperty(ad, out var d) && d.ValueKind == JsonValueKind.String ? d.GetString() : null;

    private static string Kisalt(string metin) => metin.Length <= 300 ? metin.Trim() : metin[..300].Trim() + "…";

    // `gelen ekle`: the text goes through a file (a text such as "-" or "--x" would be read as an option on the command line).
    // `gorselYolu` must already be a JPEG.
    public async Task<BeyinSonucu> GelenEkleAsync(string? metin, string? gorselYolu, string? hedef, DateTimeOffset yakalandi, CancellationToken ct)
    {
        string? metinDosyasi = null;
        try
        {
            var argumanlar = new List<string> { "gelen", "ekle", $"--yakalandi={yakalandi.ToLocalTime().ToString("yyyy-MM-dd'T'HH:mm", CultureInfo.InvariantCulture)}" };
            if (!string.IsNullOrWhiteSpace(metin))
            {
                metinDosyasi = Path.Combine(Path.GetTempPath(), "kd-metin-" + Guid.NewGuid().ToString("N") + ".txt");
                await File.WriteAllTextAsync(metinDosyasi, metin, new UTF8Encoding(false), ct);
                argumanlar.Add($"--metin-dosya={metinDosyasi}");
            }

            if (gorselYolu is not null)
                argumanlar.Add($"--gorsel={gorselYolu}");
            if (!string.IsNullOrWhiteSpace(hedef))
                argumanlar.Add($"--hedef={hedef}");

            return await CalistirAsync(argumanlar, ct);
        }
        finally
        {
            if (metinDosyasi is not null)
                File.Delete(metinDosyasi);
        }
    }
}
