using System.Globalization;
using System.Text;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Ozet;

// The week's numbers and the note text (Monday to Sunday of the app's days, 05:00 turn). Everything is counted here from the database;
// no model is asked. A part with nothing to count says "kayıt yok" instead of being left out, so a quiet week reads differently from a broken one.
public class HaftalikOzetOlusturucu(AppDbContext db)
{
    public const string KayitYok = "kayıt yok";

    // A reminder done within this long after it was due still counts as on time.
    public static readonly TimeSpan ZamanindaPayi = TimeSpan.FromHours(1);

    private static readonly string[] Aylar =
        ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];

    public static DateOnly Pazartesi(DateOnly gun) => gun.AddDays(-(((int)gun.DayOfWeek + 6) % 7));

    // "2026-W45", the ISO week of that Monday.
    public static string Kimlik(DateOnly pazartesi) =>
        $"{ISOWeek.GetYear(pazartesi.ToDateTime(TimeOnly.MinValue)):0000}-W{ISOWeek.GetWeekOfYear(pazartesi.ToDateTime(TimeOnly.MinValue)):00}";

    public static string Baslik(DateOnly pazartesi) => $"Haftalık ölçüm özeti {Kimlik(pazartesi)}";

    public static string Yol(DateOnly pazartesi) => $"aliskanliklar/haftalik/{Kimlik(pazartesi)}.md";

    // The summary is due on the Sunday at 21:00 Istanbul time.
    public static DateTimeOffset HazirlikAni(DateOnly pazartesi) => HatirlaticiHesap.An(pazartesi.AddDays(6), new TimeOnly(21, 0));

    public async Task<string> OlusturAsync(DateOnly pazartesi, DateTimeOffset simdi, CancellationToken ct)
    {
        var pazar = pazartesi.AddDays(6);
        // A day that has not come yet counts for nothing (a "no more than" habit would otherwise score on it).
        var son = new[] { pazar, GunSiniri.Bugun(simdi) }.Min();

        var metin = new StringBuilder();
        metin.AppendLine($"Hafta: {Tarih(pazartesi)} Pazartesi – {Tarih(pazar)} Pazar. Sayılar uygulamanın veritabanından hesaplandı.");
        metin.AppendLine();

        var sayacLar = await db.Aliskanliklar.AsNoTracking()
            .Where(a => a.Tur == AliskanlikTuru.Sayac && !a.Arsivlendi).OrderBy(a => a.Sira).ThenBy(a => a.Ad).ToListAsync(ct);
        var toplamlar = await AliskanlikEndpoints.GunToplamlariAsync(db, sayacLar.Select(a => a.Id).ToList(), ct);
        var kilolar = sayacLar.Where(Kilo).ToList();
        var aliskanliklar = sayacLar.Where(a => !Kilo(a)).ToList();

        Bolum(metin, "Alışkanlıklar", AliskanlikSatirlari(aliskanliklar, toplamlar, pazartesi, son));
        Bolum(metin, "Kitap", await KitapSatirlariAsync(pazartesi, son, ct));
        Bolum(metin, "Kilo", KiloSatirlari(kilolar, toplamlar, pazartesi, son));
        Bolum(metin, "Hatırlatıcılar", await HatirlaticiSatirlariAsync(pazartesi, simdi, ct));
        return metin.ToString().TrimEnd() + "\n";
    }

    // The weight is a counting habit measured in kg (there is no weight module of its own yet).
    private static bool Kilo(Aliskanlik a) => string.Equals(a.Birim?.Trim(), "kg", StringComparison.OrdinalIgnoreCase);

    private static void Bolum(StringBuilder metin, string baslik, List<string> satirlar)
    {
        metin.AppendLine($"## {baslik}");
        metin.AppendLine();
        if (satirlar.Count == 0)
            metin.AppendLine(KayitYok);
        foreach (var satir in satirlar)
            metin.AppendLine($"- {satir}");
        metin.AppendLine();
    }

    private static List<string> AliskanlikSatirlari(
        List<Aliskanlik> liste, Dictionary<Guid, Dictionary<DateOnly, GunToplami>> toplamlar, DateOnly pazartesi, DateOnly son)
    {
        var satirlar = new List<string>();
        foreach (var a in liste)
        {
            var gunler = toplamlar.GetValueOrDefault(a.Id) ?? [];
            var miktarlar = gunler.ToDictionary(x => x.Key, x => x.Value.Miktar);
            var baslangic = AliskanlikHesap.AliskanlikGunu(a.CreatedAt);
            if (miktarlar.Count > 0)
                baslangic = DateOnly.FromDayNumber(Math.Min(baslangic.DayNumber, miktarlar.Keys.Min(k => k.DayNumber)));

            var ilk = baslangic > pazartesi ? baslangic : pazartesi;
            if (ilk > son)
                continue;

            var planli = 0;
            var yapilan = 0;
            decimal toplam = 0;
            for (var gun = ilk; gun <= son; gun = gun.AddDays(1))
            {
                if (!AliskanlikHesap.Planli(a, gun))
                    continue;

                planli++;
                var miktar = miktarlar.GetValueOrDefault(gun);
                toplam += miktar;
                if (AliskanlikHesap.GununDegeri(a, miktar) >= 1)
                    yapilan++;
            }

            var haftadaN = a.Siklik == Siklik.HaftadaN && a.HaftalikSayi is > 0;
            var hedef = haftadaN ? a.HaftalikSayi!.Value : planli;
            var seri = AliskanlikHesap.Seri(a, miktarlar, AliskanlikHesap.AliskanlikGunu(a.CreatedAt), son);

            var satir = $"{a.Ad}: {yapilan}/{hedef} gün · seri {seri} {(haftadaN ? "hafta" : "gün")}";
            if (a.Olcu == Olcu.Sayili && toplam > 0)
                satir += $" · toplam {Sayi(toplam)}{(string.IsNullOrWhiteSpace(a.Birim) ? "" : " " + a.Birim.Trim())}";
            satirlar.Add(satir);
        }

        return satirlar;
    }

    private async Task<List<string>> KitapSatirlariAsync(DateOnly pazartesi, DateOnly son, CancellationToken ct)
    {
        var rafLar = await db.Aliskanliklar.AsNoTracking().Where(a => a.Tur == AliskanlikTuru.Raf).OrderBy(a => a.Sira).ThenBy(a => a.Ad).ToListAsync(ct);
        var okunan = (await db.Oturumlar.AsNoTracking()
                .Where(o => o.Tarih >= pazartesi && o.Tarih <= son && o.Oge!.Aliskanlik!.Tur == AliskanlikTuru.Raf)
                .Select(o => new { o.Oge!.AliskanlikId, Miktar = o.BitisKonum - o.BaslangicKonum }).ToListAsync(ct))
            .GroupBy(o => o.AliskanlikId).ToDictionary(g => g.Key, g => g.Sum(o => o.Miktar));
        var biten = (await db.Ogeler.AsNoTracking()
                .Where(o => o.Durum == OgeDurumu.Bitti && o.BitisTarihi >= pazartesi && o.BitisTarihi <= son && o.Aliskanlik!.Tur == AliskanlikTuru.Raf)
                .OrderBy(o => o.BitisTarihi).ThenBy(o => o.Ad).Select(o => new { o.AliskanlikId, o.Ad }).ToListAsync(ct))
            .ToLookup(o => o.AliskanlikId, o => o.Ad);

        var satirlar = new List<string>();
        foreach (var raf in rafLar)
        {
            var sayfa = okunan.GetValueOrDefault(raf.Id);
            var bitenler = biten[raf.Id].ToList();
            if (sayfa <= 0 && bitenler.Count == 0)
                continue;

            var birim = string.IsNullOrWhiteSpace(raf.Birim) ? "sayfa" : raf.Birim.Trim();
            satirlar.Add($"{raf.Ad}: okunan {Sayi(sayfa)} {birim}");
            satirlar.Add(bitenler.Count == 0 ? $"{raf.Ad}: biten yok" : $"{raf.Ad}: biten {bitenler.Count} ({string.Join(", ", bitenler)})");
        }

        return satirlar;
    }

    private static List<string> KiloSatirlari(
        List<Aliskanlik> kilolar, Dictionary<Guid, Dictionary<DateOnly, GunToplami>> toplamlar, DateOnly pazartesi, DateOnly son)
    {
        var satirlar = new List<string>();
        foreach (var kilo in kilolar)
        {
            var olcumler = (toplamlar.GetValueOrDefault(kilo.Id) ?? [])
                .Where(x => x.Key >= pazartesi && x.Key <= son).OrderBy(x => x.Key).ToList();
            if (olcumler.Count == 0)
                continue;

            var birim = kilo.Birim!.Trim();
            var ilk = olcumler[0];
            var sonOlcum = olcumler[^1];
            if (olcumler.Count == 1)
            {
                satirlar.Add($"{kilo.Ad}: tek ölçüm {Sayi(ilk.Value.Miktar)} {birim} ({Gun(ilk.Key)})");
                continue;
            }

            var fark = sonOlcum.Value.Miktar - ilk.Value.Miktar;
            satirlar.Add($"{kilo.Ad}: ilk {Sayi(ilk.Value.Miktar)} {birim} ({Gun(ilk.Key)}) · son {Sayi(sonOlcum.Value.Miktar)} {birim} ({Gun(sonOlcum.Key)}) · fark {(fark > 0 ? "+" : "")}{Sayi(fark)} {birim}");
        }

        return satirlar;
    }

    private async Task<List<string>> HatirlaticiSatirlariAsync(DateOnly pazartesi, DateTimeOffset simdi, CancellationToken ct)
    {
        var bas = HatirlaticiHesap.An(pazartesi, new TimeOnly(GunSiniri.DonusSaati, 0));
        var bit = HatirlaticiHesap.An(pazartesi.AddDays(7), new TimeOnly(GunSiniri.DonusSaati, 0));
        var olaylar = await db.HatirlaticiOlaylari.AsNoTracking().Where(o => o.Zaman >= bas && o.Zaman < bit).ToListAsync(ct);

        // Still open and past due inside the week: nobody did it and nobody snoozed it. (Judged from now; one done later is a late one.)
        var sinir = simdi < bit ? simdi : bit;
        var kacan = await db.Hatirlaticilar.AsNoTracking()
            .CountAsync(h => h.Durum == HatirlaticiDurumu.Acik && (h.ErteleAn ?? h.SonrakiAn) >= bas && (h.ErteleAn ?? h.SonrakiAn) < sinir, ct);

        var yapilan = olaylar.Where(o => o.Tur == HatirlaticiOlayTuru.Yapildi).ToList();
        var zamaninda = yapilan.Count(o => o.Zaman <= o.HedefAn + ZamanindaPayi);
        var ertelenen = olaylar.Count(o => o.Tur == HatirlaticiOlayTuru.Ertelendi);
        if (yapilan.Count == 0 && ertelenen == 0 && kacan == 0)
            return [];

        return [$"Zamanında yapılan: {zamaninda}", $"Geç yapılan: {yapilan.Count - zamaninda}", $"Ertelenen: {ertelenen}", $"Kaçan: {kacan}"];
    }

    private static string Tarih(DateOnly gun) => $"{gun.Day} {Aylar[gun.Month - 1]} {gun.Year}";

    private static string Gun(DateOnly gun) => $"{gun.Day} {Aylar[gun.Month - 1]}";

    // 82.40 -> "82,4"; the number the person typed, with a Turkish comma.
    private static string Sayi(decimal deger) => deger.ToString("0.##", CultureInfo.InvariantCulture).Replace('.', ',');
}
