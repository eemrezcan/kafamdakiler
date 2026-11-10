using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Hatirlaticilar;

// What a chain step did: the ids of what closed along the way ("h:<guid>", "m:<id>", "g:<slug>") and, when a step did not go through, a
// fixed sentence for the person (the log has the rest).
public record ZincirSonucu(List<string> Kimlikler, string? Hata)
{
    public static ZincirSonucu Bos => new([], null);
}

// The chain between a task (or a plan item) and the reminder tied to it (K-0024, madde 3), in both directions. It lives here, apart from
// the endpoints, so every way of finishing an item goes through the same rules: the day plan and task endpoints, "yaptım" of the day
// view, "yaptım" of a reminder (the app, the notification button) and the approval queue's task closing.
//
// Item or task done -> the reminder tied to it is done too. A task finished (by any route) closes every reminder tied to it for good
// (`Tamam`, a repeating one too: nothing is left to remind of). A plan item ticked counts the turn of the reminders tied to that item
// (a one-off closes, a repeating one moves to its next turn: the same progress as its own "yaptım"). Reminder done -> the plan item is
// ticked, or the task finished when the reminder has no item. A repeating reminder only ticks the item of its own day and never finishes
// the task. A failed brain step never undoes the reminder's side.
public static class HatirlaticiZinciri
{
    // The plan reference as the brain takes it: a permanent id, or `g:<task>` for an item that exists only as a task.
    // Returns the item id (null for a task reference) and the task slug (null for an item id).
    public static (string? MaddeId, string? Gorev) MaddeBagi(string madde) =>
        madde.StartsWith("g:", StringComparison.Ordinal) ? (null, madde[2..]) : (madde, null);

    // Items -> reminders. Changes (in the context; the caller saves) every open reminder tied to what was done. `gorevKimligi` is a task that
    // is finished: its reminders close for good. `maddeId` is a plan item of that day that was ticked: its reminders count the turn.
    // `haric` is the reminder that started the chain, which is already done.
    public static async Task<List<string>> YapildiAsync(
        AppDbContext db, string? maddeId, DateOnly? maddeTarihi, string? gorevKimligi, TimeOnly varsayilan, DateTimeOffset simdi,
        CancellationToken ct, Guid? haric = null)
    {
        if (maddeId is null && gorevKimligi is null)
            return [];

        var haricId = haric ?? Guid.Empty;
        var adaylar = await db.Hatirlaticilar
            .Where(h => h.Durum == HatirlaticiDurumu.Acik && h.Id != haricId
                && ((maddeId != null && h.MaddeId == maddeId && h.MaddeTarihi == maddeTarihi) || (gorevKimligi != null && h.GorevKimligi == gorevKimligi)))
            .OrderBy(h => h.Id).ToListAsync(ct);

        var kapanan = new List<string>();
        foreach (var h in adaylar)
        {
            // The finished task wins: a reminder tied to it ends, even when it is also tied to the item that was ticked.
            var gorevBitti = gorevKimligi is not null && h.GorevKimligi == gorevKimligi;
            var sonuc = gorevBitti ? HatirlaticiIslemleri.Kapat(db, h, simdi) : HatirlaticiIslemleri.Yaptim(db, h, varsayilan, simdi);
            if (sonuc.Basarili)
                kapanan.Add($"h:{h.Id}");
        }

        return kapanan;
    }

    // The answer of `gun isaretle` as a chain start: the item (named as the request named it) and, when the brain closed the task with it,
    // the task. Returns the ids that closed, the task's included.
    public static async Task<ZincirSonucu> MaddeIsaretlendiAsync(
        AppDbContext db, DateOnly tarih, string madde, MaddeIsaretlendiDto dto, TimeOnly varsayilan, DateTimeOffset simdi, ILogger log,
        CancellationToken ct, Guid? haric = null)
    {
        try
        {
            var (maddeId, istenenGorev) = MaddeBagi(madde);
            var gorev = dto.GorevKapandi ? dto.Madde.Gorev ?? istenenGorev : istenenGorev;
            var kimlikler = await YapildiAsync(db, maddeId, tarih, gorev, varsayilan, simdi, ct, haric);
            if (dto.GorevKapandi && gorev is not null)
                kimlikler.Insert(0, $"g:{gorev}");
            await db.SaveChangesAsync(ct);
            return new ZincirSonucu(kimlikler, null);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogError(e, "Closing the reminders of a ticked item failed (day {Tarih}, item {Madde})", tarih, madde);
            return new ZincirSonucu([], "Bağlı hatırlatıcı kapatılamadı.");
        }
    }

    public static async Task<ZincirSonucu> GorevBitirildiAsync(
        AppDbContext db, string kimlik, TimeOnly varsayilan, DateTimeOffset simdi, ILogger log, CancellationToken ct, Guid? haric = null)
    {
        try
        {
            var kimlikler = await YapildiAsync(db, null, null, kimlik, varsayilan, simdi, ct, haric);
            await db.SaveChangesAsync(ct);
            return new ZincirSonucu(kimlikler, null);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogError(e, "Closing the reminders of a finished task failed (task {Kimlik})", kimlik);
            return new ZincirSonucu([], "Bağlı hatırlatıcı kapatılamadı.");
        }
    }
}

// Reminders -> items (it needs the brain, so it is a service). The reminder has already been marked done by the caller.
public class HatirlaticiZinciriServisi(
    AppDbContext db, BeyinIstemcisi beyin, HatirlaticiAyari ayar, TimeProvider saat, ILogger<HatirlaticiZinciriServisi> log)
{
    // `hedefAn` is the moment of the turn that was done (read before the reminder moved on): it names the day of a repeating reminder's turn.
    public async Task<ZincirSonucu> HatirlaticiYapildiAsync(Hatirlatici h, DateTimeOffset hedefAn, CancellationToken ct)
    {
        if (h.MaddeId is null && h.GorevKimligi is null)
            return ZincirSonucu.Bos;

        var tekrarli = h.Tekrar != Tekrar.Yok;
        // A repeating reminder ticks the item only on the day the item belongs to, and never finishes the task.
        if (h.MaddeId is null && tekrarli)
            return ZincirSonucu.Bos;
        if (h.MaddeId is not null && tekrarli && GunSiniri.Bugun(hedefAn) != h.MaddeTarihi)
            return ZincirSonucu.Bos;

        if (!beyin.Bagli)
            return new ZincirSonucu([], "Beyin bağlı değil; bağlı iş işaretlenemedi.");

        try
        {
            var simdi = saat.GetUtcNow();
            if (h.MaddeId is not null)
            {
                var yanit = await BeyinYazma.MaddeIsaretle(
                    $"{h.MaddeTarihi!.Value:yyyy-MM-dd}", new MaddeIsaretleGirdi(h.MaddeId), beyin, log, ct);
                if (!yanit.Basarili)
                    return new ZincirSonucu([], Hata(yanit, "Bağlı madde işaretlenemedi"));

                var dto = (MaddeIsaretlendiDto)yanit.Veri!;
                var zincir = await HatirlaticiZinciri.MaddeIsaretlendiAsync(
                    db, h.MaddeTarihi.Value, h.MaddeId, dto, ayar.VarsayilanSaat, simdi, log, ct, haric: h.Id);
                zincir.Kimlikler.Insert(0, $"m:{h.MaddeId}");
                return zincir;
            }

            var bitti = await BeyinYazma.GorevBitir(h.GorevKimligi!, beyin, log, saat, ct);
            if (!bitti.Basarili)
                return new ZincirSonucu([], Hata(bitti, "Bağlı görev bitirilemedi"));

            var digerleri = await HatirlaticiZinciri.GorevBitirildiAsync(db, h.GorevKimligi!, ayar.VarsayilanSaat, simdi, log, ct, haric: h.Id);
            digerleri.Kimlikler.Insert(0, $"g:{h.GorevKimligi}");
            return digerleri;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            log.LogError(e, "The chain step after a reminder was done failed ({Id})", h.Id);
            return new ZincirSonucu([], "Bağlı iş işaretlenirken beklenmeyen bir hata oldu.");
        }
    }

    // A fixed sentence: the brain's own message can hold paths and went to the log already. An uncertain answer says so.
    private static string Hata(YazmaYaniti yanit, string baslangic) => yanit.Tur == YazmaTuru.Belirsiz
        ? $"{baslangic}: beyin zamanında cevap vermedi, yazılmış olabilir. Günün planına bak."
        : $"{baslangic}: {yanit.Baslik ?? "beyin kabul etmedi"}.";
}
