namespace Kafamdakiler.Aliskanliklar;

// Pure item calculations.
public static class OgeHesap
{
    private const int HizGunu = 14;

    // Where the next session starts: the end of the last session, or the item's own start.
    public static decimal OturumBaslangici(decimal baslangicKonumu, decimal? sonOturumBitisi) =>
        sonOturumBitisi ?? baslangicKonumu;

    // Share of the whole that is done (0..1); null when the total is unknown.
    public static double? Ilerleme(decimal guncelKonum, decimal? toplam) =>
        toplam is > 0 ? Math.Min(1, (double)(guncelKonum / toplam.Value)) : null;

    public static bool Bitti(decimal bitisKonum, decimal? toplam) =>
        toplam is not null && bitisKonum >= toplam;

    // Units per day over the last 14 days. A reader who started 3 days ago is averaged over 3 days, not 14.
    public static decimal Hiz(IEnumerable<(DateOnly Tarih, decimal Miktar)> oturumlar, DateOnly bugun)
    {
        var ilk = bugun.AddDays(-(HizGunu - 1));
        var pencere = oturumlar.Where(o => o.Tarih >= ilk && o.Tarih <= bugun).ToList();
        if (pencere.Count == 0)
            return 0;

        var baslangic = pencere.Min(o => o.Tarih);
        var gunSayisi = bugun.DayNumber - baslangic.DayNumber + 1;
        return pencere.Sum(o => o.Miktar) / gunSayisi;
    }

    // Finished items per year: how many and how much (pages, episodes...), newest year first.
    public static IReadOnlyList<(int Yil, int Adet, decimal Miktar)> YilOzeti(IEnumerable<(DateOnly BitisTarihi, decimal Miktar)> bitenler) =>
        bitenler.GroupBy(o => o.BitisTarihi.Year)
            .Select(g => (g.Key, g.Count(), g.Sum(o => o.Miktar)))
            .OrderByDescending(o => o.Key)
            .ToList();

    // Estimated finish day at the current speed; null when there is no total or no speed.
    public static DateOnly? TahminiBitis(decimal guncelKonum, decimal? toplam, decimal hiz, DateOnly bugun)
    {
        if (toplam is null || hiz <= 0)
            return null;

        var kalan = Math.Max(0, toplam.Value - guncelKonum);
        return bugun.AddDays((int)Math.Ceiling(kalan / hiz));
    }
}
