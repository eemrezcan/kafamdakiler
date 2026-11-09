using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Ozet;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The weekly summary end to end, minus the real brain (a fake beyin.py as a child process) and, in the last tests, with the real beyin.py on a
// copy of ornek-beyin/. Real PostgreSQL. What must not pass silently: a week written twice, a missed week never written, a failed write
// recorded as done, a wrong number, a day counted in the wrong week.
public class HaftalikOzetTests : IAsyncLifetime
{
    // Monday 2 Nov 2026 is the first day of 2026-W45; its Sunday is 8 Nov.
    private static readonly DateOnly Hafta = new(2026, 11, 2);
    private static readonly DateOnly OncekiHafta = new(2026, 10, 26);

    private readonly TestVeritabani _vt = new();
    private readonly SahteBeyin _beyin = new("ok");
    private readonly ElleSaat _saat = new(Ist(2026, 11, 8, 21, 0));

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public async ValueTask DisposeAsync()
    {
        await _vt.DisposeAsync();
        _beyin.Dispose();
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static DateTimeOffset Ist(int yil, int ay, int gun, int saat, int dakika, int saniye = 0) =>
        new DateTimeOffset(yil, ay, gun, saat, dakika, saniye, TimeSpan.FromHours(3)).ToUniversalTime();

    private HaftalikOzetYazici Yazici(BeyinIstemcisi? beyin = null) =>
        new(_vt.Db, beyin ?? _beyin.Istemci(), _saat, NullLogger<HaftalikOzetYazici>.Instance);

    private List<string[]> NotCagrilari() =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(a => a[0] == "not-ekle").ToList();

    private async Task<string> GovdeAsync(DateTimeOffset simdi) =>
        (await new HaftalikOzetOlusturucu(_vt.Db).OlusturAsync(Hafta, simdi, Ct)).ReplaceLineEndings("\n");

    // Data seeding

    private async Task<Aliskanlik> AliskanlikEkleAsync(
        string ad, AliskanlikTuru tur = AliskanlikTuru.Sayac, Olcu olcu = Olcu.EvetHayir, HedefYonu yon = HedefYonu.EnAz, decimal? hedef = null,
        string? birim = null, Siklik siklik = Siklik.HerGun, int? haftalikSayi = null)
    {
        var a = new Aliskanlik
        {
            Ad = ad, Tur = tur, Ikon = "x", Renk = "y", Olcu = olcu, HedefYonu = yon, GunlukHedef = hedef, Birim = birim, Siklik = siklik,
            HaftalikSayi = haftalikSayi, CreatedAt = Ist(2026, 10, 1, 12, 0),
        };
        _vt.Db.Aliskanliklar.Add(a);
        await _vt.Db.SaveChangesAsync(Ct);
        return a;
    }

    private async Task KayitEkleAsync(Aliskanlik a, DateOnly tarih, decimal miktar)
    {
        _vt.Db.AliskanlikKayitlari.Add(new AliskanlikKaydi { AliskanlikId = a.Id, Tarih = tarih, Miktar = miktar });
        await _vt.Db.SaveChangesAsync(Ct);
    }

    private async Task OlayEkleAsync(HatirlaticiOlayTuru tur, DateTimeOffset hedef, DateTimeOffset zaman)
    {
        _vt.Db.HatirlaticiOlaylari.Add(new HatirlaticiOlayi { HatirlaticiId = Guid.NewGuid(), Tur = tur, HedefAn = hedef, Zaman = zaman });
        await _vt.Db.SaveChangesAsync(Ct);
    }

    private async Task HatirlaticiEkleAsync(DateTimeOffset an, HatirlaticiDurumu durum = HatirlaticiDurumu.Acik, DateTimeOffset? erteleAn = null)
    {
        _vt.Db.Hatirlaticilar.Add(new Hatirlatici
        {
            Baslik = "H", Tur = HatirlaticiTuru.Gorev, Gun = HatirlaticiHesap.IstanbulGunu(an), Saat = HatirlaticiHesap.IstanbulSaati(an),
            Tekrar = Tekrar.Yok, Durum = durum, SonrakiAn = an, ErteleAn = erteleAn,
        });
        await _vt.Db.SaveChangesAsync(Ct);
    }

    // The content

    [Fact]
    public async Task Content_WithNoData_SaysKayitYokInEveryPart()
    {
        var govde = await GovdeAsync(Ist(2026, 11, 8, 21, 0));

        Assert.StartsWith("Hafta: 2 Kasım 2026 Pazartesi – 8 Kasım 2026 Pazar.", govde);
        foreach (var bolum in new[] { "Alışkanlıklar", "Kitap", "Kilo", "Hatırlatıcılar" })
            Assert.Contains($"## {bolum}\n\nkayıt yok\n", govde);
        Assert.DoesNotContain("\n- ", govde);
    }

    [Fact]
    public async Task Content_Habits_CountDaysDoneAgainstThePlan_AndGiveTheStreak()
    {
        var su = await AliskanlikEkleAsync("Su", olcu: Olcu.Sayili, hedef: 8, birim: "bardak");
        // Mon-Thu 8, Fri 3 (short), Sat-Sun 8: six days of seven, and the streak since Friday is two. The week before and after are not counted.
        foreach (var (gun, miktar) in new[] { (2, 8m), (3, 8m), (4, 8m), (5, 8m), (6, 3m), (7, 8m), (8, 8m) })
            await KayitEkleAsync(su, new DateOnly(2026, 11, gun), miktar);
        await KayitEkleAsync(su, new DateOnly(2026, 11, 1), 8);
        await KayitEkleAsync(su, new DateOnly(2026, 11, 9), 8);

        var yuruyus = await AliskanlikEkleAsync("Yürüyüş", siklik: Siklik.HaftadaN, haftalikSayi: 3);
        foreach (var gun in new[] { 3, 5, 7 })
            await KayitEkleAsync(yuruyus, new DateOnly(2026, 11, gun), 1);

        var govde = await GovdeAsync(Ist(2026, 11, 8, 21, 0));

        Assert.Contains("- Su: 6/7 gün · seri 2 gün · toplam 51 bardak\n", govde);
        Assert.Contains("- Yürüyüş: 3/3 gün · seri 1 hafta\n", govde);
    }

    [Fact]
    public async Task Content_BelirliGunlerHabit_CountsOnlyItsPlannedDays()
    {
        var spor = await AliskanlikEkleAsync("Spor", siklik: Siklik.BelirliGunler);
        spor.Gunler = Gunler.Sal | Gunler.Per | Gunler.Cmt;
        await _vt.Db.SaveChangesAsync(Ct);
        await KayitEkleAsync(spor, new DateOnly(2026, 11, 3), 1);
        await KayitEkleAsync(spor, new DateOnly(2026, 11, 5), 1);
        await KayitEkleAsync(spor, new DateOnly(2026, 11, 4), 1);

        var govde = await GovdeAsync(Ist(2026, 11, 8, 21, 0));

        Assert.Contains("- Spor: 2/3 gün · seri 0 gün\n", govde);
    }

    [Fact]
    public async Task Content_DaysThatHaveNotComeYet_AreNotCounted()
    {
        // Wednesday noon: a "no more than" habit with no entries must not score for Thursday to Sunday.
        var seker = await AliskanlikEkleAsync("Şeker", yon: HedefYonu.EnCok);

        var govde = await GovdeAsync(Ist(2026, 11, 4, 12, 0));

        Assert.Contains("- Şeker: 3/3 gün", govde);
    }

    [Fact]
    public async Task Content_Book_SumsThePagesRead_AndNamesTheFinishedBooks_OfThatWeekOnly()
    {
        var okuma = await AliskanlikEkleAsync("Okuma", AliskanlikTuru.Raf, Olcu.Sayili, birim: "sayfa");
        var kitap = new Oge { AliskanlikId = okuma.Id, Ad = "Küçük Prens", Durum = OgeDurumu.Bitti, BitisTarihi = new DateOnly(2026, 11, 5) };
        var eski = new Oge { AliskanlikId = okuma.Id, Ad = "Geçen Haftanın Kitabı", Durum = OgeDurumu.Bitti, BitisTarihi = new DateOnly(2026, 11, 1) };
        _vt.Db.Ogeler.AddRange(kitap, eski);
        await _vt.Db.SaveChangesAsync(Ct);
        foreach (var (gun, bas, bit) in new[] { (30, 0m, 10m), (3, 10m, 70m), (5, 70m, 110m), (9, 110m, 150m) })
        {
            var tarih = gun == 30 ? new DateOnly(2026, 10, 30) : new DateOnly(2026, 11, gun);
            _vt.Db.Oturumlar.Add(new Oturum { OgeId = kitap.Id, Tarih = tarih, BaslangicKonum = bas, BitisKonum = bit });
        }

        await _vt.Db.SaveChangesAsync(Ct);

        var govde = await GovdeAsync(Ist(2026, 11, 8, 21, 0));

        Assert.Contains("- Okuma: okunan 100 sayfa\n", govde);
        Assert.Contains("- Okuma: biten 1 (Küçük Prens)\n", govde);
        Assert.DoesNotContain("Geçen Haftanın Kitabı", govde);
        Assert.DoesNotContain("Okuma:", govde.Split("## Alışkanlıklar")[1].Split("## Kitap")[0]);
    }

    [Fact]
    public async Task Content_Weight_GivesTheFirstAndLastMeasurementOfTheWeek_AndTheDifference()
    {
        var kilo = await AliskanlikEkleAsync("Kilo", olcu: Olcu.Sayili, birim: "kg");
        await KayitEkleAsync(kilo, new DateOnly(2026, 11, 1), 83.00m);
        await KayitEkleAsync(kilo, new DateOnly(2026, 11, 3), 82.40m);
        await KayitEkleAsync(kilo, new DateOnly(2026, 11, 8), 81.90m);

        var govde = await GovdeAsync(Ist(2026, 11, 8, 21, 0));

        Assert.Contains("- Kilo: ilk 82,4 kg (3 Kasım) · son 81,9 kg (8 Kasım) · fark -0,5 kg\n", govde);
        // The weight is not a habit line.
        Assert.Contains("## Alışkanlıklar\n\nkayıt yok\n", govde);
    }

    [Fact]
    public async Task Content_Weight_WithOneMeasurement_SaysSo()
    {
        var kilo = await AliskanlikEkleAsync("Kilo", olcu: Olcu.Sayili, birim: "kg");
        await KayitEkleAsync(kilo, new DateOnly(2026, 11, 6), 80.5m);

        var govde = await GovdeAsync(Ist(2026, 11, 8, 21, 0));

        Assert.Contains("- Kilo: tek ölçüm 80,5 kg (6 Kasım)\n", govde);
    }

    [Fact]
    public async Task Content_Reminders_CountOnTimeLateSnoozedAndMissed_AndTheWeekEdgeFollowsTheDayTurn()
    {
        var saat10 = Ist(2026, 11, 4, 10, 0);
        await OlayEkleAsync(HatirlaticiOlayTuru.Yapildi, saat10, saat10);
        await OlayEkleAsync(HatirlaticiOlayTuru.Yapildi, saat10.AddMinutes(30), saat10.AddMinutes(90));
        await OlayEkleAsync(HatirlaticiOlayTuru.Yapildi, Ist(2026, 11, 5, 10, 0), Ist(2026, 11, 5, 18, 0));
        // Monday 04:59 is still Sunday's day: in. Monday 05:00 and Sunday the 1st are other weeks: out.
        await OlayEkleAsync(HatirlaticiOlayTuru.Ertelendi, Ist(2026, 11, 8, 20, 0), Ist(2026, 11, 9, 4, 59));
        await OlayEkleAsync(HatirlaticiOlayTuru.Ertelendi, Ist(2026, 11, 8, 20, 0), Ist(2026, 11, 9, 5, 0));
        await OlayEkleAsync(HatirlaticiOlayTuru.Yapildi, Ist(2026, 11, 1, 10, 0), Ist(2026, 11, 1, 10, 0));
        // Open and past due inside the week: missed. A closed one, one due next week and one snoozed past the week are not.
        await HatirlaticiEkleAsync(Ist(2026, 11, 6, 10, 0));
        await HatirlaticiEkleAsync(Ist(2026, 11, 6, 11, 0), HatirlaticiDurumu.Tamam);
        await HatirlaticiEkleAsync(Ist(2026, 11, 12, 10, 0));
        await HatirlaticiEkleAsync(Ist(2026, 11, 3, 10, 0), erteleAn: Ist(2026, 11, 12, 10, 0));

        var govde = await GovdeAsync(Ist(2026, 11, 9, 4, 59, 30));

        Assert.Contains("- Zamanında yapılan: 2\n- Geç yapılan: 1\n- Ertelenen: 1\n- Kaçan: 1\n", govde);
    }

    [Fact]
    public async Task Reminder_YaptimAndErtele_RecordTheEvent_WithTheDueMomentBeforeTheChange_AndARefusalRecordsNothing()
    {
        var an = Ist(2026, 11, 9, 9, 0);
        await HatirlaticiEkleAsync(an);
        await HatirlaticiEkleAsync(an.AddHours(1), HatirlaticiDurumu.Arsiv);
        var acik = await _vt.Db.Hatirlaticilar.FirstAsync(h => h.Durum == HatirlaticiDurumu.Acik, Ct);
        var arsiv = await _vt.Db.Hatirlaticilar.FirstAsync(h => h.Durum == HatirlaticiDurumu.Arsiv, Ct);
        var varsayilan = new TimeOnly(9, 0);

        Assert.True(HatirlaticiIslemleri.Ertele(_vt.Db, acik, "1s", varsayilan, an.AddMinutes(-5)).Basarili);
        Assert.True(HatirlaticiIslemleri.Yaptim(_vt.Db, acik, varsayilan, an.AddHours(1)).Basarili);
        Assert.False(HatirlaticiIslemleri.Yaptim(_vt.Db, arsiv, varsayilan, an).Basarili);
        Assert.False(HatirlaticiIslemleri.Ertele(_vt.Db, acik, "1s", varsayilan, an).Basarili);
        await _vt.Db.SaveChangesAsync(Ct);

        var olaylar = await _vt.Db.HatirlaticiOlaylari.AsNoTracking().OrderBy(o => o.Zaman).ToListAsync(Ct);
        Assert.Collection(olaylar,
            o => { Assert.Equal(HatirlaticiOlayTuru.Ertelendi, o.Tur); Assert.Equal(an, o.HedefAn); Assert.Equal(acik.Id, o.HatirlaticiId); },
            // After the snooze the reminder was due an hour after `an - 5 min`.
            o => { Assert.Equal(HatirlaticiOlayTuru.Yapildi, o.Tur); Assert.Equal(an.AddMinutes(55), o.HedefAn); });
    }

    // The write

    [Fact]
    public async Task Round_OnSundayNight_WritesTheNoteOnce_AndLaterRoundsAndRestartsWriteNoMore()
    {
        var yazici = Yazici();

        var ilk = await yazici.TurAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 8, 21, 10);
        var ikinci = await yazici.TurAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 10, 9, 0);
        var yenidenBaslayan = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.Yazildi, ilk.Durum);
        Assert.Equal(Hafta, ilk.Hafta);
        Assert.Equal(OzetDurumu.ZatenVardi, ikinci.Durum);
        Assert.Equal(OzetDurumu.ZatenVardi, yenidenBaslayan.Durum);
        var cagri = Assert.Single(NotCagrilari());
        Assert.Contains("--yol=aliskanliklar/haftalik/2026-W45.md", cagri);
        Assert.Contains("--baslik=Haftalık ölçüm özeti 2026-W45", cagri);
        Assert.Contains("--tags=haftalık,takip,alışkanlık", cagri);
        Assert.Contains("--tur=not", cagri);
        var kayit = await _vt.Db.HaftalikOzetler.AsNoTracking().SingleAsync(Ct);
        Assert.Equal(Hafta, kayit.Hafta);
        Assert.Equal(Ist(2026, 11, 8, 21, 0), kayit.YazilmaAni);
        Assert.Equal(Hafta, (await yazici.SonKayitAsync(Ct))!.Hafta);
    }

    [Fact]
    public async Task Round_TheNoteBody_IsTheComputedSummary()
    {
        var su = await AliskanlikEkleAsync("Su", olcu: Olcu.Sayili, hedef: 8, birim: "bardak");
        await KayitEkleAsync(su, new DateOnly(2026, 11, 8), 8);

        await Yazici().TurAsync(Ct);

        var metin = _beyin.Cagrilar().Single(c => SahteBeyin.Argumanlar(c)[0] == "not-ekle").GetProperty("metin").GetString()!;
        Assert.Contains("## Alışkanlıklar", metin);
        Assert.Contains("- Su: 1/7 gün · seri 1 gün · toplam 8 bardak", metin);
    }

    [Fact]
    public async Task Round_BeforeSundayNight_WritesNothingForTheWeekInProgress()
    {
        _vt.Db.HaftalikOzetler.Add(new HaftalikOzetKaydi { Hafta = OncekiHafta, YazilmaAni = Ist(2026, 11, 1, 21, 0) });
        await _vt.Db.SaveChangesAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 8, 20, 59);

        var sonuc = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.ZatenVardi, sonuc.Durum);
        Assert.Equal(OncekiHafta, sonuc.Hafta);
        Assert.Empty(NotCagrilari());
    }

    [Fact]
    public async Task Round_AfterAMissedSunday_WritesThatWeek_OnceOnTheNextOpening()
    {
        // The app was off on Sunday night; it is opened on Wednesday morning.
        _vt.Db.HaftalikOzetler.Add(new HaftalikOzetKaydi { Hafta = OncekiHafta, YazilmaAni = Ist(2026, 11, 1, 21, 0) });
        await _vt.Db.SaveChangesAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 11, 9, 0);

        var ilk = await Yazici().TurAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 11, 9, 10);
        var ikinci = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.Yazildi, ilk.Durum);
        Assert.Equal(Hafta, ilk.Hafta);
        Assert.Equal(OzetDurumu.ZatenVardi, ikinci.Durum);
        var cagri = Assert.Single(NotCagrilari());
        Assert.Contains("--yol=aliskanliklar/haftalik/2026-W45.md", cagri);
        Assert.Equal(2, await _vt.Db.HaftalikOzetler.CountAsync(Ct));
    }

    [Fact]
    public async Task Round_TheNextSunday_WritesTheNextWeek()
    {
        await Yazici().TurAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 15, 21, 0);

        var sonuc = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.Yazildi, sonuc.Durum);
        Assert.Equal(new DateOnly(2026, 11, 9), sonuc.Hafta);
        Assert.Equal(["aliskanliklar/haftalik/2026-W45.md", "aliskanliklar/haftalik/2026-W46.md"],
            NotCagrilari().Select(a => a.Single(x => x.StartsWith("--yol=")).Substring(6)).ToArray());
    }

    [Fact]
    public async Task Button_WritesThisWeekNow_AnyHour_AndANoteAlreadyWrittenIsLeftAlone()
    {
        _saat.Simdi = Ist(2026, 11, 4, 15, 0);

        var ilk = await Yazici().SimdiYazAsync(Ct);
        var ikinci = await Yazici().SimdiYazAsync(Ct);

        Assert.Equal(OzetDurumu.Yazildi, ilk.Durum);
        Assert.Equal(Hafta, ilk.Hafta);
        Assert.Equal(OzetDurumu.ZatenVardi, ikinci.Durum);
        Assert.Single(NotCagrilari());
    }

    // Failures stay visible and do not count as written

    [Fact]
    public async Task Round_WithoutTheBrain_RecordsNothing_AndWritesOnceItIsThere()
    {
        var yok = await Yazici(new BeyinIstemcisi(new BeyinAyari())).TurAsync(Ct);

        Assert.Equal(OzetDurumu.BeyinYok, yok.Durum);
        Assert.False(yok.Basarili);
        Assert.Empty(await _vt.Db.HaftalikOzetler.ToListAsync(Ct));

        var sonra = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.Yazildi, sonra.Durum);
        Assert.Single(await _vt.Db.HaftalikOzetler.ToListAsync(Ct));
    }

    [Fact]
    public async Task Round_WhenTheBrainRefuses_ReportsTheError_RecordsNothing_AndTriesAgainNextRound()
    {
        _beyin.Cikti("""{"hata": {"kod": "hata", "mesaj": "disk dolu"}}""", 1);

        var red = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.Hata, red.Durum);
        Assert.Contains("disk dolu", red.Mesaj);
        Assert.False(red.Basarili);
        Assert.Empty(await _vt.Db.HaftalikOzetler.ToListAsync(Ct));

        _beyin.Cikti("""{"yol": "aliskanliklar/haftalik/2026-W45.md"}""");
        _saat.Simdi = Ist(2026, 11, 8, 21, 10);
        var sonra = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.Yazildi, sonra.Durum);
        Assert.Equal(2, NotCagrilari().Count);
        Assert.Single(await _vt.Db.HaftalikOzetler.ToListAsync(Ct));
    }

    [Fact]
    public async Task Round_WhenTheBrainAnswersBadly_RecordsNothing()
    {
        _beyin.Mod = "bozuk";

        var sonuc = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.Hata, sonuc.Durum);
        Assert.Empty(await _vt.Db.HaftalikOzetler.ToListAsync(Ct));
    }

    [Fact]
    public async Task Round_WhenTheBrainAlreadyHoldsTheNote_CountsItAsWritten_AndRecordsTheWeek()
    {
        _beyin.Cikti("""{"hata": {"kod": "hata", "mesaj": "dosya zaten var, üstüne yazılmaz: aliskanliklar/haftalik/2026-W45.md"}}""", 1);

        var sonuc = await Yazici().TurAsync(Ct);
        var tekrar = await Yazici().TurAsync(Ct);

        Assert.Equal(OzetDurumu.ZatenVardi, sonuc.Durum);
        Assert.True(sonuc.Basarili);
        Assert.Equal(OzetDurumu.ZatenVardi, tekrar.Durum);
        Assert.Single(NotCagrilari());
        Assert.Single(await _vt.Db.HaftalikOzetler.ToListAsync(Ct));
    }

    // With the real beyin.py on a throwaway copy of ornek-beyin/ (skipped where beyin.py is not on this machine)

    [Fact]
    public async Task RealBrain_TheNoteIsCreated_AndSearchFindsIt_AndAWeekIsNeverWrittenTwice()
    {
        var vault = Path.Combine(Path.GetTempPath(), "kd-ozet-" + Guid.NewGuid().ToString("N"));
        try
        {
            var ayar = TestAyari.GercekBeyin(vault);
            Assert.True(OrnekBeyinKopyasi.HazirlaGerekirse(ayar));
            var beyin = new BeyinIstemcisi(ayar);
            var su = await AliskanlikEkleAsync("Su", olcu: Olcu.Sayili, hedef: 8, birim: "bardak");
            await KayitEkleAsync(su, new DateOnly(2026, 11, 8), 8);

            var sonuc = await Yazici(beyin).TurAsync(Ct);

            Assert.Equal(OzetDurumu.Yazildi, sonuc.Durum);
            var dosya = Path.Combine(vault, "aliskanliklar", "haftalik", "2026-W45.md");
            Assert.True(File.Exists(dosya));
            var icerik = await File.ReadAllTextAsync(dosya, Ct);
            Assert.Contains("Haftalık ölçüm özeti 2026-W45", icerik);
            Assert.Contains("- Su: 1/7 gün", icerik);

            var arama = await beyin.CalistirAsync(["ara"], Ct, ["haftalık ölçüm"]);
            Assert.True(arama.Basarili, arama.Mesaj);
            Assert.Contains(arama.Veri!.Value.EnumerateArray(), r => r.GetProperty("yol").GetString() == "aliskanliklar/haftalik/2026-W45.md");

            // The week's row is lost (a restored database, say): the brain refuses to overwrite, which is read as "already written".
            await _vt.Db.HaftalikOzetler.ExecuteDeleteAsync(Ct);
            _vt.Db.ChangeTracker.Clear();
            var tekrar = await Yazici(beyin).TurAsync(Ct);
            Assert.Equal(OzetDurumu.ZatenVardi, tekrar.Durum);
            Assert.Equal(icerik, await File.ReadAllTextAsync(dosya, Ct));
            Assert.Single(await _vt.Db.HaftalikOzetler.ToListAsync(Ct));
        }
        finally
        {
            if (Directory.Exists(vault))
                Directory.Delete(vault, recursive: true);
        }
    }
}
