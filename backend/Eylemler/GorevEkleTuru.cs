using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Gelen;

namespace Kafamdakiler.Eylemler;

// The payload of "gorev-ekle": exactly one of Proje and Alan. Bitis is yyyy-MM-dd.
public record GorevEkleYuku(string Baslik, string? Proje = null, string? Alan = null, string? Bitis = null);

// What undo needs: the task's own path, because an id (the file name) can exist in two projects.
public record GorevEkleGeriAlmaBilgisi(string Kimlik, string Yol);

// "gorev-ekle": adds a task (`gorev ekle`). Undo cancels it (`gorev guncelle --durum iptal`), and only while it is still as it
// was made: a task the user has since started, finished or cancelled is left as it is.
public class GorevEkleTuru(BeyinIstemcisi beyin, ILogger<GorevEkleTuru> gunluk) : IEylemTuru
{
    public const string Anahtar = "gorev-ekle";

    // The state a new task starts in; undo cancels only a task still in it.
    private const string BaslangicDurumu = "aktif";

    private const string GeriAlmaGerekcesi = "geri alındı";

    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public string Ad => Anahtar;

    public string GorunenAd => "Görev ekle";

    // The shape and the write rules. Whether the project exists needs the brain: DogrulaAsync.
    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _, out _);

    public async Task<Sonuc> DogrulaAsync(JsonElement yuk, CancellationToken ct)
    {
        var sekil = Coz(yuk, out var y, out _);
        if (!sekil.Basarili || y!.Proje is null)
            return sekil;

        var projeler = await GelenBeyin.ProjeleriAlAsync(beyin, gunluk, ct);
        if (!projeler.Basarili)
            return Sonuc.Gecersiz("yuk", "Beyin cevap vermedi: proje doğrulanamadı.");

        return projeler.Veri!.Contains(y.Proje.Trim())
            ? Sonuc.Tamam
            : Sonuc.Gecersiz("proje", "Böyle bir proje yok.");
    }

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out _, out var komut);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        var yanit = await beyin.CalistirAsync(komut, ct);
        if (!yanit.Basarili)
        {
            // The brain's message can hold paths: it goes to the log, the queue shows a fixed text.
            gunluk.LogWarning("Adding a task did not succeed ({Durum}, {Kod}): {Mesaj}", yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            throw new InvalidOperationException($"Beyin görevi eklemedi ({yanit.Durum}).");
        }

        try
        {
            var bilgi = new GorevEkleGeriAlmaBilgisi(BeyinOkuma.Gerekli(yanit.Veri!.Value, "kimlik"), BeyinOkuma.Gerekli(yanit.Veri!.Value, "yol"));
            return JsonSerializer.SerializeToElement(bilgi, JsonSerializerOptions.Web);
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException or KeyNotFoundException)
        {
            // It wrote (exit 0), we just cannot say where: the queue marks the action failed, the log has the reason.
            gunluk.LogWarning("The brain added a task but its answer was not in the known shape: {Mesaj}", e.Message);
            throw new InvalidOperationException("Beyin görevi ekledi ama cevabı anlaşılamadı.", e);
        }
    }

    public async Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct)
    {
        var bilgi = geriAlmaBilgisi.Deserialize<GorevEkleGeriAlmaBilgisi>(JsonSerializerOptions.Web)
            ?? throw new InvalidOperationException("Geri alma bilgisi okunamadı.");

        var liste = await beyin.CalistirAsync(["gorev", "liste", "--durum=hepsi"], ct);
        if (!liste.Basarili)
            throw new InvalidOperationException($"Görev okunamadı ({liste.Durum}).");

        var gorev = BeyinOkuma.Dizi(liste.Veri!.Value).FirstOrDefault(g => BeyinOkuma.Metin(g, "yol") == bilgi.Yol);
        // Gone, or no longer as it was made: nothing to take back, and nothing of the user's work to cancel.
        if (gorev.ValueKind != JsonValueKind.Object || BeyinOkuma.Metin(gorev, "durum") != BaslangicDurumu)
            return;

        var yanit = await beyin.CalistirAsync(["gorev", "guncelle", "--durum=iptal", $"--gerekce={GeriAlmaGerekcesi}"], ct, [bilgi.Yol]);
        if (!yanit.Basarili)
        {
            gunluk.LogWarning("Cancelling the task failed ({Durum}, {Kod}): {Mesaj}", yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            throw new InvalidOperationException($"Beyin görevi iptal etmedi ({yanit.Durum}).");
        }
    }

    // The checks of the task write itself, and the command that follows from them.
    private static Sonuc Coz(JsonElement yuk, out GorevEkleYuku? y, out List<string> komut)
    {
        komut = [];
        try
        {
            y = yuk.Deserialize<GorevEkleYuku>(Secenekler);
        }
        catch (JsonException e)
        {
            y = null;
            return Sonuc.Gecersiz("yuk", $"Yük görev biçimine uymuyor ({e.Path}).");
        }

        if (y is null || y.Baslik is null)
            return Sonuc.Gecersiz("yuk", "Yük baslik içermeli.");

        return EylemDogrulama.Sonuca(BeyinYazma.GorevEkleKomutu(new GorevEkleGirdi(y.Baslik, y.Proje, y.Alan, y.Bitis, null, null), out komut))
            ?? Sonuc.Tamam;
    }
}
