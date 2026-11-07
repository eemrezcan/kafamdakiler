using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Ses;
using Kafamdakiler.Yakalamalar;

namespace Kafamdakiler.Yonetim;

// The one list of permissions the Sahip can give the Asistan (K-0009). Each value is an `izin` claim and a policy name;
// the web panel, /api/yonetim and the mobile screen all show this list, so a new permission is added here only.
public static class Izinler
{
    public record Izin(string Ad, string Aciklama);

    public static readonly IReadOnlyList<Izin> Tumu =
    [
        new(AliskanlikPolicies.Oku, "Alışkanlıkları ve kayıtlarını okur"),
        new(AliskanlikPolicies.Yaz, "Alışkanlık, öğe ve kayıt ekler, değiştirir, siler"),
        new(YakalamaPolicies.Oku, "Yakalamaları okur"),
        new(YakalamaPolicies.Yaz, "Yakalama ekler, değiştirir, siler"),
        new(HatirlaticiPolicies.Oku, "Hatırlatıcıları okur"),
        new(HatirlaticiPolicies.Yaz, "Hatırlatıcı ekler, değiştirir, siler, yaptım ve ertele işaretler"),
        new(BeyinPolicies.Oku, "Beyni okur: proje, gün planı, arama, not"),
        new(BeyinPolicies.PlanYaz, "Gün planına madde ekler, işaretler, devreder, not yazar; görevi günlere böler"),
        new(BeyinPolicies.GorevYaz, "Görev ekler ve bitirir"),
        new(EylemPolicies.Oku,"Onay kuyruğunu okur: bekleyen ve karara bağlanmış eylemler"),
        new(EylemPolicies.Onayla, "Onay kuyruğundaki eylemi uygular, reddeder, geri alır"),
        new(GelenPolicies.Oku, "Gelen kutusunu okur: kartlar ve Claude'un yerleştirme önerileri"),
        new(GelenPolicies.Yaz, "Gelen kartı için yeniden öneri ister, kartı elle yerleştirir"),
        new(SesPolicies.AsistanKullan, "Asistanı kullanır: metinden iş çıkarır, metni özetler ya da maddeler (Claude'u çağırır, kaydetmez)"),
    ];

    public static bool Gecerli(string? ad) => Tumu.Any(i => i.Ad == ad);
}
