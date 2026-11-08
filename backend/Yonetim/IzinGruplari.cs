using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Ses;
using Kafamdakiler.Takvim;
using Kafamdakiler.Yakalamalar;

namespace Kafamdakiler.Yonetim;

public enum GrupKipi
{
    Kapali,
    Okur,
    OkurVeYazar,
    // The permissions of the group were set by hand to a mix that none of the three choices makes.
    Ozel,
}

// The Asistan's permissions grouped by area for the Yönetim screens: six cards with Kapalı / Okur / Okur ve yazar, and the
// assistant switch on its own. Every permission of `Izinler.Tumu` falls in exactly one card, or is the switch (a test checks it).
// The mobile screen keeps the same table in Dart (mobile/lib/ui/yonetim/); change both together.
public static class IzinGruplari
{
    // `Okur` opens with the "Okur" choice; `Yazar` is what "Okur ve yazar" opens on top of it.
    public record Grup(string Anahtar, string Ad, string Aciklama, IReadOnlyList<string> Okur, IReadOnlyList<string> Yazar)
    {
        public IEnumerable<string> Hepsi => Okur.Concat(Yazar);
    }

    // The one permission that is not in a card: it lets the Asistan call Claude (summaries, task extraction).
    public const string AsistanAnahtari = SesPolicies.AsistanKullan;

    public static readonly IReadOnlyList<Grup> Tumu =
    [
        new("aliskanlik", "Alışkanlıklar", "Alışkanlıkları ve kayıtlarını görür, ekler, değiştirir.",
            [AliskanlikPolicies.Oku], [AliskanlikPolicies.Yaz]),
        new("hatirlatici", "Hatırlatıcılar", "Hatırlatıcıları görür, kurar, yaptım ve ertele işaretler.",
            [HatirlaticiPolicies.Oku], [HatirlaticiPolicies.Yaz]),
        new("gelen", "Gelen ve yakalamalar", "Yakalamaları ve gelen kutusunu görür, yakalama ekler, gelen kartını yerleştirir.",
            [YakalamaPolicies.Oku, GelenPolicies.Oku], [YakalamaPolicies.Yaz, GelenPolicies.Yaz]),
        new("beyin", "Beyin ve plan", "Beyni okur; yazınca gün planına ve görevlere de dokunur.",
            [BeyinPolicies.Oku], [BeyinPolicies.PlanYaz, BeyinPolicies.GorevYaz]),
        new("takvim", "Takvim ve brifing", "Günün çizelgesini ve brifingi okur; yazınca takvime etkinlik ekler ve taşır (onay kuyruğundan geçerek).",
            [TakvimPolicies.Oku, BrifingPolicies.Oku], [TakvimPolicies.Yaz]),
        new("eylem", "Onay kuyruğu", "Bekleyen önerileri görür; yazınca onaylar, reddeder, geri alır.",
            [EylemPolicies.Oku], [EylemPolicies.Onayla]),
    ];

    public static Grup? Bul(string? anahtar) => Tumu.FirstOrDefault(g => g.Anahtar == anahtar);

    public static GrupKipi KipBul(Grup grup, IReadOnlySet<string> acik)
    {
        var okurAcik = grup.Okur.Count(acik.Contains);
        var yazarAcik = grup.Yazar.Count(acik.Contains);
        if (okurAcik == 0 && yazarAcik == 0)
            return GrupKipi.Kapali;
        if (okurAcik == grup.Okur.Count && yazarAcik == 0)
            return GrupKipi.Okur;
        if (okurAcik == grup.Okur.Count && yazarAcik == grup.Yazar.Count)
            return GrupKipi.OkurVeYazar;

        return GrupKipi.Ozel;
    }

    // The permissions that make `kip` true for the group; `Ozel` cannot be chosen, it is only ever read.
    public static IReadOnlyList<string> AcilacakIzinler(Grup grup, GrupKipi kip) => kip switch
    {
        GrupKipi.Okur => grup.Okur,
        GrupKipi.OkurVeYazar => [.. grup.Hepsi],
        _ => [],
    };
}
