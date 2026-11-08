using System.ComponentModel.DataAnnotations;
using System.Linq.Expressions;
using System.Security.Claims;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Yonetim;

public static class YonetimPolicies
{
    // Only the Sahip role, with a bearer token (the mobile app and curl).
    public const string Sahip = "yonetim";
}

public record IzinDto(string Izin, string Aciklama, bool Acik);

public class IzinYazDto
{
    [Required(ErrorMessage = "Acik zorunlu (true ya da false).")]
    public bool? Acik { get; set; }
}

public class AsistanSifreYazDto
{
    [Required(ErrorMessage = "Yeni şifre zorunlu.")]
    public string? YeniSifre { get; set; }
}

// Where a capture is on its way to the brain.
public enum GonderimDurumu
{
    // Waits for its turn (the edit delay has not passed, or the brain is off).
    Bekliyor,
    // Taken by the sender a moment ago.
    Gonderiliyor,
    // The last try failed and wrote nothing; the sender tries again by itself.
    Hatali,
    // Taken a while ago and never finished (a crash or a timeout): the card may already exist, only a retry by hand moves it.
    Takili,
    // BeyneGitti or Islendi.
    Tamam,
}

public record GonderimDto(
    Guid Id, string? Metin, bool FotografVar, string? Hedef, YakalamaDurumu Durum, GonderimDurumu Gonderim,
    DateTimeOffset YakalandiAt, DateTimeOffset GuncellendiAt, int DenemeSayisi, DateTimeOffset? SonDenemeAt,
    DateTimeOffset? GonderimBasladiAt, string? SonHata);

// What the management screens do. The /api/yonetim endpoints and the Razor page both call these, so a rule lives in one place.
public static class YonetimIslemleri
{
    // Permissions

    // The Asistan is the one account in the Asistan role (seeded at startup).
    private static async Task<IdentityUser<Guid>> AsistanAsync(UserManager<IdentityUser<Guid>> kullanicilar) =>
        (await kullanicilar.GetUsersInRoleAsync(SeedData.AssistantRole)).FirstOrDefault()
        ?? throw new InvalidOperationException("There is no account in the Asistan role.");

    public static async Task<List<IzinDto>> IzinleriGetirAsync(UserManager<IdentityUser<Guid>> kullanicilar)
    {
        var acik = (await kullanicilar.GetClaimsAsync(await AsistanAsync(kullanicilar)))
            .Where(c => c.Type == AliskanlikPolicies.IzinClaim).Select(c => c.Value).ToHashSet();
        return Izinler.Tumu.Select(i => new IzinDto(i.Ad, i.Aciklama, acik.Contains(i.Ad))).ToList();
    }

    // No security stamp change here: the API reads the claims from the database on every request, so the
    // very next request of the Asistan sees the change, and the Asistan stays signed in.
    public static async Task IzinAyarlaAsync(UserManager<IdentityUser<Guid>> kullanicilar, string izin, bool acik)
    {
        if (!Izinler.Gecerli(izin))
            throw new ArgumentException("Unknown permission.", nameof(izin));

        var asistan = await AsistanAsync(kullanicilar);
        var claim = new Claim(AliskanlikPolicies.IzinClaim, izin);
        var zatenVar = (await kullanicilar.GetClaimsAsync(asistan)).Any(c => c.Type == claim.Type && c.Value == claim.Value);

        // Add only when missing, so the table never holds the same permission twice.
        if (acik && !zatenVar)
            Basarili(await kullanicilar.AddClaimAsync(asistan, claim));
        else if (!acik && zatenVar)
            Basarili(await kullanicilar.RemoveClaimAsync(asistan, claim));
    }

    // One choice of a card (Kapalı / Okur / Okur ve yazar) sets every permission of the group: those it needs open, the rest closed.
    // `Ozel` is only a reading of the current state and cannot be chosen.
    public static async Task GrupAyarlaAsync(UserManager<IdentityUser<Guid>> kullanicilar, IzinGruplari.Grup grup, GrupKipi kip)
    {
        if (kip == GrupKipi.Ozel)
            throw new ArgumentException("Ozel cannot be set.", nameof(kip));

        var acilacak = IzinGruplari.AcilacakIzinler(grup, kip);
        foreach (var izin in grup.Hepsi)
            await IzinAyarlaAsync(kullanicilar, izin, acilacak.Contains(izin));
    }

    // The new stamp makes /api/hesap/refresh refuse the Asistan's refresh token. The access token already issued
    // keeps working until it expires (at most 1 hour); permissions are cut at once by IzinAyarlaAsync instead.
    public static async Task AsistaninOturumlariniKapatAsync(UserManager<IdentityUser<Guid>> kullanicilar) =>
        Basarili(await kullanicilar.UpdateSecurityStampAsync(await AsistanAsync(kullanicilar)));

    // Sets a new password for the Asistan (the Sahip does not need the old one) under Identity's password rules.
    // A refused password changes nothing: the reset validates before it writes. On success the Asistan's sessions
    // are closed the same way as the button above, so a phone that still holds the old password is signed out.
    public static async Task<IdentityResult> AsistaninSifresiniYenileAsync(UserManager<IdentityUser<Guid>> kullanicilar, string yeniSifre)
    {
        var asistan = await AsistanAsync(kullanicilar);
        var sonuc = await kullanicilar.ResetPasswordAsync(asistan, await kullanicilar.GeneratePasswordResetTokenAsync(asistan), yeniSifre);
        if (sonuc.Succeeded)
            await AsistaninOturumlariniKapatAsync(kullanicilar);

        return sonuc;
    }

    private static void Basarili(IdentityResult sonuc)
    {
        if (!sonuc.Succeeded)
            throw new InvalidOperationException(string.Join("; ", sonuc.Errors.Select(e => e.Description)));
    }

    // Brain and sending queue

    // Captures that need a look: the last send failed, or the sender took them long ago and never finished.
    private static Expression<Func<Yakalama, bool>> Ilgilenilecek(DateTimeOffset simdi)
    {
        var sinir = simdi - YakalamaGonderimi.ElKoymaSuresi;
        return y => y.SonHata != null
            || (y.Durum == YakalamaDurumu.Bekliyor && y.GonderimBasladiAt != null && y.GonderimBasladiAt <= sinir);
    }

    public static async Task<BeyinDurumDto> BeyinDurumuAsync(AppDbContext db, BeyinIstemcisi beyin, BeyinAyari ayar, DateTimeOffset simdi, CancellationToken ct)
    {
        var bekleyen = await db.Yakalamalar.CountAsync(y => y.Durum == YakalamaDurumu.Bekliyor, ct);
        var ilgi = await db.Yakalamalar.Where(Ilgilenilecek(simdi)).CountAsync(ct);
        return new BeyinDurumDto(beyin.Bagli, BeyinOkuma.VaultAdi(beyin, ayar), bekleyen, ilgi);
    }

    // Every capture, the ones that need a look first, then the newest. `yalnizIlgilenilecek` keeps only the first group.
    public static async Task<List<GonderimDto>> KuyrukAsync(AppDbContext db, DateTimeOffset simdi, bool yalnizIlgilenilecek, CancellationToken ct)
    {
        var ilgi = Ilgilenilecek(simdi);
        var sorgu = db.Yakalamalar.AsNoTracking().AsQueryable();
        if (yalnizIlgilenilecek)
            sorgu = sorgu.Where(ilgi);

        var liste = await sorgu
            .OrderByDescending(ilgi)
            .ThenByDescending(y => y.YakalandiAt).ThenByDescending(y => y.Id)
            .ToListAsync(ct);
        return liste.Select(y => GonderimDtoYap(y, simdi)).ToList();
    }

    public static GonderimDurumu GonderimDurumuBul(Yakalama y, DateTimeOffset simdi)
    {
        if (y.Durum != YakalamaDurumu.Bekliyor)
            return GonderimDurumu.Tamam;
        if (y.GonderimBasladiAt is not null)
            return YakalamaGonderimi.Gonderiliyor(y, simdi) ? GonderimDurumu.Gonderiliyor : GonderimDurumu.Takili;
        return y.SonHata is not null ? GonderimDurumu.Hatali : GonderimDurumu.Bekliyor;
    }

    private static GonderimDto GonderimDtoYap(Yakalama y, DateTimeOffset simdi) => new(
        y.Id, y.Metin, y.FotografId is not null, y.Hedef, y.Durum, GonderimDurumuBul(y, simdi), y.YakalandiAt, y.GuncellendiAt,
        y.DenemeSayisi, y.SonDenemeAt, y.GonderimBasladiAt, y.SonHata);

    // Gives a capture back to the sender: clears the claim and the error. One conditional UPDATE, so it cannot
    // undo a send that is running right now (409), and a capture that already left Bekliyor is not touched (409).
    // Null: there is no such capture. Careful with a "Takili" one: its card may already be in the brain.
    public static async Task<Sonuc?> YenidenDeneAsync(AppDbContext db, Guid id, DateTimeOffset simdi, CancellationToken ct)
    {
        var sinir = simdi - YakalamaGonderimi.ElKoymaSuresi;
        var degisen = await db.Yakalamalar
            .Where(y => y.Id == id && y.Durum == YakalamaDurumu.Bekliyor && (y.GonderimBasladiAt == null || y.GonderimBasladiAt <= sinir))
            .ExecuteUpdateAsync(s => s
                .SetProperty(y => y.GonderimBasladiAt, (DateTimeOffset?)null)
                .SetProperty(y => y.DenemeSayisi, 0)
                .SetProperty(y => y.SonDenemeAt, (DateTimeOffset?)null)
                .SetProperty(y => y.SonHata, (string?)null), ct);
        if (degisen == 1)
            return Sonuc.Tamam;

        var durum = await db.Yakalamalar.AsNoTracking().Where(y => y.Id == id).Select(y => (YakalamaDurumu?)y.Durum).SingleOrDefaultAsync(ct);
        return durum switch
        {
            null => null,
            YakalamaDurumu.Bekliyor => Sonuc.Catisma(YakalamaIslemleri.GonderiliyorMesaji),
            _ => Sonuc.Catisma("Yalnız bekleyen yakalama yeniden denenebilir."),
        };
    }

    public static async Task<GonderimDto?> GonderimGetirAsync(AppDbContext db, Guid id, DateTimeOffset simdi, CancellationToken ct)
    {
        var y = await db.Yakalamalar.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        return y is null ? null : GonderimDtoYap(y, simdi);
    }
}
