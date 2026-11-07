namespace Kafamdakiler.Brifing;

// The briefing made by fixed rules (yöntem "hesap"): the same card kinds and the same shape as Claude's, so nothing downstream
// has to know which made it. Used when Claude is off, its daily cap is reached, it failed or its answer was no good, and when the
// day is empty. Pure: no database, no clock.
public static class BrifingHesabi
{
    // How many items a card names in its sentence; the card still links to all of them (up to the card's limit).
    private const int CumledeAdSayisi = 3;

    public static List<BrifingKarti> Hazirla(BrifingGirdisi g)
    {
        if (g.Bos)
            return [new BrifingKarti(BrifingTurleri.Bos, "Bugün sakin bir gün", "Planda, hatırlatıcılarda ve onay kuyruğunda bekleyen bir şey yok.", [])];

        // The order of the cards is the order of urgency: what does not fit, what was left, what is planned, what is coming, what waits.
        var kartlar = new List<BrifingKarti>();

        if (g.Kapasite is { } k)
            kartlar.Add(new BrifingKarti(BrifingTurleri.Kapasite, "Bugün sığmıyor",
                $"Açık maddelerin tahmini {BrifingGirdisi.Sure(k.AcikDk)}, günün kapasitesi {BrifingGirdisi.Sure(k.KapasiteDk)}; {BrifingGirdisi.Sure(k.AsimDk)} fazla.", []));

        if (g.Kalan.Count > 0)
            kartlar.Add(new BrifingKarti(BrifingTurleri.Kalan, $"Dünden kalan {g.Kalan.Count} madde",
                Liste("Açık kalanlar", g.Kalan.Select(m => m.Baslik).ToList()), Kimlikler(g.Kalan.Select(m => m.Kimlik))));

        if (g.Plan.Count > 0)
        {
            var tahmin = g.Plan.Sum(m => m.TahminDk ?? 0);
            kartlar.Add(new BrifingKarti(BrifingTurleri.Plan, $"Bugünün planında {g.Plan.Count} açık madde",
                Liste("İlk maddeler", g.Plan.Select(m => m.Baslik).ToList(), tahmin > 0 ? $"Tahmini toplam {BrifingGirdisi.Sure(tahmin)}." : null),
                Kimlikler(g.Plan.Select(m => m.Kimlik))));
        }

        foreach (var h in g.Hatirlaticilar.Take(BrifingKartlari.EnCokKart))
        {
            var ne = BrifingGirdisi.GunAnlatimi(h.KalanGun);
            var baslik = BrifingGirdisi.Satir(h.Baslik);
            kartlar.Add(new BrifingKarti(BrifingTurleri.Hatirlatici,
                baslik.Length <= BrifingKartlari.BaslikEnUzun ? baslik : baslik[..BrifingKartlari.BaslikEnUzun].TrimEnd(),
                $"{char.ToUpperInvariant(ne[0])}{ne[1..]} saat {h.Saat} ({h.Gun:yyyy-MM-dd} {BrifingGirdisi.GunAdi(h.Gun)}).", [h.Kimlik]));
        }

        if (g.Onaylar.Count > 0)
            kartlar.Add(new BrifingKarti(BrifingTurleri.Onay, $"Onay bekleyen {g.OnayBekleyen} eylem",
                Liste("En uzun bekleyenler", g.Onaylar.Select(o => o.Ozet).ToList()), Kimlikler(g.Onaylar.Select(o => o.Kimlik))));

        if (g.Takvim.Count > 0)
            kartlar.Add(new BrifingKarti(BrifingTurleri.Takvim, $"Bugün {g.Takvim.Count} takvim etkinliği",
                Liste("Etkinlikler", g.Takvim.Select(t => $"{t.Saat} {t.Baslik}").ToList()), Kimlikler(g.Takvim.Select(t => t.Kimlik))));

        // Reminders take a card each, so a day with many of them must not push the rest out: the limit holds for the whole.
        return kartlar.Count <= BrifingKartlari.EnCokKart ? kartlar : Sinirla(kartlar);
    }

    // Past the limit the reminder cards give way first (the last of them), the other kinds stay.
    private static List<BrifingKarti> Sinirla(List<BrifingKarti> kartlar)
    {
        var fazla = kartlar.Count - BrifingKartlari.EnCokKart;
        for (var i = kartlar.Count - 1; i >= 0 && fazla > 0; i--)
        {
            if (kartlar[i].Tur != BrifingTurleri.Hatirlatici)
                continue;

            kartlar.RemoveAt(i);
            fazla--;
        }

        return kartlar.Take(BrifingKartlari.EnCokKart).ToList();
    }

    private static List<string> Kimlikler(IEnumerable<string> kimlikler) =>
        kimlikler.Take(BrifingKartlari.KartBasinaEnCokKimlik).ToList();

    // "On: a, b, c ve 2 tane daha." `basa` goes in front, so when the sentence is too long it is the titles that are cut.
    private static string Liste(string onek, List<string> basliklar, string? basa = null)
    {
        var ilk = basliklar.Take(CumledeAdSayisi).Select(BrifingGirdisi.Satir);
        var kalan = basliklar.Count - CumledeAdSayisi;
        var metin = $"{(basa is null ? "" : basa + " ")}{onek}: {string.Join(", ", ilk)}{(kalan > 0 ? $" ve {kalan} tane daha" : "")}.";
        return metin.Length <= BrifingKartlari.MetinEnUzun ? metin : metin[..(BrifingKartlari.MetinEnUzun - 1)].TrimEnd() + "…";
    }
}
