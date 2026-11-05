using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Kafamdakiler.Yakalamalar;
using Microsoft.EntityFrameworkCore;
using SkiaSharp;

namespace Kafamdakiler.Tests;

// Waiting captures -> cards in the (fake) brain. Real PostgreSQL, real child process, fake beyin.py.
public class YakalamaGonderimiTests : IAsyncLifetime
{
    private readonly TestVeritabani _vt = new();
    private readonly SahteBeyin _beyin = new("ok");

    public ValueTask InitializeAsync() => _vt.InitializeAsync();

    public async ValueTask DisposeAsync()
    {
        await _vt.DisposeAsync();
        _beyin.Dispose();
    }

    private static readonly DateTimeOffset Simdi = new(2026, 11, 5, 12, 0, 0, TimeSpan.Zero);

    // A capture last edited `once` before Simdi.
    private async Task<Yakalama> EkleAsync(TimeSpan once, string? metin = "bir düşünce", Guid? fotograf = null, string? hedef = null)
    {
        var y = new Yakalama
        {
            Metin = metin, FotografId = fotograf, Hedef = hedef,
            YakalandiAt = Simdi - once - TimeSpan.FromMinutes(1), GuncellendiAt = Simdi - once,
        };
        _vt.Db.Yakalamalar.Add(y);
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);
        return y;
    }

    private Task<YakalamaGonderimi.TurOzeti> TurAsync(DateTimeOffset simdi, AppDbContext? db = null, TimeSpan? zamanAsimi = null) =>
        YakalamaGonderimi.TurAsync(db ?? _vt.Db, _vt.Depo, _beyin.Istemci(zamanAsimi), _beyin.Ayar(zamanAsimi), simdi, TestContext.Current.CancellationToken);

    private async Task<Yakalama> OkuAsync(Guid id)
    {
        // A fresh read: the sender updates rows without going through the tracked entity.
        await using var db = _vt.YeniDb();
        return await db.Yakalamalar.AsNoTracking().SingleAsync(y => y.Id == id, TestContext.Current.CancellationToken);
    }

    [Fact]
    public async Task Due_CaptureIsSent_AndMarkedBeyneGitti()
    {
        var y = await EkleAsync(TimeSpan.FromMinutes(11), hedef: "projects/kitap-kulubu");

        var ozet = await TurAsync(Simdi);

        Assert.Equal(1, ozet.Gonderilen);
        var kayit = await OkuAsync(y.Id);
        Assert.Equal(YakalamaDurumu.BeyneGitti, kayit.Durum);
        Assert.Null(kayit.SonHata);
        var cagri = _beyin.Cagrilar().Single();
        Assert.Equal("bir düşünce", cagri.GetProperty("metin").GetString());
        var argumanlar = SahteBeyin.Argumanlar(cagri);
        Assert.Contains("--hedef=projects/kitap-kulubu", argumanlar);
        Assert.Contains($"--yakalandi={y.YakalandiAt.ToLocalTime():yyyy-MM-dd'T'HH:mm}", argumanlar);
    }

    [Fact]
    public async Task EditedRecently_StaysWaiting_UntilTheDelayPasses()
    {
        var y = await EkleAsync(TimeSpan.FromMinutes(9));

        Assert.Equal(0, (await TurAsync(Simdi)).Gonderilen);
        Assert.Equal(YakalamaDurumu.Bekliyor, (await OkuAsync(y.Id)).Durum);
        Assert.Empty(_beyin.Cagrilar());

        Assert.Equal(1, (await TurAsync(Simdi + TimeSpan.FromMinutes(2))).Gonderilen);
    }

    [Fact]
    public async Task AlreadySentOrProcessed_AreNotSentAgain()
    {
        var y = await EkleAsync(TimeSpan.FromHours(1));
        y.Durum = YakalamaDurumu.BeyneGitti;
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);

        Assert.Equal(0, (await TurAsync(Simdi)).Gonderilen);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Theory]
    [InlineData("image/png")]
    [InlineData("image/webp")]
    public async Task PngAndWebp_AreConvertedToJpeg_AndTheTempFileIsRemoved(string tur)
    {
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.FromHours(1));
        dosya.IcerikTuru = tur;
        await File.WriteAllBytesAsync(_vt.Depo.YolBul(dosya), Resim(tur == "image/png" ? SKEncodedImageFormat.Png : SKEncodedImageFormat.Webp), TestContext.Current.CancellationToken);
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);
        await EkleAsync(TimeSpan.FromMinutes(11), metin: null, fotograf: dosya.Id);

        var ozet = await TurAsync(Simdi);

        Assert.Equal(1, ozet.Gonderilen);
        var cagri = _beyin.Cagrilar().Single();
        Assert.Equal("ffd8ff", cagri.GetProperty("gorsel_bas").GetString());
        var gorsel = cagri.GetProperty("gorsel").GetString()!;
        Assert.NotEqual(_vt.Depo.YolBul(dosya), gorsel);
        Assert.False(File.Exists(gorsel));
        // The stored original is untouched.
        Assert.True(_vt.DiskteVarMi(dosya));
    }

    [Fact]
    public async Task Jpeg_IsPassedAsItIs()
    {
        var dosya = await _vt.DosyaEkleAsync(TimeSpan.FromHours(1));
        await EkleAsync(TimeSpan.FromMinutes(11), metin: null, fotograf: dosya.Id);

        await TurAsync(Simdi);

        Assert.Equal(_vt.Depo.YolBul(dosya), _beyin.Cagrilar().Single().GetProperty("gorsel").GetString());
        Assert.True(_vt.DiskteVarMi(dosya));
    }

    [Fact]
    public async Task BrainError_KeepsTheError_AndRetriesAfterTheWait()
    {
        _beyin.Mod = "hata";
        var y = await EkleAsync(TimeSpan.FromMinutes(11));

        var ilk = await TurAsync(Simdi);
        var kayit = await OkuAsync(y.Id);

        Assert.Equal(1, ilk.Hatali);
        Assert.Equal(YakalamaDurumu.Bekliyor, kayit.Durum);
        Assert.Equal(1, kayit.DenemeSayisi);
        Assert.Contains("kötü istek", kayit.SonHata);
        Assert.Null(kayit.GonderimBasladiAt);

        // Too soon: no second call yet.
        await TurAsync(Simdi + TimeSpan.FromSeconds(10));
        Assert.Single(_beyin.Cagrilar());

        // After the wait, with the brain healthy again: sent, and the error is cleared.
        _beyin.Mod = "ok";
        var sonra = await TurAsync(Simdi + TimeSpan.FromMinutes(2));
        kayit = await OkuAsync(y.Id);
        Assert.Equal(1, sonra.Gonderilen);
        Assert.Equal(YakalamaDurumu.BeyneGitti, kayit.Durum);
        Assert.Null(kayit.SonHata);
    }

    [Fact]
    public async Task BrainNotConnected_RoundDoesNothing_AndTheCaptureIsUntouched()
    {
        var y = await EkleAsync(TimeSpan.FromMinutes(11));
        Directory.Delete(_beyin.Vault);

        var ozet = await TurAsync(Simdi);

        Assert.Equal(new YakalamaGonderimi.TurOzeti(0, 0, 0), ozet);
        Assert.Equal(0, (await OkuAsync(y.Id)).DenemeSayisi);
    }

    [Fact]
    public async Task Timeout_KeepsTheClaim_AndIsNeverSentAgainByItself()
    {
        _beyin.Mod = "uyku";
        var y = await EkleAsync(TimeSpan.FromMinutes(11));

        var ozet = await TurAsync(Simdi, zamanAsimi: TimeSpan.FromSeconds(1));
        var kayit = await OkuAsync(y.Id);

        Assert.Equal(1, ozet.Belirsiz);
        Assert.NotNull(kayit.GonderimBasladiAt);
        Assert.Contains("belirsiz", kayit.SonHata);
        Assert.Equal(YakalamaDurumu.Bekliyor, kayit.Durum);

        _beyin.Mod = "ok";
        await TurAsync(Simdi + TimeSpan.FromHours(2));
        Assert.Single(_beyin.Cagrilar());
    }

    // The point of the claim: two rounds at once (or two app instances) make one card, not two.
    [Fact]
    public async Task TwoRoundsAtOnce_MakeOneCard()
    {
        _beyin.Mod = "yavas";
        var y = await EkleAsync(TimeSpan.FromMinutes(11));
        await using var ikinci = _vt.YeniDb();

        var turlar = await Task.WhenAll(TurAsync(Simdi), TurAsync(Simdi, ikinci));

        Assert.Single(_beyin.Cagrilar());
        Assert.Equal(1, turlar.Sum(t => t.Gonderilen));
        Assert.Equal(YakalamaDurumu.BeyneGitti, (await OkuAsync(y.Id)).Durum);
    }

    [Fact]
    public async Task EditedAfterTheListWasRead_IsNotSentWithTheOldContent()
    {
        var y = await EkleAsync(TimeSpan.FromMinutes(11));
        // The claim only matches the exact last-edit time the sender read; an edit in between makes it miss.
        await using (var db = _vt.YeniDb())
        {
            await db.Yakalamalar.Where(x => x.Id == y.Id)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.GuncellendiAt, Simdi), TestContext.Current.CancellationToken);
        }

        Assert.Equal(0, (await TurAsync(Simdi)).Gonderilen);
        Assert.Empty(_beyin.Cagrilar());
    }

    [Fact]
    public async Task EditOrDelete_WhileClaimed_IsRefused()
    {
        var y = await EkleAsync(TimeSpan.FromMinutes(11));
        y.GonderimBasladiAt = DateTimeOffset.UtcNow;
        await _vt.Db.SaveChangesAsync(TestContext.Current.CancellationToken);
        var dto = new YakalamaYazDto { Metin = "yeni", YakalandiAt = Simdi };

        var guncelle = await YakalamaIslemleri.GuncelleAsync(_vt.Db, _vt.Depo, y, dto, TestContext.Current.CancellationToken);
        var sil = await YakalamaIslemleri.SilAsync(_vt.Db, _vt.Depo, y, TestContext.Current.CancellationToken);

        Assert.True(guncelle.Cakisma);
        Assert.True(sil.Cakisma);
        Assert.Equal("bir düşünce", (await OkuAsync(y.Id)).Metin);
    }

    [Fact]
    public async Task EditLoadedBeforeTheClaim_CannotOverwriteIt()
    {
        var y = await EkleAsync(TimeSpan.FromMinutes(11));
        // The page loaded the capture (tracked, old row version) ...
        var yuklenen = await _vt.Db.Yakalamalar.SingleAsync(x => x.Id == y.Id, TestContext.Current.CancellationToken);
        // ... then the sender claims it ...
        await using (var db = _vt.YeniDb())
        {
            await db.Yakalamalar.Where(x => x.Id == y.Id)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.GonderimBasladiAt, DateTimeOffset.UtcNow), TestContext.Current.CancellationToken);
        }

        // ... and only then the user saves.
        var sonuc = await YakalamaIslemleri.GuncelleAsync(_vt.Db, _vt.Depo, yuklenen,
            new YakalamaYazDto { Metin = "geç kalan düzenleme", YakalandiAt = Simdi }, TestContext.Current.CancellationToken);

        Assert.True(sonuc.Cakisma);
        Assert.Equal("bir düşünce", (await OkuAsync(y.Id)).Metin);
    }

    private static byte[] Resim(SKEncodedImageFormat bicim)
    {
        using var bitmap = new SKBitmap(8, 6);
        bitmap.Erase(SKColors.CornflowerBlue);
        using var veri = SKImage.FromBitmap(bitmap).Encode(bicim, 90);
        return veri.ToArray();
    }
}
