using Kafamdakiler.Beyin;
using Microsoft.Extensions.Configuration;

namespace Kafamdakiler.Tests;

// The brain's day turns at 05:00 (Istanbul), not at midnight. A tick at 04:59 still belongs to the day before; one at 05:00 to the new day.
public class GunSiniriTests
{
    private static DateTimeOffset Istanbul(int ay, int gun, int saat, int dakika) =>
        new(2026, ay, gun, saat, dakika, 0, TimeSpan.FromHours(3));

    [Theory]
    [InlineData(11, 7, 4, 59, "2026-11-06")]
    [InlineData(11, 7, 5, 0, "2026-11-07")]
    [InlineData(11, 7, 0, 0, "2026-11-06")]
    [InlineData(11, 7, 12, 30, "2026-11-07")]
    [InlineData(11, 7, 23, 59, "2026-11-07")]
    // The turn of a month and of a year.
    [InlineData(12, 1, 4, 59, "2026-11-30")]
    [InlineData(12, 1, 5, 0, "2026-12-01")]
    public void Bugun_TurnsAt0500(int ay, int gun, int saat, int dakika, string beklenen) =>
        Assert.Equal(beklenen, GunSiniri.Bugun(Istanbul(ay, gun, saat, dakika)).ToString("yyyy-MM-dd"));

    [Fact]
    public void Bugun_NewYear_0459_IsStillLastYear() =>
        Assert.Equal(new DateOnly(2026, 12, 31), GunSiniri.Bugun(new DateTimeOffset(2027, 1, 1, 4, 59, 0, TimeSpan.FromHours(3))));

    // The clock may come in any offset (the server runs in UTC, the phone in +03:00): it is the same instant.
    [Theory]
    [InlineData("2026-11-07T01:59:00+00:00", "2026-11-06")]
    [InlineData("2026-11-07T02:00:00+00:00", "2026-11-07")]
    [InlineData("2026-11-07T04:59:00+03:00", "2026-11-06")]
    [InlineData("2026-11-07T05:00:00+03:00", "2026-11-07")]
    [InlineData("2026-11-06T20:59:00-05:00", "2026-11-06")]
    [InlineData("2026-11-06T21:00:00-05:00", "2026-11-07")]
    public void Bugun_DoesNotDependOnTheOffsetItIsGivenIn(string an, string beklenen) =>
        Assert.Equal(beklenen, GunSiniri.Bugun(DateTimeOffset.Parse(an)).ToString("yyyy-MM-dd"));

    [Fact]
    public void Dun_IsTheDayBeforeBugun()
    {
        Assert.Equal(new DateOnly(2026, 11, 5), GunSiniri.Dun(Istanbul(11, 7, 4, 59)));
        Assert.Equal(new DateOnly(2026, 11, 6), GunSiniri.Dun(Istanbul(11, 7, 5, 0)));
    }

    [Fact]
    public void TheTurningHour_IsTheBrainsOwn() => Assert.Equal(5, GunSiniri.DonusSaati);

    // Gun:KapasiteSaat

    private static GunAyari Ayar(string? deger) => GunAyari.Oku(new ConfigurationBuilder()
        .AddInMemoryCollection(deger is null ? [] : new Dictionary<string, string?> { ["Gun:KapasiteSaat"] = deger })
        .Build());

    [Fact]
    public void Capacity_DefaultsToSixHours()
    {
        Assert.Equal(360, Ayar(null).KapasiteDk);
        Assert.Equal(360, new GunAyari().KapasiteDk);
    }

    [Theory]
    [InlineData("4", 240)]
    [InlineData("7.5", 450)]
    [InlineData("24", 1440)]
    public void Capacity_ReadsTheSetting(string deger, int beklenenDk) => Assert.Equal(beklenenDk, Ayar(deger).KapasiteDk);

    [Theory]
    [InlineData("0")]
    [InlineData("-3")]
    [InlineData("25")]
    [InlineData("abc")]
    [InlineData("")]
    public void Capacity_ABadValueFallsBackToTheDefault_NotToNoWarning(string deger) => Assert.Equal(360, Ayar(deger).KapasiteDk);
}
