using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Kafamdakiler.Beyin;
using Kafamdakiler.Claude;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Kafamdakiler.Isler;
using Kafamdakiler.Ses;
using Kafamdakiler.Takvim;

namespace Kafamdakiler.Asistan;

// What Claude is asked for by the assistant's entry (K-0024, §7.1). The same suggestion as the voice preview's, plus `tip` (the kind of a
// work card). The answer is only ever a suggestion: every field is checked here as if a stranger had typed it.
public record AsistanOnerisi(
    string Tur, string Baslik, string? Gun = null, string? Saat = null, string? Tekrar = null, string? Bolum = null, int? TahminDk = null,
    string? Proje = null, string? Alan = null, string? Bitis = null, string? KaynakParca = null, double? Guven = null, string? BitisSaati = null,
    string? Yer = null, string? Tip = null, string? Gorev = null, bool? YeniGorev = null);

// One question with at most three short options, in Claude's words, until it has been cleaned.
public record AsistanSorusuOnerisi(string Metin, List<string> Secenekler);

public record ClaudeAsistanCevabi(List<AsistanOnerisi> Oneriler, AsistanSorusuOnerisi? Soru = null);

// A suggestion that passed the checks, in the terms of what applies it: a queue kind (`Kuyruk`), a capture (`Parca`: the part of the person's
// own text that is the note), or a work card (`IsGirdisi`).
// `GorevAcar` is true for a plan item that opens a new task: applying it also needs the permission to write tasks.
public record HazirOneri(
    string Tur, string Baslik, double? Guven, string Ozet, IsCikarServisi.Cevrilmis? Kuyruk = null, string? Parca = null, IsAcGirdi? IsGirdisi = null,
    bool GorevAcar = false);

// One line of a day's plan as the instruction shows it: the title, its state (acik, tamam, devredildi...) and the task it is linked to.
public record PlanSatiri(string Baslik, string? Durum, string? Gorev);

// What the classifier reads from the brain before it asks Claude (a to-do dump becomes a day plan): the open tasks (`Gorevler`, at most
// `AsistanSiniflandirici.EnCokGorev`), today's and yesterday's plans. `AcikKimlikler` is every open task id, or null when the tasks could not be read
// (then a task id cannot be checked here; the plan write checks it again).
public record PlanBaglami(
    IReadOnlyList<AcikGorevDto> Gorevler, IReadOnlyList<PlanSatiri> Bugun, IReadOnlyList<PlanSatiri> Dun, IReadOnlySet<string>? AcikKimlikler = null);

public enum SiniflandirmaDurumu { Tamam, Kullanilamiyor }

// `Neden` says why Claude could not be used (a sentence for the person); `Soru` is set when it is not sure and wants to ask.
public record SiniflandirmaSonucu(
    SiniflandirmaDurumu Durum, List<HazirOneri> Oneriler, List<AtlananOneri> Atlananlar, AsistanSorusuOnerisi? Soru = null, string? Neden = null);

// The assistant's classifier: the person's text goes to Claude as data (ClaudeIstemcisi's delimiter rule), and what comes back is checked by
// the voice module's own rules (IsCikarServisi.Cevir: the kind, past dates, the 730-day limit, the project that must exist, the kind's
// shape), plus the same kind of rules for the two new kinds. No photo ever goes in: only text.
public partial class AsistanSiniflandirici(
    ClaudeIstemcisi claude, BeyinIstemcisi beyin, IsCikarServisi isCikar, TimeProvider saat, ILogger<AsistanSiniflandirici> gunluk)
{
    public const string Not = "not";
    public const string Is = "is";

    // Below this a suggestion is not sure enough to apply without asking.
    public const double GuvenEsigi = 0.5;

    public const int EnCokSecenek = 3;
    public const int SoruEnUzun = 200;
    public const int SecenekEnUzun = 60;

    public const string CagriAdi = "asistan-girdi";

    // A plan item the person gave no estimate for.
    public const int VarsayilanTahminDk = 30;

    // How many open tasks go into the instruction (the nearest deadlines first).
    public const int EnCokGorev = 60;

    public static readonly string[] Turler = [.. IsCikarServisi.KuyrukTurleri, Not, Is];

    // `claudeMetni` is what Claude reads (the person's text, or the three parts of a second round); `orijinal` is the person's own text, the
    // only thing a note or a card is ever made of. `soruSorabilir` is false in the second round: it must decide.
    public async Task<SiniflandirmaSonucu> SiniflandirAsync(
        string orijinal, string claudeMetni, DateOnly bugun, bool soruSorabilir, bool baglamli, string gerekceOnEki, CancellationToken ct)
    {
        if (!claude.Bagli)
            return Kullanilamiyor("Asistan şu an bağlı değil.");

        // Only projects that exist and are not hidden may be named. Without a brain there are none (and tasks and cards fail later, in words).
        var projeler = await BeyinOkuma.ProjelerAl(beyin, gunluk, ct);
        var liste = projeler.Basarili ? projeler.Veri! : [];

        // The server's own day, whatever "today" the instruction was given.
        var sunucuBugun = GunSiniri.Bugun(saat.GetUtcNow());
        var planBaglami = await PlanBaglamiOkuAsync(sunucuBugun, ct);

        var yanit = await claude.SorAsync<ClaudeAsistanCevabi>(
            new ClaudeIstegi(CagriAdi, Talimat(bugun, liste, soruSorabilir, baglamli, planBaglami), claudeMetni, Sema(liste, soruSorabilir)), ct);
        if (!yanit.Basarili)
            return Kullanilamiyor(yanit.Durum switch
            {
                ClaudeDurumu.BagliDegil => "Asistan şu an bağlı değil.",
                ClaudeDurumu.SinirDoldu => "Claude için bugünlük sınır doldu.",
                ClaudeDurumu.ZamanAsimi => "Asistan zamanında cevap vermedi.",
                _ => "Asistan cevap veremedi.",
            });

        if (soruSorabilir && SoruTemizle(yanit.Veri!.Soru) is { } soru)
            return new SiniflandirmaSonucu(SiniflandirmaDurumu.Tamam, [], [], soru);

        var projeKimlikleri = liste.Select(p => p.Kimlik).ToHashSet(StringComparer.Ordinal);
        var oneriler = new List<HazirOneri>();
        var atlananlar = new List<AtlananOneri>();
        var kullanilan = new HashSet<string>(StringComparer.Ordinal);
        foreach (var (o, sira) in (yanit.Veri!.Oneriler ?? []).Select((o, i) => (o, i)))
        {
            if (sira >= IsCikarServisi.EnCokOneri)
            {
                atlananlar.Add(new AtlananOneri(o?.Tur, o?.Baslik, o?.KaynakParca, $"Çok fazla öneri: ilk {IsCikarServisi.EnCokOneri} işlendi."));
                continue;
            }

            var (hazir, neden) = Cevir(o, orijinal, sunucuBugun, projeKimlikleri, gerekceOnEki, planBaglami, kullanilan);
            if (hazir is null)
                atlananlar.Add(new AtlananOneri(o?.Tur, o?.Baslik, o?.KaynakParca, neden!));
            else
                oneriler.Add(hazir);
        }

        return new SiniflandirmaSonucu(SiniflandirmaDurumu.Tamam, oneriler, atlananlar);
    }

    // The rules for one suggestion: the voice module's for its four kinds, the same sort for a note and a card. Nothing is written here.
    //
    // For "plan-ekle" the plan context adds its rules (PlanEkleKurallari): a default estimate, the task must be open, nothing twice in a day.
    // `kullanilan` is what the earlier suggestions of the same answer took (a task or a title, for a day); pass one set per answer.
    public (HazirOneri? Sonuc, string? Neden) Cevir(
        AsistanOnerisi? o, string orijinal, DateOnly bugun, IReadOnlySet<string> projeler, string gerekceOnEki = "Asistan",
        PlanBaglami? baglam = null, ISet<string>? kullanilan = null)
    {
        if (o is null)
            return (null, "Boş öneri.");
        if (o.Tur is null || !Turler.Contains(o.Tur))
            return (null, "Bilinmeyen öneri türü.");

        if (o.Tur is not (Not or Is))
        {
            var (cevrilmis, neden) = isCikar.Cevir(
                new IsOnerisi(o.Tur, o.Baslik, o.Gun, o.Saat, o.Tekrar, o.Bolum, o.TahminDk, o.Proje, o.Alan, o.Bitis, o.KaynakParca, o.Guven, o.BitisSaati, o.Yer),
                bugun, projeler, gerekceOnEki);
            if (cevrilmis is null)
                return (null, neden);
            if (o.Tur == PlanEkleTuru.Anahtar)
                return PlanEkleKurallari(o, cevrilmis, bugun, projeler, baglam, kullanilan ?? new HashSet<string>(StringComparer.Ordinal));
            return (new HazirOneri(o.Tur, cevrilmis.Oneri.Baslik, cevrilmis.Oneri.Guven, cevrilmis.Ozet, Kuyruk: cevrilmis), null);
        }

        var baslik = Temizle(o.Baslik, 200);
        if (o.Guven is { } g && (double.IsNaN(g) || g is < 0 or > 1))
            return (null, "Güven 0 ile 1 arasında olmalı.");

        // The part of the person's own words this is about, only when Claude quoted it as it was; otherwise the whole text.
        var parca = string.IsNullOrWhiteSpace(o.KaynakParca) || !orijinal.Contains(o.KaynakParca.Trim(), StringComparison.Ordinal) ? null : o.KaynakParca.Trim();

        if (o.Tur == Not)
            return (new HazirOneri(Not, baslik.Length > 0 ? baslik : "Not", o.Guven, "Not olarak kaydedilecek", Parca: parca), null);

        if (baslik.Length == 0)
            return (null, "Başlık boş.");
        var tip = string.IsNullOrWhiteSpace(o.Tip) ? "kod" : o.Tip.Trim();
        if (!IsKartlari.Tipler.Contains(tip))
            return (null, "İş tipi kod, genel ya da yeni-proje olmalı.");
        var proje = string.IsNullOrWhiteSpace(o.Proje) ? null : o.Proje.Trim();
        var alan = string.IsNullOrWhiteSpace(o.Alan) ? null : o.Alan.Trim();
        if ((proje is null) == (alan is null))
            return (null, "Proje ya da alandan tam biri verilmeli.");
        if (proje is not null && !projeler.Contains(proje))
            return (null, $"Böyle bir proje yok: {proje}.");
        if (alan is not null && !GelenYolu.AcikKokler.Contains(alan, StringComparer.Ordinal))
            return (null, $"Alan {string.Join(", ", GelenYolu.AcikKokler)} arasından biri olmalı.");

        var talep = parca ?? orijinal;
        return (new HazirOneri(Is, baslik, o.Guven, $"İş kartı ({tip})", Parca: parca, IsGirdisi: new IsAcGirdi(baslik, talep, proje, alan, tip)), null);
    }

    // The plan item's own rules, after the voice module's checks passed: an estimate always, a link to an open task (or a new task in an open place),
    // and nothing that is already in the day. The queue payload gets `gorev` / `gorevAc` and the summary says where it is linked.
    private static (HazirOneri? Sonuc, string? Neden) PlanEkleKurallari(
        AsistanOnerisi o, IsCikarServisi.Cevrilmis c, DateOnly bugun, IReadOnlySet<string> projeler, PlanBaglami? baglam, ISet<string> kullanilan)
    {
        var gorev = string.IsNullOrWhiteSpace(o.Gorev) ? null : o.Gorev.Trim();
        var yeni = o.YeniGorev == true;
        if (gorev is not null && yeni)
            return (null, "Görev ya da yeni görev, ikisi birden değil.");

        var proje = string.IsNullOrWhiteSpace(o.Proje) ? null : o.Proje.Trim();
        var alan = string.IsNullOrWhiteSpace(o.Alan) ? null : o.Alan.Trim();
        if (yeni)
        {
            if ((proje is null) == (alan is null))
                return (null, "Proje ya da alandan tam biri verilmeli.");
            if (proje is not null && !projeler.Contains(proje))
                return (null, $"Böyle bir proje yok: {proje}.");
            if (alan is not null && !GelenYolu.AcikKokler.Contains(alan, StringComparer.Ordinal))
                return (null, $"Alan {string.Join(", ", GelenYolu.AcikKokler)} arasından biri olmalı.");
        }

        if (gorev is not null && baglam?.AcikKimlikler is { } acik && !acik.Contains(gorev))
            return (null, "Bu görev açık değil (bitmiş ya da yok).");

        // Only the plan of the day the item is for can hold it already: today's, which was read.
        var gun = c.Oneri.Gun!;
        var bugunku = gun == $"{bugun:yyyy-MM-dd}" ? baglam?.Bugun ?? [] : [];
        var baslikAnahtari = $"b:{gun}:{BaslikAnahtari(c.Oneri.Baslik)}";
        var gorevAnahtari = gorev is null ? null : $"g:{gun}:{gorev}";
        if ((gorev is not null && bugunku.Any(m => m.Gorev == gorev))
            || bugunku.Any(m => BaslikAnahtari(m.Baslik) == BaslikAnahtari(c.Oneri.Baslik))
            || (gorevAnahtari is not null && kullanilan.Contains(gorevAnahtari)) || kullanilan.Contains(baslikAnahtari))
            return (null, "Bugünün planında zaten var.");

        kullanilan.Add(baslikAnahtari);
        if (gorevAnahtari is not null)
            kullanilan.Add(gorevAnahtari);

        var tahmin = o.TahminDk ?? VarsayilanTahminDk;
        var yuk = JsonNode.Parse(c.Yuk.GetRawText())!.AsObject();
        yuk["tahminDk"] = tahmin;
        var ozet = c.Ozet;
        if (gorev is not null)
        {
            yuk["gorev"] = gorev;
            ozet += $" · görev: {gorev}";
        }
        else if (yeni)
        {
            var ac = new JsonObject();
            if (proje is not null) ac["proje"] = proje;
            if (alan is not null) ac["alan"] = alan;
            yuk["gorevAc"] = ac;
            ozet += $" · yeni görev ({proje ?? alan})";
        }

        var yeniC = c with { Yuk = JsonSerializer.SerializeToElement(yuk), Ozet = ozet, Oneri = c.Oneri with { TahminDk = tahmin } };
        return (new HazirOneri(o.Tur, yeniC.Oneri.Baslik, yeniC.Oneri.Guven, ozet, Kuyruk: yeniC, GorevAcar: yeni), null);
    }

    [GeneratedRegex(@"\s*~\s*\d+\s*(dk|sa|s)?\s*$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex TahminEkiKalibi();

    // A title as it is compared: lowercase, trimmed, spaces collapsed, the `~30dk` estimate left off.
    internal static string BaslikAnahtari(string? baslik)
    {
        var tek = string.Join(' ', (baslik ?? "").Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        return TahminEkiKalibi().Replace(tek, "").Trim().ToLowerInvariant();
    }

    // The open tasks and today's and yesterday's plans, for the instruction. Each part that cannot be read is left empty (a warning in the log):
    // the classifier works without a brain, only without the context.
    private async Task<PlanBaglami> PlanBaglamiOkuAsync(DateOnly bugun, CancellationToken ct)
    {
        var gorevler = new List<AcikGorevDto>();
        HashSet<string>? acik = null;
        List<PlanSatiri> bugunku = [], dunku = [];
        try
        {
            var yanit = await BeyinOkuma.AcikGorevlerAl(beyin, gunluk, ct);
            if (yanit.Basarili)
            {
                acik = yanit.Veri!.Select(g => g.Kimlik).ToHashSet(StringComparer.Ordinal);
                gorevler = [.. yanit.Veri!.OrderBy(g => g.Bitis ?? DateOnly.MaxValue).Take(EnCokGorev)];
            }
            else if (!yanit.BagliDegil)
                gunluk.LogWarning("The open tasks could not be read for the assistant ({Durum}); it works without them", yanit.Durum);

            if (acik is not null)
            {
                var izinli = await BeyinOkuma.IzinliGorevlerAl(beyin, gunluk, ct);
                bugunku = await GunSatirlariAl(bugun, izinli, ct);
                dunku = await GunSatirlariAl(bugun.AddDays(-1), izinli, ct);
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            gunluk.LogWarning(e, "The plan context for the assistant could not be read; it works without it");
        }

        return new PlanBaglami(gorevler, bugunku, dunku, acik);
    }

    private async Task<List<PlanSatiri>> GunSatirlariAl(DateOnly gun, IReadOnlySet<string> izinli, CancellationToken ct)
    {
        var yanit = await BeyinOkuma.GunAl($"{gun:yyyy-MM-dd}", beyin, gunluk, ct, izinliGorevler: izinli);
        if (!yanit.Basarili)
        {
            gunluk.LogWarning("The plan of {Gun} could not be read for the assistant ({Durum}); it works without it", gun, yanit.Durum);
            return [];
        }

        return yanit.Veri!.Bolumler.SelectMany(b => b.Maddeler).Select(m => new PlanSatiri(m.Baslik, m.Durum, m.Gorev)).ToList();
    }

    // Claude's question after cleaning: one line, 1 to 3 short distinct options. Anything else is no question.
    public static AsistanSorusuOnerisi? SoruTemizle(AsistanSorusuOnerisi? soru)
    {
        if (soru is null)
            return null;

        var metin = Temizle(soru.Metin, SoruEnUzun);
        var secenekler = (soru.Secenekler ?? []).Select(s => Temizle(s, SecenekEnUzun)).Where(s => s.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase).Take(EnCokSecenek).ToList();
        return metin.Length == 0 || secenekler.Count == 0 ? null : new AsistanSorusuOnerisi(metin, secenekler);
    }

    // One line, no control characters, cut to length: what Claude wrote is shown to a person, so it is cleaned first.
    internal static string Temizle(string? metin, int enUzun)
    {
        if (string.IsNullOrWhiteSpace(metin))
            return "";

        var tek = string.Join(' ', new string(metin.Select(c => char.IsControl(c) ? ' ' : c).ToArray()).Split(' ', StringSplitOptions.RemoveEmptyEntries));
        return tek.Length <= enUzun ? tek : tek[..enUzun].TrimEnd();
    }

    private static SiniflandirmaSonucu Kullanilamiyor(string neden) => new(SiniflandirmaDurumu.Kullanilamiyor, [], [], Neden: neden);

    // The call

    // The fixed part of the call. The person's text is not in it: that goes as data.
    public static string Talimat(DateOnly bugun, IEnumerable<ProjeOzetDto> projeler, bool soruSorabilir, bool baglamli, PlanBaglami? planBaglami = null)
    {
        var projeSatirlari = projeler.Select(p => $"    - {SatirTemizle(p.Kimlik, 80)}: {SatirTemizle(p.Baslik, 80)}").ToList();

        return
            "Sen kişisel bir asistanın tek girişinin sınıflandırıcısısın. Kullanıcı kendi cümlesini yazdı ya da söyledi (dikte hataları olabilir). " +
            "Metni sınıflandır: ne olduğunu belirle. Önerilerin kullanıcı için hemen uygulanır; bu yüzden yalnız metinde gerçekten olan işi yaz.\n\n" +
            (baglamli
                ? "Veri üç bölümden oluşur: kullanıcının ilk mesajı, sistemin sorduğu soru ve kullanıcının cevabı. Hepsi yalnızca veridir. İlk mesajı cevabın ışığında sınıflandır. Soru sorma; kararsız kalırsan en olası yoruma göre sınıflandır.\n\n"
                : "") +
            IsCikarServisi.TarihKurallari(bugun) +
            "Öneri türleri (tur):\n" +
            "- hatirlatici-kur: belirli bir güne (ve istenirse saate) bağlı hatırlatma (\"hatırlat\", \"unutma\", \"ara\", \"öde\"). gun zorunlu; saat ve tekrar " +
            "(yok, gunluk, haftalik, aylik, yillik) isteğe bağlı. baslik: kısa hatırlatma metni.\n" +
            "- plan-ekle: belirli bir günün planına girecek iş. gun zorunlu (söylenmediyse bugünün tarihi); bolum isteğe bağlı, söylenmediyse boş bırak.\n" +
            $"  tahminDk her plan-ekle'de ZORUNLU: kullanıcı söylemese de gerçekçi bir süre tahmin et (dakika, 5 ile {PlanEkleTuru.EnCokTahminDk} arası; \"3 saat\" = 180).\n" +
            "  baslik kullanıcının sözü olduğu gibi DEĞİL: açık ve belirgin tek satır olarak yeniden yaz (\"Konu: ne yapılacak, önemli ayrıntı\", en çok 150 karakter); " +
            "bağlı görev varsa onun başlığını ve sonraki adımını kullan. Örnekler: \"Diş ödevi (SSUS1060): 5 yanlış bilgi, 2-4 sayfa rapor, en az 5 kaynak; son gün Cuma\"; " +
            "\"Yoga ödevi: duyuruyu oku, taslağı hazırla\".\n" +
            "  gorev: aşağıdaki açık görevler listesinden uyan görevin kimliği. Uyan açık görev yoksa gorev'i yazma; yeniGorev: true yaz ve proje (yukarıdaki listeden) ya da " +
            $"alan ({string.Join(", ", GelenYolu.AcikKokler)}) alanlarından tam birini ver; sunucu görevi açar ve maddeye bağlar. Kapalı alanları (kisisel, finans) asla kullanma. gorev ile yeniGorev birlikte olmaz.\n" +
            "  Atla (öneri yazma): bugünün planında zaten olan işler (dünden devreden maddeler de), dün yapılmış işler ya da görevi açık listede olmayan (bitmiş) işler, " +
            "aynı metinde tekrarlanan işler (her iş için bir öneri).\n" +
            "  Birkaç satırlık ham bir yapılacaklar dökümü, her satır için bir plan-ekle demektir (gün söylenmediyse bugün); her biri için ayrı gorev-ekle yazma.\n" +
            "- gorev-ekle: günü belli olmayan ya da uzun süren, kalıcı görev. Bir projeye aitse proje, yalnız şu listeden:\n" +
            (projeSatirlari.Count > 0 ? string.Join('\n', projeSatirlari) : "    (hiç proje yok; proje alanını kullanma)") + "\n" +
            $"  değilse alan ({string.Join(", ", GelenYolu.AcikKokler)}). proje ve alandan tam biri verilir. bitis isteğe bağlı (yyyy-MM-dd).\n" +
            "- takvim-ekle: belirli bir gün ve saatte olacak bir toplantı, randevu ya da etkinlik. gun zorunlu; saat (başlangıç) söylendiyse yaz, " +
            "söylenmediyse boş bırak (tüm gün etkinlik olur); bitisSaati ve yer isteğe bağlı. Yalnız unutulmaması istenen şeyler hatirlatici-kur'dur.\n" +
            "- not: yapılacak iş ya da tarih içermeyen düşünce, fikir, bilgi, alıntı (saklanacak şey). baslik: kısa ad. kaynakParca: notun cümleleri, metinden olduğu gibi.\n" +
            "- is: yapay zekânın birkaç adımda çalışacağı, planlanıp onaylanarak ilerleyecek büyük bir talep (bir özellik yazmak, bir şeyi araştırmak). " +
            "baslik: kısa ad. tip: kod (yazılım işi), genel (kod olmayan iş) ya da yeni-proje. proje (yalnız yukarıdaki listeden) ya da alan; tam biri verilir.\n\n" +
            "Bir cümlede birden çok iş varsa ayrı öneriler yaz. Metinde olmayan iş uydurma. " + $"En çok {IsCikarServisi.EnCokOneri} öneri.\n" +
            "kaynakParca: önerinin dayandığı cümle ya da cümle parçası, metinden olduğu gibi. guven: 0 ile 1 arasında bir sayı; tür ya da tarih konusunda emin değilsen düşük ver.\n" +
            PlanBaglamiMetni(planBaglami) +
            (soruSorabilir
                ? "Bir şeyin ne olduğundan emin olamazsan (iki tür de olabiliyorsa ya da metin çelişiyorsa) tahmin yürütme: soru alanına TEK bir kısa soru ve en çok " +
                  $"{EnCokSecenek} kısa seçenek yaz, oneriler boş kalsın. Emin olduğunda soru alanını hiç yazma."
                : "");
    }

    // The context block of the instruction: the open tasks, today's and yesterday's plans. It is data from the brain, each line cleaned,
    // and it belongs to the fixed instruction like the project list; the person's text stays the data.
    private static string PlanBaglamiMetni(PlanBaglami? b)
    {
        if (b is null)
            return "";

        static string Plan(IReadOnlyList<PlanSatiri> satirlar) => satirlar.Count == 0
            ? "    (boş)\n"
            : string.Concat(satirlar.Take(80).Select(m =>
                $"    - {SatirTemizle(m.Baslik, 120)} [{SatirTemizle(m.Durum ?? "acik", 20)}]{(m.Gorev is null ? "" : $" (görev: {SatirTemizle(m.Gorev, 80)})")}\n"));

        var gorevler = b.Gorevler.Count == 0
            ? "    (liste boş ya da okunamadı)\n"
            : string.Concat(b.Gorevler.Select(g =>
                $"    - {SatirTemizle(g.Kimlik, 80)}: {SatirTemizle(g.Baslik, 100)}" +
                $"{(g.Bitis is { } t ? $" (son gün {t.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)})" : "")}" +
                $"{(string.IsNullOrWhiteSpace(g.SonrakiAdim) ? "" : $" — sonraki adım: {SatirTemizle(g.SonrakiAdim, 100)}")}\n"));

        return "Açık görevler (plan-ekle'nin gorev alanı yalnız bu kimliklerden biri olabilir):\n" + gorevler +
               "Bugünün planı (bunlar zaten planda):\n" + Plan(b.Bugun) +
               "Dünün planı (tamam olanlar yapıldı; açık kalanlar bugüne devredilmiş olabilir):\n" + Plan(b.Dun) + "\n";
    }

    // The answer shape: the voice call's schema with the two new kinds, the card's `tip`, and (when it may ask) one optional `soru`.
    public static string Sema(IEnumerable<ProjeOzetDto> projeler, bool soruSorabilir)
    {
        var sema = JsonNode.Parse(IsCikarServisi.Sema(projeler, Turler))!.AsObject();
        var ozellikler = sema["properties"]!.AsObject();
        var oge = ozellikler["oneriler"]!["items"]!["properties"]!.AsObject();
        oge["gorev"] = new JsonObject { ["type"] = "string", ["description"] = "plan-ekle: bağlanacak açık görevin kimliği (açık görevler listesinden)" };
        oge["yeniGorev"] = new JsonObject { ["type"] = "boolean", ["description"] = "plan-ekle: uyan açık görev yoksa true; proje ya da alandan tam biri verilir" };
        oge["tip"] = new JsonObject { ["type"] = "string", ["enum"] = new JsonArray(IsKartlari.Tipler.Select(t => (JsonNode)JsonValue.Create(t)!).ToArray()) };

        if (soruSorabilir)
        {
            ozellikler["soru"] = new JsonObject
            {
                ["type"] = "object",
                ["properties"] = new JsonObject
                {
                    ["metin"] = new JsonObject { ["type"] = "string", ["description"] = "Tek kısa soru" },
                    ["secenekler"] = new JsonObject
                    {
                        ["type"] = "array",
                        ["items"] = new JsonObject { ["type"] = "string" },
                        ["description"] = $"En çok {EnCokSecenek} kısa seçenek",
                    },
                },
                ["required"] = new JsonArray("metin", "secenekler"),
                ["additionalProperties"] = false,
            };
        }

        return sema.ToJsonString();
    }

    private static string SatirTemizle(string metin, int enUzun) => Temizle(metin, enUzun);
}
