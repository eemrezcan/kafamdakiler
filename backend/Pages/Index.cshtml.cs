using System.Globalization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.Yapilacaklar;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Kafamdakiler.Pages;

// The home page, "Bugün" (K-0024): the one view of a day (GunGorunumuServisi, the same as GET /api/gun/{tarih}) with its writes
// (GunSayfasi). On top the assistant's short summary and the weight of the day, then what yesterday left, the habits and the one list of
// plan items, tasks, reminders and calendar events with one "yaptım". No date means today by the brain's own day-turn rule (05:00);
// another day is just that day's list. The habits (a compact strip) belong to today's page only; they do not depend on the plan, and a failing
// read only drops them. The briefing lives in the Asistan stream (Bugün keeps only the assistant's one-line summary).
public class IndexModel(
    BeyinIstemcisi beyin, ILogger<BeyinIstemcisi> gunluk, GunGorunumuServisi gunServisi, GunIslemleri islemler, AppDbContext db,
    HatirlaticiAyari hatirlaticiAyari, TimeProvider saat)
    : GunSayfasi(beyin, gunluk, gunServisi, islemler, db, hatirlaticiAyari, saat)
{
    // The day asked for; always a real date once the page is shown.
    public DateOnly Tarih { get; private set; }

    // Set when the address held something that looks like a date but is not one (the page then answers 400 and asks nothing of the brain).
    public string? TarihHatasi { get; private set; }

    public bool BugunSayfasi => Tarih == Bugun;

    // The day as the day view builds it; null when it could not be built (the page then says so).
    public GunGorunumuDto? Gorunum { get; private set; }

    // Why the plan part is missing or incomplete, for the person: no brain here, or a brain that did not answer.
    public string? PlanUyarisi => Gorunum?.Kaynaklar.Plan switch
    {
        "yok" => "Beyin bağlı değil: bu makinede beyin ayarlı değil, günün planı gösterilemiyor. Hatırlatıcılar ve takvim etkinlikleri yine burada.",
        "okunamadi" => "Beyin cevabı anlaşılamadı: günün planı okunamadı, liste eksik olabilir. Biraz sonra tekrar dene.",
        _ => null,
    };

    // The project's title for a row ("Staj Hazırlığı", not "staj-hazirligi"); the id when the brain did not name it.
    public List<ProjeOzetDto> Projeler { get; private set; } = [];

    public string ProjeAdi(string kimlik) => Projeler.FirstOrDefault(p => p.Kimlik == kimlik)?.Baslik ?? kimlik;

    // The habits planned for today, as the same cards as the habits page (tick, −/+, "Nereye kadar geldin?" work here too).
    public List<Aliskanliklar.IndexModel.Kart> BugunkuAliskanliklar { get; private set; } = [];

    // Forms are offered for an open day only.
    public bool Yazilabilir => Gorunum is { Kapandi: false };

    public async Task<IActionResult> OnGetAsync(string? tarih, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(tarih))
            Tarih = Bugun;
        else if (DateOnly.TryParseExact(tarih, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var gun) && gun.Year is >= 2000 and <= 2100)
            Tarih = gun;
        else
        {
            // Shaped like a date (the route says so) but not a real one: a 400 page, the brain is not asked.
            Tarih = Bugun;
            TarihHatasi = "Tarih yyyy-MM-dd biçiminde ve gerçek bir gün olmalı.";
            Response.StatusCode = StatusCodes.Status400BadRequest;
            return Page();
        }

        try
        {
            Gorunum = TarihHatasi is null ? await GunServisi.GetirAsync(Tarih, KullaniciId, ct) : null;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The day view of the home page failed.");
        }

        if (Gorunum?.Kaynaklar.Plan == "tamam")
            Projeler = (await BeyinOkuma.ProjelerAl(Istemci, Gunluk, ct)).Veri ?? [];

        if (BugunSayfasi)
        {
            await AliskanliklariYukleAsync(ct);
        }

        return Page();
    }

    private async Task AliskanliklariYukleAsync(CancellationToken ct)
    {
        try
        {
            var liste = await Db.Aliskanliklar.Where(a => !a.Arsivlendi).OrderBy(a => a.Sira).ThenBy(a => a.CreatedAt).ToListAsync(ct);
            var dtolar = await AliskanlikEndpoints.DtoYapAsync(Db, liste, ct);
            var bugun = AliskanlikIslemleri.Bugun();
            for (var i = 0; i < liste.Count; i++)
            {
                if (!dtolar[i].Bugun.Planli)
                    continue;
                var gunler = await AliskanlikEndpoints.GunleriHesaplaAsync(Db, liste[i], bugun.AddDays(-6), bugun, ct);
                BugunkuAliskanliklar.Add(new Aliskanliklar.IndexModel.Kart(dtolar[i], gunler));
            }
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            Gunluk.LogError(e, "The habits of the home page failed.");
        }
    }

    // "Taşı" on a leftover of yesterday carries it to today in the brain.
    public async Task<IActionResult> OnPostSabahTasiAsync(string? madde) =>
        Don(await BeyinYazma.MaddeDevret($"{GunSiniri.Dun(Saat.GetUtcNow()):yyyy-MM-dd}", new MaddeDevretGirdi(madde), Istemci, Gunluk, CancellationToken.None),
            "Bugüne taşındı");

    // "Bırak" on a leftover: nothing goes to the brain, the item only leaves today's list. Same rows as POST /api/gun/{tarih}/dunden/{id}/birak
    // (so the phone and the web let go of the same things); repeating it changes nothing.
    public async Task<IActionResult> OnPostSabahBirakAsync(string? madde)
    {
        if (!BeyinYazma.MaddeKimligiGecerli(madde))
            return Reddet("Madde, kalıcı kimliğiyle verilmeli.");
        if (KullaniciId is not { } kullaniciId)
            return Challenge();

        var temiz = madde!.Trim();
        if (!await Db.BirakilanMaddeler.AnyAsync(b => b.Tarih == Bugun && b.MaddeId == temiz && b.KullaniciId == kullaniciId))
        {
            Db.BirakilanMaddeler.Add(new BirakilanMadde { Tarih = Bugun, MaddeId = temiz, KullaniciId = kullaniciId, BirakmaAni = Saat.GetUtcNow() });
            try
            {
                await Db.SaveChangesAsync();
            }
            catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
            {
                // Two requests at once: the other one wrote it, which is what was asked.
            }
        }

        return DonusSonucu();
    }
}
