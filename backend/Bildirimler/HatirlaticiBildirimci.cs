using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Bildirimler;

// One round of the reminder side of the line: every open reminder whose moment has come (and is not too old) is sent to the phones
// once. The moment is the one the rules already keep (`SonrakiAn`, or the snooze `ErteleAn` in front of it); this adds no second
// calculation. The phone still schedules its own copy as a backup: it shows the same notification id, so the two meet there.
public class HatirlaticiBildirimci(AppDbContext db, BildirimServisi bildirimler, TimeProvider saat, BildirimHattiAyari ayar)
{
    // Where a tap goes in the app (the edit screen of the reminder).
    public const string Rota = "/hatirlatici/{id}/duzenle";

    // The key of one occurrence: the reminder and the moment it was due. A snooze is a new moment, so it is a new occurrence.
    public static string Anahtar(Hatirlatici h) => $"hatirlatici:{h.Id}:{h.EtkinAn.ToUnixTimeSeconds()}";

    // The number of notifications made.
    public async Task<int> TurAsync(CancellationToken ct)
    {
        // Without a key file nothing can be sent, and nothing is recorded as sent: when push is switched on, the late-enough ones still go.
        if (!bildirimler.PushAcik)
            return 0;

        var simdi = saat.GetUtcNow();
        var enEski = simdi - ayar.EnGecGecikme;
        var vakti = await db.Hatirlaticilar.AsNoTracking()
            .Where(h => h.Durum == HatirlaticiDurumu.Acik && (h.ErteleAn ?? h.SonrakiAn) <= simdi && (h.ErteleAn ?? h.SonrakiAn) > enEski)
            .OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id)
            .ToListAsync(ct);
        if (vakti.Count == 0)
            return 0;

        var alicilar = await bildirimler.AlicilarAsync([HatirlaticiPolicies.Oku], ct);
        var yapilan = 0;
        foreach (var h in vakti)
        {
            // The same words as the phone's own notification of the moment.
            var metin = h.Tur == HatirlaticiTuru.Soz && h.Kime is not null ? $"bugün · Kime: {h.Kime}" : "bugün";
            foreach (var kullanici in alicilar)
            {
                if (await bildirimler.BirKezOlusturVeGonderAsync(kullanici, h.Baslik, metin, "hatirlatici", Rota, h.Id.ToString(), Anahtar(h), ct))
                    yapilan++;
            }
        }

        return yapilan;
    }
}
