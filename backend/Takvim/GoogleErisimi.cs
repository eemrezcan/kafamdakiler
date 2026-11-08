using System.Security.Cryptography;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Takvim;

public enum ErisimDurumu
{
    Tamam,
    // The Google settings are not all there.
    Kapali,
    // Nobody has connected a Google account.
    BagliDegil,
    // The stored token no longer works: the Sahip has to connect again.
    YenidenBaglan,
    // The connection works but was made without the scope this feature needs: the Sahip has to connect again to grant it.
    IzinYok,
}

public record ErisimSonucu(ErisimDurumu Durum, string? Token = null)
{
    public bool Basarili => Durum == ErisimDurumu.Tamam;

    public string Mesaj => Durum switch
    {
        ErisimDurumu.Kapali => "Google Takvim ayarlı değil.",
        ErisimDurumu.BagliDegil => "Google bağlı değil.",
        ErisimDurumu.YenidenBaglan => "Google bağlantısı geçersiz: yeniden bağlanmak gerekiyor.",
        ErisimDurumu.IzinYok => "Google bağlantısında bu özellik için izin yok: yeniden bağlanmak gerekiyor.",
        _ => "",
    };
}

// The refresh token's seal, and the access tokens made from it. A singleton: the kinds of the approval queue and the sync both
// ask it, each in its own scope, and it opens its own scope for the database. A short-lived access token is kept in memory
// until it is about to expire (never written anywhere).
public class GoogleErisimi(
    IServiceScopeFactory kapsamlar, IDataProtectionProvider koruma, IGoogleTakvimIstemcisi istemci, TakvimAyari ayar, TimeProvider saat,
    ILogger<GoogleErisimi> gunluk)
{
    // The purpose string isolates this seal from the cookies' and the antiforgery tokens'.
    public const string TokenAmaci = "Kafamdakiler.Google.YenilemeTokeni.v1";
    public const string DogrulayiciAmaci = "Kafamdakiler.Google.KodDogrulayici.v1";

    // A token that expires within this is renewed.
    private static readonly TimeSpan Pay = TimeSpan.FromMinutes(2);

    private readonly SemaphoreSlim _kilit = new(1, 1);
    private GoogleErisimTokeni? _onbellek;

    private readonly IDataProtector _tokenKoruyucu = koruma.CreateProtector(TokenAmaci);
    private readonly IDataProtector _dogrulayiciKoruyucu = koruma.CreateProtector(DogrulayiciAmaci);

    public string TokenMuhurle(string acik) => _tokenKoruyucu.Protect(acik);

    public string DogrulayiciMuhurle(string acik) => _dogrulayiciKoruyucu.Protect(acik);

    public string? DogrulayiciAc(string muhurlu) => Ac(_dogrulayiciKoruyucu, muhurlu);

    // Forget the access token held in memory (the connection was cut or made again).
    public void Unut()
    {
        _kilit.Wait();
        try
        {
            _onbellek = null;
        }
        finally
        {
            _kilit.Release();
        }
    }

    // The refresh token in the clear, or null when it is not there or cannot be opened. Used to revoke it.
    public string? YenilemeTokeniAc(GoogleBaglantisi baglanti) => Ac(_tokenKoruyucu, baglanti.YenilemeTokeni);

    // The same token, after a look at the scopes Google granted to the connection: IzinYok when `kapsam` is not among them.
    // The calendar does not ask this (its scopes are required to connect); a feature added later, like Gmail, does.
    public async Task<ErisimSonucu> TokenAlAsync(string kapsam, CancellationToken ct)
    {
        if (!ayar.Acik)
            return new ErisimSonucu(ErisimDurumu.Kapali);

        using (var kapsamKapsami = kapsamlar.CreateScope())
        {
            var db = kapsamKapsami.ServiceProvider.GetRequiredService<AppDbContext>();
            var baglanti = await db.GoogleBaglantilari.AsNoTracking().FirstOrDefaultAsync(ct);
            // No connection, or one that needs reconnecting, is answered by the plain call below.
            if (baglanti is { Durum: GoogleBaglantiDurumu.Bagli } && !baglanti.KapsamVar(kapsam))
                return new ErisimSonucu(ErisimDurumu.IzinYok);
        }

        return await TokenAlAsync(ct);
    }

    public async Task<ErisimSonucu> TokenAlAsync(CancellationToken ct)
    {
        if (!ayar.Acik)
            return new ErisimSonucu(ErisimDurumu.Kapali);

        await _kilit.WaitAsync(ct);
        try
        {
            if (_onbellek is { } hazir && hazir.BitisAni - Pay > saat.GetUtcNow())
                return new ErisimSonucu(ErisimDurumu.Tamam, hazir.Token);

            using var kapsam = kapsamlar.CreateScope();
            var db = kapsam.ServiceProvider.GetRequiredService<AppDbContext>();
            var baglanti = await db.GoogleBaglantilari.AsNoTracking().FirstOrDefaultAsync(ct);
            if (baglanti is null)
                return new ErisimSonucu(ErisimDurumu.BagliDegil);
            if (baglanti.Durum == GoogleBaglantiDurumu.YenidenBaglan)
                return new ErisimSonucu(ErisimDurumu.YenidenBaglan);

            var yenileme = YenilemeTokeniAc(baglanti);
            if (yenileme is null)
            {
                // The key that sealed it is gone (the key folder was lost): the token is unusable, and saying so beats failing again every round.
                gunluk.LogWarning("The stored Google refresh token cannot be opened (the Data Protection key changed?). Reconnecting is needed.");
                await YenidenBaglanIsaretleAsync(db, baglanti.YenilemeTokeni, ct);
                return new ErisimSonucu(ErisimDurumu.YenidenBaglan);
            }

            try
            {
                var yeni = await istemci.ErisimTokeniAlAsync(yenileme, ct);
                _onbellek = yeni;
                return new ErisimSonucu(ErisimDurumu.Tamam, yeni.Token);
            }
            catch (GoogleYetkiGecersizException e)
            {
                gunluk.LogWarning(e, "Google refused the stored refresh token. Reconnecting is needed.");
                _onbellek = null;
                await YenidenBaglanIsaretleAsync(db, baglanti.YenilemeTokeni, ct);
                return new ErisimSonucu(ErisimDurumu.YenidenBaglan);
            }
        }
        finally
        {
            _kilit.Release();
        }
    }

    // Only the token that failed is marked: a connect made a moment ago (a new token in the row) is left alone.
    private static Task<int> YenidenBaglanIsaretleAsync(AppDbContext db, string basarisizMuhurlu, CancellationToken ct) =>
        db.GoogleBaglantilari.Where(b => b.YenilemeTokeni == basarisizMuhurlu && b.Durum == GoogleBaglantiDurumu.Bagli)
            .ExecuteUpdateAsync(s => s.SetProperty(b => b.Durum, GoogleBaglantiDurumu.YenidenBaglan), ct);

    private static string? Ac(IDataProtector koruyucu, string muhurlu)
    {
        try
        {
            return koruyucu.Unprotect(muhurlu);
        }
        catch (CryptographicException)
        {
            return null;
        }
    }
}
