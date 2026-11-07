using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Takvim;

namespace Kafamdakiler.Eylemler;

// The payload of "takvim-ekle". A timed event: Baslangic and Bitis (ISO 8601 with an offset, e.g. 2026-11-09T14:00:00+03:00).
// An all-day one: TumGun true and Gun (yyyy-MM-dd), BitisGunu the last day when it lasts more than one. `Takvim` is one of
// the chosen calendars (Google:Takvimler); left out it is the first.
public record TakvimEkleYuku(
    string Baslik, string? Takvim = null, string? Baslangic = null, string? Bitis = null, bool? TumGun = null,
    string? Gun = null, string? BitisGunu = null, string? Yer = null);

// The payload of "takvim-tasi": the Google id of the event and its new time, written as in TakvimEkleYuku.
public record TakvimTasiYuku(
    string Kimlik, string? Takvim = null, string? Baslangic = null, string? Bitis = null, bool? TumGun = null,
    string? Gun = null, string? BitisGunu = null);

// The checks the two calendar kinds share. A payload is checked as if a stranger wrote it: it may come from Claude.
internal static class TakvimYukuDenetimi
{
    public const int BaslikEnUzun = 200;
    public const int YerEnUzun = 300;
    public const int KimlikEnUzun = 1024;

    // A timed event longer than this is more likely a slip of the date than an event; an all-day one may run a month.
    public const int SaatliEnCokGun = 7;
    public const int TumGunEnCokGun = 31;

    private const int EnErkenYil = 2000;
    private const int EnGecYil = 2100;

    public static Sonuc Acik(TakvimAyari ayar) =>
        ayar.Acik ? Sonuc.Tamam : Sonuc.Gecersiz("yuk", "Google Takvim bağlı değil.");

    public static Sonuc Takvim(string? istenen, TakvimAyari ayar, out string takvim)
    {
        takvim = ayar.VarsayilanTakvim;
        if (istenen is null)
            return Sonuc.Tamam;
        if (!ayar.Takvimler.Contains(istenen.Trim(), StringComparer.Ordinal))
            return Sonuc.Gecersiz("takvim", "Takvim, seçili takvimlerden biri olmalı.");

        takvim = istenen.Trim();
        return Sonuc.Tamam;
    }

    public static Sonuc Baslik(string? baslik, out string temiz)
    {
        temiz = TakvimZamani.Duzelt(baslik, BaslikEnUzun + 1);
        if (temiz.Length == 0)
            return Sonuc.Gecersiz("baslik", "Başlık boş olamaz.");
        if (temiz.Length > BaslikEnUzun)
            return Sonuc.Gecersiz("baslik", $"Başlık en çok {BaslikEnUzun} karakter olabilir.");
        return Sonuc.Tamam;
    }

    public static Sonuc Yer(string? yer, out string? temiz)
    {
        temiz = null;
        if (string.IsNullOrWhiteSpace(yer))
            return Sonuc.Tamam;

        var duz = TakvimZamani.Duzelt(yer, YerEnUzun + 1);
        if (duz.Length > YerEnUzun)
            return Sonuc.Gecersiz("yer", $"Yer en çok {YerEnUzun} karakter olabilir.");

        temiz = duz;
        return Sonuc.Tamam;
    }

    public static Sonuc Kimlik(string? kimlik, out string temiz)
    {
        temiz = kimlik?.Trim() ?? "";
        if (temiz.Length == 0 || temiz.Length > KimlikEnUzun || temiz.Any(char.IsControl))
            return Sonuc.Gecersiz("kimlik", "Etkinlik kimliği geçersiz.");
        return Sonuc.Tamam;
    }

    // The time of the payload as Google's own shapes. Exactly one of the two forms (timed, all-day) may be used.
    public static Sonuc Zaman(
        bool? tumGun, string? baslangic, string? bitis, string? gun, string? bitisGunu, out GoogleZaman? bas, out GoogleZaman? bit)
    {
        bas = bit = null;
        if (tumGun == true)
        {
            if (baslangic is not null || bitis is not null)
                return Sonuc.Gecersiz("tumGun", "Tüm gün etkinlikte baslangic ve bitis verilmez; gun verilir.");
            if (!TakvimZamani.GunCoz(gun, out var ilk))
                return Sonuc.Gecersiz("gun", "Gün yyyy-MM-dd biçiminde olmalı.");

            var son = ilk;
            if (bitisGunu is not null && !TakvimZamani.GunCoz(bitisGunu, out son))
                return Sonuc.Gecersiz("bitisGunu", "Bitiş günü yyyy-MM-dd biçiminde olmalı.");
            if (son < ilk)
                return Sonuc.Gecersiz("bitisGunu", "Bitiş günü başlangıç gününden önce olamaz.");
            if (son.DayNumber - ilk.DayNumber >= TumGunEnCokGun)
                return Sonuc.Gecersiz("bitisGunu", $"Etkinlik en çok {TumGunEnCokGun} gün sürebilir.");
            if (YilDisinda(ilk.Year) || YilDisinda(son.Year))
                return Sonuc.Gecersiz("gun", "Tarih makul bir aralıkta olmalı.");

            // Google's end date of an all-day event is the day after the last one.
            bas = new GoogleZaman(null, ilk);
            bit = new GoogleZaman(null, son.AddDays(1));
            return Sonuc.Tamam;
        }

        if (gun is not null || bitisGunu is not null)
            return Sonuc.Gecersiz("gun", "Saatli etkinlikte gun verilmez; baslangic ve bitis verilir (tüm gün için tumGun true).");
        if (baslangic is null || bitis is null)
            return Sonuc.Gecersiz("baslangic", "baslangic ve bitis zorunlu.");
        if (!TakvimZamani.AnCoz(baslangic, out var b))
            return Sonuc.Gecersiz("baslangic", "Başlangıç, saat dilimi farkıyla yazılmalı (2026-11-09T14:00:00+03:00).");
        if (!TakvimZamani.AnCoz(bitis, out var s))
            return Sonuc.Gecersiz("bitis", "Bitiş, saat dilimi farkıyla yazılmalı (2026-11-09T15:00:00+03:00).");
        if (s <= b)
            return Sonuc.Gecersiz("bitis", "Bitiş başlangıçtan sonra olmalı.");
        if (s - b > TimeSpan.FromDays(SaatliEnCokGun))
            return Sonuc.Gecersiz("bitis", $"Saatli etkinlik en çok {SaatliEnCokGun} gün sürebilir.");
        if (YilDisinda(b.Year) || YilDisinda(s.Year))
            return Sonuc.Gecersiz("baslangic", "Tarih makul bir aralıkta olmalı.");

        bas = new GoogleZaman(b, null);
        bit = new GoogleZaman(s, null);
        return Sonuc.Tamam;
    }

    private static bool YilDisinda(int yil) => yil < EnErkenYil || yil > EnGecYil;
}
