using Kafamdakiler.Ayarlar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Takvim;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Brifing;

// Either the input of a briefing or the reason it could not be read.
public record GirdiSonucu(BrifingGirdisi? Girdi, string? Mesaj = null);

// Reads what the briefing is made from: the day plan and yesterday's leftovers from the brain, the reminders and the approval
// queue from the database. Everything is worked out here (counts, days, the capacity excess), so Claude never has to.
// With the brain not set up on this machine its parts are simply empty. With the brain set up but unreadable the whole read fails:
// a briefing that says nothing about the plan because the plan could not be read would look like an empty day.
public class BrifingGirdiOkuyucu(AppDbContext db, BeyinIstemcisi beyin, GunAyari gunAyari, ILogger<BrifingGirdiOkuyucu> gunluk)
{
    // "The next 3 days": the briefing's own day and the three after it.
    public const int HatirlaticiGunSayisi = 3;

    // The most things one list holds; the rest is left out of the input.
    public const int EnCokMadde = 15;
    public const int EnCokHatirlatici = 15;
    public const int EnCokOnay = 5;
    public const int EnCokTakvim = 15;

    public async Task<GirdiSonucu> OkuAsync(DateOnly gun, CancellationToken ct)
    {
        List<BrifingMaddesi> plan = [], kalan = [];
        int toplam = 0, yapildi = 0;
        BrifingKapasitesi? kapasite = null;

        if (beyin.Bagli)
        {
            var bugunYaniti = await BeyinOkuma.GunAl($"{gun:yyyy-MM-dd}", beyin, gunluk, ct, gunAyari, await GunKapasitesi.DkAsync(db, gunAyari, gun, ct));
            if (!bugunYaniti.Basarili)
                return new GirdiSonucu(null, "Bugünün planı beyinden okunamadı.");
            var dunYaniti = await BeyinOkuma.GunAl($"{gun.AddDays(-1):yyyy-MM-dd}", beyin, gunluk, ct, gunAyari, await GunKapasitesi.DkAsync(db, gunAyari, gun.AddDays(-1), ct));
            if (!dunYaniti.Basarili)
                return new GirdiSonucu(null, "Dünün planı beyinden okunamadı.");

            var bugun = bugunYaniti.Veri!;
            var maddeler = bugun.Bolumler.SelectMany(b => b.Maddeler.Select(m => (Bolum: b.Ad, Madde: m))).ToList();
            toplam = maddeler.Count;
            yapildi = maddeler.Count(m => BeyinGorunum.Yapildi(m.Madde.Durum));
            plan = maddeler.Where(m => m.Madde.Durum == "acik").Take(EnCokMadde)
                .Select(m => new BrifingMaddesi(m.Madde.Id, m.Madde.Baslik, m.Bolum, m.Madde.TahminDk, m.Madde.Proje)).ToList();
            kapasite = bugun.KapasiteUyarisi is { } u ? new BrifingKapasitesi(u.AcikTahminDk, u.KapasiteDk, u.AsimDk) : null;

            kalan = dunYaniti.Veri!.Bolumler.SelectMany(b => b.Maddeler.Where(m => m.Durum == "acik").Select(m => (Bolum: b.Ad, Madde: m)))
                .Take(EnCokMadde)
                .Select(m => new BrifingMaddesi(m.Madde.Id, m.Madde.Baslik, m.Bolum, m.Madde.TahminDk, m.Madde.Proje)).ToList();
        }

        return new GirdiSonucu(new BrifingGirdisi(
            gun, toplam, yapildi, plan, kalan, await HatirlaticilariAlAsync(gun, ct), await BekleyenSayisiAsync(ct),
            await OnaylariAlAsync(ct), kapasite, await TakvimiAlAsync(gun, ct)));
    }

    // The briefing's day's events from the synced calendar (K2.3c): all-day ones first, then by the clock. With Google not connected
    // the table is empty and so is this. The id is the event's own, which the card links to.
    private async Task<List<BrifingTakvimi>> TakvimiAlAsync(DateOnly gun, CancellationToken ct)
    {
        var satirlar = await db.TakvimEtkinlikleri.AsNoTracking().GununEtkinlikleri(gun).Take(EnCokTakvim).ToListAsync(ct);
        return satirlar.Select(e => new BrifingTakvimi(
            e.Id.ToString(), e.Baslik,
            e.TumGun ? "Tüm gün" : $"{TakvimZamani.SaatMetni(e.Baslangic)}–{TakvimZamani.SaatMetni(e.Bitis)}")).ToList();
    }

    // Open reminders that fire from the start of the briefing's day to the end of the third day after it (the days turn at 05:00).
    // A snoozed reminder counts by the moment it was snoozed to.
    private async Task<List<BrifingHatirlaticisi>> HatirlaticilariAlAsync(DateOnly gun, CancellationToken ct)
    {
        var donus = new TimeOnly(GunSiniri.DonusSaati, 0);
        var bas = HatirlaticiHesap.An(gun, donus);
        var son = HatirlaticiHesap.An(gun.AddDays(HatirlaticiGunSayisi + 1), donus);
        var satirlar = await db.Hatirlaticilar.AsNoTracking()
            .Where(h => h.Durum == HatirlaticiDurumu.Acik && (h.ErteleAn ?? h.SonrakiAn) >= bas && (h.ErteleAn ?? h.SonrakiAn) < son)
            .OrderBy(h => h.ErteleAn ?? h.SonrakiAn).ThenBy(h => h.Id)
            .Take(EnCokHatirlatici).ToListAsync(ct);

        return satirlar.Select(h =>
        {
            var an = h.EtkinAn;
            var hGun = GunSiniri.Bugun(an);
            return new BrifingHatirlaticisi(h.Id.ToString(), h.Baslik, hGun, $"{HatirlaticiHesap.IstanbulSaati(an):HH:mm}", hGun.DayNumber - gun.DayNumber);
        }).ToList();
    }

    private async Task<int> BekleyenSayisiAsync(CancellationToken ct) =>
        await db.Eylemler.CountAsync(e => e.Durum == EylemDurumu.Bekliyor, ct);

    // "The most important": the ones that have waited longest. They are the ones a person is least likely to remember.
    private async Task<List<BrifingOnayi>> OnaylariAlAsync(CancellationToken ct)
    {
        var satirlar = await db.Eylemler.AsNoTracking().Where(e => e.Durum == EylemDurumu.Bekliyor)
            .OrderBy(e => e.CreatedAt).ThenBy(e => e.Id).Take(EnCokOnay)
            .Select(e => new { e.Id, e.Tur, e.Ozet }).ToListAsync(ct);
        return satirlar.Select(e => new BrifingOnayi(e.Id.ToString(), e.Tur, e.Ozet)).ToList();
    }
}
