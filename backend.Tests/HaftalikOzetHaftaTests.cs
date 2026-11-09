using Kafamdakiler.Beyin;
using Kafamdakiler.Ozet;

namespace Kafamdakiler.Tests;

// Which week a moment belongs to, and which week the Sunday round is answerable for. The week follows the app's day (it turns at 05:00,
// GunSiniri), so Sunday 23:59 and Monday 00:00 are still the same week; the new one begins Monday 05:00. No database needed.
public class HaftalikOzetHaftaTests
{
    private static DateTimeOffset Ist(int ay, int gun, int saat, int dakika) =>
        new DateTimeOffset(2026, ay, gun, saat, dakika, 0, TimeSpan.FromHours(3)).ToUniversalTime();

    [Theory]
    // Before Sunday 21:00 the week in progress is not due yet: the answerable week is the one before (26 Oct).
    [InlineData(11, 8, 20, 59, 10, 26)]
    [InlineData(11, 8, 21, 0, 11, 2)]
    [InlineData(11, 8, 23, 59, 11, 2)]
    // Monday 00:00 to 04:59 is still Sunday's day; from 05:00 the new week has begun but is not due, so the ended week stays the answer.
    [InlineData(11, 9, 0, 0, 11, 2)]
    [InlineData(11, 9, 4, 59, 11, 2)]
    [InlineData(11, 9, 5, 0, 11, 2)]
    [InlineData(11, 11, 10, 0, 11, 2)]
    [InlineData(11, 15, 20, 59, 11, 2)]
    [InlineData(11, 15, 21, 0, 11, 9)]
    public void HedefHafta_IsTheLatestWeekWhoseSundayNineInTheEveningHasPassed(int ay, int gun, int saat, int dakika, int beklenenAy, int beklenenGun)
    {
        Assert.Equal(new DateOnly(2026, beklenenAy, beklenenGun), HaftalikOzetYazici.HedefHafta(Ist(ay, gun, saat, dakika)));
    }

    [Theory]
    [InlineData(11, 8, 23, 59, 11, 2)]
    [InlineData(11, 9, 0, 0, 11, 2)]
    [InlineData(11, 9, 4, 59, 11, 2)]
    [InlineData(11, 9, 5, 0, 11, 9)]
    [InlineData(11, 2, 0, 0, 10, 26)]
    [InlineData(11, 2, 5, 0, 11, 2)]
    public void Pazartesi_FollowsTheFiveOClockTurnOfTheDay(int ay, int gun, int saat, int dakika, int beklenenAy, int beklenenGun)
    {
        var pazartesi = HaftalikOzetOlusturucu.Pazartesi(GunSiniri.Bugun(Ist(ay, gun, saat, dakika)));

        Assert.Equal(new DateOnly(2026, beklenenAy, beklenenGun), pazartesi);
    }

    [Fact]
    public void Kimlik_Yol_AndBaslik_AreTheIsoWeekOfTheMonday()
    {
        var pazartesi = new DateOnly(2026, 11, 2);

        Assert.Equal("2026-W45", HaftalikOzetOlusturucu.Kimlik(pazartesi));
        Assert.Equal("aliskanliklar/haftalik/2026-W45.md", HaftalikOzetOlusturucu.Yol(pazartesi));
        Assert.Equal("Haftalık ölçüm özeti 2026-W45", HaftalikOzetOlusturucu.Baslik(pazartesi));
        // The ISO year can differ from the calendar year around New Year: Monday 29 Dec 2025 is the first week of 2026.
        Assert.Equal("2026-W01", HaftalikOzetOlusturucu.Kimlik(new DateOnly(2025, 12, 29)));
    }

    [Fact]
    public void HazirlikAni_IsSundayNineInTheEveningInIstanbul()
    {
        Assert.Equal(Ist(11, 8, 21, 0), HaftalikOzetOlusturucu.HazirlikAni(new DateOnly(2026, 11, 2)));
    }
}
