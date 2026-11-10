using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;

namespace Kafamdakiler.Hatirlaticilar;

// The write rules of reminders. The endpoints call these (the web pages will too), so a rule lives in one place.
public static class HatirlaticiIslemleri
{
    private static TimeOnly KuralSaati(Hatirlatici h, TimeOnly varsayilan) => h.Saat ?? varsayilan;

    // Copies the form onto the entity and recomputes the next moment. Editing the rule clears a snooze.
    public static void Uygula(Hatirlatici h, HatirlaticiYazDto dto, TimeOnly varsayilan, DateTimeOffset simdi)
    {
        h.Baslik = dto.Baslik.Trim();
        h.Not = string.IsNullOrWhiteSpace(dto.Not) ? null : dto.Not.Trim();
        h.Tur = dto.Tur;
        h.Kime = dto.Tur == HatirlaticiTuru.Soz && !string.IsNullOrWhiteSpace(dto.Kime) ? dto.Kime.Trim() : null;
        h.Gun = dto.Gun!.Value;
        h.Saat = dto.Saat;
        h.Tekrar = dto.Tekrar;
        h.OnceGun = dto.OnceGun;
        h.Durum = dto.Durum;
        h.Israrli = dto.Israrli;
        h.IsrarAraligiDakika = dto.IsrarAraligiDakika;
        h.IsrarEnCok = dto.IsrarEnCok;
        h.Acil = dto.Acil;
        // The link fields: absent (null) keeps what the reminder has, so a form or an older client that does not know them cannot cut the
        // link by editing the title; an empty text takes the link away.
        if (dto.MaddeId is not null || dto.MaddeTarihi is not null)
        {
            h.MaddeId = string.IsNullOrWhiteSpace(dto.MaddeId) ? null : dto.MaddeId.Trim();
            h.MaddeTarihi = h.MaddeId is null ? null : dto.MaddeTarihi;
        }

        if (dto.GorevKimligi is not null)
            h.GorevKimligi = string.IsNullOrWhiteSpace(dto.GorevKimligi) ? null : dto.GorevKimligi.Trim();

        // The days only mean something to a weekly rule: anywhere else they are dropped; a weekly one without any given keeps its days.
        if (dto.Tekrar != Tekrar.Haftalik)
            h.Gunler = Gunler.Yok;
        else if (dto.Gunler is { } secilenler)
            h.Gunler = secilenler.Aggregate(Gunler.Yok, (toplam, gun) => toplam | gun);
        h.ErteleAn = null;
        h.SonrakiAn = HatirlaticiHesap.Sonraki(h.Tekrar, h.Gun, KuralSaati(h, varsayilan), simdi, h.Gunler);
    }

    // Done: a repeating reminder moves to its next turn (after the current one, even if marked early), a one-off is closed.
    public static Sonuc Yaptim(Hatirlatici h, TimeOnly varsayilan, DateTimeOffset simdi)
    {
        if (h.Durum != HatirlaticiDurumu.Acik)
            return Sonuc.Catisma("Hatırlatıcı açık değil.");

        h.ErteleAn = null;
        if (h.Tekrar == Tekrar.Yok)
            h.Durum = HatirlaticiDurumu.Tamam;
        else
            h.SonrakiAn = HatirlaticiHesap.Sonraki(h.Tekrar, h.Gun, KuralSaati(h, varsayilan),
                simdi > h.SonrakiAn ? simdi : h.SonrakiAn, h.Gunler);

        return Sonuc.Tamam;
    }

    // Snooze: only the moment changes, the rule stays.
    public static Sonuc Ertele(Hatirlatici h, string? sure, TimeOnly varsayilan, DateTimeOffset simdi)
    {
        if (h.Durum != HatirlaticiDurumu.Acik)
            return Sonuc.Catisma("Hatırlatıcı açık değil.");

        if (HatirlaticiHesap.ErteleAni(sure, simdi, KuralSaati(h, varsayilan)) is not { } an)
            return Sonuc.Gecersiz("sure", "Süre 1s ya da yarin olmalı.");

        h.ErteleAn = an;
        return Sonuc.Tamam;
    }

    // The same two actions, and on success the event the weekly summary counts. The event is added to the context; the caller saves.
    public static Sonuc Yaptim(AppDbContext db, Hatirlatici h, TimeOnly varsayilan, DateTimeOffset simdi) =>
        OlayliUygula(db, h, HatirlaticiOlayTuru.Yapildi, simdi, () => Yaptim(h, varsayilan, simdi));

    public static Sonuc Ertele(AppDbContext db, Hatirlatici h, string? sure, TimeOnly varsayilan, DateTimeOffset simdi) =>
        OlayliUygula(db, h, HatirlaticiOlayTuru.Ertelendi, simdi, () => Ertele(h, sure, varsayilan, simdi));

    private static Sonuc OlayliUygula(AppDbContext db, Hatirlatici h, HatirlaticiOlayTuru tur, DateTimeOffset simdi, Func<Sonuc> uygula)
    {
        // The due moment is read before the action moves it.
        var hedef = h.EtkinAn;
        var sonuc = uygula();
        if (sonuc.Basarili)
            db.HatirlaticiOlaylari.Add(new HatirlaticiOlayi { HatirlaticiId = h.Id, Tur = tur, HedefAn = hedef, Zaman = simdi });

        return sonuc;
    }

    // The chosen days as the API shows them ("pzt", "cum"), Monday first; empty for anything but a weekly rule with days.
    public static List<Gunler> GunListesi(Hatirlatici h) =>
        h.Tekrar == Tekrar.Haftalik
            ? Enum.GetValues<Gunler>().Where(g => g != Gunler.Yok && h.Gunler.HasFlag(g)).ToList()
            : [];

    public static HatirlaticiDto DtoYap(Hatirlatici h, DateTimeOffset simdi, string? zincirHatasi = null) => new(
        h.Id, h.Baslik, h.Not, h.Tur, h.Kime, h.Gun, h.Saat, h.Tekrar, h.OnceGun, h.Durum, h.SonrakiAn, h.ErteleAn, h.EtkinAn,
        HatirlaticiHesap.OnceAni(h.SonrakiAn, h.OnceGun), HatirlaticiHesap.KalanGun(h.EtkinAn, simdi), h.CreatedAt,
        h.Israrli, h.IsrarAraligiDakika, h.IsrarEnCok, h.Acil,
        h.MaddeId, h.MaddeTarihi, h.GorevKimligi, GunListesi(h), zincirHatasi);
}
