using Kafamdakiler.Aliskanliklar;

namespace Kafamdakiler.Tests;

public class AliskanlikHesapTests
{
    private static readonly DateOnly Bas = new(2026, 9, 1);

    private static Aliskanlik Sayac(int hedef = 8, Siklik siklik = Siklik.HerGun, int? haftalik = null, Gunler? gunler = null) => new()
    {
        Olcu = Olcu.Sayili,
        HedefYonu = HedefYonu.EnAz,
        GunlukHedef = hedef,
        Siklik = siklik,
        HaftalikSayi = haftalik,
        Gunler = gunler,
    };

    // Entries for `gun` days starting at Bas, each with the given amount.
    private static Dictionary<DateOnly, decimal> Gunler(int gun, int miktar, int ilkGun = 0) =>
        Enumerable.Range(ilkGun, gun).ToDictionary(i => Bas.AddDays(i), _ => (decimal)miktar);

    [Theory]
    [InlineData("2026-10-31T04:59:00+03:00", "2026-10-30")]
    [InlineData("2026-10-31T05:00:00+03:00", "2026-10-31")]
    [InlineData("2026-10-31T00:00:00+03:00", "2026-10-30")]
    [InlineData("2026-10-31T23:59:00+03:00", "2026-10-31")]
    [InlineData("2026-10-31T01:59:00Z", "2026-10-30")] // 04:59 Istanbul
    [InlineData("2026-10-31T02:00:00Z", "2026-10-31")] // 05:00 Istanbul
    [InlineData("2026-07-01T04:59:00+03:00", "2026-06-30")] // summer: Istanbul is still +03:00
    [InlineData("2026-01-01T04:59:00+03:00", "2025-12-31")] // year boundary
    public void AliskanlikGunu_IsMovedBackBeforeFiveInIstanbul(string an, string beklenen)
    {
        Assert.Equal(DateOnly.Parse(beklenen), AliskanlikHesap.AliskanlikGunu(DateTimeOffset.Parse(an)));
    }

    [Theory]
    [InlineData(HedefYonu.EnAz, 30, 15, 0.5)]
    [InlineData(HedefYonu.EnAz, 30, 30, 1)]
    [InlineData(HedefYonu.EnAz, 30, 45, 1)]
    [InlineData(HedefYonu.EnAz, 30, 0, 0)]
    [InlineData(HedefYonu.EnCok, 2, 0, 1)] // no entry: the day succeeds
    [InlineData(HedefYonu.EnCok, 2, 2, 1)]
    [InlineData(HedefYonu.EnCok, 2, 3, 0)] // over the limit
    [InlineData(HedefYonu.EnCok, 0, 0, 1)] // "at most 0" = never do it
    [InlineData(HedefYonu.EnCok, 0, 1, 0)]
    public void GununDegeri_Sayili_FollowsDirection(HedefYonu yon, int hedef, int miktar, double beklenen)
    {
        Assert.Equal(beklenen, AliskanlikHesap.GununDegeri(Olcu.Sayili, yon, hedef, miktar), 6);
    }

    [Theory]
    [InlineData(HedefYonu.EnAz, 1, 1)]
    [InlineData(HedefYonu.EnAz, 0, 0)]
    [InlineData(HedefYonu.EnCok, 0, 1)]
    [InlineData(HedefYonu.EnCok, 1, 0)]
    public void GununDegeri_EvetHayir_HasNoTarget(HedefYonu yon, int miktar, double beklenen)
    {
        Assert.Equal(beklenen, AliskanlikHesap.GununDegeri(Olcu.EvetHayir, yon, null, miktar));
    }

    [Theory]
    [InlineData("2026-10-26", true)] // Monday
    [InlineData("2026-10-27", false)] // Tuesday
    [InlineData("2026-10-30", true)] // Friday
    [InlineData("2026-11-01", false)] // Sunday
    public void Planli_BelirliGunler_UsesDayFlags(string gun, bool beklenen)
    {
        var a = Sayac(siklik: Siklik.BelirliGunler, gunler: Aliskanliklar.Gunler.Pzt | Aliskanliklar.Gunler.Cum);
        Assert.Equal(beklenen, AliskanlikHesap.Planli(a, DateOnly.Parse(gun)));
    }

    [Theory]
    [InlineData(Siklik.HerGun)]
    [InlineData(Siklik.HaftadaN)]
    public void Planli_OtherFrequencies_CountEveryDay(Siklik siklik)
    {
        var a = Sayac(siklik: siklik, haftalik: 3);
        Assert.All(Enumerable.Range(0, 7), i => Assert.True(AliskanlikHesap.Planli(a, Bas.AddDays(i))));
    }

    [Fact]
    public void Guc_NeverDone_IsZero()
    {
        var bugun = Bas.AddDays(10);
        Assert.Equal(0, AliskanlikHesap.Guc(Sayac(), new Dictionary<DateOnly, decimal>(), Bas, bugun));
    }

    [Theory]
    [InlineData(10)]
    [InlineData(60)]
    [InlineData(400)]
    public void Guc_AlwaysDone_ApproachesOneAndNeverExceedsIt(int gun)
    {
        var guc = AliskanlikHesap.Guc(Sayac(), Gunler(gun, 8), Bas, Bas.AddDays(gun - 1));

        Assert.InRange(guc, 0.4, 1.0);
        if (gun >= 60)
            Assert.True(guc > 0.95);
    }

    [Fact]
    public void Guc_OneMiss_LowersButDoesNotReset()
    {
        var oncesi = AliskanlikHesap.Guc(Sayac(), Gunler(30, 8), Bas, Bas.AddDays(29));

        var kacirmali = Gunler(30, 8);
        kacirmali[Bas.AddDays(30)] = 0;
        var sonrasi = AliskanlikHesap.Guc(Sayac(), kacirmali, Bas, Bas.AddDays(30));

        Assert.True(sonrasi < oncesi);
        Assert.True(sonrasi > 0.5 * oncesi);
    }

    [Fact]
    public void Guc_BelirliGunler_IgnoresUnplannedDays()
    {
        var a = Sayac(siklik: Siklik.BelirliGunler, gunler: Aliskanliklar.Gunler.Pzt);
        var yalnizPazartesi = Enumerable.Range(0, 70).Select(i => Bas.AddDays(i))
            .Where(g => g.DayOfWeek == DayOfWeek.Monday).ToDictionary(g => g, _ => 8m);
        var bugun = Bas.AddDays(69);

        // Entries (or their absence) on other days must not change anything.
        var digerGunlerle = new Dictionary<DateOnly, decimal>(yalnizPazartesi);
        foreach (var g in Enumerable.Range(0, 70).Select(i => Bas.AddDays(i)).Where(g => g.DayOfWeek != DayOfWeek.Monday))
            digerGunlerle[g] = 0;

        var biri = AliskanlikHesap.Guc(a, yalnizPazartesi, Bas, bugun);
        var digeri = AliskanlikHesap.Guc(a, digerGunlerle, Bas, bugun);

        Assert.Equal(biri, digeri, 9);
        Assert.True(biri > 0.35); // 10 Mondays: 1 - 0.948^10
    }

    [Fact]
    public void Guc_HaftadaN_DropsSlowerThanDaily()
    {
        // 28 perfect days, then 3 misses. A 3-per-week quota is still met within the last 7 days,
        // so the weekly habit loses less of its strength than the daily one (the levels differ, so compare the relative drop).
        var veri = Gunler(28, 8);
        foreach (var i in new[] { 28, 29, 30 })
            veri[Bas.AddDays(i)] = 0;

        double Dusus(Aliskanlik a)
        {
            var once = AliskanlikHesap.Guc(a, veri, Bas, Bas.AddDays(27));
            var sonra = AliskanlikHesap.Guc(a, veri, Bas, Bas.AddDays(30));
            return (once - sonra) / once;
        }

        var gunluk = Dusus(Sayac());
        var haftalik = Dusus(Sayac(siklik: Siklik.HaftadaN, haftalik: 3));

        Assert.True(gunluk > 0);
        Assert.True(haftalik < gunluk);
    }

    [Fact]
    public void GucSerisi_ReturnsOnePointPerDayAndSkipsTodayWithoutEntry()
    {
        var bugun = Bas.AddDays(4);
        var seri = AliskanlikHesap.GucSerisi(Sayac(), Gunler(4, 8), Bas, bugun, bugun);

        Assert.Equal(5, seri.Count);
        Assert.Equal(seri[3].Guc, seri[4].Guc); // today has no entry yet: not counted
    }

    [Fact]
    public void Seri_CountsConsecutiveSuccessfulDays()
    {
        var bugun = Bas.AddDays(9);
        var veri = Gunler(10, 8);
        veri[Bas.AddDays(3)] = 2; // broken on day 3

        Assert.Equal(6, AliskanlikHesap.Seri(Sayac(), veri, Bas, bugun));
        Assert.Equal(6, AliskanlikHesap.EnUzunSeri(Sayac(), veri, Bas, bugun));
    }

    [Fact]
    public void Seri_TodayWithoutEntry_DoesNotBreakTheStreak()
    {
        var bugun = Bas.AddDays(5);

        Assert.Equal(5, AliskanlikHesap.Seri(Sayac(), Gunler(5, 8), Bas, bugun));
    }

    [Fact]
    public void Seri_MissedYesterday_IsZeroButLongestStays()
    {
        var bugun = Bas.AddDays(6);
        var veri = Gunler(5, 8); // days 0-4 done, day 5 missed, today open

        Assert.Equal(0, AliskanlikHesap.Seri(Sayac(), veri, Bas, bugun));
        Assert.Equal(5, AliskanlikHesap.EnUzunSeri(Sayac(), veri, Bas, bugun));
    }

    [Fact]
    public void Seri_BelirliGunler_SkipsUnplannedDays()
    {
        // 2026-09-01 is a Tuesday. Planned: Tuesday and Friday.
        var a = Sayac(siklik: Siklik.BelirliGunler, gunler: Aliskanliklar.Gunler.Sal | Aliskanliklar.Gunler.Cum);
        var veri = new Dictionary<DateOnly, decimal>
        {
            [new DateOnly(2026, 9, 1)] = 8, // Tue
            [new DateOnly(2026, 9, 4)] = 8, // Fri
            [new DateOnly(2026, 9, 8)] = 8, // Tue
        };

        Assert.Equal(3, AliskanlikHesap.Seri(a, veri, Bas, new DateOnly(2026, 9, 9)));
    }

    [Fact]
    public void Seri_HaftadaN_CountsWeeks()
    {
        // 2026-09-01 is a Tuesday, so weeks start on 08-31, 09-07, 09-14.
        var a = Sayac(siklik: Siklik.HaftadaN, haftalik: 2);
        var veri = new Dictionary<DateOnly, decimal>
        {
            [new DateOnly(2026, 9, 1)] = 8, [new DateOnly(2026, 9, 2)] = 8, // week 1: 2 days
            [new DateOnly(2026, 9, 8)] = 8, [new DateOnly(2026, 9, 10)] = 8, // week 2: 2 days
            [new DateOnly(2026, 9, 15)] = 8, // week 3 (open): 1 of 2 so far
        };

        Assert.Equal(2, AliskanlikHesap.Seri(a, veri, Bas, new DateOnly(2026, 9, 16)));
    }
}
