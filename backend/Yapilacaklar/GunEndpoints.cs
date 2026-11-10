using System.Globalization;
using System.Security.Claims;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Takvim;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.Yapilacaklar;

public record BirakildiDto(DateOnly Tarih, string MaddeId, bool Birakildi);

// The endpoints of the day and calendar views (K-0024, API sözleşmesi §1-§4). The day itself is read with `takvim.oku`; the writes check
// the permission of what they touch (`plan.yaz`, `gorev.yaz`, `hatirlatici.yaz`), by the kind of the id in the request.
public static class GunEndpoints
{
    // The id of "yaptım" and of the shortcuts: the kind letter, a colon, the id.
    private const char PlanOneki = 'm';
    private const char GorevOneki = 'g';
    private const char HatirlaticiOneki = 'h';
    private const char EtkinlikOneki = 'e';

    public const string GeriAlinamazAnahtari = "gorev-geri-alinamaz";

    public static void MapGunEndpoints(this IEndpointRouteBuilder app)
    {
        const string Anahtar = TekrarGuvenligi.Baslik;

        var oku = app.MapGroup("/api").WithTags("Gün").RequireAuthorization(TakvimPolicies.Oku);

        oku.MapGet("/gun/{tarih}", async (string tarih, GunGorunumuServisi servis, TimeProvider saat, ClaimsPrincipal kullanici, CancellationToken ct) =>
            GunCoz(tarih, saat) is not { } gun
                ? TarihHatasi
                : Results.Ok(await servis.GetirAsync(gun, BildirimEndpoints.KullaniciId(kullanici), ct)));

        oku.MapGet("/takvim", async (string? baslangic, string? bitis, TakvimAraligiServisi servis, CancellationToken ct) =>
        {
            if (!TakvimZamani.GunCoz(baslangic, out var ilk) || ilk.Year is < 2000 or > 2100)
                return Sorun("baslangic", "Başlangıç yyyy-MM-dd biçiminde olmalı.");
            if (!TakvimZamani.GunCoz(bitis, out var son) || son.Year is < 2000 or > 2100)
                return Sorun("bitis", "Bitiş yyyy-MM-dd biçiminde olmalı.");
            if (son < ilk)
                return Sorun("bitis", "Bitiş, başlangıçtan önce olamaz.");
            if (son.DayNumber - ilk.DayNumber + 1 > TakvimAraligiServisi.EnCokGun)
                return Sorun("bitis", $"Aralık en çok {TakvimAraligiServisi.EnCokGun} gün olabilir.");

            return Results.Ok(await servis.GetirAsync(ilk, son, ct));
        });

        // Writes: signed in is the gate here, the permission is checked inside, by what the request touches.
        var girisli = app.MapGroup("/api/gun/{tarih}").WithTags("Gün")
            .RequireAuthorization(policy => policy.AddAuthenticationSchemes(IdentityConstants.BearerScheme).RequireAuthenticatedUser());

        // One "yaptım" for everything on the list. The prefix of the id says where it goes.
        girisli.MapPost("/yaptim", async (string tarih, YaptimGirdisi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
            TekrarGuvenligi tekrar, GunGorunumuServisi servis, GunIslemleri islemler, TimeProvider saat, CancellationToken ct) =>
        {
            if (GunCoz(tarih, saat) is not { } gun)
                return TarihHatasi;

            var kimlik = girdi.Kimlik!.Trim();
            if (Ayir(kimlik) is not { } parca)
                return Sorun("kimlik", "Kimlik m:<madde>, g:<görev> ya da h:<hatırlatıcı> biçiminde olmalı.");

            switch (parca.Onek)
            {
                case EtkinlikOneki:
                    return Sorun("kimlik", "Takvim etkinliği için yaptım yok.");
                case PlanOneki when !IzinVar(kullanici, BeyinPolicies.PlanYaz):
                case GorevOneki when !IzinVar(kullanici, BeyinPolicies.GorevYaz):
                case HatirlaticiOneki when !IzinVar(kullanici, HatirlaticiPolicies.Yaz):
                    return Yasak();
                case GorevOneki when girdi.Geri:
                    return Results.Problem(
                        type: GeriAlinamazAnahtari, title: "Görev geri alınamaz", detail: "Biten görev buradan yeniden açılamaz.",
                        statusCode: StatusCodes.Status409Conflict, extensions: new Dictionary<string, object?> { ["kod"] = GeriAlinamazAnahtari });
                case HatirlaticiOneki when !Guid.TryParse(parca.Deger, out _):
                    return Sorun("kimlik", "Hatırlatıcı kimliği geçerli bir Guid olmalı.");
            }

            return await tekrar.CalistirAsync(kullanici, anahtar, "gun-yaptim", new { tarih, girdi },
                () => islemler.YaptimAsync(gun, parca.Onek, parca.Deger, kimlik, girdi.Geri, BildirimEndpoints.KullaniciId(kullanici), ct), CancellationToken.None);
        });

        // Carry an item to the next day: a plan item (the brain's devret), a task (an item for it tomorrow), a reminder (snoozed to tomorrow).
        girisli.MapPost("/devret", async (string tarih, DevretGirdisi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
            TekrarGuvenligi tekrar, GunIslemleri islemler, TimeProvider saat, CancellationToken ct) =>
        {
            if (GunCoz(tarih, saat) is not { } gun)
                return TarihHatasi;

            var kimlik = girdi.Kimlik!.Trim();
            if (Ayir(kimlik) is not { } parca)
                return Sorun("kimlik", "Kimlik m:<madde>, g:<görev> ya da h:<hatırlatıcı> biçiminde olmalı.");

            switch (parca.Onek)
            {
                case EtkinlikOneki:
                    return Sorun("kimlik", "Takvim etkinliği ertelenemez.");
                case PlanOneki or GorevOneki when !IzinVar(kullanici, BeyinPolicies.PlanYaz):
                case HatirlaticiOneki when !IzinVar(kullanici, HatirlaticiPolicies.Yaz):
                    return Yasak();
                case HatirlaticiOneki when !Guid.TryParse(parca.Deger, out _):
                    return Sorun("kimlik", "Hatırlatıcı kimliği geçerli bir Guid olmalı.");
            }

            return await tekrar.CalistirAsync(kullanici, anahtar, "gun-devret", new { tarih, girdi },
                () => islemler.DevretAsync(gun, parca.Onek, parca.Deger, kimlik, BildirimEndpoints.KullaniciId(kullanici), ct), CancellationToken.None);
        });

        // "Bırak" on a leftover of yesterday: nothing goes to the brain, the item just leaves today's list. Repeating it changes nothing.
        girisli.MapPost("/dunden/{maddeId}/birak", async (string tarih, string maddeId, ClaimsPrincipal kullanici, AppDbContext db, TimeProvider saat, CancellationToken ct) =>
        {
            if (GunCoz(tarih, saat) is not { } gun)
                return TarihHatasi;
            if (!IzinVar(kullanici, BeyinPolicies.PlanYaz))
                return Yasak();
            if (!BeyinYazma.MaddeKimligiGecerli(maddeId))
                return Sorun("maddeId", "Madde, kalıcı kimliğiyle (ör. a3f09c) verilmeli.");
            if (BildirimEndpoints.KullaniciId(kullanici) is not { } kullaniciId)
                return Results.Unauthorized();

            var temiz = maddeId.Trim();
            if (!await db.BirakilanMaddeler.AnyAsync(b => b.Tarih == gun && b.MaddeId == temiz && b.KullaniciId == kullaniciId, ct))
            {
                db.BirakilanMaddeler.Add(new BirakilanMadde { Tarih = gun, MaddeId = temiz, KullaniciId = kullaniciId, BirakmaAni = saat.GetUtcNow() });
                try
                {
                    await db.SaveChangesAsync(ct);
                }
                catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
                {
                    // Two requests at once: the other one wrote it, which is what was asked.
                }
            }

            return Results.Ok(new BirakildiDto(gun, temiz, true));
        });

        // A new item, and a reminder for it when the body has one. The reminder part is checked before anything is written.
        girisli.MapPost("/ogeler", async (string tarih, YeniOgeGirdisi girdi, [FromHeader(Name = Anahtar)] string? anahtar, ClaimsPrincipal kullanici,
            TekrarGuvenligi tekrar, GunIslemleri islemler, TimeProvider saat, CancellationToken ct) =>
        {
            if (GunCoz(tarih, saat) is not { } gun)
                return TarihHatasi;
            if (!IzinVar(kullanici, BeyinPolicies.PlanYaz) || (girdi.Hatirlatici is not null && !IzinVar(kullanici, HatirlaticiPolicies.Yaz)))
                return Yasak();

            return await tekrar.CalistirAsync(kullanici, anahtar, "gun-oge-ekle", new { tarih, girdi },
                () => islemler.OgeEkleAsync(gun, girdi, BildirimEndpoints.KullaniciId(kullanici), ct), CancellationToken.None);
        });

        // The reminder of an item: one per item. POST sets it up, PUT changes it, DELETE takes it away.
        var hatirlatici = app.MapGroup("/api/gun/{tarih}/ogeler/{kimlik}/hatirlatici").WithTags("Gün")
            .RequireAuthorization(HatirlaticiPolicies.Yaz);

        hatirlatici.MapPost("/", async (string tarih, string kimlik, OgeHatirlaticiDto dto, GunIslemleri islemler, GunGorunumuServisi servis, TimeProvider saat, ClaimsPrincipal kullanici, CancellationToken ct) =>
        {
            if (GunCoz(tarih, saat) is not { } gun)
                return TarihHatasi;
            if (OgeKimligi(kimlik) is not { } parca)
                return Sorun("kimlik", "Kimlik m:<madde> ya da g:<görev> biçiminde olmalı.");

            return await islemler.HatirlaticiKurAsync(gun, kimlik, parca, dto, BildirimEndpoints.KullaniciId(kullanici), ct);
        });

        hatirlatici.MapPut("/", async (string tarih, string kimlik, OgeHatirlaticiDto dto, GunIslemleri islemler, TimeProvider saat, CancellationToken ct) =>
        {
            if (GunCoz(tarih, saat) is not { } gun)
                return TarihHatasi;
            if (OgeKimligi(kimlik) is not { } parca)
                return Sorun("kimlik", "Kimlik m:<madde> ya da g:<görev> biçiminde olmalı.");

            return await islemler.HatirlaticiDegistirAsync(gun, parca, dto, ct);
        });

        hatirlatici.MapDelete("/", async (string tarih, string kimlik, GunIslemleri islemler, TimeProvider saat, CancellationToken ct) =>
        {
            if (GunCoz(tarih, saat) is not { } gun)
                return TarihHatasi;
            if (OgeKimligi(kimlik) is not { } parca)
                return Sorun("kimlik", "Kimlik m:<madde> ya da g:<görev> biçiminde olmalı.");

            return await islemler.HatirlaticiKaldirAsync(gun, parca, ct);
        });
    }

    private static readonly IResult TarihHatasi = Sorun("tarih", "Tarih yyyy-MM-dd biçiminde ya da bugun olmalı.");

    private static IResult Yasak() =>
        Results.Problem(title: "Yetki yok", detail: "Bu işlem için gereken izin bu hesapta açık değil.", statusCode: StatusCodes.Status403Forbidden);

    // `bugun` (by the 05:00 rule) or yyyy-MM-dd.
    internal static DateOnly? GunCoz(string? tarih, TimeProvider saat)
    {
        if (tarih == "bugun")
            return GunSiniri.Bugun(saat.GetUtcNow());

        return DateOnly.TryParseExact(tarih, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun) && gun.Year is >= 2000 and <= 2100
            ? gun
            : null;
    }

    internal static bool IzinVar(ClaimsPrincipal kullanici, string izin) =>
        kullanici.IsInRole(SeedData.OwnerRole) || kullanici.HasClaim(AliskanlikPolicies.IzinClaim, izin);

    public record KimlikParcasi(char Onek, string Deger);

    // "m:a3f09c" -> ('m', "a3f09c"). Null when it is not a typed id.
    internal static KimlikParcasi? Ayir(string kimlik) =>
        kimlik.Length > 2 && kimlik[1] == ':' && kimlik[0] is PlanOneki or GorevOneki or HatirlaticiOneki or EtkinlikOneki
            ? new KimlikParcasi(kimlik[0], kimlik[2..])
            : null;

    // The id of an item a reminder can be set on: a plan item or a task.
    internal static KimlikParcasi? OgeKimligi(string kimlik) => Ayir(kimlik) is { Onek: PlanOneki or GorevOneki } parca ? parca : null;
}
