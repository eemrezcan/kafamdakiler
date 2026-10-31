using Kafamdakiler.Aliskanliklar;

namespace Kafamdakiler.Tests;

public class OgeHesapTests
{
    private static readonly DateOnly Bugun = new(2026, 10, 31);

    [Theory]
    [InlineData(12, null, 12)]
    [InlineData(12, 35, 35)]
    public void OturumBaslangici_IsLastSessionEndOrItemStart(int baslangicKonumu, int? sonBitis, int beklenen)
    {
        Assert.Equal(beklenen, OgeHesap.OturumBaslangici(baslangicKonumu, sonBitis));
    }

    [Theory]
    [InlineData(35, 160, 0.21875)]
    [InlineData(160, 160, 1)]
    [InlineData(0, 160, 0)]
    public void Ilerleme_IsShareOfTotal(int konum, int toplam, double beklenen)
    {
        Assert.Equal(beklenen, OgeHesap.Ilerleme(konum, toplam));
    }

    [Theory]
    [InlineData(35, null)]
    [InlineData(35, 0)]
    public void Ilerleme_WithoutTotal_IsNull(int konum, int? toplam)
    {
        Assert.Null(OgeHesap.Ilerleme(konum, toplam));
    }

    [Theory]
    [InlineData(159, 160, false)]
    [InlineData(160, 160, true)] // last page finishes the item
    [InlineData(500, null, false)] // no total: finishing is manual
    public void Bitti_OnlyWhenTotalIsReached(int bitis, int? toplam, bool beklenen)
    {
        Assert.Equal(beklenen, OgeHesap.Bitti(bitis, toplam));
    }

    [Fact]
    public void Hiz_NoSessions_IsZero()
    {
        Assert.Equal(0, OgeHesap.Hiz([], Bugun));
    }

    [Fact]
    public void Hiz_SingleDay_IsNotDilutedByEmptyHistory()
    {
        Assert.Equal(23, OgeHesap.Hiz([(Bugun, 23)], Bugun));
    }

    [Fact]
    public void Hiz_AveragesOverDaysSinceFirstSessionInWindow()
    {
        // 20 + 10 pages, first session 4 days ago (inclusive of today: 5 days).
        var hiz = OgeHesap.Hiz([(Bugun.AddDays(-4), 20), (Bugun, 10)], Bugun);

        Assert.Equal(6, hiz);
    }

    [Fact]
    public void Hiz_IgnoresSessionsOlderThanFourteenDays()
    {
        var hiz = OgeHesap.Hiz([(Bugun.AddDays(-14), 1000), (Bugun.AddDays(-13), 14)], Bugun);

        Assert.Equal(1, hiz);
    }

    [Theory]
    [InlineData(35, 160, 23.0, "2026-11-06")] // 125 left / 23 = 5.4 -> 6 days
    [InlineData(150, 160, 10.0, "2026-11-01")] // exactly one day
    [InlineData(160, 160, 10.0, "2026-10-31")] // already done
    public void TahminiBitis_RoundsUpToWholeDays(int konum, int toplam, double hiz, string beklenen)
    {
        Assert.Equal(DateOnly.Parse(beklenen), OgeHesap.TahminiBitis(konum, toplam, (decimal)hiz, Bugun));
    }

    [Fact]
    public void YilOzeti_GroupsFinishedItemsByYear_NewestFirst()
    {
        var ozet = OgeHesap.YilOzeti([
            (new DateOnly(2025, 3, 1), 200m), (new DateOnly(2026, 1, 5), 150m), (new DateOnly(2026, 10, 1), 100.5m)]);

        Assert.Equal([(2026, 2, 250.5m), (2025, 1, 200m)], ozet);
        Assert.Empty(OgeHesap.YilOzeti([]));
    }

    [Fact]
    public void FractionalPositions_AreSupported()
    {
        // E-book at 12.5% of 100, a session of 2.5 units.
        Assert.Equal(0.125, OgeHesap.Ilerleme(12.5m, 100m));
        Assert.Equal(2.5m, OgeHesap.Hiz([(Bugun, 2.5m)], Bugun));
        Assert.Equal(0.5, AliskanlikHesap.GununDegeri(Olcu.Sayili, HedefYonu.EnAz, 2.5m, 1.25m));
    }

    [Theory]
    [InlineData(35, null, 23.0)]
    [InlineData(35, 160, 0.0)]
    public void TahminiBitis_WithoutTotalOrSpeed_IsNull(int konum, int? toplam, double hiz)
    {
        Assert.Null(OgeHesap.TahminiBitis(konum, toplam, (decimal)hiz, Bugun));
    }
}
