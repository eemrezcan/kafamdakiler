using System.Text.Json;
using Kafamdakiler.Beyin;
using Kafamdakiler.Claude;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Brifing;

public enum BrifingDurumu
{
    Tamam,
    // The hour of the day's briefing has not come yet and none was made.
    HenuzHazirDegil,
    Bulunamadi,
    // A bad input; `Alan` names the field.
    Gecersiz,
    // The Sahip has asked for a new one the most times a day allows.
    SinirDoldu,
    // The brain is set up but could not be read: nothing was made, nothing was stored.
    GirdiOkunamadi,
}

public record BrifingSonucu(BrifingDurumu Durum, GunlukBrifing? Brifing = null, string? Mesaj = null, string? Alan = null)
{
    public bool Basarili => Durum == BrifingDurumu.Tamam;
}

// The votes of the last days, summed per card kind: the kinds the person wants more of and less of.
public record OyOzeti(List<string> DahaCok, List<string> DahaAz)
{
    public bool Bos => DahaCok.Count == 0 && DahaAz.Count == 0;
}

// Makes the day's briefing (K2.7): reads the input, asks Claude for 5 to 7 cards, checks every card, and falls back to fixed rules
// when Claude cannot be used. One briefing per day: the second request for the same day gets the stored one.
// The cards are only ever shown; nothing in a briefing changes anything.
public class BrifingHazirlayici(
    AppDbContext db, BrifingGirdiOkuyucu okuyucu, ClaudeIstemcisi claude, BrifingAyari ayar, TimeProvider saat, ILogger<BrifingHazirlayici> gunluk)
{
    // The Sahip may ask for a new briefing this many times a day (the first one does not count).
    public const int GundeEnCokYenileme = 3;

    // Votes of this many days before the briefing's day count towards the next instruction.
    public const int OyGunSayisi = 14;

    // A kind needs this many more thumbs one way than the other before the instruction says anything about it.
    public const int OyEsigi = 2;

    // One briefing is made at a time: the background round and a request must not both make the same day's, and Claude is slow.
    // The unique day in the table backs this up should two instances ever run.
    private static readonly SemaphoreSlim Kilit = new(1, 1);

    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    // The brain's day of this moment (05:00 turn).
    public DateOnly Bugun => GunSiniri.Bugun(saat.GetUtcNow());

    // The moment a day's briefing is due: the setting's hour on that day, Istanbul time. A day is "after its hour" until it ends,
    // so a request at 03:00 for the day that began yesterday is still after yesterday's 06:30.
    public DateTimeOffset HazirlikAni(DateOnly gun) => HatirlaticiHesap.An(gun, ayar.Saat);

    public Task<GunlukBrifing?> GetirAsync(DateOnly gun, CancellationToken ct) =>
        db.Brifingler.AsNoTracking().FirstOrDefaultAsync(b => b.Gun == gun, ct);

    // GET today: the stored briefing, else (after the hour) a new one. Before the hour nothing is made.
    public async Task<BrifingSonucu> BugunAsync(CancellationToken ct)
    {
        var an = saat.GetUtcNow();
        var gun = GunSiniri.Bugun(an);
        if (await GetirAsync(gun, ct) is { } mevcut)
            return new BrifingSonucu(BrifingDurumu.Tamam, mevcut);
        if (an < HazirlikAni(gun))
            return new BrifingSonucu(BrifingDurumu.HenuzHazirDegil, Mesaj: $"Bugünün brifingi saat {ayar.Saat:HH:mm}'de hazırlanır.");

        return await UretAsync(gun, ct);
    }

    // The background round: the same as asking for today's, minus the answer.
    public Task<BrifingSonucu> TurAsync(CancellationToken ct) => BugunAsync(ct);

    private async Task<BrifingSonucu> UretAsync(DateOnly gun, CancellationToken ct)
    {
        await Kilit.WaitAsync(ct);
        try
        {
            // Read again under the lock: the request that was ahead of this one has stored it by now.
            if (await GetirAsync(gun, ct) is { } mevcut)
                return new BrifingSonucu(BrifingDurumu.Tamam, mevcut);

            var uretim = await HazirlaAsync(gun, ct);
            if (uretim.Mesaj is not null)
                return new BrifingSonucu(BrifingDurumu.GirdiOkunamadi, Mesaj: uretim.Mesaj);

            var satir = new GunlukBrifing { Gun = gun, Kartlar = Seri(uretim.Kartlar), UretimAni = saat.GetUtcNow(), Yontem = uretim.Yontem };
            db.Brifingler.Add(satir);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // Another instance stored the day first: its briefing stands.
                db.ChangeTracker.Clear();
                if (await GetirAsync(gun, ct) is { } baskasi)
                    return new BrifingSonucu(BrifingDurumu.Tamam, baskasi);
                throw;
            }

            return new BrifingSonucu(BrifingDurumu.Tamam, satir);
        }
        finally
        {
            Kilit.Release();
        }
    }

    // POST yenile (the Sahip): today's briefing is made again and replaces the stored one, with its votes. At most
    // GundeEnCokYenileme times a day. The new one may be a "hesap" one if Claude is not available: the method says so.
    public async Task<BrifingSonucu> YenileAsync(CancellationToken ct)
    {
        await Kilit.WaitAsync(ct);
        try
        {
            var gun = Bugun;
            var satir = await db.Brifingler.FirstOrDefaultAsync(b => b.Gun == gun, ct);
            if (satir is { } mevcut && mevcut.YenilemeSayisi >= GundeEnCokYenileme)
                return new BrifingSonucu(BrifingDurumu.SinirDoldu, Mesaj: $"Bir günde en çok {GundeEnCokYenileme} kez yenilenebilir.");

            var uretim = await HazirlaAsync(gun, ct);
            if (uretim.Mesaj is not null)
                return new BrifingSonucu(BrifingDurumu.GirdiOkunamadi, Mesaj: uretim.Mesaj);

            if (satir is null)
            {
                satir = new GunlukBrifing { Gun = gun };
                db.Brifingler.Add(satir);
            }
            else
            {
                satir.YenilemeSayisi++;
                // The votes were about the old cards.
                db.BrifingOylari.RemoveRange(await db.BrifingOylari.Where(o => o.Gun == gun).ToListAsync(ct));
            }

            satir.Kartlar = Seri(uretim.Kartlar);
            satir.UretimAni = saat.GetUtcNow();
            satir.Yontem = uretim.Yontem;
            await db.SaveChangesAsync(ct);
            return new BrifingSonucu(BrifingDurumu.Tamam, satir);
        }
        finally
        {
            Kilit.Release();
        }
    }

    private record Uretim(List<BrifingKarti> Kartlar, BrifingYontemi Yontem, string? Mesaj = null);

    private async Task<Uretim> HazirlaAsync(DateOnly gun, CancellationToken ct)
    {
        var okuma = await okuyucu.OkuAsync(gun, ct);
        if (okuma.Girdi is not { } girdi)
            return new Uretim([], BrifingYontemi.Hesap, okuma.Mesaj ?? "Brifingin girdisi okunamadı.");

        var (kartlar, yontem) = await KartlariHazirlaAsync(gun, girdi, ct);
        return new Uretim(kartlar, yontem);
    }

    private async Task<(List<BrifingKarti>, BrifingYontemi)> KartlariHazirlaAsync(DateOnly gun, BrifingGirdisi girdi, CancellationToken ct)
    {
        // An empty day needs no model.
        if (girdi.Bos)
            return (BrifingHesabi.Hazirla(girdi), BrifingYontemi.Hesap);
        if (!claude.Bagli)
        {
            gunluk.LogInformation("Claude is not connected; the briefing for {Gun} is made by rules.", gun);
            return (BrifingHesabi.Hazirla(girdi), BrifingYontemi.Hesap);
        }

        var oylar = await OyOzetiAsync(gun, ct);
        ClaudeSonucu<ClaudeBrifingCevabi> yanit;
        try
        {
            yanit = await claude.SorAsync<ClaudeBrifingCevabi>(
                new ClaudeIstegi("brifing", Talimat(gun, oylar), girdi.Metin(), BrifingKartlari.Sema(girdi)), ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            gunluk.LogError(e, "The Claude call for the briefing of {Gun} failed; rules make it instead.", gun);
            return (BrifingHesabi.Hazirla(girdi), BrifingYontemi.Hesap);
        }

        if (!yanit.Basarili)
        {
            // The daily cap, a timeout, a broken answer: all end the same way, with the rules.
            gunluk.LogWarning("Claude gave no briefing for {Gun} ({Durum}); rules make it instead.", gun, yanit.Durum);
            return (BrifingHesabi.Hazirla(girdi), BrifingYontemi.Hesap);
        }

        var denetim = BrifingKartlari.Denetle(yanit.Veri!, girdi);
        if (denetim.AtilanKart > 0 || denetim.AtilanKimlik > 0)
            gunluk.LogWarning("Briefing for {Gun}: {Cards} cards and {Ids} ids of Claude's answer were thrown away.", gun, denetim.AtilanKart, denetim.AtilanKimlik);

        // An answer that is mostly made up is not trusted for the rest of it either.
        if (denetim.Kartlar.Count == 0 || denetim.AtilanKart > denetim.Kartlar.Count)
        {
            gunluk.LogWarning("Claude's briefing for {Gun} was not usable; rules make it instead.", gun);
            return (BrifingHesabi.Hazirla(girdi), BrifingYontemi.Hesap);
        }

        return (denetim.Kartlar, BrifingYontemi.Claude);
    }

    // Votes

    // Thumbs up (1), thumbs down (-1) or taking the vote back (0) on one card of a day's briefing.
    public async Task<BrifingSonucu> OyVerAsync(DateOnly gun, int sira, int oy, CancellationToken ct)
    {
        if (oy is not (1 or -1 or 0))
            return new BrifingSonucu(BrifingDurumu.Gecersiz, Mesaj: "Oy 1 (beğendim), -1 (beğenmedim) ya da 0 (geri al) olmalı.", Alan: "oy");

        var brifing = await GetirAsync(gun, ct);
        if (brifing is null)
            return new BrifingSonucu(BrifingDurumu.Bulunamadi, Mesaj: "O güne ait brifing yok.");
        var kartlar = KartlariOku(brifing);
        if (sira < 0 || sira >= kartlar.Count)
            return new BrifingSonucu(BrifingDurumu.Bulunamadi, Mesaj: "Böyle bir kart yok.");

        for (var deneme = 0; ; deneme++)
        {
            var satir = await db.BrifingOylari.FindAsync([gun, sira], ct);
            if (oy == 0)
            {
                if (satir is not null)
                    db.BrifingOylari.Remove(satir);
            }
            else if (satir is null)
            {
                db.BrifingOylari.Add(new BrifingOyu { Gun = gun, Sira = sira, Tur = kartlar[sira].Tur, Oy = oy, Zaman = saat.GetUtcNow() });
            }
            else
            {
                satir.Oy = oy;
                satir.Zaman = saat.GetUtcNow();
            }

            try
            {
                await db.SaveChangesAsync(ct);
                return new BrifingSonucu(BrifingDurumu.Tamam, brifing);
            }
            catch (DbUpdateException) when (deneme == 0)
            {
                // Two votes on the same card at once: the second starts again from what is stored.
                db.ChangeTracker.Clear();
            }
        }
    }

    // The votes of the OyGunSayisi days before `gun`.
    public async Task<OyOzeti> OyOzetiAsync(DateOnly gun, CancellationToken ct)
    {
        var bas = gun.AddDays(-OyGunSayisi);
        var oylar = await db.BrifingOylari.AsNoTracking().Where(o => o.Gun >= bas && o.Gun < gun).ToListAsync(ct);
        return Ozetle(oylar);
    }

    public static OyOzeti Ozetle(IEnumerable<BrifingOyu> oylar)
    {
        var net = oylar.GroupBy(o => o.Tur).ToDictionary(g => g.Key, g => g.Sum(o => o.Oy));
        // In the order of the kinds, and only kinds that exist: what goes into the instruction is never a stored string.
        var cok = BrifingTurleri.Tumu.Where(t => net.GetValueOrDefault(t) >= OyEsigi).ToList();
        var az = BrifingTurleri.Tumu.Where(t => net.GetValueOrDefault(t) <= -OyEsigi).ToList();
        return new OyOzeti(cok, az);
    }

    // The fixed part of the call. The day's input is not in it: that goes as data.
    public static string Talimat(DateOnly gun, OyOzeti oylar)
    {
        var talimat =
            "Sen kişisel bir asistanın sabah brifingi hazırlayıcısısın. Kullanıcı güne başlarken bakacağı kısa bir brifing istiyor: " +
            $"verideki işlerden en önemli {BrifingKartlari.EnAzKart} ile {BrifingKartlari.EnCokKart} kartı seç, önem sırasına göre diz " +
            "ve her kart için kısa bir başlık ile tek cümlelik bir metin yaz. Hiçbir şey kaydedilmez ve hiçbir iş yapılmaz; kartlar yalnızca gösterilir.\n\n" +
            $"Bugün: {gun:yyyy-MM-dd} {BrifingGirdisi.GunAdi(gun)}.\n\n" +
            "Veride işlerin satırları id=<kimlik> ile başlar. Kart türleri (tur):\n" +
            "- plan: bugünün planındaki açık maddeler. bagliKimlikler: o maddelerin kimlikleri.\n" +
            "- kalan: dünden kalan açık maddeler. bagliKimlikler: o maddelerin kimlikleri.\n" +
            "- hatirlatici: yaklaşan bir hatırlatıcı. bagliKimlikler: hatırlatıcının kimliği.\n" +
            "- onay: onay bekleyen eylemler. bagliKimlikler: o eylemlerin kimlikleri.\n" +
            "- takvim: bugünün takvim etkinlikleri. bagliKimlikler: o etkinliklerin kimlikleri.\n" +
            "- kapasite: açık işler güne sığmıyor uyarısı. bagliKimlikler boş dizi olsun.\n" +
            "Yalnız veride karşılığı olan türlerde kart yaz; bir tür için tek kart yeter, ama hatırlatıcılar ayrı kartlar olabilir. " +
            "Kimlikleri veride yazıldığı gibi yaz; kimlik uydurma, bir türün kimliğini başka türün kartında kullanma.\n\n" +
            "Sayıları, süreleri, günleri ve tarihleri veride hazır verildiği gibi kullan; kendin sayma, toplama ya da gün hesabı yapma. " +
            $"Başlık en çok {BrifingKartlari.BaslikEnUzun} karakter, metin tek cümle ve en çok {BrifingKartlari.MetinEnUzun} karakter olsun. " +
            "Türkçe, sade yaz. Veride olmayan hiçbir şeyi yazma.";

        if (oylar.Bos)
            return talimat;

        // Only kind names go in, from the fixed list.
        var cumleler = new List<string>();
        if (oylar.DahaCok.Count > 0)
            cumleler.Add($"daha çok görmek istediği türler: {string.Join(", ", oylar.DahaCok)}");
        if (oylar.DahaAz.Count > 0)
            cumleler.Add($"daha az görmek istediği türler: {string.Join(", ", oylar.DahaAz)}");
        return talimat +
            $"\n\nKullanıcı son {OyGunSayisi} günün brifinglerinde kartlara verdiği oylarla şunu söyledi — {string.Join("; ", cumleler)}. " +
            "Seçerken ve sıralarken bunu gözet; ama güne gerçekten önemli bir şey varsa türü az istense de yaz.";
    }

    // Reading and showing

    public static List<BrifingKarti> KartlariOku(GunlukBrifing brifing) =>
        JsonSerializer.Deserialize<List<BrifingKarti>>(brifing.Kartlar, Json) ?? [];

    private static string Seri(List<BrifingKarti> kartlar) => JsonSerializer.Serialize(kartlar, Json);

    public async Task<BrifingDto> DtoYapAsync(GunlukBrifing brifing, CancellationToken ct)
    {
        var oylar = await db.BrifingOylari.AsNoTracking().Where(o => o.Gun == brifing.Gun).ToDictionaryAsync(o => o.Sira, o => o.Oy, ct);
        var kartlar = KartlariOku(brifing).Select((k, sira) => new BrifingKartDto(sira, k.Tur, k.Baslik, k.Metin, k.BagliKimlikler, oylar.GetValueOrDefault(sira))).ToList();
        return new BrifingDto(brifing.Gun, brifing.UretimAni, brifing.Yontem, kartlar, Math.Max(0, GundeEnCokYenileme - brifing.YenilemeSayisi));
    }
}
