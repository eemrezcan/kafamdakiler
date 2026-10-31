using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Microsoft.EntityFrameworkCore;
using static Kafamdakiler.Aliskanliklar.AliskanlikIslemleri;

namespace Kafamdakiler.Aliskanliklar;

public static class AliskanlikEndpoints
{
    internal readonly record struct GunToplami(decimal Miktar, int? Dakika);

    public static void MapAliskanlikEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api/aliskanliklar").WithTags("Alışkanlıklar")
            .RequireAuthorization(AliskanlikPolicies.Oku);
        var yaz = app.MapGroup("/api/aliskanliklar").WithTags("Alışkanlıklar")
            .RequireAuthorization(AliskanlikPolicies.Yaz);

        oku.MapGet("/", async (AppDbContext db, CancellationToken ct, bool arsiv = false) =>
        {
            var liste = await db.Aliskanliklar.Where(a => a.Arsivlendi == arsiv)
                .OrderBy(a => a.Sira).ThenBy(a => a.CreatedAt).ToListAsync(ct);
            return Results.Ok(await DtoYapAsync(db, liste, ct));
        });

        oku.MapGet("/{id:guid}", async (Guid id, AppDbContext db, CancellationToken ct) =>
        {
            var a = await db.Aliskanliklar.FindAsync([id], ct);
            return a is null ? Results.NotFound() : Results.Ok((await DtoYapAsync(db, [a], ct))[0]);
        });

        yaz.MapPost("/", async (AliskanlikYazDto dto, AppDbContext db, CancellationToken ct) =>
        {
            // The same client id twice (an offline retry) returns the existing record.
            if (dto.Id is { } id && await db.Aliskanliklar.FindAsync([id], ct) is { } mevcut)
                return Results.Ok((await DtoYapAsync(db, [mevcut], ct))[0]);

            var a = new Aliskanlik();
            if (dto.Id is { } yeniId)
                a.Id = yeniId;
            AliskanlikUygula(a, dto);
            db.Aliskanliklar.Add(a);
            await db.SaveChangesAsync(ct);

            return Results.Created($"/api/aliskanliklar/{a.Id}", (await DtoYapAsync(db, [a], ct))[0]);
        });

        yaz.MapPut("/{id:guid}", async (Guid id, AliskanlikYazDto dto, AppDbContext db, CancellationToken ct) =>
        {
            var a = await db.Aliskanliklar.FindAsync([id], ct);
            if (a is null)
                return Results.NotFound();
            if (AliskanlikKontrol(a, dto) is { Basarili: false } sonuc)
                return Yanit(sonuc);

            AliskanlikUygula(a, dto);
            await db.SaveChangesAsync(ct);
            return Results.Ok((await DtoYapAsync(db, [a], ct))[0]);
        });

        yaz.MapDelete("/{id:guid}", async (Guid id, AppDbContext db, DosyaDeposu depo, CancellationToken ct) =>
        {
            var a = await db.Aliskanliklar.FindAsync([id], ct);
            if (a is null)
                return Results.NotFound();

            await AliskanlikSilAsync(db, depo, a, ct);
            return Results.NoContent();
        });

        yaz.MapPut("/{id:guid}/kayitlar/{tarih}", async (Guid id, DateOnly tarih, KayitYazDto dto, AppDbContext db, CancellationToken ct) =>
        {
            var a = await db.Aliskanliklar.FindAsync([id], ct);
            if (a is null)
                return Results.NotFound();

            var sonuc = await KayitYazAsync(db, a, tarih, dto.Miktar, dto.Dakika, ct);
            return sonuc.Basarili ? Results.Ok((await GunleriHesaplaAsync(db, a, tarih, tarih, ct))[0]) : Yanit(sonuc);
        });

        yaz.MapDelete("/{id:guid}/kayitlar/{tarih}", async (Guid id, DateOnly tarih, AppDbContext db, CancellationToken ct) =>
        {
            var a = await db.Aliskanliklar.FindAsync([id], ct);
            if (a is null)
                return Results.NotFound();

            var sonuc = await KayitSilAsync(db, a, tarih, ct);
            return sonuc.Basarili ? Results.NoContent() : Yanit(sonuc);
        });

        oku.MapGet("/{id:guid}/gunler", async (Guid id, AppDbContext db, CancellationToken ct, DateOnly? baslangic = null, DateOnly? bitis = null) =>
        {
            var a = await db.Aliskanliklar.FindAsync([id], ct);
            if (a is null)
                return Results.NotFound();

            var son = bitis ?? Bugun();
            var ilk = baslangic ?? son.AddDays(-29);
            if (son < ilk)
                return Sorun("bitis", "Bitiş, başlangıçtan önce olamaz.");
            if (son.DayNumber - ilk.DayNumber > 366)
                return Sorun("bitis", "Aralık en çok 367 gün olabilir.");

            return Results.Ok(await GunleriHesaplaAsync(db, a, ilk, son, ct));
        });
    }

    internal static IResult Sorun(string alan, string mesaj) =>
        Results.ValidationProblem(new Dictionary<string, string[]> { [alan] = [mesaj] });

    internal static IResult Cakisma(string detay) =>
        Results.Problem(title: "Çakışma", detail: detay, statusCode: StatusCodes.Status409Conflict);

    // Refused write -> 400 with the field, or 409.
    internal static IResult Yanit(Sonuc sonuc) =>
        sonuc.Cakisma || sonuc.Alan is null ? Cakisma(sonuc.Mesaj!) : Sorun(sonuc.Alan, sonuc.Mesaj!);

    // Day totals per habit: Sayac from the entries, Raf from the sessions of all its items.
    internal static async Task<Dictionary<DateOnly, GunToplami>> GunToplamlariAsync(AppDbContext db, Guid aliskanlikId, CancellationToken ct) =>
        (await GunToplamlariAsync(db, [aliskanlikId], ct)).GetValueOrDefault(aliskanlikId) ?? [];

    internal static async Task<Dictionary<Guid, Dictionary<DateOnly, GunToplami>>> GunToplamlariAsync(
        AppDbContext db, List<Guid> idler, CancellationToken ct)
    {
        var kayitlar = await db.AliskanlikKayitlari.Where(k => idler.Contains(k.AliskanlikId))
            .Select(k => new { k.AliskanlikId, k.Tarih, k.Miktar, k.Dakika }).ToListAsync(ct);
        var oturumlar = await db.Oturumlar.Where(o => idler.Contains(o.Oge!.AliskanlikId))
            .Select(o => new { o.Oge!.AliskanlikId, o.Tarih, Miktar = o.BitisKonum - o.BaslangicKonum, o.Dakika }).ToListAsync(ct);

        var sonuc = new Dictionary<Guid, Dictionary<DateOnly, GunToplami>>();
        void Ekle(Guid id, DateOnly tarih, decimal miktar, int? dakika)
        {
            if (!sonuc.TryGetValue(id, out var gunler))
                sonuc[id] = gunler = [];

            gunler[tarih] = gunler.TryGetValue(tarih, out var eski)
                ? new GunToplami(eski.Miktar + miktar, eski.Dakika is null && dakika is null ? null : (eski.Dakika ?? 0) + (dakika ?? 0))
                : new GunToplami(miktar, dakika);
        }

        foreach (var k in kayitlar)
            Ekle(k.AliskanlikId, k.Tarih, k.Miktar, k.Dakika);
        foreach (var o in oturumlar)
            Ekle(o.AliskanlikId, o.Tarih, o.Miktar, o.Dakika);

        return sonuc;
    }

    internal static async Task<List<GunDto>> GunleriHesaplaAsync(AppDbContext db, Aliskanlik a, DateOnly ilk, DateOnly son, CancellationToken ct)
    {
        var veri = await GunToplamlariAsync(db, a.Id, ct);
        var bugun = Bugun();
        var miktarlar = veri.ToDictionary(x => x.Key, x => x.Value.Miktar);
        var gucler = AliskanlikHesap.GucSerisi(a, miktarlar, AliskanlikHesap.AliskanlikGunu(a.CreatedAt), son, bugun)
            .ToDictionary(x => x.Gun, x => x.Guc);

        var gunler = new List<GunDto>();
        for (var gun = ilk; gun <= son; gun = gun.AddDays(1))
        {
            var toplam = veri.GetValueOrDefault(gun);
            gunler.Add(new GunDto(gun, Sade(toplam.Miktar), toplam.Dakika, Yuvarla(AliskanlikHesap.GununDegeri(a, toplam.Miktar)),
                AliskanlikHesap.Planli(a, gun), Yuvarla(gucler.GetValueOrDefault(gun))));
        }

        return gunler;
    }

    internal static async Task<List<AliskanlikDto>> DtoYapAsync(AppDbContext db, List<Aliskanlik> liste, CancellationToken ct)
    {
        var idler = liste.Select(a => a.Id).ToList();
        var veri = await GunToplamlariAsync(db, idler, ct);
        var devam = (await db.Ogeler.Where(o => idler.Contains(o.AliskanlikId) && o.Durum == OgeDurumu.Devam)
                .OrderBy(o => o.CreatedAt)
                .Select(o => new { o.AliskanlikId, o.Id, o.Ad, o.AltBaslik, o.FotografId, o.Toplam, o.BaslangicKonumu, Son = o.Oturumlar.Max(t => (decimal?)t.BitisKonum) })
                .ToListAsync(ct))
            .ToLookup(o => o.AliskanlikId);

        var bugun = Bugun();
        return liste.Select(a =>
        {
            var gunler = veri.GetValueOrDefault(a.Id) ?? [];
            var miktarlar = gunler.ToDictionary(x => x.Key, x => x.Value.Miktar);
            var baslangic = AliskanlikHesap.AliskanlikGunu(a.CreatedAt);
            var bugunToplam = gunler.GetValueOrDefault(bugun);

            var devamEdenler = devam[a.Id].Select(o =>
            {
                var konum = OgeHesap.OturumBaslangici(o.BaslangicKonumu, o.Son);
                var ilerleme = OgeHesap.Ilerleme(konum, o.Toplam);
                return new DevamEdenDto(o.Id, o.Ad, o.AltBaslik, OgeEndpoints.FotografUrl(o.FotografId), Sade(konum), Sade(o.Toplam),
                    ilerleme is { } i ? Yuvarla(i) : null);
            }).ToList();

            return new AliskanlikDto(
                a.Id, a.Ad, a.Tur, a.Ikon, a.Renk, a.Olcu, a.HedefYonu, Sade(a.GunlukHedef), a.Birim, a.OgeEtiketi, a.AltBaslikEtiketi,
                a.Siklik, a.HaftalikSayi, GunListesi(a.Gunler), a.Sira, a.Arsivlendi, a.CreatedAt,
                new BugunDto(bugun, Sade(bugunToplam.Miktar), bugunToplam.Dakika, Yuvarla(AliskanlikHesap.GununDegeri(a, bugunToplam.Miktar)),
                    AliskanlikHesap.Planli(a, bugun)),
                Yuvarla(AliskanlikHesap.Guc(a, miktarlar, baslangic, bugun)),
                AliskanlikHesap.Seri(a, miktarlar, baslangic, bugun),
                AliskanlikHesap.EnUzunSeri(a, miktarlar, baslangic, bugun),
                devamEdenler);
        }).ToList();
    }

    private static List<Gunler> GunListesi(Gunler? gunler) =>
        Enum.GetValues<Gunler>().Where(g => g != Gunler.Yok && gunler is { } secili && secili.HasFlag(g)).ToList();
}
