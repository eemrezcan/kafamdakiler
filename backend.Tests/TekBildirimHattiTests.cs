using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Data;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Hatirlaticilar;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// A fake clone reader: what `git log` would have said per project.
public sealed class SahteKomitOkuyucu : IKomitOkuyucu
{
    public Dictionary<string, List<GitKomiti>> Komitler { get; } = [];

    public Task<IReadOnlyList<GitKomiti>> SonKomitlerAsync(string proje, CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<GitKomiti>>(Komitler.GetValueOrDefault(proje) ?? []);
}

// The one notification line (reminders and the brain's tasks) end to end on real PostgreSQL: the fake FCM sender, a fake beyin.py as a
// child process, a clock moved by hand. What must not pass silently: a reminder sent twice or never, a stale one that still arrives,
// a task closed without proof, a close that cannot be undone, a question asked again every day, a notification for someone who may
// not read it.
public sealed class TekBildirimHattiTests : IAsyncLifetime
{
    private const string Proje = "kitap-kulubu";
    private const string GorevYolu = "projects/kitap-kulubu/gorevler/mobil-gorunum-duzeltmeleri.md";
    private const string Kimlik = "mobil-gorunum-duzeltmeleri";
    private const string Baslik = "Mobil görünüm düzeltmeleri";
    private const string KartYolu = "projects/kitap-kulubu/oturumlar.md";

    private readonly TestVeritabani _vt = new();
    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahtePushGondericisi _push = new();
    private readonly SahteKomitOkuyucu _komitler = new();
    private readonly ElleSaat _saat = new(Ist(2026, 11, 9, 10, 0));
    private readonly string _anahtar = Path.Combine(Path.GetTempPath(), "kd-test-anahtar-" + Guid.NewGuid().ToString("N") + ".json");
    private readonly BildirimHattiAyari _ayar = new();
    private Guid _sahip;

    public async ValueTask InitializeAsync()
    {
        await _vt.InitializeAsync();
        await File.WriteAllTextAsync(_anahtar, "{}", Ct);
        _sahip = await KullaniciEkleAsync("sahip", "tok-sahip", sahip: true);
    }

    public async ValueTask DisposeAsync()
    {
        await _vt.DisposeAsync();
        _beyin.Dispose();
        if (File.Exists(_anahtar))
            File.Delete(_anahtar);
    }

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    private static DateTimeOffset Ist(int yil, int ay, int gun, int saat, int dakika) =>
        new DateTimeOffset(yil, ay, gun, saat, dakika, 0, TimeSpan.FromHours(3)).ToUniversalTime();

    // Setup

    private PushAyari PushAcik(bool acik = true) => new() { AnahtarDosyasi = acik ? _anahtar : "" };

    private BildirimServisi Servis(AppDbContext db, bool pushAcik = true) => new(db, PushAcik(pushAcik), _push, new PushDurumu(), _saat);

    private async Task<Guid> KullaniciEkleAsync(string ad, string token, bool sahip = false, params string[] izinler)
    {
        var kullanici = new IdentityUser<Guid> { Id = Guid.NewGuid(), UserName = ad, NormalizedUserName = ad.ToUpperInvariant() };
        _vt.Db.Users.Add(kullanici);
        if (sahip)
        {
            var rol = await _vt.Db.Roles.FirstOrDefaultAsync(r => r.Name == SeedData.OwnerRole, Ct);
            if (rol is null)
            {
                rol = new IdentityRole<Guid> { Id = Guid.NewGuid(), Name = SeedData.OwnerRole, NormalizedName = SeedData.OwnerRole.ToUpperInvariant() };
                _vt.Db.Roles.Add(rol);
            }

            _vt.Db.UserRoles.Add(new IdentityUserRole<Guid> { UserId = kullanici.Id, RoleId = rol.Id });
        }

        foreach (var izin in izinler)
            _vt.Db.UserClaims.Add(new IdentityUserClaim<Guid> { UserId = kullanici.Id, ClaimType = AliskanlikPolicies.IzinClaim, ClaimValue = izin });

        _vt.Db.BildirimCihazlari.Add(new BildirimCihazi { KullaniciId = kullanici.Id, Token = token, KayitAni = _saat.Simdi, GuncellemeAni = _saat.Simdi });
        await _vt.Db.SaveChangesAsync(Ct);
        return kullanici.Id;
    }

    private async Task<Hatirlatici> HatirlaticiEkleAsync(
        DateTimeOffset an, string baslik = "İlaç al", HatirlaticiDurumu durum = HatirlaticiDurumu.Acik, DateTimeOffset? erteleAn = null)
    {
        var h = new Hatirlatici
        {
            Baslik = baslik, Gun = DateOnly.FromDateTime(an.UtcDateTime), Tekrar = Tekrar.Yok, Durum = durum, SonrakiAn = an, ErteleAn = erteleAn,
        };
        _vt.Db.Hatirlaticilar.Add(h);
        await _vt.Db.SaveChangesAsync(Ct);
        return h;
    }

    private HatirlaticiBildirimci HatirlaticiTuru(bool pushAcik = true) => new(_vt.Db, Servis(_vt.Db, pushAcik), _saat, _ayar);

    private Task<List<Bildirim>> BildirimlerAsync(string? kaynak = null) =>
        _vt.Db.Bildirimler.AsNoTracking().Where(b => kaynak == null || b.KaynakTuru == kaynak).OrderBy(b => b.OlusmaAni).ToListAsync(Ct);

    // Reminders

    [Fact]
    public async Task ADueReminder_IsSentOnce_AndASecondRoundDoesNotSendTheSameOccurrenceAgain()
    {
        var h = await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-1));

        Assert.Equal(1, await HatirlaticiTuru().TurAsync(Ct));
        Assert.Equal(0, await HatirlaticiTuru().TurAsync(Ct));

        var b = Assert.Single(await BildirimlerAsync());
        Assert.Equal(("hatirlatici", "İlaç al", h.Id.ToString(), HatirlaticiBildirimci.Rota), (b.KaynakTuru, b.Baslik, b.HedefKimligi, b.Rota));
        Assert.Equal(HatirlaticiBildirimci.Anahtar(h), b.Anahtar);
        var gonderilen = Assert.Single(_push.Gonderilenler);
        Assert.Equal(("tok-sahip", b.Id), (gonderilen.Token, gonderilen.BildirimId));
    }

    [Fact]
    public async Task AReminderMissedByMoreThanTheDelay_IsSkipped_AndOneMissedByLessIsSent()
    {
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-16), "Çok eski");
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-14), "Az eski");

        await HatirlaticiTuru().TurAsync(Ct);

        Assert.Equal(["Az eski"], (await BildirimlerAsync()).Select(b => b.Baslik));
    }

    [Fact]
    public async Task AFutureReminder_ADoneOne_AndAnArchivedOne_AreNotSent()
    {
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(5), "Gelecek");
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-1), "Yapıldı", HatirlaticiDurumu.Tamam);
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-1), "Arşiv", HatirlaticiDurumu.Arsiv);

        Assert.Equal(0, await HatirlaticiTuru().TurAsync(Ct));

        Assert.Empty(await BildirimlerAsync());
        Assert.Empty(_push.Gonderilenler);
    }

    [Fact]
    public async Task ASnoozedReminder_IsANewOccurrence_AtTheSnoozeMoment_AndNotBefore()
    {
        var h = await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-1));
        await HatirlaticiTuru().TurAsync(Ct);

        // The person snoozes it for an hour: the old moment is no longer the one that counts.
        var kayit = await _vt.Db.Hatirlaticilar.FirstAsync(x => x.Id == h.Id, Ct);
        kayit.ErteleAn = _saat.Simdi.AddHours(1);
        await _vt.Db.SaveChangesAsync(Ct);
        Assert.Equal(0, await HatirlaticiTuru().TurAsync(Ct));

        _saat.Simdi = _saat.Simdi.AddHours(1).AddMinutes(1);
        Assert.Equal(1, await HatirlaticiTuru().TurAsync(Ct));

        var anahtarlar = (await BildirimlerAsync()).Select(b => b.Anahtar).ToList();
        Assert.Equal(2, anahtarlar.Distinct().Count());
    }

    [Fact]
    public async Task WhenEveryDeviceFails_TheOccurrenceIsTriedAgainOnTheNextRound_AndOnlyThenIsItDone()
    {
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-1));
        _push.Sonuclar["tok-sahip"] = PushSonucu.Hata;

        Assert.Equal(0, await HatirlaticiTuru().TurAsync(Ct));
        Assert.Empty(await BildirimlerAsync());

        _push.Sonuclar["tok-sahip"] = PushSonucu.Gitti;
        Assert.Equal(1, await HatirlaticiTuru().TurAsync(Ct));
        Assert.Equal(0, await HatirlaticiTuru().TurAsync(Ct));

        Assert.Single(await BildirimlerAsync());
        Assert.Equal(2, _push.Gonderilenler.Count);
    }

    [Fact]
    public async Task OnlyTheSahipAndTheHoldersOfTheReadPermission_AreTold()
    {
        await KullaniciEkleAsync("okuyan", "tok-okuyan", sahip: false, HatirlaticiPolicies.Oku);
        await KullaniciEkleAsync("baska-izin", "tok-baska", sahip: false, AliskanlikPolicies.Oku);
        await KullaniciEkleAsync("izinsiz", "tok-izinsiz");
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-1));

        await HatirlaticiTuru().TurAsync(Ct);

        Assert.Equal(["tok-okuyan", "tok-sahip"], _push.Gonderilenler.Select(g => g.Token).Order());
    }

    [Fact]
    public async Task WithPushOff_NothingIsRecordedAsSent_SoSwitchingItOnStillSendsAReminderThatIsNotTooLate()
    {
        await HatirlaticiEkleAsync(_saat.Simdi.AddMinutes(-2));

        Assert.Equal(0, await HatirlaticiTuru(pushAcik: false).TurAsync(Ct));
        Assert.Empty(await BildirimlerAsync());

        Assert.Equal(1, await HatirlaticiTuru().TurAsync(Ct));
    }

    // The brain's tasks

    private static object Gorev(string oncelik = "yuksek", string yol = GorevYolu, string kimlik = Kimlik, string baslik = Baslik, string? proje = Proje) => new
    {
        yol, kimlik, baslik, durum = "aktif", bitis = "2026-11-08", oncelik, proje, alan = (string?)null, tetik = (string?)null,
        tarihi_gelen = true, gizli = false, kanit = Array.Empty<string>(),
    };

    private void GorevListesi(params object[] gorevler) => _beyin.Cikti("gorev liste", JsonSerializer.Serialize(gorevler));

    // The journal and the last card of the project, as the brain would print them. Both default to "nothing".
    private void ProjeKaynaklari(string? kart = null, (string Baslik, string Metin)[]? gunluk = null)
    {
        _beyin.Cikti("proje goster", JsonSerializer.Serialize(new
        {
            kimlik = Proje, baslik = "Kitap Kulübü", yol = "projects/kitap-kulubu/proje.md", durum = "", siradaki_adim = "",
            acik_gorevler = Array.Empty<object>(),
            son_gunluk = (gunluk ?? []).Select(g => new { zaman = "2026-11-09", baslik = g.Baslik, metin = g.Metin }).ToArray(),
        }));
        if (kart is null)
            _beyin.CiktiKonumsal("not oku", KartYolu, """{"hata": {"kod": "bulunamadi", "mesaj": "yok"}}""", cikis: 1);
        else
            _beyin.CiktiKonumsal("not oku", KartYolu, JsonSerializer.Serialize(new
            {
                yol = KartYolu, baslik = "Oturumlar", ustbilgi = new { }, govde = kart, ustbilgi_hatalari = Array.Empty<string>(),
            }));
    }

    private void BeyinKomutlari(string bitir = """{"yol": "projects/kitap-kulubu/gorevler/mobil-gorunum-duzeltmeleri.md", "kimlik": "mobil-gorunum-duzeltmeleri", "degisen": ["durum"]}""")
    {
        _beyin.Cikti("gorev bitir", bitir);
        _beyin.Cikti("gorev guncelle", """{"yol": "projects/kitap-kulubu/gorevler/mobil-gorunum-duzeltmeleri.md", "kimlik": "mobil-gorunum-duzeltmeleri", "degisen": ["durum"]}""");
    }

    private (GorevBildirimci Tur, EylemServisi Eylemler) GorevTuru(AppDbContext? db = null)
    {
        db ??= _vt.Db;
        var beyin = _beyin.Istemci();
        var turler = new EylemTurleri([new GorevKapatTuru(beyin, NullLogger<GorevKapatTuru>.Instance)]);
        var eylemler = new EylemServisi(db, turler, _saat, NullLogger<EylemServisi>.Instance);
        return (new GorevBildirimci(beyin, db, Servis(db), eylemler, _komitler, _saat, NullLogger<GorevBildirimci>.Instance), eylemler);
    }

    private List<string[]> Cagrilar(string ilk, string ikinci) =>
        _beyin.Cagrilar().Select(SahteBeyin.Argumanlar).Where(a => a[0] == ilk && a[1] == ikinci).ToList();

    private Task<List<Eylem>> EylemlerAsync() => _vt.Db.Eylemler.AsNoTracking().Where(e => e.Tur == GorevKapatTuru.Anahtar).OrderBy(e => e.CreatedAt).ToListAsync(Ct);

    [Fact]
    public async Task ALowPriorityTask_IsNeverNotified_AndTheBrainIsNotAskedForEvidence()
    {
        GorevListesi(Gorev("dusuk"), Gorev("orta", yol: "projects/kitap-kulubu/gorevler/b.md", kimlik: "b", baslik: "B işi"));
        ProjeKaynaklari();
        BeyinKomutlari();

        var ozet = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal(new GorevTuruOzeti(true), ozet);
        Assert.Empty(await BildirimlerAsync());
        Assert.Empty(_push.Gonderilenler);
        Assert.Empty(Cagrilar("proje", "goster"));
        Assert.Empty(Cagrilar("gorev", "bitir"));
    }

    [Fact]
    public async Task AHighPriorityTaskWithNoEvidence_IsRemindedOnce_AndNotAgainTheSameDay()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari();

        var ilk = await GorevTuru().Tur.TurAsync(Ct);
        _saat.Simdi = _saat.Simdi.AddHours(5);
        var ikinci = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal(1, ilk.Hatirlatilan);
        Assert.Equal(0, ikinci.Hatirlatilan);
        var b = Assert.Single(await BildirimlerAsync("gorev"));
        Assert.Equal((Baslik, "/projeler/{id}", Proje), (b.Baslik, b.Rota, b.HedefKimligi));
        Assert.Empty(Cagrilar("gorev", "bitir"));
        Assert.Empty(await EylemlerAsync());
    }

    [Fact]
    public async Task TheNextDay_TheTaskIsRemindedAgain()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari();

        await GorevTuru().Tur.TurAsync(Ct);
        _saat.Simdi = _saat.Simdi.AddDays(1);
        await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal(2, (await BildirimlerAsync("gorev")).Count);
    }

    [Fact]
    public async Task StrongEvidence_ClosesTheTaskWithItsProof_TellsTheUser_AndTheCloseCanBeUndone()
    {
        const string Hash = "a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0";
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari();
        _komitler.Komitler[Proje] = [new GitKomiti(Hash, "feat: finish mobil-gorunum-duzeltmeleri pages")];
        var (tur, eylemler) = GorevTuru();

        var ozet = await tur.TurAsync(Ct);

        Assert.Equal((1, 0, 0), (ozet.Kapatilan, ozet.Sorulan, ozet.Hatirlatilan));
        var bitir = Assert.Single(Cagrilar("gorev", "bitir"));
        Assert.Contains("--kanit=commit:a1b2c3d4e5f6", bitir);
        Assert.Equal(GorevYolu, bitir[^1]);
        var eylem = Assert.Single(await EylemlerAsync());
        Assert.Equal(EylemDurumu.Uygulandi, eylem.Durum);
        Assert.NotNull(eylem.GeriAlmaBilgisi);
        var b = Assert.Single(await BildirimlerAsync("dogrulama"));
        Assert.StartsWith("Kapattım:", b.Baslik);
        Assert.Equal(("/eylem/{id}", eylem.Id.ToString()), (b.Rota, b.HedefKimligi));

        // Undo: the brain now lists the task as closed with our proof; the action opens it again.
        _beyin.Cikti("gorev liste", JsonSerializer.Serialize(new[]
        {
            new { yol = GorevYolu, kimlik = Kimlik, baslik = Baslik, durum = "bitti", kanit = new[] { "commit:a1b2c3d4e5f6" } },
        }));
        var geriAlma = await eylemler.GeriAlAsync(eylem.Id, kullanici: null, Ct);

        Assert.True(geriAlma.Basarili, geriAlma.Mesaj);
        var guncelle = Assert.Single(Cagrilar("gorev", "guncelle"));
        Assert.Contains("--durum=aktif", guncelle);
        Assert.Equal(GorevYolu, guncelle[^1]);
        Assert.Equal(EylemDurumu.GeriAlindi, (await EylemlerAsync()).Single().Durum);
    }

    [Fact]
    public async Task AnUndoneClose_IsNotRepeatedOnTheSameProof_ButANewCommitIsANewProof()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari();
        _komitler.Komitler[Proje] = [new GitKomiti("a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0", "feat: finish mobil-gorunum-duzeltmeleri")];
        var (tur, eylemler) = GorevTuru();
        await tur.TurAsync(Ct);
        _beyin.Cikti("gorev liste", JsonSerializer.Serialize(new[]
        {
            new { yol = GorevYolu, kimlik = Kimlik, baslik = Baslik, durum = "bitti", kanit = new[] { "commit:a1b2c3d4e5f6" } },
        }));
        await eylemler.GeriAlAsync((await EylemlerAsync()).Single().Id, null, Ct);
        GorevListesi(Gorev());

        // The next day the same commit is still the only proof: the task is reminded, not closed again.
        _saat.Simdi = _saat.Simdi.AddDays(1);
        var ayni = await GorevTuru().Tur.TurAsync(Ct);
        Assert.Equal((0, 1), (ayni.Kapatilan, ayni.Hatirlatilan));
        Assert.Single(Cagrilar("gorev", "bitir"));

        // A new commit that names it is a new proof.
        _komitler.Komitler[Proje].Insert(0, new GitKomiti("ffffffffffff1234567890123456789012345678", "fix: mobil-gorunum-duzeltmeleri after review"));
        _saat.Simdi = _saat.Simdi.AddDays(1);
        var yeni = await GorevTuru().Tur.TurAsync(Ct);
        Assert.Equal(1, yeni.Kapatilan);
        Assert.Equal(2, Cagrilar("gorev", "bitir").Count);
    }

    [Fact]
    public async Task AnUndoDoesNotReopenATaskThatIsNoLongerClosedByThatProof()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari();
        _komitler.Komitler[Proje] = [new GitKomiti("a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0", "feat: finish mobil-gorunum-duzeltmeleri")];
        var (tur, eylemler) = GorevTuru();
        await tur.TurAsync(Ct);

        // The person has reopened it and closed it again with a proof of their own.
        _beyin.Cikti("gorev liste", JsonSerializer.Serialize(new[]
        {
            new { yol = GorevYolu, kimlik = Kimlik, baslik = Baslik, durum = "bitti", kanit = new[] { "https://example.test/pr/1" } },
        }));
        await eylemler.GeriAlAsync((await EylemlerAsync()).Single().Id, null, Ct);

        Assert.Empty(Cagrilar("gorev", "guncelle"));
    }

    [Fact]
    public async Task ACardThatSaysTheTaskIsDone_ClosesItWithADatedWordOfTheUser()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari(kart: "## 2026-11-09 09:00 · etiket · abc\n  mobil-gorunum-duzeltmeleri bitti.\n");
        BeyinKomutlari();

        var ozet = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal(1, ozet.Kapatilan);
        Assert.Contains("--kanit=onay:dogrulama-2026-11-09", Assert.Single(Cagrilar("gorev", "bitir")));
    }

    [Fact]
    public async Task WeakEvidence_LeavesTheTaskOpen_PutsAQuestionInTheQueue_AndAsksOnce()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari(gunluk: [("Görünüm işleri", "Mobil görünüm düzeltmeleri üzerinde çalışıldı")]);
        BeyinKomutlari();
        var (tur, _) = GorevTuru();

        var ilk = await tur.TurAsync(Ct);
        _saat.Simdi = _saat.Simdi.AddDays(1);
        var ikinci = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal((0, 1, 0), (ilk.Kapatilan, ilk.Sorulan, ilk.Hatirlatilan));
        // The question is still waiting on the next day: it is not asked twice, and the queue does not grow.
        Assert.Equal((0, 0, 0), (ikinci.Kapatilan, ikinci.Sorulan, ikinci.Hatirlatilan));
        Assert.Empty(Cagrilar("gorev", "bitir"));
        var eylem = Assert.Single(await EylemlerAsync());
        Assert.Equal(EylemDurumu.Bekliyor, eylem.Durum);
        Assert.True(eylem.DisKaynak);
        var b = Assert.Single(await BildirimlerAsync("dogrulama"));
        Assert.Equal("Bitmiş görünüyor, kapatayım mı?", b.Baslik);
        Assert.Equal(("/eylem/{id}", eylem.Id.ToString()), (b.Rota, b.HedefKimligi));
    }

    [Fact]
    public async Task AWeakQuestionIsNeverAppliedByItself_EvenWhenTheKindIsSetToKendinYap()
    {
        _vt.Db.EylemIzinleri.Add(new EylemIzni { Tur = GorevKapatTuru.Anahtar, Kip = EylemKipi.KendinYap });
        await _vt.Db.SaveChangesAsync(Ct);
        GorevListesi(Gorev());
        ProjeKaynaklari(gunluk: [("Görünüm işleri", "Mobil görünüm düzeltmeleri üzerinde çalışıldı")]);
        BeyinKomutlari();

        await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal(EylemDurumu.Bekliyor, Assert.Single(await EylemlerAsync()).Durum);
        Assert.Empty(Cagrilar("gorev", "bitir"));
    }

    [Fact]
    public async Task ARefusedQuestion_IsNotAskedAgainForAWhile_TheTaskIsRemindedInstead()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari(gunluk: [("Görünüm işleri", "Mobil görünüm düzeltmeleri üzerinde çalışıldı")]);
        BeyinKomutlari();
        var (tur, eylemler) = GorevTuru();
        await tur.TurAsync(Ct);
        await eylemler.ReddetAsync((await EylemlerAsync()).Single().Id, birDahaOnerme: false, kullanici: null, Ct);

        _saat.Simdi = _saat.Simdi.AddDays(1);
        var ozet = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal((0, 0, 1), (ozet.Kapatilan, ozet.Sorulan, ozet.Hatirlatilan));
        Assert.Single(await EylemlerAsync());

        // After the quiet period the guess may be made again.
        _saat.Simdi = _saat.Simdi.AddDays(8);
        Assert.Equal(1, (await GorevTuru().Tur.TurAsync(Ct)).Sorulan);
    }

    [Fact]
    public async Task WhenTheKindIsForbidden_ThereIsNoCloseAndNoQuestion_JustTheReminder()
    {
        _vt.Db.EylemIzinleri.Add(new EylemIzni { Tur = GorevKapatTuru.Anahtar, Kip = EylemKipi.Yasak });
        await _vt.Db.SaveChangesAsync(Ct);
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari();
        _komitler.Komitler[Proje] = [new GitKomiti("a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0", "feat: finish mobil-gorunum-duzeltmeleri")];

        var ozet = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal((0, 0, 1), (ozet.Kapatilan, ozet.Sorulan, ozet.Hatirlatilan));
        Assert.Empty(Cagrilar("gorev", "bitir"));
        Assert.Empty(await EylemlerAsync());
    }

    [Fact]
    public async Task WhenTheBrainRefusesTheClose_TheTaskIsRemindedAsOpen_NotAnnouncedAsClosed()
    {
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari(bitir: """{"hata": {"kod": "gecersiz", "mesaj": "görev zaten bitti"}}""");
        _beyin.Cikti("gorev bitir", """{"hata": {"kod": "gecersiz", "mesaj": "görev zaten bitti"}}""", cikis: 1);
        _komitler.Komitler[Proje] = [new GitKomiti("a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0", "feat: finish mobil-gorunum-duzeltmeleri")];

        var ozet = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal((0, 1), (ozet.Kapatilan, ozet.Hatirlatilan));
        Assert.Equal(EylemDurumu.Hatali, Assert.Single(await EylemlerAsync()).Durum);
        Assert.DoesNotContain(await BildirimlerAsync(), b => b.Baslik.StartsWith("Kapattım"));
    }

    [Fact]
    public async Task ATaskWithoutAProject_HasNoEvidenceToLookFor_AndIsJustReminded()
    {
        GorevListesi(Gorev(yol: "spor/gorevler/kosu.md", kimlik: "kosu-programi-hazirla", baslik: "Koşu programı hazırla", proje: null));
        BeyinKomutlari();

        var ozet = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal(1, ozet.Hatirlatilan);
        Assert.Empty(Cagrilar("proje", "goster"));
        var b = Assert.Single(await BildirimlerAsync("gorev"));
        Assert.Null(b.Rota);
    }

    [Fact]
    public async Task AnUserWhoCannotOpenTheQueue_IsNotToldOfACloseOrAQuestion_AndNothingIsClosedWhenNobodyCanBeTold()
    {
        // Only a person who may read the brain but not decide: the task is reminded, never closed behind everyone's back.
        _vt.Db.BildirimCihazlari.RemoveRange(_vt.Db.BildirimCihazlari);
        await _vt.Db.SaveChangesAsync(Ct);
        await KullaniciEkleAsync("okuyan", "tok-okuyan", sahip: false, BeyinPolicies.Oku);
        GorevListesi(Gorev());
        ProjeKaynaklari();
        BeyinKomutlari();
        _komitler.Komitler[Proje] = [new GitKomiti("a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0", "feat: finish mobil-gorunum-duzeltmeleri")];

        var ozet = await GorevTuru().Tur.TurAsync(Ct);

        Assert.Equal((0, 1), (ozet.Kapatilan, ozet.Hatirlatilan));
        Assert.Empty(Cagrilar("gorev", "bitir"));
    }

    [Fact]
    public async Task WhenTheBrainDoesNotAnswer_TheRoundSaysItDidNotRead()
    {
        _beyin.Mod = "hata";

        Assert.False((await GorevTuru().Tur.TurAsync(Ct)).Okundu);
        Assert.Empty(await BildirimlerAsync());
    }

    // The timer

    [Theory]
    [InlineData(8, 59, null)]
    [InlineData(9, 0, 9)]
    [InlineData(9, 29, 9)]
    [InlineData(9, 30, null)]
    [InlineData(14, 10, 14)]
    [InlineData(19, 5, 19)]
    [InlineData(23, 0, null)]
    public void TheTaskRound_RunsOnlyInsideTheWindowOfTheSetHours(int saat, int dakika, int? beklenen)
    {
        var vakit = BildirimZamanlayici.GorevSaati(new BildirimHattiAyari(), Ist(2026, 11, 9, saat, dakika));

        Assert.Equal(beklenen, vakit?.Saat.Hour);
    }

    private BildirimZamanlayici Zamanlayici()
    {
        var servisler = new ServiceCollection();
        servisler.AddLogging();
        servisler.AddScoped(_ => _vt.YeniDb());
        servisler.AddSingleton(PushAcik());
        servisler.AddSingleton<IPushGondericisi>(_push);
        servisler.AddSingleton<PushDurumu>();
        servisler.AddSingleton<TimeProvider>(_saat);
        servisler.AddSingleton(_ayar);
        servisler.AddSingleton(_beyin.Istemci());
        servisler.AddSingleton<IKomitOkuyucu>(_komitler);
        servisler.AddSingleton<EylemTurleri>(sp => new EylemTurleri([new GorevKapatTuru(sp.GetRequiredService<BeyinIstemcisi>(), NullLogger<GorevKapatTuru>.Instance)]));
        servisler.AddScoped<EylemServisi>();
        servisler.AddScoped<BildirimServisi>();
        servisler.AddScoped<HatirlaticiBildirimci>();
        servisler.AddScoped<GorevBildirimci>();
        var saglayici = servisler.BuildServiceProvider();
        return new BildirimZamanlayici(saglayici.GetRequiredService<IServiceScopeFactory>(), _ayar, _saat, NullLogger<BildirimZamanlayici>.Instance);
    }

    [Fact]
    public async Task TheTimer_LooksAtTheTasksOnceForEachSetHour_AndAgainForTheNextHourAndDay()
    {
        GorevListesi();
        var zamanlayici = Zamanlayici();

        _saat.Simdi = Ist(2026, 11, 9, 9, 5);
        await zamanlayici.TurAsync(Ct);
        await zamanlayici.TurAsync(Ct);
        Assert.Single(Cagrilar("gorev", "liste"));

        _saat.Simdi = Ist(2026, 11, 9, 11, 0);
        await zamanlayici.TurAsync(Ct);
        Assert.Single(Cagrilar("gorev", "liste"));

        _saat.Simdi = Ist(2026, 11, 9, 14, 5);
        await zamanlayici.TurAsync(Ct);
        Assert.Equal(2, Cagrilar("gorev", "liste").Count);

        _saat.Simdi = Ist(2026, 11, 10, 9, 5);
        await zamanlayici.TurAsync(Ct);
        Assert.Equal(3, Cagrilar("gorev", "liste").Count);
    }

    [Fact]
    public async Task TheTimer_WhenTheBrainDoesNotAnswer_KeepsTheHourOpen_UntilItDoes()
    {
        var zamanlayici = Zamanlayici();
        _saat.Simdi = Ist(2026, 11, 9, 9, 1);

        _beyin.Mod = "hata";
        await zamanlayici.TurAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 9, 9, 2);
        await zamanlayici.TurAsync(Ct);
        Assert.Equal(2, Cagrilar("gorev", "liste").Count);

        GorevListesi();
        _saat.Simdi = Ist(2026, 11, 9, 9, 3);
        await zamanlayici.TurAsync(Ct);
        await zamanlayici.TurAsync(Ct);
        Assert.Equal(3, Cagrilar("gorev", "liste").Count);
    }

    [Fact]
    public async Task TheTimer_SendsADueReminderOnItsMinuteRound_WithoutWaitingForATaskHour()
    {
        await HatirlaticiEkleAsync(Ist(2026, 11, 9, 11, 59));
        _saat.Simdi = Ist(2026, 11, 9, 12, 0);
        var zamanlayici = Zamanlayici();

        await zamanlayici.TurAsync(Ct);
        _saat.Simdi = Ist(2026, 11, 9, 12, 1);
        await zamanlayici.TurAsync(Ct);

        Assert.Single(_push.Gonderilenler);
        Assert.Empty(Cagrilar("gorev", "liste"));
    }
}
