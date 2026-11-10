using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The forward half of the chain (an item or task is done, so the reminder tied to it is done too) at the level of the database, and the
// approval queue's task closing, which has to run it too: all the ways of finishing a task close its reminders (K-0024, sözleşme §1.2).
public sealed class HatirlaticiZinciriTests(UygulamaFabrikasi uygulama) : IClassFixture<UygulamaFabrikasi>
{
    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static readonly DateTimeOffset Simdi = new DateTimeOffset(2026, 11, 9, 7, 0, 0, TimeSpan.FromHours(3)).ToUniversalTime();
    private static readonly DateOnly Bugun = new(2026, 11, 9);
    private static readonly TimeOnly Varsayilan = new(9, 0);

    private async Task<Hatirlatici> EkleAsync(
        string baslik, Tekrar tekrar = Tekrar.Yok, string? maddeId = null, DateOnly? maddeTarihi = null, string? gorev = null,
        HatirlaticiDurumu durum = HatirlaticiDurumu.Acik)
    {
        var h = new Hatirlatici { Baslik = baslik, Gun = Bugun, Saat = new TimeOnly(14, 0), Tekrar = tekrar, MaddeId = maddeId, MaddeTarihi = maddeTarihi, GorevKimligi = gorev, Durum = durum };
        h.SonrakiAn = HatirlaticiHesap.Sonraki(tekrar, Bugun, new TimeOnly(14, 0), Simdi);
        await using var db = uygulama.YeniDb();
        db.Hatirlaticilar.Add(h);
        await db.SaveChangesAsync(Ct);
        return h;
    }

    private async Task TemizleAsync()
    {
        await using var db = uygulama.YeniDb();
        await db.HatirlaticiOlaylari.ExecuteDeleteAsync(Ct);
        await db.Hatirlaticilar.ExecuteDeleteAsync(Ct);
    }

    private async Task<Hatirlatici> OkuAsync(Guid id)
    {
        await using var db = uygulama.YeniDb();
        return await db.Hatirlaticilar.AsNoTracking().SingleAsync(h => h.Id == id, Ct);
    }

    [Fact]
    public async Task YapildiAsync_ClosesAnOpenOneOff_AndAnItemIsNamedByItsIdAndItsDay()
    {
        await TemizleAsync();
        var maddeli = await EkleAsync("madde", maddeId: "a3f09c", maddeTarihi: Bugun);
        var baskaGun = await EkleAsync("başka gün", maddeId: "a3f09c", maddeTarihi: Bugun.AddDays(-1));
        var baskaMadde = await EkleAsync("başka madde", maddeId: "b4e1d2", maddeTarihi: Bugun);
        var gorevli = await EkleAsync("görev", gorev: "uye-girisi");
        var kapali = await EkleAsync("kapalı", maddeId: "a3f09c", maddeTarihi: Bugun, durum: HatirlaticiDurumu.Tamam);
        var arsiv = await EkleAsync("arşiv", gorev: "uye-girisi", durum: HatirlaticiDurumu.Arsiv);

        await using var db = uygulama.YeniDb();
        var kapananlar = await HatirlaticiZinciri.YapildiAsync(db, "a3f09c", Bugun, "uye-girisi", Varsayilan, Simdi, Ct);
        await db.SaveChangesAsync(Ct);

        Assert.Equivalent(new[] { $"h:{maddeli.Id}", $"h:{gorevli.Id}" }, kapananlar);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await OkuAsync(maddeli.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await OkuAsync(gorevli.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Acik, (await OkuAsync(baskaGun.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Acik, (await OkuAsync(baskaMadde.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Tamam, (await OkuAsync(kapali.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Arsiv, (await OkuAsync(arsiv.Id)).Durum);
        // Counted once each in the weekly summary, and none for the ones that were not open.
        Assert.Equal(2, await db.HatirlaticiOlaylari.CountAsync(o => o.Tur == HatirlaticiOlayTuru.Yapildi, Ct));
    }

    [Fact]
    public async Task YapildiAsync_ARepeatingOneCountsTheTurn_NothingTiedMeansNothingToDo_AndTheStarterIsLeftOut()
    {
        await TemizleAsync();
        var gunluk = await EkleAsync("her gün", Tekrar.Gunluk, gorev: "uye-girisi");
        var baslatan = await EkleAsync("başlatan", gorev: "uye-girisi");
        var once = await OkuAsync(gunluk.Id);

        await using var db = uygulama.YeniDb();
        Assert.Empty(await HatirlaticiZinciri.YapildiAsync(db, null, null, null, Varsayilan, Simdi, Ct));
        var kapananlar = await HatirlaticiZinciri.YapildiAsync(db, null, null, "uye-girisi", Varsayilan, Simdi, Ct, haric: baslatan.Id);
        await db.SaveChangesAsync(Ct);

        Assert.Equal([$"h:{gunluk.Id}"], kapananlar);
        var sonra = await OkuAsync(gunluk.Id);
        Assert.Equal(HatirlaticiDurumu.Acik, sonra.Durum);
        Assert.Equal(once.SonrakiAn.AddDays(1), sonra.SonrakiAn);
        Assert.Equal(HatirlaticiDurumu.Acik, (await OkuAsync(baslatan.Id)).Durum);
    }

    [Theory]
    [InlineData("a3f09c", "a3f09c", null)]
    [InlineData("g:uye-girisi", null, "uye-girisi")]
    public void MaddeBagi_NamesAnItemByItsIdAndATaskOnlyItemByItsSlug(string madde, string? maddeId, string? gorev) =>
        Assert.Equal((maddeId, gorev), HatirlaticiZinciri.MaddeBagi(madde));

    [Fact]
    public async Task GorevKapat_TheApprovalQueuesTaskClosingClosesTheRemindersOfThatTask()
    {
        await TemizleAsync();
        using var beyin = new SahteBeyin("ok");
        var gorevli = await EkleAsync("görev", gorev: "uye-girisi");
        var baska = await EkleAsync("başka görev", gorev: "baska-gorev");
        var tur = new GorevKapatTuru(beyin.Istemci(), NullLogger<GorevKapatTuru>.Instance, new HatirlaticiAyari());
        var yuk = JsonSerializer.SerializeToElement(new { yol = "projects/kitap-kulubu/gorevler/uye-girisi.md", kanit = "onay:uygulama-2026-11-09" });

        await using var db = uygulama.YeniDb();
        await tur.UygulaAsync(yuk, new EylemBaglami(db, Simdi), Ct);
        // The queue saves the context with the action; the kind itself only changes it.
        await db.SaveChangesAsync(Ct);

        Assert.Equal(HatirlaticiDurumu.Tamam, (await OkuAsync(gorevli.Id)).Durum);
        Assert.Equal(HatirlaticiDurumu.Acik, (await OkuAsync(baska.Id)).Durum);
        var gorevBitir = beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Single(a => a[0] == "gorev" && a[1] == "bitir");
        Assert.Contains("--kanit=onay:uygulama-2026-11-09", gorevBitir);
    }
}
