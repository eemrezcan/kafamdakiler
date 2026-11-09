using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Bildirimler;

// A task of the brain that is due, as the line sees it.
public record BildirimGorevi(string Yol, string Kimlik, string Baslik, string? Proje, string? Oncelik, DateOnly? Bitis);

public record GorevTuruOzeti(bool Okundu, int Aday = 0, int Kapatilan = 0, int Sorulan = 0, int Hatirlatilan = 0);

// One round of the brain-task side of the line, run at a few hours of the day. Due tasks already reach the morning briefing, so
// only a high-priority one (`oncelik: yuksek`) is a candidate for a notification in the middle of the day, and at most one a day.
//
// Before a candidate is told about, the evidence is looked at (GorevKaniti): a strong proof closes the task and says "kapattım"
// (undo is in the approval queue), a weak one asks "kapatayım mı?" (a `gorev-kapat` suggestion waits in the queue), and with no
// evidence the task is simply reminded. Claude is not used here: the evidence is plain text matching.
//
// Not a candidate yet: a task whose `tetik` (a free sentence such as "when the calendar page is done") has come true. The brain keeps
// no field that says so, and deciding it from the words would take Claude; so today only the priority picks.
public class GorevBildirimci(
    BeyinIstemcisi beyin, AppDbContext db, BildirimServisi bildirimler, EylemServisi eylemler, IKomitOkuyucu komitler,
    TimeProvider saat, ILogger<GorevBildirimci> log)
{
    // After a rejected suggestion the same kind of guess is not made again for this long.
    public static readonly TimeSpan RedSessizligi = TimeSpan.FromDays(7);

    public static bool Aday(BildirimGorevi g) => g.Oncelik == "yuksek";

    public static string Anahtar(BildirimGorevi g, DateOnly gun) => $"gorev:{g.Yol}:{gun:yyyy-MM-dd}";

    public async Task<GorevTuruOzeti> TurAsync(CancellationToken ct)
    {
        if (!bildirimler.PushAcik || !beyin.Bagli)
            return new GorevTuruOzeti(false);

        var gorevler = await GorevleriOkuAsync(ct);
        if (gorevler is null)
            return new GorevTuruOzeti(false);

        var adaylar = gorevler.Where(Aday).ToList();
        if (adaylar.Count == 0)
            return new GorevTuruOzeti(true);

        var simdi = saat.GetUtcNow();
        var bugun = HatirlaticiHesap.IstanbulGunu(simdi);
        var okuyanlar = await bildirimler.AlicilarAsync([BeyinPolicies.Oku], ct);
        // Who can be told about a close or a question: they must also be able to open the queue and undo.
        var kararVerenler = await bildirimler.AlicilarAsync([BeyinPolicies.Oku, EylemPolicies.Onayla], ct);

        var onceki = await OncekiEylemleriAsync(simdi, ct);
        var onbellek = new Dictionary<string, ProjeKaniti>();
        int kapatilan = 0, sorulan = 0, hatirlatilan = 0;
        foreach (var g in adaylar)
        {
            var anahtar = Anahtar(g, bugun);
            // At most one a day per task and person: when everyone who would be told has been, there is nothing to look at.
            var bugunSoylenen = await db.Bildirimler.Where(b => b.Anahtar == anahtar).Select(b => b.KullaniciId).ToListAsync(ct);
            if (okuyanlar.All(bugunSoylenen.Contains))
                continue;

            var buGorevinEylemleri = onceki.Where(e => e.Yol == g.Yol).ToList();
            // A question is already waiting: do not ask again, and do not make the person's queue longer.
            if (buGorevinEylemleri.Any(e => e.Durum == EylemDurumu.Bekliyor))
                continue;

            var kanit = g.Proje is null || kararVerenler.Count == 0
                ? KanitSonucu.Yok
                : await KanitAraAsync(g, bugun, onbellek, ct);
            kanit = Sustur(kanit, buGorevinEylemleri, simdi);
            if (kanit.Duzey != KanitDuzeyi.Yok && await YasakMiAsync(ct))
                kanit = KanitSonucu.Yok;

            switch (kanit.Duzey)
            {
                case KanitDuzeyi.Guclu:
                    if (await KapatVeSoyleAsync(g, kanit, anahtar, kararVerenler, ct))
                    {
                        kapatilan++;
                        continue;
                    }

                    break;
                case KanitDuzeyi.Zayif:
                    if (await SorVeSoyleAsync(g, kanit, anahtar, kararVerenler, ct))
                    {
                        sorulan++;
                        continue;
                    }

                    break;
            }

            var metin = g.Proje is null ? "Görevin vakti geldi" : $"Görevin vakti geldi · {g.Proje}";
            foreach (var kullanici in okuyanlar)
            {
                if (await bildirimler.BirKezOlusturVeGonderAsync(kullanici, Kisalt(g.Baslik), metin, "gorev",
                        g.Proje is null ? null : "/projeler/{id}", g.Proje, anahtar, ct))
                    hatirlatilan++;
            }
        }

        return new GorevTuruOzeti(true, adaylar.Count, kapatilan, sorulan, hatirlatilan);
    }

    // `gorev liste --tarihi-gelen`: open tasks whose date has come. Hidden tasks and the closed folders are left out by the brain
    // and again here. Null when the brain did not answer (the round is tried again later).
    private async Task<List<BildirimGorevi>?> GorevleriOkuAsync(CancellationToken ct)
    {
        var yanit = await beyin.CalistirAsync(["gorev", "liste", "--tarihi-gelen"], ct);
        if (!yanit.Basarili)
        {
            log.LogWarning("Reading the due tasks did not succeed ({Durum}, {Kod}): {Mesaj}", yanit.Durum, yanit.HataKodu, yanit.Mesaj);
            return null;
        }

        try
        {
            return BeyinOkuma.Dizi(yanit.Veri!.Value).Where(BeyinOkuma.Gorunur).Where(BeyinOkuma.AcikYol)
                .Select(g => new BildirimGorevi(
                    BeyinOkuma.Gerekli(g, "yol"), BeyinOkuma.Gerekli(g, "kimlik"), BeyinOkuma.Gerekli(g, "baslik"),
                    BeyinOkuma.Metin(g, "proje"), BeyinOkuma.Metin(g, "oncelik"), BeyinOkuma.Tarih(g, "bitis")))
                .ToList();
        }
        catch (InvalidDataException e)
        {
            log.LogWarning("The due task list was not in the known shape: {Mesaj}", e.Message);
            return null;
        }
    }

    // What a project's last card, journal and commits say; read once per project in a round.
    private record ProjeKaniti(string? SonKart, IReadOnlyList<GunlukKaydi> Gunluk, IReadOnlyList<GitKomiti> Komitler);

    private async Task<KanitSonucu> KanitAraAsync(BildirimGorevi g, DateOnly bugun, Dictionary<string, ProjeKaniti> onbellek, CancellationToken ct)
    {
        if (!onbellek.TryGetValue(g.Proje!, out var kaynak))
        {
            var kart = await BeyinOkuma.NotAl($"projects/{g.Proje}/oturumlar.md", beyin, log, ct);
            var proje = await BeyinOkuma.ProjeAl(g.Proje!, beyin, log, ct);
            kaynak = new ProjeKaniti(
                kart.Basarili ? GorevKaniti.SonKart(kart.Veri!.Govde) : null,
                proje.Basarili ? proje.Veri!.SonGunluk.Select(s => new GunlukKaydi(s.Baslik, s.Metin)).ToList() : [],
                await komitler.SonKomitlerAsync(g.Proje!, ct));
            onbellek[g.Proje!] = kaynak;
        }

        return GorevKaniti.Ara(g.Kimlik, g.Baslik, kaynak.Komitler, kaynak.SonKart, kaynak.Gunluk, bugun);
    }

    // What the person already said to a close of this task: an undone close is not repeated on the same proof (a new commit is a new
    // proof), and a refused question is not asked again for a while.
    private static KanitSonucu Sustur(KanitSonucu kanit, List<OncekiEylem> onceki, DateTimeOffset simdi) => kanit.Duzey switch
    {
        KanitDuzeyi.Guclu when onceki.Any(e => e.Durum == EylemDurumu.GeriAlindi && e.Kanit == kanit.Kanit) => KanitSonucu.Yok,
        KanitDuzeyi.Zayif when onceki.Any(e => e.Durum == EylemDurumu.Reddedildi && e.Ani > simdi - RedSessizligi) => KanitSonucu.Yok,
        _ => kanit,
    };

    private record OncekiEylem(string Yol, string? Kanit, EylemDurumu Durum, DateTimeOffset Ani);

    // The closing actions of the last weeks and every waiting one, read once per round.
    private async Task<List<OncekiEylem>> OncekiEylemleriAsync(DateTimeOffset simdi, CancellationToken ct)
    {
        var sinir = simdi - TimeSpan.FromDays(30);
        var satirlar = await db.Eylemler.AsNoTracking()
            .Where(e => e.Tur == GorevKapatTuru.Anahtar && (e.Durum == EylemDurumu.Bekliyor || e.CreatedAt > sinir))
            .Select(e => new { e.Yuk, e.Durum, e.CreatedAt, e.KararAni })
            .ToListAsync(ct);

        var sonuc = new List<OncekiEylem>();
        foreach (var s in satirlar)
        {
            try
            {
                using var yuk = JsonDocument.Parse(s.Yuk);
                if (BeyinOkuma.Metin(yuk.RootElement, "yol") is { } yol)
                    sonuc.Add(new OncekiEylem(yol, BeyinOkuma.Metin(yuk.RootElement, "kanit"), s.Durum, s.KararAni ?? s.CreatedAt));
            }
            catch (JsonException)
            {
                // A payload that is not JSON cannot name a task.
            }
        }

        return sonuc;
    }

    // "Bir daha önerme": the person forbade this kind, so there is no close and no question.
    private async Task<bool> YasakMiAsync(CancellationToken ct) =>
        await db.EylemIzinleri.AsNoTracking().AnyAsync(i => i.Tur == GorevKapatTuru.Anahtar && i.Kip == EylemKipi.Yasak, ct);

    private static JsonElement Yuk(string yol, string kanit) =>
        JsonSerializer.SerializeToElement(new GorevKapatYuku(yol, kanit), JsonSerializerOptions.Web);

    // Strong proof: the task is closed, and the people who can undo it are told. False when the close did not happen (the task is
    // then reminded as usual, not announced as closed).
    private async Task<bool> KapatVeSoyleAsync(BildirimGorevi g, KanitSonucu kanit, string anahtar, List<Guid> kararVerenler, CancellationToken ct)
    {
        var sonuc = await eylemler.OnayliUygulaAsync(
            new EylemOnerisi(GorevKapatTuru.Anahtar, Yuk(g.Yol, kanit.Kanit!), $"Görev kapatıldı: {g.Baslik}", "dogrulama", DisKaynak: false, Gerekce: kanit.Neden, Guven: 1.0),
            kullanici: null, ct);
        if (!sonuc.Basarili)
        {
            log.LogWarning("Closing the task {Gorev} on strong evidence did not succeed ({Tur}): {Mesaj}", g.Kimlik, sonuc.Tur, sonuc.Mesaj);
            return false;
        }

        foreach (var kullanici in kararVerenler)
            await bildirimler.BirKezOlusturVeGonderAsync(kullanici, Kisalt($"Kapattım: {g.Baslik}"), $"{kanit.Neden} Geri almak için dokun.",
                "dogrulama", "/eylem/{id}", sonuc.Eylem!.Id.ToString(), anahtar, ct);

        return true;
    }

    // Weak proof: a `gorev-kapat` suggestion waits in the queue and the notification asks. A suggestion made from a guess is never
    // applied by itself, whatever mode the kind is in (DisKaynak does that), and its notification has no Onayla button.
    private async Task<bool> SorVeSoyleAsync(BildirimGorevi g, KanitSonucu kanit, string anahtar, List<Guid> kararVerenler, CancellationToken ct)
    {
        // The proof written on the task if the person says yes: the day they said it, by their word.
        var onay = $"onay:dogrulama-{HatirlaticiHesap.IstanbulGunu(saat.GetUtcNow()):yyyy-MM-dd}";
        var sonuc = await eylemler.OnerAsync(
            new EylemOnerisi(GorevKapatTuru.Anahtar, Yuk(g.Yol, onay), $"Görevi kapat: {g.Baslik}", "dogrulama", DisKaynak: true, Gerekce: kanit.Neden, Guven: 0.5),
            ct);
        if (!sonuc.Basarili)
        {
            log.LogWarning("Suggesting to close the task {Gorev} did not succeed ({Tur}): {Mesaj}", g.Kimlik, sonuc.Tur, sonuc.Mesaj);
            return false;
        }

        foreach (var kullanici in kararVerenler)
            await bildirimler.BirKezOlusturVeGonderAsync(kullanici, "Bitmiş görünüyor, kapatayım mı?", Kisalt($"{g.Baslik} · {kanit.Neden}", 2000),
                "dogrulama", "/eylem/{id}", sonuc.Eylem!.Id.ToString(), anahtar, ct);

        return true;
    }

    private static string Kisalt(string metin, int enUzun = 200) => metin.Length <= enUzun ? metin : metin[..(enUzun - 1)] + "…";
}
