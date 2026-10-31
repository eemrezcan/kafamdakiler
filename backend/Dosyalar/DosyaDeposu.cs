using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Dosyalar;

// Files live on disk outside wwwroot; the database keeps only their info (K-0015).
public class DosyaDeposu(AppDbContext db, IConfiguration config, IWebHostEnvironment env)
{
    public const long EnBuyukBoyut = 10 * 1024 * 1024;

    private static readonly Dictionary<string, string> Uzantilar = new()
    {
        ["image/jpeg"] = ".jpg",
        ["image/png"] = ".png",
        ["image/webp"] = ".webp",
    };

    private string Klasor
    {
        get
        {
            var klasor = config["Dosyalar:Klasor"];
            if (string.IsNullOrWhiteSpace(klasor))
                throw new InvalidOperationException("Dosyalar:Klasor is not configured.");

            return Path.GetFullPath(klasor, env.ContentRootPath);
        }
    }

    // The type comes from the file's first bytes; the name and content type the client sends are not trusted.
    public static string? TurBul(ReadOnlySpan<byte> bas)
    {
        if (bas.Length >= 3 && bas[0] == 0xFF && bas[1] == 0xD8 && bas[2] == 0xFF)
            return "image/jpeg";
        if (bas.Length >= 4 && bas[0] == 0x89 && bas[1] == 0x50 && bas[2] == 0x4E && bas[3] == 0x47)
            return "image/png";
        if (bas.Length >= 12 && bas[..4].SequenceEqual("RIFF"u8) && bas[8..12].SequenceEqual("WEBP"u8))
            return "image/webp";

        return null;
    }

    // Checks size and type, then stores the upload. On refusal the message says what to fix.
    public async Task<(Dosya? Dosya, string? Hata)> YukleAsync(IFormFile dosya, CancellationToken ct)
    {
        if (dosya.Length is 0 or > EnBuyukBoyut)
            return (null, "Dosya boş olamaz ve en çok 10 MB olabilir.");

        await using var akis = dosya.OpenReadStream();
        var bas = new byte[12];
        var okunan = await akis.ReadAtLeastAsync(bas, bas.Length, throwOnEndOfStream: false, ct);

        var tur = TurBul(bas.AsSpan(0, okunan));
        if (tur is null)
            return (null, "Yalnız jpg, png ve webp kabul edilir.");

        return (await KaydetAsync(akis, tur, ct), null);
    }

    private async Task<Dosya> KaydetAsync(Stream icerik, string icerikTuru, CancellationToken ct)
    {
        var dosya = new Dosya
        {
            DiskAdi = Guid.NewGuid().ToString("N") + Uzantilar[icerikTuru],
            IcerikTuru = icerikTuru,
            Boyut = icerik.Length,
        };

        Directory.CreateDirectory(Klasor);
        await using (var hedef = File.Create(YolBul(dosya)))
        {
            icerik.Position = 0;
            await icerik.CopyToAsync(hedef, ct);
        }

        db.Dosyalar.Add(dosya);
        await db.SaveChangesAsync(ct);
        return dosya;
    }

    public string YolBul(Dosya dosya) => Path.Combine(Klasor, dosya.DiskAdi);

    // Removes the rows and the files. Missing files are not an error.
    public async Task SilAsync(IEnumerable<Guid> idler, CancellationToken ct)
    {
        var liste = idler.ToList();
        if (liste.Count == 0)
            return;

        var dosyalar = await db.Dosyalar.Where(d => liste.Contains(d.Id)).ToListAsync(ct);
        db.Dosyalar.RemoveRange(dosyalar);
        await db.SaveChangesAsync(ct);

        foreach (var dosya in dosyalar)
            File.Delete(YolBul(dosya));
    }
}
