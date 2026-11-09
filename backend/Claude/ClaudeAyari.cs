namespace Kafamdakiler.Claude;

// The "Claude" settings. With Komut empty the layer is off and the rest of the app works.
public class ClaudeAyari
{
    // The claude executable: a full path, or a bare name found on PATH. Empty means "Claude bağlı değil".
    public string Komut { get; init; } = "";

    // Passed as --model: an alias (sonnet, opus) or a full model name.
    public string Model { get; init; } = "sonnet";

    // A model per kind of call, by the call's name (ClaudeIstegi.Tur): "gmail-cikar", "ses-is-cikar", "brifing"... A name that has
    // no entry takes the entry of the longest shorter name made by dropping its last "-part" ("ses-yeniden-yaz-ozet" falls back
    // to "ses-yeniden-yaz"), and a name with none at all takes `Model`.
    public IReadOnlyDictionary<string, string> Modeller { get; init; } = new Dictionary<string, string>();

    public TimeSpan ZamanAsimi { get; init; } = TimeSpan.FromSeconds(120);

    // How many claude processes may run at once.
    public int EsZamanliEnCok { get; init; } = 1;

    // A cap on the calls started per day (Europe/Istanbul) for one model, so a loop or a flood cannot drain the subscription.
    // It is the limit of every model that has no entry in `ModelSiniri`.
    public int GunlukEnCokCagri { get; init; } = 50;

    // A daily cap per model, by the model family ("haiku", "sonnet", "opus"; a full model name counts as its family). The cheap
    // model gets more calls than the dear one.
    public IReadOnlyDictionary<string, int> ModelSiniri { get; init; } = VarsayilanModelSiniri;

    public static readonly IReadOnlyDictionary<string, int> VarsayilanModelSiniri =
        new Dictionary<string, int> { ["haiku"] = 200, ["opus"] = 10 };

    public bool Acik => !string.IsNullOrWhiteSpace(Komut);

    // The model for a call named `istekAdi`. An empty entry counts as none.
    public string ModelSec(string istekAdi)
    {
        var ad = istekAdi;
        while (true)
        {
            if (Modeller.TryGetValue(ad, out var model) && !string.IsNullOrWhiteSpace(model))
                return model.Trim();

            var son = ad.LastIndexOf('-');
            if (son <= 0)
                return Model;
            ad = ad[..son];
        }
    }

    // The key a model is counted under: its family when the name holds one ("claude-haiku-4-5" → "haiku"), else the lower-cased name.
    public static string ModelAnahtari(string model)
    {
        var ad = model.Trim().ToLowerInvariant();
        foreach (var aile in (string[])["haiku", "sonnet", "opus"])
            if (ad.Contains(aile))
                return aile;
        return ad;
    }

    // The daily cap of a model, by the name as ModelSec gives it.
    public int SinirBul(string model) => ModelSiniri.TryGetValue(ModelAnahtari(model), out var sinir) ? sinir : GunlukEnCokCagri;

    // A relative path with a directory part is resolved against the app folder, like Beyin:Komut.
    // A bare name ("claude") is left alone: the operating system looks it up on PATH.
    public static ClaudeAyari Oku(IConfiguration config, string icerikKoku)
    {
        var bolum = config.GetSection("Claude");
        var komut = bolum["Komut"];
        if (!string.IsNullOrWhiteSpace(komut) && komut.IndexOfAny(['/', '\\']) >= 0)
            komut = Path.GetFullPath(komut, icerikKoku);

        return new ClaudeAyari
        {
            Komut = string.IsNullOrWhiteSpace(komut) ? "" : komut,
            Model = bolum["Model"] is { Length: > 0 } model ? model : "sonnet",
            Modeller = new Dictionary<string, string>(
                bolum.GetSection("Modeller").GetChildren().Where(c => !string.IsNullOrWhiteSpace(c.Value)).Select(c => KeyValuePair.Create(c.Key, c.Value!)),
                StringComparer.OrdinalIgnoreCase),
            ZamanAsimi = TimeSpan.FromSeconds(bolum.GetValue("ZamanAsimiSaniye", 120.0)),
            EsZamanliEnCok = Math.Max(1, bolum.GetValue("EsZamanliEnCok", 1)),
            GunlukEnCokCagri = Math.Max(0, bolum.GetValue("GunlukEnCokCagri", 50)),
            ModelSiniri = ModelSinirlariniOku(bolum),
        };
    }

    // The defaults, overridden entry by entry by `Claude:ModelSiniri:<model>`.
    private static IReadOnlyDictionary<string, int> ModelSinirlariniOku(IConfigurationSection bolum)
    {
        var sinirlar = new Dictionary<string, int>(VarsayilanModelSiniri);
        foreach (var c in bolum.GetSection("ModelSiniri").GetChildren())
            if (int.TryParse(c.Value, out var n))
                sinirlar[ModelAnahtari(c.Key)] = Math.Max(0, n);
        return sinirlar;
    }
}
