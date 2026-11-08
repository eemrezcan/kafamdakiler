using System.Globalization;

namespace Kafamdakiler.Aliskanliklar;

// Text and choices for the web pages (Turkish display).
public static class Gorunum
{
    private static readonly CultureInfo Tr = new("tr-TR");

    // Colors of the habit cards; the names are also the CSS classes (kd-c-violet ...).
    public static readonly string[] Renkler = ["violet", "pink", "blue", "teal", "green", "amber", "red", "slate"];

    // Lucide icon keys; the same list as the mobile app.
    public static readonly string[] Ikonlar =
    [
        "book-open", "book", "glass-water", "droplet", "coffee", "cigarette", "footprints", "bike", "dumbbell",
        "brain", "flower-2", "film", "tv", "graduation-cap", "headphones", "music", "pencil", "languages",
        "moon", "sun", "pill", "heart", "apple", "wine", "smartphone", "target", "flame", "star",
    ];

    public static readonly Gunler[] Haftanin = [Gunler.Pzt, Gunler.Sal, Gunler.Car, Gunler.Per, Gunler.Cum, Gunler.Cmt, Gunler.Paz];

    public static string RenkSinifi(string renk) => "kd-c-" + (Renkler.Contains(renk) ? renk : "violet");

    public static string Ikon(string ikon) => "lucide-" + (Ikonlar.Contains(ikon) ? ikon : "target");

    // 2.5 -> "2,5"
    public static string Sayi(decimal deger) => deger.ToString("0.##", Tr);

    // For <input type="number" value="...">: always a dot.
    public static string Girdi(decimal deger) => AliskanlikIslemleri.Say(deger);

    public static string Tarih(DateOnly tarih) => tarih.ToString("d MMMM yyyy", Tr);

    public static string GunAy(DateOnly tarih) => tarih.ToString("d MMM", Tr);

    public static string GunAdi(DateOnly tarih) => tarih.ToString("dddd", Tr);

    public static string GunKisa(DateOnly tarih) => tarih.ToString("ddd", Tr);

    // 40 -> "40 dk", 125 -> "2 sa 5 dk"
    public static string Sure(int dakika) =>
        dakika < 60 ? $"{dakika} dk" : dakika % 60 == 0 ? $"{dakika / 60} sa" : $"{dakika / 60} sa {dakika % 60} dk";

    // For style="width:...": always a dot.
    public static string Genislik(double oran) => (oran * 100).ToString("0.#", CultureInfo.InvariantCulture) + "%";

    // Turkish puts the sign first: "%14".
    public static string Yuzde(double oran) => "%" + Math.Round(oran * 100).ToString("0", Tr);

    public static string GunAdi(Gunler gun) => gun switch
    {
        Gunler.Pzt => "Pzt",
        Gunler.Sal => "Sal",
        Gunler.Car => "Çar",
        Gunler.Per => "Per",
        Gunler.Cum => "Cum",
        Gunler.Cmt => "Cmt",
        Gunler.Paz => "Paz",
        _ => "",
    };

    public static string DurumAdi(OgeDurumu durum) => durum switch
    {
        OgeDurumu.Siradaki => "Sıradaki",
        OgeDurumu.Devam => "Devam",
        OgeDurumu.Bitti => "Bitti",
        OgeDurumu.Birakildi => "Bırakıldı",
        _ => "",
    };

    public static string SiklikMetni(AliskanlikDto a) => a.Siklik switch
    {
        Siklik.HaftadaN => $"Haftada {a.HaftalikSayi} gün",
        Siklik.BelirliGunler => string.Join(", ", a.Gunler.Select(GunAdi)),
        _ => "Her gün",
    };

    // "6 / 8 bardak", "1 / en çok 2 kahve", "Yapıldı"
    public static string BugunMetni(AliskanlikDto a)
    {
        var miktar = a.Bugun.Miktar;
        if (a.Olcu == Olcu.EvetHayir)
        {
            return a.HedefYonu == HedefYonu.EnAz
                ? (miktar > 0 ? "Yapıldı" : "Henüz yapılmadı")
                : (miktar > 0 ? "Yapıldı (sınır aşıldı)" : "Yapılmadı");
        }

        var hedef = Sayi(a.GunlukHedef ?? 0);
        return a.HedefYonu == HedefYonu.EnAz
            ? $"{Sayi(miktar)} / {hedef} {a.Birim}"
            : $"{Sayi(miktar)} / en çok {hedef} {a.Birim}";
    }

    // Fill of the progress bar (0..1) and its state: "ok", "over" (EnCok limit passed) or "".
    public static (double Oran, string Durum) Ilerleme(AliskanlikDto a)
    {
        if (a.Olcu == Olcu.EvetHayir)
            return (a.Bugun.Miktar > 0 ? 1 : 0, a.HedefYonu == HedefYonu.EnCok && a.Bugun.Miktar > 0 ? "over" : a.Bugun.Miktar > 0 ? "ok" : "");

        var hedef = a.GunlukHedef ?? 0;
        var oran = hedef > 0 ? Math.Min(1, (double)(a.Bugun.Miktar / hedef)) : (a.Bugun.Miktar > 0 ? 1 : 0);

        if (a.HedefYonu == HedefYonu.EnCok)
            return (oran, a.Bugun.Miktar > hedef ? "over" : "");

        return (oran, a.Bugun.Deger >= 1 ? "ok" : "");
    }

    // One day of the strips: "done", "part", "miss" or "off" (not planned that day, or before the habit existed).
    public static string GunDurumu(GunDto gun, DateTimeOffset olusturulma) =>
        gun.Tarih < AliskanlikHesap.AliskanlikGunu(olusturulma) ? "none"
        : !gun.Planli ? "off"
        : gun.Deger >= 1 ? "done" : gun.Deger > 0 ? "part" : "miss";

    // Step of the − / + buttons: whole numbers, or halves when the goal itself is fractional.
    public static decimal Adim(AliskanlikDto a) =>
        a.GunlukHedef is { } hedef && hedef != Math.Floor(hedef) ? 0.5m : 1m;
}
