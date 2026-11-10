using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;
using static Kafamdakiler.Yapilacaklar.GunEndpoints;

namespace Kafamdakiler.Yapilacaklar;

// The writes of the day view (K-0024, §1.1, §2, §4). Each goes to what already writes: the brain's plan and tasks (BeyinYazma), the
// reminder rules (HatirlaticiIslemleri) and the chain between them (HatirlaticiZinciri). The endpoint has checked the permissions already.
public class GunIslemleri(
    AppDbContext db, BeyinIstemcisi beyin, GunGorunumuServisi gunServisi, HatirlaticiZinciriServisi zincir, HatirlaticiAyari ayar,
    TimeProvider saat, ILogger<GunIslemleri> log)
{
    // "Yaptım" on any item of the list. `onek` is m, g or h. A refusal is a YazmaYaniti (400/404/409/503) that is not kept under an
    // Idempotency-Key; what was written is a 200, and an uncertain brain answer a 202.
    public async Task<YazmaYaniti> YaptimAsync(DateOnly gun, char onek, string deger, string kimlik, bool geri, Guid? kullaniciId, CancellationToken ct)
    {
        var simdi = saat.GetUtcNow();
        switch (onek)
        {
            case 'm':
            {
                var yanit = await BeyinYazma.MaddeIsaretle($"{gun:yyyy-MM-dd}", new MaddeIsaretleGirdi(deger, geri), beyin, log, ct);
                if (!yanit.Basarili)
                    return yanit;

                var dto = (MaddeIsaretlendiDto)yanit.Veri!;
                // Only a tick closes what is tied to the item; taking it back leaves the reminders as they are.
                var zincirSonucu = geri
                    ? ZincirSonucu.Bos
                    : await HatirlaticiZinciri.MaddeIsaretlendiAsync(db, dto.Tarih, deger, dto, ayar.VarsayilanSaat, simdi, log, ct);
                var oge = await OgeAlAsync(gun, kimlik, kullaniciId, () => MaddedenOge(dto.Madde, kimlik, gun), ct);
                return YazmaYaniti.Tamam(new YaptimYanitiDto(oge, zincirSonucu.Kimlikler, zincirSonucu.Hata));
            }

            case 'g':
            {
                // The task leaves the open list once it is finished, so what the person saw is read first and marked done.
                var onceki = await OgeAlAsync(gun, kimlik, kullaniciId, () => null, ct);
                var yanit = await BeyinYazma.GorevBitir(deger, beyin, log, saat, ct);
                if (!yanit.Basarili)
                    return yanit;

                var zincirSonucu = await HatirlaticiZinciri.GorevBitirildiAsync(db, deger, ayar.VarsayilanSaat, simdi, log, ct);
                var oge = (onceki ?? GorevOgesi(kimlik, deger, gun)) with { Durum = YapilacakDurumu.Yapildi };
                return YazmaYaniti.Tamam(new YaptimYanitiDto(oge, zincirSonucu.Kimlikler, zincirSonucu.Hata));
            }

            default:
            {
                var h = await db.Hatirlaticilar.FindAsync([Guid.Parse(deger)], ct);
                if (h is null)
                    return YazmaYaniti.Red(StatusCodes.Status404NotFound, "Bulunamadı", "Hatırlatıcı bulunamadı.");

                if (geri)
                {
                    // Only a closed one-off can be opened again: a repeating reminder has already moved on to its next turn.
                    if (h is not { Durum: HatirlaticiDurumu.Tamam, Tekrar: Tekrar.Yok })
                        return YazmaYaniti.Red(StatusCodes.Status409Conflict, "Hatırlatıcı geri alınamaz", "Yalnız tamamlanmış tek seferlik hatırlatıcı yeniden açılır.");

                    h.Durum = HatirlaticiDurumu.Acik;
                    // The weekly summary counted that "yaptım"; it no longer stands.
                    var olay = await db.HatirlaticiOlaylari.Where(o => o.HatirlaticiId == h.Id && o.Tur == HatirlaticiOlayTuru.Yapildi)
                        .OrderByDescending(o => o.Zaman).FirstOrDefaultAsync(ct);
                    if (olay is not null)
                        db.HatirlaticiOlaylari.Remove(olay);
                    await db.SaveChangesAsync(ct);
                    return YazmaYaniti.Tamam(new YaptimYanitiDto(
                        await OgeAlAsync(gun, kimlik, kullaniciId, () => HatirlaticidanOge(h, YapilacakDurumu.Acik, gun), ct), [], null));
                }

                // The turn that is being done, read before the reminder moves on to the next one.
                var hedefAn = h.EtkinAn;
                var sonuc = HatirlaticiIslemleri.Yaptim(db, h, ayar.VarsayilanSaat, simdi);
                if (!sonuc.Basarili)
                    return sonuc.Alan is null
                        ? YazmaYaniti.Red(StatusCodes.Status409Conflict, "Çakışma", sonuc.Mesaj!)
                        : YazmaYaniti.Sorun(sonuc.Alan, sonuc.Mesaj!);

                // The reminder is saved first: a failed step of the chain does not undo it.
                await db.SaveChangesAsync(ct);
                var zincirSonucu = await zincir.HatirlaticiYapildiAsync(h, hedefAn, ct);
                var oge = await OgeAlAsync(gun, kimlik, kullaniciId, () => HatirlaticidanOge(h, YapilacakDurumu.Yapildi, gun), ct);
                return YazmaYaniti.Tamam(new YaptimYanitiDto(oge, zincirSonucu.Kimlikler, zincirSonucu.Hata));
            }
        }
    }

    // Carry an item to the next day (E2). A plan item goes through the brain's own `gun devret`; a task that has no item is added to the next
    // day's plan as an item linked to it (`gun ekle --gorev`, with the task's title); a reminder is snoozed to tomorrow (its own "yarin").
    // The answer is the item as it is on its new day.
    public async Task<YazmaYaniti> DevretAsync(DateOnly gun, char onek, string deger, string kimlik, Guid? kullaniciId, CancellationToken ct)
    {
        var simdi = saat.GetUtcNow();
        switch (onek)
        {
            case 'm':
            {
                var yanit = await BeyinYazma.MaddeDevret($"{gun:yyyy-MM-dd}", new MaddeDevretGirdi(deger), beyin, log, ct);
                if (!yanit.Basarili)
                    return yanit;

                var dto = (MaddeDevredildiDto)yanit.Veri!;
                var yeniKimlik = $"m:{dto.Madde.Id}";
                var oge = await OgeAlAsync(dto.DevredilenGun, yeniKimlik, kullaniciId, () => MaddedenOge(dto.Madde, yeniKimlik, dto.DevredilenGun), ct);
                return YazmaYaniti.Tamam(new DevretYanitiDto(oge));
            }

            case 'g':
            {
                var gorev = await OgeAlAsync(gun, kimlik, kullaniciId, () => null, ct);
                if (gorev is null)
                    return YazmaYaniti.Red(StatusCodes.Status404NotFound, "Bulunamadı", "Görev o günün listesinde yok.");

                var yarin = gun.AddDays(1);
                var metin = Kisalt(YapilacakYardimcisi.BaslikTemizle(gorev.Baslik), BeyinYazma.EnUzunMetin);
                var yanit = await BeyinYazma.MaddeEkle($"{yarin:yyyy-MM-dd}", new MaddeEkleGirdi(metin, null, deger), beyin, log, ct);
                if (!yanit.Basarili)
                    return yanit;

                var dto = (MaddeEklendiDto)yanit.Veri!;
                var yeniKimlik = $"m:{dto.Madde.Id}";
                var oge = await OgeAlAsync(yarin, yeniKimlik, kullaniciId, () => MaddedenOge(dto.Madde, yeniKimlik, yarin), ct);
                return YazmaYaniti.Tamam(new DevretYanitiDto(oge));
            }

            default:
            {
                var h = await db.Hatirlaticilar.FindAsync([Guid.Parse(deger)], ct);
                if (h is null)
                    return YazmaYaniti.Red(StatusCodes.Status404NotFound, "Bulunamadı", "Hatırlatıcı bulunamadı.");

                var sonuc = HatirlaticiIslemleri.Ertele(db, h, "yarin", ayar.VarsayilanSaat, simdi);
                if (!sonuc.Basarili)
                    return sonuc.Alan is null
                        ? YazmaYaniti.Red(StatusCodes.Status409Conflict, "Çakışma", sonuc.Mesaj!)
                        : YazmaYaniti.Sorun(sonuc.Alan, sonuc.Mesaj!);

                await db.SaveChangesAsync(ct);
                var yeniGun = GunSiniri.Bugun(h.EtkinAn);
                var oge = await OgeAlAsync(yeniGun, kimlik, kullaniciId, () => HatirlaticidanOge(h, YapilacakDurumu.Acik, yeniGun), ct);
                return YazmaYaniti.Tamam(new DevretYanitiDto(oge));
            }
        }
    }

    // A new item (§4): `gun ekle` with the title and the estimate in the brain's own syntax (what the approval queue's "plan-ekle" does),
    // then the reminder when the body has one, tied to the item that was just written.
    public async Task<YazmaYaniti> OgeEkleAsync(DateOnly gun, YeniOgeGirdisi girdi, Guid? kullaniciId, CancellationToken ct)
    {
        var baslik = girdi.Baslik!.Trim();
        var metin = PlanEkleTuru.MaddeMetni(new PlanEkleYuku($"{gun:yyyy-MM-dd}", baslik, girdi.Bolum, girdi.TahminDk));
        var yanit = await BeyinYazma.MaddeEkle($"{gun:yyyy-MM-dd}", new MaddeEkleGirdi(metin, girdi.Bolum, null), beyin, log, ct);
        if (!yanit.Basarili)
            return yanit;

        var dto = (MaddeEklendiDto)yanit.Veri!;
        var simdi = saat.GetUtcNow();
        var kimlik = $"m:{dto.Madde.Id}";
        if (girdi.Hatirlatici is { } hatirlatici)
        {
            var yaz = new HatirlaticiYazDto
            {
                Baslik = Kisalt(YapilacakYardimcisi.BaslikTemizle(dto.Madde.Baslik), 200),
                Tur = HatirlaticiTuru.Gorev,
                Gun = gun,
                // The hour of the form is the reminder's when the reminder has none of its own.
                Saat = hatirlatici.Saat ?? girdi.Saat,
                Tekrar = hatirlatici.Tekrar,
                Gunler = hatirlatici.Gunler,
                Acil = hatirlatici.Acil,
                Israrli = hatirlatici.Israrli,
                OnceGun = hatirlatici.OnceGun,
                MaddeId = dto.Madde.Id,
                MaddeTarihi = dto.Tarih,
                GorevKimligi = dto.Madde.Gorev,
            };
            var h = new Hatirlatici();
            HatirlaticiIslemleri.Uygula(h, yaz, ayar.VarsayilanSaat, simdi);
            db.Hatirlaticilar.Add(h);
            await db.SaveChangesAsync(ct);
        }

        var oge = await OgeAlAsync(gun, kimlik, kullaniciId, () => MaddedenOge(dto.Madde, kimlik, gun), ct);
        return YazmaYaniti.Tamam(oge);
    }

    // The reminder of an item (§2): POST sets it up.
    public async Task<IResult> HatirlaticiKurAsync(DateOnly gun, string kimlik, KimlikParcasi parca, OgeHatirlaticiDto dto, Guid? kullaniciId, CancellationToken ct)
    {
        var bulunan = await OgeBulAsync(gun, kimlik, kullaniciId, ct);
        if (bulunan.Hata is not null)
            return bulunan.Hata;

        if (await Hatirlaticilari(gun, parca).AnyAsync(h => h.Durum == HatirlaticiDurumu.Acik, ct))
            return Cakisma("Bu öğenin zaten bir hatırlatıcısı var; değiştirmek için PUT, kaldırmak için DELETE kullan.");

        var oge = bulunan.Oge!;
        var plan = parca.Onek == 'm';
        var yaz = new HatirlaticiYazDto
        {
            Baslik = Kisalt(oge.Baslik, 200),
            Tur = HatirlaticiTuru.Gorev,
            Gun = gun,
            Saat = dto.Saat,
            Tekrar = dto.Tekrar,
            Gunler = dto.Gunler,
            Acil = dto.Acil,
            Israrli = dto.Israrli,
            OnceGun = dto.OnceGun,
            // A plan item is named with the day of its plan file; a task by its slug (an item that is linked to a task carries both).
            MaddeId = plan ? parca.Deger : null,
            MaddeTarihi = plan ? gun : null,
            GorevKimligi = plan ? oge.GorevKimligi : parca.Deger,
        };
        var simdi = saat.GetUtcNow();
        var h = new Hatirlatici();
        HatirlaticiIslemleri.Uygula(h, yaz, ayar.VarsayilanSaat, simdi);
        db.Hatirlaticilar.Add(h);
        await db.SaveChangesAsync(ct);
        return Results.Created($"/api/hatirlaticilar/{h.Id}", HatirlaticiIslemleri.DtoYap(h, simdi));
    }

    // PUT: the open reminder of the item gets the new rule (its title and its link stay; a snooze is cleared, as when a reminder is edited).
    public async Task<IResult> HatirlaticiDegistirAsync(DateOnly gun, KimlikParcasi parca, OgeHatirlaticiDto dto, CancellationToken ct)
    {
        var h = await Hatirlaticilari(gun, parca).Where(x => x.Durum == HatirlaticiDurumu.Acik).OrderBy(x => x.SonrakiAn).FirstOrDefaultAsync(ct);
        if (h is null)
            return Results.NotFound();

        var yaz = new HatirlaticiYazDto
        {
            Baslik = h.Baslik,
            Not = h.Not,
            Tur = h.Tur,
            Kime = h.Kime,
            Gun = h.Gun,
            Saat = dto.Saat,
            Tekrar = dto.Tekrar,
            Gunler = dto.Gunler,
            Acil = dto.Acil,
            Israrli = dto.Israrli,
            IsrarAraligiDakika = h.IsrarAraligiDakika,
            IsrarEnCok = h.IsrarEnCok,
            OnceGun = dto.OnceGun,
            Durum = HatirlaticiDurumu.Acik,
            MaddeId = h.MaddeId,
            MaddeTarihi = h.MaddeTarihi,
            GorevKimligi = h.GorevKimligi,
        };
        var simdi = saat.GetUtcNow();
        HatirlaticiIslemleri.Uygula(h, yaz, ayar.VarsayilanSaat, simdi);
        await db.SaveChangesAsync(ct);
        return Results.Ok(HatirlaticiIslemleri.DtoYap(h, simdi));
    }

    // DELETE: every reminder tied to the item goes (the closed ones too: they would otherwise come back as "the item's reminder").
    public async Task<IResult> HatirlaticiKaldirAsync(DateOnly gun, KimlikParcasi parca, CancellationToken ct)
    {
        var liste = await Hatirlaticilari(gun, parca).ToListAsync(ct);
        if (liste.Count == 0)
            return Results.NotFound();

        db.Hatirlaticilar.RemoveRange(liste);
        await db.SaveChangesAsync(ct);
        return Results.NoContent();
    }

    // The reminders tied to an item, as the day view ties them: a plan item by its id and day, a task by its slug.
    private IQueryable<Hatirlatici> Hatirlaticilari(DateOnly gun, KimlikParcasi parca)
    {
        var deger = parca.Deger;
        return parca.Onek == 'm'
            ? db.Hatirlaticilar.Where(h => h.Durum != HatirlaticiDurumu.Arsiv && h.MaddeId == deger && h.MaddeTarihi == gun)
            : db.Hatirlaticilar.Where(h => h.Durum != HatirlaticiDurumu.Arsiv && h.GorevKimligi == deger && h.MaddeId == null);
    }

    // The item as the day shows it, or the answer to give when it cannot be found: 503 without a brain, 502 when it cannot be read, 404.
    private async Task<(YapilacakDto? Oge, IResult? Hata)> OgeBulAsync(DateOnly gun, string kimlik, Guid? kullaniciId, CancellationToken ct)
    {
        var gorunum = await gunServisi.GetirAsync(gun, kullaniciId, ct);
        if (gorunum.Kaynaklar.Plan == "yok")
            return (null, Results.Problem(title: "Beyin bağlı değil", detail: "Bu makinede beyin ayarlı değil ya da komutu bulunamadı.", statusCode: StatusCodes.Status503ServiceUnavailable));
        if (gorunum.Kaynaklar.Plan == "okunamadi")
            return (null, Results.Problem(title: "Beyin cevabı anlaşılamadı", detail: "Günün planı okunamadı, biraz sonra tekrar dene.", statusCode: StatusCodes.Status502BadGateway));

        return gorunum.Ogeler.FirstOrDefault(o => o.Kimlik == kimlik) is { } oge
            ? (oge, null)
            : (null, Results.Problem(title: "Bulunamadı", detail: "Öğe o günün listesinde yok.", statusCode: StatusCodes.Status404NotFound));
    }

    // The item as the day shows it after the write; `yedek` builds it from what the write answered when the day cannot be read or no longer lists it.
    private async Task<YapilacakDto> OgeAlAsync(DateOnly gun, string kimlik, Guid? kullaniciId, Func<YapilacakDto?> yedek, CancellationToken ct)
    {
        try
        {
            var gorunum = await gunServisi.GetirAsync(gun, kullaniciId, ct);
            if (gorunum.Ogeler.FirstOrDefault(o => o.Kimlik == kimlik) is { } oge)
                return oge;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            // The write has happened: a view that cannot be built must not turn it into an error.
            log.LogWarning(e, "The day view could not be read after a write ({Kimlik})", kimlik);
        }

        return yedek()!;
    }

    private static YapilacakDto MaddedenOge(YazilanMaddeDto m, string kimlik, DateOnly tarih)
    {
        var (baslik, bolunmus) = YapilacakYardimcisi.BaslikAyir(m.Baslik);
        return new YapilacakDto(
            kimlik, YapilacakTuru.Plan, baslik, null, null, false, m.TahminDk, m.SureDk is > 0 ? m.SureDk : null,
            BeyinGorunum.Yapildi(m.Durum) ? YapilacakDurumu.Yapildi : YapilacakDurumu.Acik, m.Proje, m.Bolum, null, bolunmus, null,
            m.Id, m.Gorev, null, null, null, tarih);
    }

    private static YapilacakDto GorevOgesi(string kimlik, string slug, DateOnly tarih) => new(
        kimlik, YapilacakTuru.Gorev, slug, null, null, false, null, null, YapilacakDurumu.Acik, null, null, null, null, null,
        null, slug, null, null, null, tarih);

    private static YapilacakDto HatirlaticidanOge(Hatirlatici h, YapilacakDurumu durum, DateOnly tarih) => new(
        $"h:{h.Id}", YapilacakTuru.Hatirlatici, h.Baslik, YapilacakYardimcisi.HatirlaticiSaati(h), null, false, null, null, durum, null, null, null, null,
        YapilacakYardimcisi.Ozet(h), h.MaddeId, h.GorevKimligi, h.Id, null, null, tarih);

    private static string Kisalt(string metin, int enUzun) => metin.Length <= enUzun ? metin : metin[..enUzun].TrimEnd();
}
