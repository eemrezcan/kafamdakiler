using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;

namespace Kafamdakiler.Eylemler;

// The payload of "plan-ekle": one item for one day's plan. `Gun` is yyyy-MM-dd. `TahminDk` becomes the `~45dk` the brain reads
// as the estimate of the item. `Gorev` links the item to an open task; `GorevAc` opens a new task (titled `Metin`) first and links to that.
// At most one of the two. Old payloads (the voice path never sends them) still parse.
public record PlanEkleYuku(string Gun, string Metin, string? Bolum = null, int? TahminDk = null, string? Gorev = null, PlanGorevAcYuku? GorevAc = null);

// Where a new task goes: exactly one of Proje and Alan (the same rule as "gorev-ekle").
public record PlanGorevAcYuku(string? Proje = null, string? Alan = null);

// "plan-ekle": adds an item to a day's plan (`gun ekle`). The brain has no command that takes a plan item out again
// (a tick can be undone, a carry-over moves it, but nothing removes it), so this kind cannot be undone, and so it is
// never applied by itself either (EylemServisi): "Kendin yap" promises an undo.
public class PlanEkleTuru(BeyinIstemcisi beyin, ILogger<PlanEkleTuru> gunluk) : IEylemTuru
{
    public const string Anahtar = "plan-ekle";

    public const int EnCokTahminDk = 720;

    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public string Ad => Anahtar;

    public string GorunenAd => "Plana madde ekle";

    public bool GeriAlinabilir => false;

    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _, out _);

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var y, out var gun);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        // A new task first (titled like the item), then the item linked to it.
        var gorev = y!.Gorev?.Trim();
        var gorevAcildi = false;
        if (y.GorevAc is { } ac)
        {
            var gorevYaniti = await BeyinYazma.GorevEkle(new GorevEkleGirdi(y.Metin, ac.Proje, ac.Alan, null, null, null), beyin, gunluk, ct);
            if (!gorevYaniti.Basarili)
            {
                gunluk.LogWarning("Opening a task for a plan item did not succeed ({Tur}): {Baslik} {Ayrinti}", gorevYaniti.Tur, gorevYaniti.Baslik, gorevYaniti.Ayrinti);
                throw new InvalidOperationException($"Beyin görevi açmadı ({gorevYaniti.Tur}).");
            }

            gorev = ((GorevEklendiDto)gorevYaniti.Veri!).Kimlik;
            gorevAcildi = true;
        }

        // The same entry point as the plan page: its checks run again, and the date goes to the brain explicitly.
        var yanit = await BeyinYazma.MaddeEkle(
            $"{gun:yyyy-MM-dd}", new MaddeEkleGirdi(MaddeMetni(y), y.Bolum, gorev), beyin, gunluk, ct);
        if (!yanit.Basarili)
        {
            // An uncertain answer may have written: the queue shows a fixed text, the log says which it was.
            gunluk.LogWarning("Adding a plan item for {Gun} did not succeed ({Tur}): {Baslik} {Ayrinti}", y.Gun, yanit.Tur, yanit.Baslik, yanit.Ayrinti);
            throw new InvalidOperationException(gorevAcildi
                ? $"Görev açıldı ({gorev}) ama beyin maddeyi yazmadı ({yanit.Tur})."
                : $"Beyin maddeyi yazmadı ({yanit.Tur}).");
        }

        var eklenen = (MaddeEklendiDto)yanit.Veri!;
        return JsonSerializer.SerializeToElement(
            new { tarih = $"{eklenen.Tarih:yyyy-MM-dd}", madde = eklenen.Madde.Id, gorev }, JsonSerializerOptions.Web);
    }

    public Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct) =>
        throw new NotSupportedException("Plana eklenen madde geri alınamaz.");

    // The text as the brain gets it: the title, then the estimate.
    public static string MaddeMetni(PlanEkleYuku y) => y.TahminDk is { } dk ? $"{y.Metin.Trim()} ~{dk}dk" : y.Metin.Trim();

    private static Sonuc Coz(JsonElement yuk, out PlanEkleYuku? y, out DateOnly gun)
    {
        gun = default;
        try
        {
            y = yuk.Deserialize<PlanEkleYuku>(Secenekler);
        }
        catch (JsonException e)
        {
            y = null;
            return Sonuc.Gecersiz("yuk", $"Yük plan maddesi biçimine uymuyor ({e.Path}).");
        }

        if (y is null || y.Gun is null || y.Metin is null)
            return Sonuc.Gecersiz("yuk", "Yük gun ve metin içermeli.");
        if (y.TahminDk is < 1 or > EnCokTahminDk)
            return Sonuc.Gecersiz("tahminDk", $"Tahmin 1 ile {EnCokTahminDk} dakika arasında olmalı.");

        // The checks of the plan write itself, on the text the brain will get.
        if (EylemDogrulama.Sonuca(BeyinYazma.TarihDenetle(y.Gun, out gun)) is { } tarihHatasi)
            return tarihHatasi;
        if (EylemDogrulama.Sonuca(BeyinYazma.MetinDenetle(MaddeMetni(y), "metin", BeyinYazma.EnUzunMetin, out _)) is { } metinHatasi)
            return metinHatasi;
        if (EylemDogrulama.Sonuca(BeyinYazma.Istege(y.Bolum, "bolum", BeyinYazma.EnUzunBolum, out var bolum)) is { } bolumHatasi)
            return bolumHatasi;
        if (bolum is not null && bolum.Equals("Kapanış", StringComparison.OrdinalIgnoreCase))
            return Sonuc.Gecersiz("bolum", "Kapanış bölümüne madde eklenmez.");

        if (y.Gorev is not null && y.GorevAc is not null)
            return Sonuc.Gecersiz("gorev", "Görev ya da yeni görev, ikisi birden değil.");
        if (y.Gorev is not null && !BeyinYazma.GorevKimligiGecerli(y.Gorev.Trim()))
            return Sonuc.Gecersiz("gorev", "Görev kimliği küçük harf, rakam ve tire olmalı.");
        if (y.GorevAc is { } ac
            && EylemDogrulama.Sonuca(BeyinYazma.GorevEkleKomutu(new GorevEkleGirdi(y.Metin, ac.Proje, ac.Alan, null, null, null), out _)) is { } acHatasi)
            return acHatasi;

        return Sonuc.Tamam;
    }
}
