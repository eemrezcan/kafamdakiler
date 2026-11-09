using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Ozet;

public enum OzetDurumu
{
    // The note is in the brain now.
    Yazildi,
    // The week was already written (by an earlier round, or the brain already held the note). Nothing was changed.
    ZatenVardi,
    // The brain is not set up on this machine: nothing was made, the next round tries again.
    BeyinYok,
    // The brain was set up but did not take the note: nothing is recorded, the next round tries again.
    Hata,
}

public record OzetSonucu(OzetDurumu Durum, DateOnly Hafta, string? Mesaj = null)
{
    public bool Basarili => Durum is OzetDurumu.Yazildi or OzetDurumu.ZatenVardi;
}

// Writes the summary note of a week into the brain, once (the week's row is the record; the brain refuses to overwrite a note, which backs
// it up). Used by the background round and by the Sahip's "şimdi yaz" button.
public class HaftalikOzetYazici(AppDbContext db, BeyinIstemcisi beyin, TimeProvider saat, ILogger<HaftalikOzetYazici> log)
{
    // The tags we want first; the brain takes only tags in its list (etiketler.md), so when it refuses one the next, nearer set is tried.
    private static readonly string[] EtiketKumeleri = ["haftalık,takip,alışkanlık", "alışkanlık,özet", "alışkanlık"];

    // One write at a time: the round and the button must not both write the same week.
    private static readonly SemaphoreSlim Kilit = new(1, 1);

    // The week the background round is responsible for: the latest one whose Sunday 21:00 has passed. So a round on Sunday night writes
    // that week, and a first round after a missed Sunday writes the week that ended.
    public static DateOnly HedefHafta(DateTimeOffset an)
    {
        var pazartesi = HaftalikOzetOlusturucu.Pazartesi(GunSiniri.Bugun(an));
        return an >= HaftalikOzetOlusturucu.HazirlikAni(pazartesi) ? pazartesi : pazartesi.AddDays(-7);
    }

    public Task<OzetSonucu> TurAsync(CancellationToken ct) => YazAsync(HedefHafta(saat.GetUtcNow()), ct);

    // The button: this week, now, whatever the hour. A week already written stays as it is.
    public Task<OzetSonucu> SimdiYazAsync(CancellationToken ct) =>
        YazAsync(HaftalikOzetOlusturucu.Pazartesi(GunSiniri.Bugun(saat.GetUtcNow())), ct);

    public Task<HaftalikOzetKaydi?> SonKayitAsync(CancellationToken ct) =>
        db.HaftalikOzetler.AsNoTracking().OrderByDescending(k => k.Hafta).FirstOrDefaultAsync(ct);

    private async Task<OzetSonucu> YazAsync(DateOnly hafta, CancellationToken ct)
    {
        await Kilit.WaitAsync(ct);
        try
        {
            if (await db.HaftalikOzetler.AnyAsync(k => k.Hafta == hafta, ct))
                return new OzetSonucu(OzetDurumu.ZatenVardi, hafta);
            if (!beyin.Bagli)
                return new OzetSonucu(OzetDurumu.BeyinYok, hafta, "Beyin bağlı değil.");

            var simdi = saat.GetUtcNow();
            var govde = await new HaftalikOzetOlusturucu(db).OlusturAsync(hafta, simdi, ct);

            BeyinSonucu sonuc = null!;
            foreach (var etiketler in EtiketKumeleri)
            {
                sonuc = await beyin.NotEkleAsync(HaftalikOzetOlusturucu.Yol(hafta), HaftalikOzetOlusturucu.Baslik(hafta), etiketler, "not", govde, ct);
                if (!(sonuc.Durum == BeyinDurumu.BeyinHatasi && (sonuc.Mesaj ?? "").Contains("sözlükte olmayan etiket", StringComparison.OrdinalIgnoreCase)))
                    break;
            }

            // The brain never overwrites: "already there" is the note of this week (an earlier write whose answer we lost, or a hand-made one).
            var vardi = sonuc is { Durum: BeyinDurumu.BeyinHatasi } && (sonuc.Mesaj ?? "").Contains("zaten var", StringComparison.OrdinalIgnoreCase);
            if (!sonuc.Basarili && !vardi)
            {
                log.LogWarning("The weekly summary for {Hafta} could not be written ({Durum}): {Mesaj} It will be tried again.", hafta, sonuc.Durum, sonuc.Mesaj);
                return new OzetSonucu(sonuc.Durum == BeyinDurumu.BagliDegil ? OzetDurumu.BeyinYok : OzetDurumu.Hata, hafta, sonuc.Mesaj);
            }

            db.HaftalikOzetler.Add(new HaftalikOzetKaydi { Hafta = hafta, YazilmaAni = simdi });
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // Another instance recorded the week first: the note is in the brain either way.
                db.ChangeTracker.Clear();
            }

            return new OzetSonucu(vardi ? OzetDurumu.ZatenVardi : OzetDurumu.Yazildi, hafta);
        }
        finally
        {
            Kilit.Release();
        }
    }
}
