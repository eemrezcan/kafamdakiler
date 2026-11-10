using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Hatirlaticilar;

namespace Kafamdakiler.Eylemler;

// The payload of "gorev-kapat": the task's path in the vault and the proof it is done (`commit:<hash>` or `onay:<source>`).
public record GorevKapatYuku(string Yol, string Kanit);

// "gorev-kapat": closes a task that the evidence says is done (`gorev bitir --kanit`). Made by the notification line, never by a
// person's form: a strong proof closes it at once and says so, a weak one waits here as a question. Undo opens the task again
// (`gorev guncelle --durum aktif`), and only while it is still as this action closed it: a task the user has since reopened,
// or closed with a proof of their own, is left as it is.
public partial class GorevKapatTuru(BeyinIstemcisi beyin, ILogger<GorevKapatTuru> gunluk, HatirlaticiAyari? hatirlaticiAyari = null) : IEylemTuru
{
    public const string Anahtar = "gorev-kapat";

    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    // The two proofs the notification line makes. The brain accepts more; this kind does not.
    [GeneratedRegex(@"^(commit:[0-9a-f]{7,40}|onay:[\p{L}\p{N}_-]{1,80})\z", RegexOptions.CultureInvariant)]
    private static partial Regex KanitKalibi();

    public string Ad => Anahtar;

    public string GorunenAd => "Görevi kapat";

    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _);

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var y);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        var yanit = await beyin.CalistirAsync(["gorev", "bitir", $"--kanit={y!.Kanit}"], ct, [y.Yol]);
        if (!yanit.Basarili)
        {
            // The brain's message can hold paths: it goes to the log, the queue shows a fixed text.
            gunluk.LogWarning("Closing a task did not succeed ({Durum}, {Kod}): {Mesaj}", yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            throw new EylemHatasi($"Beyin görevi kapatmadı ({yanit.Durum}).");
        }

        // The reminders tied to the task close with it (K-0024). They are changed in the context; the queue saves it with the action.
        // The task's slug is its file name.
        await HatirlaticiZinciri.YapildiAsync(
            baglam.Db, null, null, Path.GetFileNameWithoutExtension(y.Yol), (hatirlaticiAyari ?? new HatirlaticiAyari()).VarsayilanSaat, baglam.Simdi, ct);

        return JsonSerializer.SerializeToElement(y, JsonSerializerOptions.Web);
    }

    public async Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct)
    {
        var bilgi = geriAlmaBilgisi.Deserialize<GorevKapatYuku>(JsonSerializerOptions.Web)
            ?? throw new InvalidOperationException("Geri alma bilgisi okunamadı.");

        var liste = await beyin.CalistirAsync(["gorev", "liste", "--durum=hepsi"], ct);
        if (!liste.Basarili)
            throw new EylemHatasi($"Görev okunamadı ({liste.Durum}).");

        var gorev = BeyinOkuma.Dizi(liste.Veri!.Value).FirstOrDefault(g => BeyinOkuma.Metin(g, "yol") == bilgi.Yol);
        // Gone, open again, or closed by somebody with a proof that is not ours: nothing to take back.
        if (gorev.ValueKind != JsonValueKind.Object || BeyinOkuma.Metin(gorev, "durum") != "bitti"
            || !BeyinOkuma.DiziAlani(gorev, "kanit").Any(k => k.ValueKind == JsonValueKind.String && k.GetString() == bilgi.Kanit))
        {
            return;
        }

        var yanit = await beyin.CalistirAsync(["gorev", "guncelle", "--durum=aktif"], ct, [bilgi.Yol]);
        if (!yanit.Basarili)
        {
            gunluk.LogWarning("Opening the task again failed ({Durum}, {Kod}): {Mesaj}", yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            throw new EylemHatasi($"Beyin görevi yeniden açmadı ({yanit.Durum}).");
        }
    }

    private static Sonuc Coz(JsonElement yuk, out GorevKapatYuku? y)
    {
        try
        {
            y = yuk.Deserialize<GorevKapatYuku>(Secenekler);
        }
        catch (JsonException e)
        {
            y = null;
            return Sonuc.Gecersiz("yuk", $"Yük görev kapatma biçimine uymuyor ({e.Path}).");
        }

        if (y is null || y.Yol is null || y.Kanit is null)
            return Sonuc.Gecersiz("yuk", "Yük yol ve kanit içermeli.");
        // A task file lives in a `gorevler` folder; a path anywhere else is not a task.
        if (!NotYolu.Gecerli(y.Yol) || !y.Yol.Contains("/gorevler/", StringComparison.Ordinal))
            return Sonuc.Gecersiz("yol", "Yol bir görev dosyası olmalı.");
        if (!KanitKalibi().IsMatch(y.Kanit))
            return Sonuc.Gecersiz("kanit", "Kanıt commit:<hash> ya da onay:<kaynak> olmalı.");

        return Sonuc.Tamam;
    }
}
