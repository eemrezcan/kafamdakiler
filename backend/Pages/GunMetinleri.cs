using System.Globalization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Yapilacaklar;

namespace Kafamdakiler.Pages;

// What a row of the day list is told with (Turkish display), and what the row partial needs. Pure functions, so they are unit tested.
public static class GunMetinleri
{
    private static readonly CultureInfo Tr = new("tr-TR");

    public static string TurAdi(YapilacakTuru tur) => tur switch
    {
        YapilacakTuru.Plan => "Plan",
        YapilacakTuru.Gorev => "Görev",
        YapilacakTuru.Hatirlatici => "Hatırlatıcı",
        _ => "Etkinlik",
    };

    // The hue class of the row's left edge.
    public static string TurRengi(YapilacakTuru tur) => tur switch
    {
        YapilacakTuru.Plan => "kd-c-violet",
        YapilacakTuru.Gorev => "kd-c-blue",
        YapilacakTuru.Hatirlatici => "kd-c-pink",
        _ => "kd-c-teal",
    };

    public static string GunKisaltmasi(Gunler gun) => gun switch
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

    // "09:00 · her gün · acil": what the reminder of a row says, short.
    public static string HatirlaticiMetni(HatirlaticiOzetDto h)
    {
        var parcalar = new List<string> { h.Saat ?? "saatinde" };
        if (h.OnceGun > 0)
            parcalar.Add($"{h.OnceGun} gün önce");

        parcalar.Add(h.Tekrar switch
        {
            Tekrar.Gunluk => "her gün",
            Tekrar.Haftalik when h.Gunler is { Count: > 0 } gunler => string.Join(", ", gunler.Select(GunKisaltmasi)),
            Tekrar.Haftalik => "her hafta",
            Tekrar.Aylik => "her ay",
            Tekrar.Yillik => "her yıl",
            _ => "",
        });
        if (h.Acil)
            parcalar.Add("acil");
        if (h.Israrli)
            parcalar.Add("ısrarlı");

        return string.Join(" · ", parcalar.Where(p => p.Length > 0));
    }

    // What the day says about its calendar events when Google is not giving them (null when nothing is missing).
    public static string? GoogleNotu(string google) => google switch
    {
        "bagliDegil" => "Google Takvim bağlı değil, etkinlikler görünmüyor.",
        "yenidenBaglan" => "Google Takvim bağlantısı koptu, etkinlikler görünmüyor.",
        _ => null,
    };

    // "1 sa 30 dk", the gap between a row's start and end hours, or null.
    public static string? SaatAraligi(YapilacakDto oge) =>
        oge.TumGun ? "Tüm gün" : oge.Saat is null ? null : oge.BitisSaati is null ? oge.Saat : $"{oge.Saat}–{oge.BitisSaati}";

    // "d MMMM ddd" (3 Kasım Salı) for the day navigation and the calendar's headings.
    public static string GunEtiketi(DateOnly gun) => gun.ToString("d MMMM ddd", Tr);

    public static string AyBasligi(DateOnly ayBasi) => ayBasi.ToString("MMMM yyyy", Tr);
}

// The row partial's model: the row, the day it is shown on, where its forms send the person back to, and what it may do.
public record GunSatiriModeli(YapilacakDto Oge, DateOnly Gun, string Donus, bool Yazilabilir, IReadOnlyDictionary<string, string>? ProjeAdlari = null)
{
    public string ProjeAdi(string kimlik) => ProjeAdlari is not null && ProjeAdlari.TryGetValue(kimlik, out var ad) ? ad : kimlik;
}

// The reminder fields partial's model: the reminder the row has (null for a new one). A record, because a null `model` would fall back to the parent's.
public record HatirlaticiAlanlari(HatirlaticiOzetDto? Ozet);

// The new-item form partial's model: the day it adds to and where it goes back to.
public record YeniOgeModeli(DateOnly Gun, string Donus);
