using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Pages.Aliskanliklar;

// What a shelf habit's page shows of its shelf: the items by shelf (in display order) and the yearly summary of the finished ones.
public record RafVerisi(IReadOnlyList<(OgeDurumu Durum, List<OgeDto> Ogeler)> Raflar, IReadOnlyList<(int Yil, int Adet, decimal Miktar)> YilOzeti)
{
    public static readonly RafVerisi Bos = new([], []);

    public bool BosMu => Raflar.All(r => r.Ogeler.Count == 0);

    public List<OgeDto> Devam => Raflar.FirstOrDefault(r => r.Durum == OgeDurumu.Devam).Ogeler ?? [];

    public static async Task<RafVerisi> YukleAsync(AppDbContext db, Guid aliskanlikId, CancellationToken ct)
    {
        var bugun = AliskanlikIslemleri.Bugun();
        var ogeler = (await AliskanlikIslemleri.OgeSorgu(db).Where(o => o.AliskanlikId == aliskanlikId).ToListAsync(ct))
            .Select(o => OgeEndpoints.OgeDtoYap(o, bugun)).ToList();

        var raflar = new List<(OgeDurumu, List<OgeDto>)>
        {
            (OgeDurumu.Devam, ogeler.Where(o => o.Durum == OgeDurumu.Devam).OrderBy(o => o.Olusturulma).ToList()),
            (OgeDurumu.Siradaki, ogeler.Where(o => o.Durum == OgeDurumu.Siradaki).OrderBy(o => o.Olusturulma).ToList()),
            (OgeDurumu.Bitti, ogeler.Where(o => o.Durum == OgeDurumu.Bitti).OrderByDescending(o => o.BitisTarihi).ToList()),
            (OgeDurumu.Birakildi, ogeler.Where(o => o.Durum == OgeDurumu.Birakildi).OrderByDescending(o => o.Olusturulma).ToList()),
        };
        var yilOzeti = OgeHesap.YilOzeti(ogeler.Where(o => o.Durum == OgeDurumu.Bitti)
            .Select(o => (o.BitisTarihi ?? bugun, o.GuncelKonum - o.BaslangicKonumu)));
        return new RafVerisi(raflar, yilOzeti);
    }
}
