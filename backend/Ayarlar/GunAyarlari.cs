using System.ComponentModel.DataAnnotations;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Yonetim;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Ayarlar;

// The day capacity the person set (K-0024): how many minutes of planned work fit in a weekday and in a weekend day. One row for the
// whole app (it is a one-person app: the Asistan reads the Sahip's setting), always row 1. Without a row the `Gun:KapasiteSaat`
// setting decides, for both kinds of day.
public class GunAyarlari
{
    public int Id { get; set; } = 1;
    public int HaftaIciDk { get; set; }
    public int HaftaSonuDk { get; set; }
}

public class GunAyarlariYazDto
{
    [Required(ErrorMessage = "Hafta içi kapasitesi zorunlu.")]
    [Range(1, 1440, ErrorMessage = "Hafta içi kapasitesi 1 ile 1440 dakika arasında olmalı.")]
    public int? HaftaIciDk { get; set; }

    [Required(ErrorMessage = "Hafta sonu kapasitesi zorunlu.")]
    [Range(1, 1440, ErrorMessage = "Hafta sonu kapasitesi 1 ile 1440 dakika arasında olmalı.")]
    public int? HaftaSonuDk { get; set; }
}

public record GunAyarlariDto(int HaftaIciDk, int HaftaSonuDk);

// The one place that answers "how much fits in this day". The brain's day warning, the timeline and the briefing all ask here.
public static class GunKapasitesi
{
    public static bool HaftaSonu(DateOnly gun) => gun.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday;

    public static async Task<GunAyarlariDto> AyarAsync(AppDbContext db, GunAyari yedek, CancellationToken ct)
    {
        var satir = await db.GunAyarlari.AsNoTracking().FirstOrDefaultAsync(ct);
        return satir is null ? new GunAyarlariDto(yedek.KapasiteDk, yedek.KapasiteDk) : new GunAyarlariDto(satir.HaftaIciDk, satir.HaftaSonuDk);
    }

    public static async Task<int> DkAsync(AppDbContext db, GunAyari yedek, DateOnly gun, CancellationToken ct)
    {
        var ayar = await AyarAsync(db, yedek, ct);
        return HaftaSonu(gun) ? ayar.HaftaSonuDk : ayar.HaftaIciDk;
    }

    // For the endpoints that take the date as text: null when it is not a date (the read itself answers 400 then).
    public static async Task<int?> DkAsync(AppDbContext db, GunAyari yedek, string? tarih, CancellationToken ct) =>
        DateOnly.TryParseExact(tarih, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out var gun)
            ? await DkAsync(db, yedek, gun, ct)
            : null;
}

public static class AyarEndpoints
{
    public static void MapAyarEndpoints(this IEndpointRouteBuilder app)
    {
        var oku = app.MapGroup("/api/ayarlar").WithTags("Ayarlar").RequireAuthorization(Takvim.TakvimPolicies.Oku);
        var sahip = app.MapGroup("/api/ayarlar").WithTags("Ayarlar").RequireAuthorization(YonetimPolicies.Sahip);

        oku.MapGet("/gun", async (AppDbContext db, GunAyari yedek, CancellationToken ct) =>
            Results.Ok(await GunKapasitesi.AyarAsync(db, yedek, ct)));

        sahip.MapPut("/gun", async (GunAyarlariYazDto dto, AppDbContext db, GunAyari yedek, CancellationToken ct) =>
        {
            var satir = await db.GunAyarlari.FirstOrDefaultAsync(ct);
            if (satir is null)
            {
                satir = new GunAyarlari();
                db.GunAyarlari.Add(satir);
            }

            satir.HaftaIciDk = dto.HaftaIciDk!.Value;
            satir.HaftaSonuDk = dto.HaftaSonuDk!.Value;
            await db.SaveChangesAsync(ct);
            return Results.Ok(await GunKapasitesi.AyarAsync(db, yedek, ct));
        });
    }
}
