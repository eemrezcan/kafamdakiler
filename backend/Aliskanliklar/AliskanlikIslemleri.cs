using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Aliskanliklar;

// Outcome of a write that can be refused. The API turns it into 400/409, the web pages into form errors.
public record Sonuc(string? Alan = null, string? Mesaj = null, bool Cakisma = false)
{
    public static readonly Sonuc Tamam = new();

    public bool Basarili => Mesaj is null;

    public static Sonuc Gecersiz(string alan, string mesaj) => new(alan, mesaj);

    public static Sonuc Catisma(string mesaj) => new(null, mesaj, true);
}

// The write rules of habits, items and sessions. The /api endpoints and the Razor pages both call these,
// so a rule lives in one place.
public static class AliskanlikIslemleri
{
    public static DateOnly Bugun() => AliskanlikHesap.AliskanlikGunu(DateTimeOffset.UtcNow);

    // Habits

    public static void AliskanlikUygula(Aliskanlik a, AliskanlikYazDto dto)
    {
        a.Ad = dto.Ad.Trim();
        a.Tur = dto.Tur!.Value;
        a.Ikon = dto.Ikon;
        a.Renk = dto.Renk;
        a.Olcu = dto.Olcu!.Value;
        a.HedefYonu = dto.HedefYonu;
        a.GunlukHedef = dto.Olcu == Olcu.Sayili ? dto.GunlukHedef : null;
        a.Birim = dto.Olcu == Olcu.Sayili ? dto.Birim?.Trim() : null;
        a.OgeEtiketi = dto.Tur == AliskanlikTuru.Raf ? dto.OgeEtiketi?.Trim() : null;
        a.AltBaslikEtiketi = dto.Tur == AliskanlikTuru.Raf ? dto.AltBaslikEtiketi?.Trim() : null;
        a.Siklik = dto.Siklik;
        a.HaftalikSayi = dto.Siklik == Siklik.HaftadaN ? dto.HaftalikSayi : null;
        a.Gunler = dto.Siklik == Siklik.BelirliGunler
            ? dto.Gunler!.Aggregate(Gunler.Yok, (toplam, gun) => toplam | gun)
            : null;
        a.Sira = dto.Sira;
        a.Arsivlendi = dto.Arsivlendi;
    }

    public static Sonuc AliskanlikKontrol(Aliskanlik a, AliskanlikYazDto dto) =>
        a.Tur != dto.Tur ? Sonuc.Catisma("Alışkanlığın türü sonradan değiştirilemez.") : Sonuc.Tamam;

    // Entries, items and sessions go with it (cascade); the photos are removed from the disk too.
    public static async Task AliskanlikSilAsync(AppDbContext db, DosyaDeposu depo, Aliskanlik a, CancellationToken ct)
    {
        var fotograflar = await db.Ogeler.Where(o => o.AliskanlikId == a.Id && o.FotografId != null)
            .Select(o => o.FotografId!.Value).ToListAsync(ct);

        db.Aliskanliklar.Remove(a);
        await db.SaveChangesAsync(ct);
        await depo.SilAsync(fotograflar, ct);
    }

    // Daily entries (Sayac)

    // Writes the day's total, not an increment, so a retry changes nothing.
    public static async Task<Sonuc> KayitYazAsync(AppDbContext db, Aliskanlik a, DateOnly tarih, decimal miktar, int? dakika, CancellationToken ct)
    {
        if (a.Tur == AliskanlikTuru.Raf)
            return Sonuc.Catisma("Raf alışkanlığına günlük kayıt yazılmaz; oturum eklenir.");
        if (tarih > Bugun())
            return Sonuc.Gecersiz("tarih", "Gelecek bir güne kayıt yazılamaz.");

        var kayit = await db.AliskanlikKayitlari.FirstOrDefaultAsync(k => k.AliskanlikId == a.Id && k.Tarih == tarih, ct);
        if (kayit is null)
        {
            kayit = new AliskanlikKaydi { AliskanlikId = a.Id, Tarih = tarih };
            db.AliskanlikKayitlari.Add(kayit);
        }

        kayit.Miktar = a.Olcu == Olcu.EvetHayir ? 1 : miktar;
        kayit.Dakika = dakika;
        await db.SaveChangesAsync(ct);
        return Sonuc.Tamam;
    }

    public static async Task<Sonuc> KayitSilAsync(AppDbContext db, Aliskanlik a, DateOnly tarih, CancellationToken ct)
    {
        if (a.Tur == AliskanlikTuru.Raf)
            return Sonuc.Catisma("Raf alışkanlığına günlük kayıt yazılmaz; oturum eklenir.");

        await db.AliskanlikKayitlari.Where(k => k.AliskanlikId == a.Id && k.Tarih == tarih).ExecuteDeleteAsync(ct);
        return Sonuc.Tamam;
    }

    // Items (Raf)

    public static IQueryable<Oge> OgeSorgu(AppDbContext db) => db.Ogeler.Include(o => o.Oturumlar);

    public static decimal GuncelKonum(Oge oge) =>
        OgeHesap.OturumBaslangici(oge.BaslangicKonumu, oge.Oturumlar.Count > 0 ? oge.Oturumlar.Max(t => t.BitisKonum) : null);

    public static async Task<(Sonuc Sonuc, Oge? Oge)> OgeOlusturAsync(AppDbContext db, Aliskanlik a, OgeYazDto dto, CancellationToken ct)
    {
        if (a.Tur != AliskanlikTuru.Raf)
            return (Sonuc.Catisma("Yalnız Raf alışkanlığına öğe eklenir."), null);
        if (await FotografYokMu(db, dto.FotografId, ct))
            return (Sonuc.Gecersiz("fotografId", "Fotoğraf bulunamadı."), null);

        var oge = new Oge { AliskanlikId = a.Id };
        if (dto.Id is { } id)
            oge.Id = id;
        OgeUygula(oge, dto);
        db.Ogeler.Add(oge);
        await db.SaveChangesAsync(ct);
        return (Sonuc.Tamam, oge);
    }

    // `oge` must come from OgeSorgu (sessions loaded).
    public static async Task<Sonuc> OgeGuncelleAsync(AppDbContext db, DosyaDeposu depo, Oge oge, OgeYazDto dto, CancellationToken ct)
    {
        // The first session must start where the item starts, so the start cannot move once sessions exist.
        if (oge.Oturumlar.Count > 0 && dto.BaslangicKonumu != oge.BaslangicKonumu)
            return Sonuc.Catisma("Oturum girilmiş öğenin başlangıç konumu değiştirilemez.");
        if (dto.Toplam is { } toplam && toplam < GuncelKonum(oge))
            return Sonuc.Gecersiz("toplam", "Toplam, güncel konumdan küçük olamaz.");
        if (dto.FotografId != oge.FotografId && await FotografYokMu(db, dto.FotografId, ct))
            return Sonuc.Gecersiz("fotografId", "Fotoğraf bulunamadı.");

        var eskiFotograf = oge.FotografId;
        OgeUygula(oge, dto);
        await db.SaveChangesAsync(ct);

        // A replaced photo is no longer used by anything: remove it from the disk too.
        if (eskiFotograf is { } eski && eski != oge.FotografId)
            await depo.SilAsync([eski], ct);

        return Sonuc.Tamam;
    }

    public static async Task OgeSilAsync(AppDbContext db, DosyaDeposu depo, Oge oge, CancellationToken ct)
    {
        var fotograf = oge.FotografId;
        db.Ogeler.Remove(oge);
        await db.SaveChangesAsync(ct);
        if (fotograf is { } f)
            await depo.SilAsync([f], ct);
    }

    // Moves the item between shelves (Devam / Bitti / Birakildi...) without touching its other fields.
    public static async Task OgeDurumAsync(AppDbContext db, Oge oge, OgeDurumu durum, CancellationToken ct)
    {
        DurumUygula(oge, durum);
        await db.SaveChangesAsync(ct);
    }

    private static void OgeUygula(Oge oge, OgeYazDto dto)
    {
        oge.Ad = dto.Ad.Trim();
        oge.AltBaslik = string.IsNullOrWhiteSpace(dto.AltBaslik) ? null : dto.AltBaslik.Trim();
        oge.Toplam = dto.Toplam;
        oge.BaslangicKonumu = dto.BaslangicKonumu;
        oge.FotografId = dto.FotografId;
        oge.Puan = dto.Puan;
        oge.Not = string.IsNullOrWhiteSpace(dto.Not) ? null : dto.Not;
        DurumUygula(oge, dto.Durum);
    }

    private static void DurumUygula(Oge oge, OgeDurumu durum)
    {
        oge.Durum = durum;
        if (durum == OgeDurumu.Devam)
            oge.BaslamaTarihi ??= Bugun();
        if (durum == OgeDurumu.Bitti)
            oge.BitisTarihi ??= Bugun();
        else
            oge.BitisTarihi = null;
    }

    private static async Task<bool> FotografYokMu(AppDbContext db, Guid? fotografId, CancellationToken ct) =>
        fotografId is { } id && !await db.Dosyalar.AnyAsync(d => d.Id == id, ct);

    // Sessions (Raf)

    // `oge` must come from OgeSorgu (sessions loaded). The start position is found by the server.
    public static async Task<(Sonuc Sonuc, Oturum? Oturum)> OturumEkleAsync(AppDbContext db, Oge oge, OturumEkleDto dto, CancellationToken ct)
    {
        if (oge.Durum == OgeDurumu.Bitti)
            return (Sonuc.Catisma("Öğe bitti; oturum eklenemez."), null);

        var baslangic = GuncelKonum(oge);
        if (dto.BaslangicKonum is { } gonderilen && gonderilen != baslangic)
            return (Sonuc.Catisma($"Başlangıç konumu uyuşmuyor: sunucuda {Say(baslangic)}, gönderilen {Say(gonderilen)}."), null);
        if (dto.BitisKonum <= baslangic)
            return (Sonuc.Gecersiz("bitisKonum", $"Bitiş konumu başlangıçtan ({Say(baslangic)}) büyük olmalı."), null);
        if (oge.Toplam is { } toplam && dto.BitisKonum > toplam)
            return (Sonuc.Gecersiz("bitisKonum", $"Bitiş konumu toplamı ({Say(toplam)}) aşamaz."), null);

        var tarih = AliskanlikHesap.AliskanlikGunu(dto.BaslangicAni ?? DateTimeOffset.UtcNow);
        var oturum = new Oturum
        {
            OgeId = oge.Id,
            Tarih = tarih,
            BaslangicKonum = baslangic,
            BitisKonum = dto.BitisKonum,
            Dakika = dto.Dakika,
        };
        if (dto.Id is { } id)
            oturum.Id = id;
        db.Oturumlar.Add(oturum);

        oge.Durum = OgeDurumu.Devam;
        oge.BaslamaTarihi ??= tarih;
        if (OgeHesap.Bitti(dto.BitisKonum, oge.Toplam))
        {
            oge.Durum = OgeDurumu.Bitti;
            oge.BitisTarihi = tarih;
        }

        await db.SaveChangesAsync(ct);
        return (Sonuc.Tamam, oturum);
    }

    // `oturum.Oge` must be loaded. Only the last session of an item can change.
    public static async Task<Sonuc> OturumGuncelleAsync(AppDbContext db, Oturum oturum, decimal bitisKonum, int? dakika, CancellationToken ct)
    {
        if (!await SonMu(db, oturum, ct))
            return Sonuc.Catisma("Yalnız son oturum değiştirilebilir.");

        var oge = oturum.Oge!;
        if (bitisKonum <= oturum.BaslangicKonum)
            return Sonuc.Gecersiz("bitisKonum", $"Bitiş konumu başlangıçtan ({Say(oturum.BaslangicKonum)}) büyük olmalı.");
        if (oge.Toplam is { } toplam && bitisKonum > toplam)
            return Sonuc.Gecersiz("bitisKonum", $"Bitiş konumu toplamı ({Say(toplam)}) aşamaz.");

        oturum.BitisKonum = bitisKonum;
        oturum.Dakika = dakika;

        if (oge.Toplam is not null)
        {
            if (OgeHesap.Bitti(bitisKonum, oge.Toplam))
            {
                oge.Durum = OgeDurumu.Bitti;
                oge.BitisTarihi = oturum.Tarih;
            }
            else if (oge.Durum == OgeDurumu.Bitti)
            {
                oge.Durum = OgeDurumu.Devam;
                oge.BitisTarihi = null;
            }
        }

        await db.SaveChangesAsync(ct);
        return Sonuc.Tamam;
    }

    // `oturum.Oge` must be loaded.
    public static async Task<Sonuc> OturumSilAsync(AppDbContext db, Oturum oturum, CancellationToken ct)
    {
        if (!await SonMu(db, oturum, ct))
            return Sonuc.Catisma("Yalnız son oturum silinebilir.");

        // If this session finished the item, the item is back in progress.
        var oge = oturum.Oge!;
        if (oge.Durum == OgeDurumu.Bitti && OgeHesap.Bitti(oturum.BitisKonum, oge.Toplam))
        {
            oge.Durum = OgeDurumu.Devam;
            oge.BitisTarihi = null;
        }

        db.Oturumlar.Remove(oturum);
        await db.SaveChangesAsync(ct);
        return Sonuc.Tamam;
    }

    private static Task<bool> SonMu(AppDbContext db, Oturum oturum, CancellationToken ct) =>
        db.Oturumlar.Where(t => t.OgeId == oturum.OgeId).AllAsync(t => t.BitisKonum <= oturum.BitisKonum, ct);

    // Number rounding used by the API and by the pages.

    public static double Yuvarla(double deger) => Math.Round(deger, 2);

    public static decimal Yuvarla(decimal deger) => Math.Round(deger, 2);

    // 35.00 -> 35 (numeric(10,2) values come back with two decimals).
    public static decimal Sade(decimal deger) => deger / 1.0000000000000000000000000000m;

    public static decimal? Sade(decimal? deger) => deger is { } d ? Sade(d) : null;

    // For messages and number inputs: 35.00 -> "35", 2.5 -> "2.5".
    public static string Say(decimal deger) => deger.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture);
}
