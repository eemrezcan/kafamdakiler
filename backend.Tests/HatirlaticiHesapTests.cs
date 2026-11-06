using Kafamdakiler.Hatirlaticilar;
using Microsoft.Extensions.Configuration;

namespace Kafamdakiler.Tests;

// Pure recurrence math and the Yaptim / Ertele transitions: no database, no clock.
public class HatirlaticiHesapTests
{
    private static readonly TimeOnly Dokuz = new(9, 0);

    private static DateTimeOffset Z(string s) => DateTimeOffset.Parse(s);

    private static DateTimeOffset Istanbul(string gun, string saat = "09:00") => HatirlaticiHesap.An(DateOnly.Parse(gun), TimeOnly.Parse(saat));

    [Fact]
    public void An_ConvertsIstanbulToUtc()
    {
        Assert.Equal(Z("2026-11-06T06:00:00Z"), Istanbul("2026-11-06"));
        Assert.Equal(TimeSpan.Zero, Istanbul("2026-11-06").Offset);
    }

    [Fact]
    public void Sonraki_OneOff_IsItsOwnMoment_EvenWhenPast()
    {
        Assert.Equal(Istanbul("2026-01-01"), HatirlaticiHesap.Sonraki(Tekrar.Yok, new(2026, 1, 1), Dokuz, Z("2026-11-06T00:00:00Z")));
    }

    [Fact]
    public void Sonraki_Daily_IsTodayIfNotYetPassed_ElseTomorrow()
    {
        var baslangic = new DateOnly(2026, 11, 1);
        Assert.Equal(Istanbul("2026-11-06"), HatirlaticiHesap.Sonraki(Tekrar.Gunluk, baslangic, Dokuz, Z("2026-11-06T05:59:00Z")));
        Assert.Equal(Istanbul("2026-11-07"), HatirlaticiHesap.Sonraki(Tekrar.Gunluk, baslangic, Dokuz, Z("2026-11-06T06:00:00Z")));
    }

    [Fact]
    public void Sonraki_StartInTheFuture_IsTheStartItself()
    {
        Assert.Equal(Istanbul("2027-03-01"), HatirlaticiHesap.Sonraki(Tekrar.Gunluk, new(2027, 3, 1), Dokuz, Z("2026-11-06T00:00:00Z")));
        Assert.Equal(Istanbul("2027-03-31"), HatirlaticiHesap.Sonraki(Tekrar.Aylik, new(2027, 3, 31), Dokuz, Z("2026-11-06T00:00:00Z")));
    }

    [Fact]
    public void Sonraki_Weekly_KeepsTheWeekday()
    {
        // 2026-11-02 is a Monday.
        var sonuc = HatirlaticiHesap.Sonraki(Tekrar.Haftalik, new(2026, 11, 2), Dokuz, Z("2026-11-06T00:00:00Z"));
        Assert.Equal(Istanbul("2026-11-09"), sonuc);
        Assert.Equal(DayOfWeek.Monday, HatirlaticiHesap.IstanbulGunu(sonuc).DayOfWeek);
    }

    [Theory]
    [InlineData("2026-12-31T10:00:00Z", "2027-01-31")]
    [InlineData("2027-01-31T10:00:00Z", "2027-02-28")] // 31 -> end of a common February
    [InlineData("2027-02-28T10:00:00Z", "2027-03-31")] // and back to the 31st: counted from the start day
    [InlineData("2027-03-31T10:00:00Z", "2027-04-30")]
    [InlineData("2027-12-31T10:00:00Z", "2028-01-31")]
    [InlineData("2028-01-31T10:00:00Z", "2028-02-29")] // leap year
    public void Sonraki_Monthly_From31st_UsesTheLastDayOfShortMonths(string simdi, string beklenen)
    {
        Assert.Equal(Istanbul(beklenen), HatirlaticiHesap.Sonraki(Tekrar.Aylik, new(2026, 10, 31), Dokuz, Z(simdi)));
    }

    [Fact]
    public void Sonraki_Monthly_From30th_GivesFebruaryEnd()
    {
        Assert.Equal(Istanbul("2027-02-28"), HatirlaticiHesap.Sonraki(Tekrar.Aylik, new(2026, 11, 30), Dokuz, Z("2027-01-30T10:00:00Z")));
        Assert.Equal(Istanbul("2028-02-29"), HatirlaticiHesap.Sonraki(Tekrar.Aylik, new(2026, 11, 30), Dokuz, Z("2028-01-30T10:00:00Z")));
    }

    [Theory]
    [InlineData("2026-03-10T00:00:00Z", "2026-03-15")]
    [InlineData("2026-03-15T10:00:00Z", "2027-03-15")]
    public void Sonraki_Yearly_RepeatsOnTheSameDate(string simdi, string beklenen)
    {
        Assert.Equal(Istanbul(beklenen), HatirlaticiHesap.Sonraki(Tekrar.Yillik, new(2024, 3, 15), Dokuz, Z(simdi)));
    }

    [Theory]
    [InlineData("2027-01-01T00:00:00Z", "2027-02-28")] // common year
    [InlineData("2028-01-01T00:00:00Z", "2028-02-29")] // leap year
    [InlineData("2028-03-01T00:00:00Z", "2029-02-28")]
    [InlineData("2031-03-01T00:00:00Z", "2032-02-29")]
    public void Sonraki_Yearly_From29Feb_UsesTheLastDayOfFebruary(string simdi, string beklenen)
    {
        Assert.Equal(Istanbul(beklenen), HatirlaticiHesap.Sonraki(Tekrar.Yillik, new(2024, 2, 29), Dokuz, Z(simdi)));
    }

    [Fact]
    public void Sonraki_FarInThePast_StillFindsTheNextTurn()
    {
        Assert.Equal(Istanbul("2026-11-07"), HatirlaticiHesap.Sonraki(Tekrar.Gunluk, new(2000, 1, 1), Dokuz, Z("2026-11-06T10:00:00Z")));
        Assert.Equal(Istanbul("2026-11-30"), HatirlaticiHesap.Sonraki(Tekrar.Aylik, new(2000, 1, 31), Dokuz, Z("2026-11-06T10:00:00Z")));
        Assert.Equal(Istanbul("2027-01-31"), HatirlaticiHesap.Sonraki(Tekrar.Aylik, new(2000, 1, 31), Dokuz, Z("2026-12-31T10:00:00Z")));
        Assert.Equal(Istanbul("2027-01-01"), HatirlaticiHesap.Sonraki(Tekrar.Yillik, new(1990, 1, 1), Dokuz, Z("2026-11-06T10:00:00Z")));
    }

    [Fact]
    public void Sonraki_UsesIstanbulMidnight_NotUtc()
    {
        // 22:30 UTC on Nov 5 is already 01:30 on Nov 6 in Istanbul. A 00:30 daily reminder fired at 00:30 Nov 6 (21:30Z).
        var yarimGece = new TimeOnly(0, 30);
        Assert.Equal(Istanbul("2026-11-07", "00:30"), HatirlaticiHesap.Sonraki(Tekrar.Gunluk, new(2026, 11, 1), yarimGece, Z("2026-11-05T22:30:00Z")));
        Assert.Equal(Istanbul("2026-11-06", "00:30"), HatirlaticiHesap.Sonraki(Tekrar.Gunluk, new(2026, 11, 1), yarimGece, Z("2026-11-05T21:00:00Z")));
    }

    [Fact]
    public void IstanbulGunu_RollsOverAtUtcPlus3()
    {
        Assert.Equal(new DateOnly(2026, 11, 5), HatirlaticiHesap.IstanbulGunu(Z("2026-11-05T20:59:59Z")));
        Assert.Equal(new DateOnly(2026, 11, 6), HatirlaticiHesap.IstanbulGunu(Z("2026-11-05T21:00:00Z")));
    }

    [Fact]
    public void KalanGun_CountsIstanbulDays()
    {
        var simdi = Z("2026-11-05T22:00:00Z"); // 01:00 on Nov 6 in Istanbul
        Assert.Equal(0, HatirlaticiHesap.KalanGun(Istanbul("2026-11-06"), simdi));
        Assert.Equal(3, HatirlaticiHesap.KalanGun(Istanbul("2026-11-09", "00:10"), simdi));
        Assert.Equal(-1, HatirlaticiHesap.KalanGun(Istanbul("2026-11-05", "23:00"), simdi));
    }

    [Fact]
    public void OnceAni_IsDaysBefore_AtTheSameHour()
    {
        Assert.Equal(Istanbul("2026-12-12", "09:00"), HatirlaticiHesap.OnceAni(Istanbul("2026-12-15"), 3));
        Assert.Equal(Istanbul("2026-02-27", "18:45"), HatirlaticiHesap.OnceAni(Istanbul("2026-03-02", "18:45"), 3));
        Assert.Null(HatirlaticiHesap.OnceAni(Istanbul("2026-12-15"), 0));
    }

    [Fact]
    public void ErteleAni_OneHour_And_TomorrowAtTheRuleHour()
    {
        var simdi = Z("2026-11-05T22:00:00Z"); // 01:00 on Nov 6 in Istanbul
        Assert.Equal(Z("2026-11-05T23:00:00Z"), HatirlaticiHesap.ErteleAni("1s", simdi, Dokuz));
        Assert.Equal(Istanbul("2026-11-07"), HatirlaticiHesap.ErteleAni("yarin", simdi, Dokuz));
        Assert.Null(HatirlaticiHesap.ErteleAni("2s", simdi, Dokuz));
        Assert.Null(HatirlaticiHesap.ErteleAni(null, simdi, Dokuz));
    }

    // Yaptim and Ertele

    private static Hatirlatici Yeni(Tekrar tekrar, string gun = "2026-11-10", TimeOnly? saat = null)
    {
        var h = new Hatirlatici { Baslik = "x", Gun = DateOnly.Parse(gun), Saat = saat, Tekrar = tekrar };
        h.SonrakiAn = HatirlaticiHesap.Sonraki(tekrar, h.Gun, saat ?? Dokuz, Z("2026-11-06T00:00:00Z"));
        return h;
    }

    [Fact]
    public void Yaptim_OneOff_BecomesTamam()
    {
        var h = Yeni(Tekrar.Yok);
        h.ErteleAn = Z("2026-11-09T00:00:00Z");

        Assert.True(HatirlaticiIslemleri.Yaptim(h, Dokuz, Z("2026-11-10T07:00:00Z")).Basarili);
        Assert.Equal(HatirlaticiDurumu.Tamam, h.Durum);
        Assert.Null(h.ErteleAn);
    }

    [Fact]
    public void Yaptim_Repeating_MovesToTheNextTurn_AndClearsTheSnooze()
    {
        var h = Yeni(Tekrar.Gunluk);
        h.ErteleAn = Z("2026-11-10T08:00:00Z");

        // Marked after the 09:00 turn passed: the next turn is tomorrow.
        Assert.True(HatirlaticiIslemleri.Yaptim(h, Dokuz, Z("2026-11-10T09:00:00Z")).Basarili);
        Assert.Equal(HatirlaticiDurumu.Acik, h.Durum);
        Assert.Equal(Istanbul("2026-11-11"), h.SonrakiAn);
        Assert.Null(h.ErteleAn);
    }

    [Fact]
    public void Yaptim_Repeating_MarkedEarly_SkipsTheTurnThatWasDue()
    {
        var h = Yeni(Tekrar.Haftalik, "2026-11-10");

        HatirlaticiIslemleri.Yaptim(h, Dokuz, Z("2026-11-06T10:00:00Z"));
        Assert.Equal(Istanbul("2026-11-17"), h.SonrakiAn);
    }

    [Fact]
    public void Yaptim_Monthly_From31st_KeepsTheStartDay()
    {
        var h = Yeni(Tekrar.Aylik, "2026-10-31");
        Assert.Equal(Istanbul("2026-11-30"), h.SonrakiAn);

        HatirlaticiIslemleri.Yaptim(h, Dokuz, Z("2026-11-30T09:00:00Z"));
        Assert.Equal(Istanbul("2026-12-31"), h.SonrakiAn);
    }

    [Fact]
    public void Yaptim_OnAClosedReminder_IsAConflict()
    {
        var h = Yeni(Tekrar.Yok);
        h.Durum = HatirlaticiDurumu.Arsiv;

        var sonuc = HatirlaticiIslemleri.Yaptim(h, Dokuz, Z("2026-11-10T07:00:00Z"));
        Assert.False(sonuc.Basarili);
        Assert.True(sonuc.Cakisma);
    }

    [Fact]
    public void Ertele_SetsErteleAn_AndLeavesTheRuleAlone()
    {
        var h = Yeni(Tekrar.Gunluk);
        var kural = h.SonrakiAn;
        var simdi = Z("2026-11-10T10:00:00Z");

        Assert.True(HatirlaticiIslemleri.Ertele(h, "1s", Dokuz, simdi).Basarili);
        Assert.Equal(Z("2026-11-10T11:00:00Z"), h.ErteleAn);
        Assert.Equal(kural, h.SonrakiAn);
        Assert.Equal(h.ErteleAn, h.EtkinAn);

        Assert.True(HatirlaticiIslemleri.Ertele(h, "yarin", Dokuz, simdi).Basarili);
        Assert.Equal(Istanbul("2026-11-11"), h.ErteleAn);
        Assert.Equal(kural, h.SonrakiAn);
    }

    [Fact]
    public void Ertele_UnknownDuration_IsRefused()
    {
        var h = Yeni(Tekrar.Yok);
        var sonuc = HatirlaticiIslemleri.Ertele(h, "2s", Dokuz, Z("2026-11-10T10:00:00Z"));

        Assert.False(sonuc.Basarili);
        Assert.Equal("sure", sonuc.Alan);
        Assert.Null(h.ErteleAn);
    }

    [Fact]
    public void Settings_DefaultHour_IsNineUnlessGiven()
    {
        var bos = new ConfigurationBuilder().Build();
        Assert.Equal(new TimeOnly(9, 0), HatirlaticiAyari.Oku(bos).VarsayilanSaat);

        var ayar = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Hatirlatici:VarsayilanSaat"] = "07:30" }).Build();
        Assert.Equal(new TimeOnly(7, 30), HatirlaticiAyari.Oku(ayar).VarsayilanSaat);
    }
}
