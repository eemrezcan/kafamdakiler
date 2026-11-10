using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Yapilacaklar;

namespace Kafamdakiler.Tests;

// The reminder rules that K-0024 adds, as pure functions: a weekly reminder with several days, which day of a rule a date is, the moments a
// day holds, the day's weight and the title cleaning. The examples of the weekly rule are the ones the phone's own port (mobile
// hatirlatici_hesap.dart) is tested with: change them together.
public class HatirlaticiCokGunluTests
{
    private static readonly TimeOnly Dokuz = new(9, 0);
    private static readonly TimeZoneInfo Istanbul = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");

    private static DateOnly D(string gun) => DateOnly.ParseExact(gun, "yyyy-MM-dd");

    // A moment as "2026-11-09 08:59" in Istanbul.
    private static DateTimeOffset Ist(string gun, string saat = "00:00") =>
        HatirlaticiHesap.An(D(gun), TimeOnly.ParseExact(saat, "HH:mm"));

    // The weekly rule with several days: the days from the start day on (the start day included) whose weekday is chosen.

    // 2026-11-09 is a Monday.
    [Theory]
    [InlineData("2026-11-09", 0, "2026-11-09")]
    [InlineData("2026-11-09", 1, "2026-11-11")]
    [InlineData("2026-11-09", 2, "2026-11-16")]
    [InlineData("2026-11-09", 3, "2026-11-18")]
    [InlineData("2026-11-09", 10, "2026-12-14")]
    // Started on a Tuesday, which is not a chosen day: the first one is the next chosen day.
    [InlineData("2026-11-10", 0, "2026-11-11")]
    [InlineData("2026-11-10", 1, "2026-11-16")]
    [InlineData("2026-11-10", 2, "2026-11-18")]
    // Started on a Sunday.
    [InlineData("2026-11-15", 0, "2026-11-16")]
    public void Olusum_MondayAndWednesday_CountsOnlyTheChosenDaysFromTheStartDay(string baslangic, int n, string beklenen) =>
        Assert.Equal(D(beklenen), HatirlaticiHesap.Olusum(Tekrar.Haftalik, D(baslangic), n, Gunler.Pzt | Gunler.Car));

    [Theory]
    [InlineData("2026-11-06", 0, "2026-11-07")]
    [InlineData("2026-11-06", 1, "2026-11-08")]
    [InlineData("2026-11-06", 2, "2026-11-14")]
    [InlineData("2026-11-06", 3, "2026-11-15")]
    public void Olusum_SaturdayAndSunday(string baslangic, int n, string beklenen) =>
        Assert.Equal(D(beklenen), HatirlaticiHesap.Olusum(Tekrar.Haftalik, D(baslangic), n, Gunler.Cmt | Gunler.Paz));

    [Theory]
    [InlineData(0, "2026-11-13")]
    [InlineData(1, "2026-11-20")]
    [InlineData(5, "2026-12-18")]
    public void Olusum_OneChosenDay_IsAPlainWeeklyRuleOnThatDay(int n, string beklenen) =>
        Assert.Equal(D(beklenen), HatirlaticiHesap.Olusum(Tekrar.Haftalik, D("2026-11-09"), n, Gunler.Cum));

    [Fact]
    public void Olusum_AllSevenDays_IsEveryDay()
    {
        var hepsi = Gunler.Pzt | Gunler.Sal | Gunler.Car | Gunler.Per | Gunler.Cum | Gunler.Cmt | Gunler.Paz;
        for (var n = 0; n < 15; n++)
            Assert.Equal(D("2026-11-09").AddDays(n), HatirlaticiHesap.Olusum(Tekrar.Haftalik, D("2026-11-09"), n, hepsi));
    }

    [Fact]
    public void Olusum_NoChosenDay_OrAnotherKindOfRule_IgnoresTheDays()
    {
        // No day chosen: every 7 days from the start day, as before.
        Assert.Equal(D("2026-11-23"), HatirlaticiHesap.Olusum(Tekrar.Haftalik, D("2026-11-09"), 2, Gunler.Yok));
        // Only a weekly rule reads the days.
        Assert.Equal(D("2026-11-10"), HatirlaticiHesap.Olusum(Tekrar.Gunluk, D("2026-11-09"), 1, Gunler.Cum));
        Assert.Equal(D("2026-12-09"), HatirlaticiHesap.Olusum(Tekrar.Aylik, D("2026-11-09"), 1, Gunler.Cum));
        Assert.Equal(D("2026-11-09"), HatirlaticiHesap.Olusum(Tekrar.Yok, D("2026-11-09"), 0, Gunler.Cum));
    }

    // The first firing moment strictly after `sonra`.

    [Theory]
    [InlineData("2026-11-09 08:59", "2026-11-09 09:00")] // before the hour on a chosen day: the same day
    [InlineData("2026-11-09 09:00", "2026-11-11 09:00")] // exactly at the hour: strictly after, so the next chosen day
    [InlineData("2026-11-10 12:00", "2026-11-11 09:00")] // between two chosen days
    [InlineData("2026-11-11 09:01", "2026-11-16 09:00")] // the last chosen day of the week has passed: next week's first
    [InlineData("2026-11-14 23:00", "2026-11-16 09:00")] // a weekend
    public void Sonraki_MondayAndWednesday(string sonra, string beklenen)
    {
        var (gun, saat) = (sonra[..10], sonra[11..]);
        var beklenenGun = beklenen[..10];
        Assert.Equal(Ist(beklenenGun, beklenen[11..]), HatirlaticiHesap.Sonraki(Tekrar.Haftalik, D("2026-11-09"), Dokuz, Ist(gun, saat), Gunler.Pzt | Gunler.Car));
    }

    [Fact]
    public void Sonraki_BeforeTheStartDay_IsTheFirstChosenDayFromTheStartDay()
    {
        // Starts on a Thursday: Wednesday the 11th is before it, so the first one is Monday the 16th.
        Assert.Equal(Ist("2026-11-16", "09:00"), HatirlaticiHesap.Sonraki(Tekrar.Haftalik, D("2026-11-12"), Dokuz, Ist("2026-11-09", "07:00"), Gunler.Pzt | Gunler.Car));
        // Starts on a chosen day in the future.
        Assert.Equal(Ist("2026-11-16", "09:00"), HatirlaticiHesap.Sonraki(Tekrar.Haftalik, D("2026-11-16"), Dokuz, Ist("2026-11-01", "07:00"), Gunler.Pzt | Gunler.Car));
    }

    [Fact]
    public void Sonraki_NoDays_IsThePlainWeeklyRule_AndTheDaysAreIgnoredByTheOtherRules()
    {
        Assert.Equal(Ist("2026-11-16", "09:00"), HatirlaticiHesap.Sonraki(Tekrar.Haftalik, D("2026-11-09"), Dokuz, Ist("2026-11-09", "09:00")));
        Assert.Equal(Ist("2026-11-10", "09:00"), HatirlaticiHesap.Sonraki(Tekrar.Gunluk, D("2026-11-09"), Dokuz, Ist("2026-11-09", "09:00"), Gunler.Cum));
        Assert.Equal(Ist("2026-11-09", "09:00"), HatirlaticiHesap.Sonraki(Tekrar.Yok, D("2026-11-09"), Dokuz, Ist("2026-11-20", "09:00"), Gunler.Cum));
    }

    [Fact]
    public void Sonraki_EachAnswerIsAnOlusumOfTheRule_AndTheNextOneIsTheFollowingDay()
    {
        var gunler = Gunler.Sal | Gunler.Cum | Gunler.Paz;
        var sonra = Ist("2026-10-01", "00:00");
        for (var i = 0; i < 30; i++)
        {
            var an = HatirlaticiHesap.Sonraki(Tekrar.Haftalik, D("2026-09-01"), Dokuz, sonra, gunler);
            Assert.True(gunler.HasFlag(HatirlaticiHesap.HaftaGunu(HatirlaticiHesap.IstanbulGunu(an))));
            Assert.True(an > sonra);
            sonra = an;
        }
    }

    // Which day of a rule a date is (the calendar's view of a repeating reminder)

    private static Hatirlatici Kural(Tekrar tekrar, string gun, Gunler gunler = Gunler.Yok) => new() { Gun = D(gun), Tekrar = tekrar, Gunler = gunler };

    [Theory]
    [InlineData(Tekrar.Yok, "2026-11-09", "2026-11-09", true)]
    [InlineData(Tekrar.Yok, "2026-11-09", "2026-11-10", false)]
    [InlineData(Tekrar.Gunluk, "2026-11-09", "2026-11-08", false)]
    [InlineData(Tekrar.Gunluk, "2026-11-09", "2026-12-30", true)]
    [InlineData(Tekrar.Haftalik, "2026-11-09", "2026-11-16", true)]
    [InlineData(Tekrar.Haftalik, "2026-11-09", "2026-11-17", false)]
    [InlineData(Tekrar.Aylik, "2026-01-31", "2026-02-28", true)]
    [InlineData(Tekrar.Aylik, "2026-01-31", "2026-03-31", true)]
    [InlineData(Tekrar.Aylik, "2026-01-31", "2026-03-28", false)]
    [InlineData(Tekrar.Yillik, "2024-02-29", "2026-02-28", true)]
    [InlineData(Tekrar.Yillik, "2024-02-29", "2028-02-29", true)]
    [InlineData(Tekrar.Yillik, "2024-02-29", "2026-03-01", false)]
    public void KuralGunu_FollowsTheRulesOwnCounting(Tekrar tekrar, string baslangic, string gun, bool beklenen) =>
        Assert.Equal(beklenen, YapilacakYardimcisi.KuralGunu(Kural(tekrar, baslangic), D(gun)));

    [Fact]
    public void KuralGunu_AWeeklyRuleWithDays_IsTheChosenWeekdaysFromTheStartDay()
    {
        var kural = Kural(Tekrar.Haftalik, "2026-11-09", Gunler.Pzt | Gunler.Cum);
        Assert.True(YapilacakYardimcisi.KuralGunu(kural, D("2026-11-13")));
        Assert.True(YapilacakYardimcisi.KuralGunu(kural, D("2026-11-16")));
        Assert.False(YapilacakYardimcisi.KuralGunu(kural, D("2026-11-11")));
        Assert.False(YapilacakYardimcisi.KuralGunu(kural, D("2026-11-06")), "a Friday before the start day");
    }

    // The moments of a reminder in a brain day

    private static readonly ILookup<Guid, DateTimeOffset> Yapilanlar0 = Array.Empty<(Guid, DateTimeOffset)>().ToLookup(x => x.Item1, x => x.Item2);

    [Fact]
    public void Anlar_AnOpenOneOffHasItsPendingMoment_ASnoozeIsItsOwnMoment()
    {
        var h = Kural(Tekrar.Yok, "2026-11-09");
        h.SonrakiAn = Ist("2026-11-09", "14:00");
        Assert.Equal([(Ist("2026-11-09", "14:00"), false)], YapilacakYardimcisi.Anlar(h, D("2026-11-09"), Dokuz, Yapilanlar0));
        Assert.Empty(YapilacakYardimcisi.Anlar(h, D("2026-11-10"), Dokuz, Yapilanlar0));

        h.ErteleAn = Ist("2026-11-10", "08:00");
        Assert.Empty(YapilacakYardimcisi.Anlar(h, D("2026-11-09"), Dokuz, Yapilanlar0));
        Assert.Equal([(Ist("2026-11-10", "08:00"), false)], YapilacakYardimcisi.Anlar(h, D("2026-11-10"), Dokuz, Yapilanlar0));
    }

    [Fact]
    public void Anlar_TheBrainDayEndsAtFiveInTheMorning()
    {
        var h = Kural(Tekrar.Yok, "2026-11-10");
        h.SonrakiAn = Ist("2026-11-10", "02:00");
        // 02:00 on the 10th still belongs to the 9th.
        Assert.Single(YapilacakYardimcisi.Anlar(h, D("2026-11-09"), Dokuz, Yapilanlar0));
        Assert.Empty(YapilacakYardimcisi.Anlar(h, D("2026-11-10"), Dokuz, Yapilanlar0));
    }

    [Fact]
    public void Anlar_ARepeatingOneHasItsLaterTurnsToo_ButNotAPastOne()
    {
        var h = Kural(Tekrar.Gunluk, "2026-11-09");
        h.Saat = new TimeOnly(19, 0);
        h.SonrakiAn = Ist("2026-11-10", "19:00");
        Assert.Equal([(Ist("2026-11-10", "19:00"), false)], YapilacakYardimcisi.Anlar(h, D("2026-11-10"), Dokuz, Yapilanlar0));
        Assert.Equal([(Ist("2026-11-12", "19:00"), false)], YapilacakYardimcisi.Anlar(h, D("2026-11-12"), Dokuz, Yapilanlar0));
        // The 9th was done (it is behind the pending turn): without a record it is not shown.
        Assert.Empty(YapilacakYardimcisi.Anlar(h, D("2026-11-09"), Dokuz, Yapilanlar0));
    }

    [Fact]
    public void Anlar_ADoneTurnIsShownAsDone_AndAClosedOneOffToo()
    {
        var tekrarli = Kural(Tekrar.Gunluk, "2026-11-09");
        tekrarli.Saat = new TimeOnly(19, 0);
        tekrarli.SonrakiAn = Ist("2026-11-10", "19:00");
        var yapilan = new[] { (tekrarli.Id, Ist("2026-11-09", "19:00")) }.ToLookup(x => x.Item1, x => x.Item2);
        Assert.Equal([(Ist("2026-11-09", "19:00"), true)], YapilacakYardimcisi.Anlar(tekrarli, D("2026-11-09"), Dokuz, yapilan));

        // Closed without a record (edited by hand): its own moment, as done.
        var tek = Kural(Tekrar.Yok, "2026-11-09");
        tek.Durum = HatirlaticiDurumu.Tamam;
        tek.SonrakiAn = Ist("2026-11-09", "14:00");
        Assert.Equal([(Ist("2026-11-09", "14:00"), true)], YapilacakYardimcisi.Anlar(tek, D("2026-11-09"), Dokuz, Yapilanlar0));
    }

    // The day's weight

    private static YapilacakDto Oge(YapilacakTuru tur, YapilacakDurumu durum, int? tahmin) => new(
        "x", tur, "x", null, null, false, tahmin, null, durum, null, null, null, null, null, null, null, null, null, null, new DateOnly(2026, 11, 9));

    [Fact]
    public void Yuk_CountsOpenPlanAndTaskItems_ByTheirEstimate_AndTheRestApart()
    {
        var ogeler = new[]
        {
            Oge(YapilacakTuru.Plan, YapilacakDurumu.Acik, 30),
            Oge(YapilacakTuru.Gorev, YapilacakDurumu.Acik, 90),
            Oge(YapilacakTuru.Plan, YapilacakDurumu.Acik, null),
            Oge(YapilacakTuru.Plan, YapilacakDurumu.Yapildi, 60),
            Oge(YapilacakTuru.Hatirlatici, YapilacakDurumu.Acik, 45),
            Oge(YapilacakTuru.Etkinlik, YapilacakDurumu.Acik, null),
        };

        var yuk = YapilacakYardimcisi.Yuk(ogeler, etkinlikDk: 60, kapasiteDk: 360);

        Assert.Equal(new GunYukuDto(120, 60, 360, 0, 180, 1), yuk);
    }

    [Fact]
    public void Yuk_OverTheCapacity_HasTheExcessAndNoRoom_UnderIt_TheRoomAndNoExcess()
    {
        var ogeler = new[] { Oge(YapilacakTuru.Plan, YapilacakDurumu.Acik, 300) };

        Assert.Equal(new GunYukuDto(300, 100, 360, 40, 0, 0), YapilacakYardimcisi.Yuk(ogeler, 100, 360));
        Assert.Equal(new GunYukuDto(300, 60, 360, 0, 0, 0), YapilacakYardimcisi.Yuk(ogeler, 60, 360));
        Assert.Equal(new GunYukuDto(0, 0, 360, 0, 360, 0), YapilacakYardimcisi.Yuk([], 0, 360));
    }

    // Titles

    [Theory]
    [InlineData("Rapor yaz ~30dk", "Rapor yaz")]
    [InlineData("Rapor yaz ~1s", "Rapor yaz")]
    [InlineData("Rapor yaz ~1s30dk", "Rapor yaz")]
    [InlineData("Rapor ~45d yaz", "Rapor yaz")]
    [InlineData("Rapor yaz", "Rapor yaz")]
    [InlineData("~30dk", "")]
    public void BaslikTemizle_TakesTheEstimateMarkerOut(string baslik, string beklenen) =>
        Assert.Equal(beklenen, YapilacakYardimcisi.BaslikTemizle(baslik));

    [Theory]
    [InlineData("Kitap oku (2/3)", "Kitap oku", 2, 3)]
    [InlineData("Kitap oku (1/14) ~30dk", "Kitap oku", 1, 14)]
    [InlineData("Kitap oku", "Kitap oku", 0, 0)]
    [InlineData("Kitap oku (3/2)", "Kitap oku (3/2)", 0, 0)]
    [InlineData("Kitap oku (0/3)", "Kitap oku (0/3)", 0, 0)]
    [InlineData("Kitap oku (1/1)", "Kitap oku (1/1)", 0, 0)]
    [InlineData("(1/3) başta", "(1/3) başta", 0, 0)]
    public void BaslikAyir_ReadsTheCountOfASplitTask_OnlyWhenItMakesSense(string baslik, string beklenenBaslik, int sira, int toplam)
    {
        var (sade, bolunmus) = YapilacakYardimcisi.BaslikAyir(baslik);

        Assert.Equal(beklenenBaslik, sade);
        Assert.Equal(sira == 0 ? null : new BolunmusDto(sira, toplam), bolunmus);
    }

    [Fact]
    public void Kimlikle_AnIdOfATaskOnlyItemIsATask_AnyOtherIsAPlanItem()
    {
        Assert.Equal((YapilacakTuru.Gorev, "g:uye-girisi", (string?)null, (string?)"uye-girisi"), YapilacakYardimcisi.Kimlikle("g:uye-girisi", null));
        Assert.Equal((YapilacakTuru.Plan, "m:a3f09c", (string?)"a3f09c", (string?)"uye-girisi"), YapilacakYardimcisi.Kimlikle("a3f09c", "uye-girisi"));
    }
}
