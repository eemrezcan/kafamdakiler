using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Isler;

public record IsTuruOzeti(bool Okundu, int Bekleyen = 0, int Bildirilen = 0);

// The card watcher: every round of the notification line (once a minute) looks at the open cards, and a card that has just fallen to the
// person (it is theirs, and in "karar" or at a gate) is told about once, with a notification that opens the card. The same card in the same
// stage is never told twice: the key is `is:<card>:<stage>:<last update>`, so a card that goes back to "plan" and comes round again is a
// new occurrence. A write of the person's own (answering one of two questions, a note) also moves the update time; it is not news to
// them, so a card whose last history line is theirs is skipped.
//
// The recipients are the people who may read the cards and have a phone registered. Push off: nothing is recorded, as with reminders.
public class IsBildirimci(BeyinIstemcisi beyin, AppDbContext db, BildirimServisi bildirimler, ILogger<IsBildirimci> log)
{
    public const string KaynakTuru = "is";

    // Where a tap goes in the app; `{id}` is the card's id.
    public const string Rota = "/asistan/{id}";

    public static string Anahtar(IsKartiDto k) => $"is:{k.Kimlik}:{k.Asama}:{k.Guncelleme}";

    // The card is the person's turn: theirs, and a decision or a gate.
    public static bool SendeBekliyor(IsKartiDto k) =>
        k.Acik && k.Sahip == "kullanici" && (k.Asama == "karar" || IsKartlari.Kapilar.Contains(k.Asama));

    public async Task<IsTuruOzeti> TurAsync(CancellationToken ct)
    {
        if (!bildirimler.PushAcik || !beyin.Bagli)
            return new IsTuruOzeti(false);

        var liste = await beyin.CalistirAsync(["is", "liste", "--acik"], ct);
        if (!liste.Basarili)
        {
            log.LogWarning("Reading the open cards did not succeed ({Durum}, {Kod}): {Mesaj}", liste.Durum, liste.HataKodu, liste.Mesaj);
            return new IsTuruOzeti(false);
        }

        List<IsKartiDto> adaylar;
        try
        {
            adaylar = BeyinOkuma.Dizi(liste.Veri!.Value)
                .Where(BeyinOkuma.Gorunur).Where(BeyinOkuma.AcikYol).Where(k => BeyinOkuma.Metin(k, "hata") is null)
                .Select(IsKartlari.Kart).Where(SendeBekliyor).ToList();
        }
        catch (Exception e) when (e is InvalidDataException or InvalidOperationException)
        {
            log.LogWarning("The open card list was not in the known shape: {Mesaj}", e.Message);
            return new IsTuruOzeti(false);
        }

        if (adaylar.Count == 0)
            return new IsTuruOzeti(true);

        var alicilar = await bildirimler.AlicilarAsync([IsPolicies.Oku], ct);
        var bildirilen = 0;
        foreach (var aday in adaylar)
        {
            var anahtar = Anahtar(aday);
            var soylenen = await db.Bildirimler.Where(b => b.Anahtar == anahtar).Select(b => b.KullaniciId).ToListAsync(ct);
            if (alicilar.All(soylenen.Contains))
                continue;

            var kart = await IsKartlari.Al(aday.Kimlik, beyin, log, ct);
            if (!kart.Basarili)
                continue;

            // The person's own last write (an answer, a note) moved the update time: not news.
            if (kart.Veri!.Gecmis.LastOrDefault()?.Kim == IsKartlari.Kim)
                continue;

            var (baslik, metin) = Metinler(kart.Veri);
            foreach (var kullanici in alicilar)
            {
                if (await bildirimler.BirKezOlusturVeGonderAsync(kullanici, baslik, metin, KaynakTuru, Rota, aday.Kimlik, anahtar, ct))
                    bildirilen++;
            }
        }

        return new IsTuruOzeti(true, adaylar.Count, bildirilen);
    }

    // The words of the notification: the card's title, and what is waited for.
    public static (string Baslik, string Metin) Metinler(IsAyrintiDto k)
    {
        var yer = k.Proje ?? k.Alan;
        var son = yer is null ? "" : $" · {yer}";
        var metin = k.Asama switch
        {
            "karar" => k.Sorular.FirstOrDefault(s => s.Cevap is null) is { } soru
                ? Kisalt($"Karar bekliyor: {soru.Soru}") + son
                : "Karar bekliyor" + son,
            "kod-onayi" => "Kod onayı bekliyor" + son,
            "push-onayi" => "Push onayı bekliyor" + son,
            "deploy-onayi" => "Deploy onayı bekliyor" + son,
            _ => "Sende bekliyor" + son,
        };
        return (Kisalt(k.Baslik), metin);
    }

    private static string Kisalt(string metin, int enUzun = 200) => metin.Length <= enUzun ? metin : metin[..(enUzun - 1)] + "…";
}
