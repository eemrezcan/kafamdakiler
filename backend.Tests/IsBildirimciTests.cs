using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Bildirimler;
using Kafamdakiler.Data;
using Kafamdakiler.Isler;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Kafamdakiler.Tests;

// The card watcher on real PostgreSQL, with the fake FCM sender and a fake beyin.py: a card that falls to the person is told about once
// for that stage; their own writes are not news; a card that goes back and comes round again is a new occurrence; nobody is told what
// their permissions would not let them open.
public sealed class IsBildirimciTests : IAsyncLifetime
{
    private readonly TestVeritabani _vt = new();
    private readonly SahteBeyin _beyin = new("ok");
    private readonly SahtePushGondericisi _push = new();
    private readonly ElleSaat _saat = new(new DateTimeOffset(2026, 11, 10, 10, 0, 0, TimeSpan.FromHours(3)).ToUniversalTime());
    private readonly string _anahtar = Path.Combine(Path.GetTempPath(), "kd-test-anahtar-" + Guid.NewGuid().ToString("N") + ".json");
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

    private async Task<Guid> KullaniciEkleAsync(string ad, string token, bool sahip = false, params string[] izinler)
    {
        var kullanici = new IdentityUser<Guid> { Id = Guid.NewGuid(), UserName = ad, NormalizedUserName = ad.ToUpperInvariant() };
        _vt.Db.Users.Add(kullanici);
        if (sahip)
        {
            var rol = new IdentityRole<Guid> { Id = Guid.NewGuid(), Name = SeedData.OwnerRole, NormalizedName = SeedData.OwnerRole.ToUpperInvariant() };
            _vt.Db.Roles.Add(rol);
            _vt.Db.UserRoles.Add(new IdentityUserRole<Guid> { UserId = kullanici.Id, RoleId = rol.Id });
        }

        foreach (var izin in izinler)
            _vt.Db.UserClaims.Add(new IdentityUserClaim<Guid> { UserId = kullanici.Id, ClaimType = AliskanlikPolicies.IzinClaim, ClaimValue = izin });

        _vt.Db.BildirimCihazlari.Add(new BildirimCihazi { KullaniciId = kullanici.Id, Token = token, KayitAni = _saat.Simdi, GuncellemeAni = _saat.Simdi });
        await _vt.Db.SaveChangesAsync(Ct);
        return kullanici.Id;
    }

    private IsBildirimci Izleyici(bool pushAcik = true) => new(
        _beyin.Istemci(), _vt.Db, new BildirimServisi(_vt.Db, new PushAyari { AnahtarDosyasi = pushAcik ? _anahtar : "" }, _push, new PushDurumu(), _saat),
        NullLogger<IsBildirimci>.Instance);

    // The open card list and the detail of one card, as the brain prints them.
    private void Kart(string kimlik, string asama = "karar", string sahip = "kullanici", string guncelleme = "2026-11-10T09:00", string sonKim = "vps",
        SahteIsKarti.Soru[]? sorular = null, bool gizli = false)
    {
        _beyin.CiktiKonumsal("is goster", kimlik, SahteIsKarti.Ayrinti(kimlik, asama, sahip, sorular: sorular, gecmis: [$"{sonKim}: bir şey oldu"], guncelleme: guncelleme));
        _beyin.Cikti("is liste", SahteIsKarti.Liste(SahteIsKarti.Kart(kimlik, asama, sahip, guncelleme: guncelleme, gizli: gizli)));
    }

    private Task<List<Bildirim>> BildirimlerAsync() => _vt.Db.Bildirimler.AsNoTracking().OrderBy(b => b.OlusmaAni).ToListAsync(Ct);

    [Fact]
    public async Task ACardThatFallsToThePerson_IsToldAboutOnce_AndTheSameStageIsNeverToldTwice()
    {
        Kart("kart-bir", sorular: [new(1, "Hangi kütüphane?", ["a", "b"])]);

        var ilk = await Izleyici().TurAsync(Ct);
        var ikinci = await Izleyici().TurAsync(Ct);

        Assert.Equal((true, 1, 1), (ilk.Okundu, ilk.Bekleyen, ilk.Bildirilen));
        Assert.Equal(0, ikinci.Bildirilen);
        var b = Assert.Single(await BildirimlerAsync());
        Assert.Equal(("is", "Kart kart-bir", "kart-bir", IsBildirimci.Rota), (b.KaynakTuru, b.Baslik, b.HedefKimligi, b.Rota));
        Assert.Equal("is:kart-bir:karar:2026-11-10T09:00", b.Anahtar);
        Assert.Contains("Karar bekliyor: Hangi kütüphane?", b.Metin);
        var gonderilen = Assert.Single(_push.Gonderilenler);
        Assert.Equal(("tok-sahip", b.Id), (gonderilen.Token, gonderilen.BildirimId));
    }

    [Theory]
    [InlineData("kod-onayi", "Kod onayı bekliyor")]
    [InlineData("push-onayi", "Push onayı bekliyor")]
    [InlineData("deploy-onayi", "Deploy onayı bekliyor")]
    public async Task EachGate_IsToldAbout_WithItsOwnWords(string asama, string metin)
    {
        Kart("kart-bir", asama);

        await Izleyici().TurAsync(Ct);

        Assert.StartsWith(metin, Assert.Single(await BildirimlerAsync()).Metin);
    }

    [Theory]
    [InlineData("karar", "vps")]
    [InlineData("kod-onayi", "laptop")]
    [InlineData("plan", "kullanici")]
    [InlineData("yapim", "kullanici")]
    [InlineData("talep", "kullanici")]
    [InlineData("bitti", "kullanici")]
    public async Task ACardThatIsNotTheirsOrNotAtADecisionOrGate_IsNotToldAbout(string asama, string sahip)
    {
        Kart("kart-bir", asama, sahip);

        var ozet = await Izleyici().TurAsync(Ct);

        Assert.Equal(0, ozet.Bildirilen);
        Assert.Empty(await BildirimlerAsync());
        Assert.Empty(_push.Gonderilenler);
    }

    [Fact]
    public async Task APersonsOwnWrite_MovesTheUpdateTime_ButIsNotNews()
    {
        Kart("kart-bir", sorular: [new(1, "Bir", ["a"]), new(2, "İki", ["a"])]);
        await Izleyici().TurAsync(Ct);

        // They answered one of two questions: the card is still theirs, the update time is new, the last history line is theirs.
        Kart("kart-bir", guncelleme: "2026-11-10T09:30", sonKim: "kullanici", sorular: [new(1, "Bir", ["a"], Cevap: "a"), new(2, "İki", ["a"])]);
        await Izleyici().TurAsync(Ct);

        Assert.Single(await BildirimlerAsync());
    }

    [Fact]
    public async Task ACardThatGoesBackAndComesRoundAgain_IsANewOccurrence()
    {
        Kart("kart-bir", sorular: [new(1, "Bir", ["a"])]);
        await Izleyici().TurAsync(Ct);

        // Back to the plan, the VPS revises it and the card falls to the person again: a new update time, written by the VPS.
        Kart("kart-bir", guncelleme: "2026-11-10T13:00", sonKim: "vps", sorular: [new(1, "Bir", ["a"], Cevap: "a"), new(2, "Yeni soru", ["a"])]);
        await Izleyici().TurAsync(Ct);

        Assert.Equal(["is:kart-bir:karar:2026-11-10T09:00", "is:kart-bir:karar:2026-11-10T13:00"], (await BildirimlerAsync()).Select(b => b.Anahtar));
    }

    [Fact]
    public async Task ACardAtAGate_ThenAtTheNextGate_IsToldAboutAtEach()
    {
        Kart("kart-bir", "kod-onayi");
        await Izleyici().TurAsync(Ct);
        Kart("kart-bir", "push-onayi", guncelleme: "2026-11-10T12:00");
        await Izleyici().TurAsync(Ct);

        Assert.Equal(2, (await BildirimlerAsync()).Count);
    }

    [Fact]
    public async Task WithPushOff_NothingIsReadOrRecorded_AndWhenItComesOn_TheWaitingCardIsToldAbout()
    {
        Kart("kart-bir");

        var kapali = await Izleyici(pushAcik: false).TurAsync(Ct);

        Assert.False(kapali.Okundu);
        Assert.Empty(_beyin.Cagrilar());
        Assert.Empty(await BildirimlerAsync());

        await Izleyici().TurAsync(Ct);
        Assert.Single(await BildirimlerAsync());
    }

    [Fact]
    public async Task AHiddenCardOrOneThatCouldNotBeRead_IsNotToldAbout()
    {
        _beyin.Cikti("is liste", SahteIsKarti.Liste(
            SahteIsKarti.Kart("gizli-kart", gizli: true),
            SahteIsKarti.Kart("bozuk-kart", hata: "üst bilgi okunamadı"),
            SahteIsKarti.Kart("finans-kart", proje: null, alan: "finans")));

        var ozet = await Izleyici().TurAsync(Ct);

        Assert.Equal((true, 0), (ozet.Okundu, ozet.Bildirilen));
        Assert.Empty(await BildirimlerAsync());
    }

    [Fact]
    public async Task ABrainThatDoesNotAnswer_IsNotARead_AndNothingIsRecorded()
    {
        _beyin.Cikti("is liste", SahteIsKarti.Hata("hata"), cikis: 1);

        var ozet = await Izleyici().TurAsync(Ct);

        Assert.False(ozet.Okundu);
        Assert.Empty(await BildirimlerAsync());
    }

    [Fact]
    public async Task OnlyThePeopleWhoMayReadTheCards_AndHaveAPhone_AreTold()
    {
        var izinli = await KullaniciEkleAsync("izinli", "tok-izinli", sahip: false, IsPolicies.Oku);
        await KullaniciEkleAsync("izinsiz", "tok-izinsiz", sahip: false);
        Kart("kart-bir");

        await Izleyici().TurAsync(Ct);

        Assert.Equal(new[] { _sahip, izinli }.Order(), (await BildirimlerAsync()).Select(b => b.KullaniciId).Order());
        Assert.DoesNotContain(_push.Gonderilenler, g => g.Token == "tok-izinsiz");
    }

    [Fact]
    public async Task AFailedSend_ForEveryPhone_IsTriedAgainOnTheNextRound()
    {
        _push.Sonuclar["tok-sahip"] = Kafamdakiler.Bildirimler.PushSonucu.Hata;
        Kart("kart-bir");

        await Izleyici().TurAsync(Ct);
        Assert.Empty(await BildirimlerAsync());

        _push.Sonuclar.Clear();
        await Izleyici().TurAsync(Ct);
        Assert.Single(await BildirimlerAsync());
    }
}
