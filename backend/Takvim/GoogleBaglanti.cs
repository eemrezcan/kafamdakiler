using System.Buffers.Text;
using System.Security.Cryptography;
using System.Text;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Requests;
using Kafamdakiler.Claude;
using Kafamdakiler.Data;
using Kafamdakiler.Gmail;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Takvim;

public enum BaglantiSonucuTuru
{
    Tamam,
    // The Google settings are not all there.
    Kapali,
    // No such state, a state already used, or none sent.
    StateGecersiz,
    StateSuresiDolmus,
    // The state belongs to another person's connect.
    KullaniciUyusmuyor,
    // The person said no at Google's consent screen (or Google returned an error).
    Reddedildi,
    // Google granted less than the app needs (the consent screen lets a person untick scopes).
    EksikIzin,
    // The code did not work, or Google sent no refresh token.
    KodGecersiz,
}

public record BaglantiSonucu(BaglantiSonucuTuru Tur)
{
    public bool Basarili => Tur == BaglantiSonucuTuru.Tamam;
}

public record BaglantiKesmeSonucu(bool BaglantiVardi, bool GoogleIptal);

// `Durum`: kapali (settings missing), bagliDegil, bagli, yenidenBaglan. The token itself is never in here.
// `Gmail`: kapali (off in the settings, or Google or Claude not set up, or no account connected), izinYok (connected, but without the
// Gmail scope or the connection needs reconnecting: "Gmail için yeniden bağla"), acik. `GmailSonTarama` is when the scan last got as far
// as asking Gmail (empty after a restart until the next round); `GmailIslenen` is how many mails it has dealt with.
public record GoogleDurumDto(
    bool Acik, string Durum, DateTimeOffset? BaglananAni, IReadOnlyList<string> Takvimler, DateTimeOffset? SonEsitleme, int EtkinlikSayisi,
    string Gmail = "kapali", DateTimeOffset? GmailSonTarama = null, int GmailIslenen = 0);

// Connecting the Google account (K2.3c): OAuth 2.0 authorization code with PKCE. The rules of it, in one place:
//  - `state` is 256 random bits, kept only as its SHA-256, good for one callback within BaglantiSuresi, and bound to the Sahip who
//    started it. A callback with any other state, an expired one, one already used, or another person's is refused.
//  - the PKCE verifier is made here, sealed in the database, and sent to Google only in the code exchange; the address carries the
//    S256 challenge only.
//  - the refresh token is sealed with Data Protection before it is stored, and only the scopes the app asked for are accepted.
public class GoogleBaglanti(
    AppDbContext db, IGoogleTakvimIstemcisi istemci, GoogleErisimi erisim, TakvimAyari ayar, GmailAyari gmailAyar, ClaudeAyari claudeAyar,
    GmailTaramaDurumu gmailDurumu, TimeProvider saat, ILogger<GoogleBaglanti> gunluk)
{
    // A connect has to be finished within this.
    public static readonly TimeSpan BaglantiSuresi = TimeSpan.FromMinutes(10);

    // The longest `state` a callback may send before it is dropped without a lookup.
    private const int StateEnUzun = 200;

    // The address of Google's consent screen for the Sahip `kullaniciId`; null when the module is off.
    public async Task<Uri?> BaslatAsync(Guid kullaniciId, CancellationToken ct)
    {
        if (!ayar.Acik)
            return null;

        var simdi = saat.GetUtcNow();
        // Old unfinished connects go; so does an earlier one of this person: only the latest link works.
        await db.GoogleYetkilendirmeleri.Where(y => y.BitisAni < simdi || y.KullaniciId == kullaniciId).ExecuteDeleteAsync(ct);

        var state = Rastgele(32);
        var dogrulayici = Rastgele(64);
        db.GoogleYetkilendirmeleri.Add(new GoogleYetkilendirmesi
        {
            StateOzeti = Ozet(state),
            KodDogrulayici = erisim.DogrulayiciMuhurle(dogrulayici),
            KullaniciId = kullaniciId,
            BitisAni = simdi + BaglantiSuresi,
        });
        await db.SaveChangesAsync(ct);

        return YetkiAdresi(ayar, state, Meydanokuma(dogrulayici));
    }

    // The consent address. Pure: no network.
    public static Uri YetkiAdresi(TakvimAyari ayar, string state, string kodMeydanOkumasi) =>
        new GoogleAuthorizationCodeRequestUrl(new Uri(GoogleAuthConsts.AuthorizationUrl))
        {
            ClientId = ayar.ClientId,
            RedirectUri = ayar.DonusAdresi,
            Scope = string.Join(' ', TakvimAyari.Kapsamlar),
            State = state,
            // offline + consent: Google returns a refresh token every time, not only the first.
            AccessType = "offline",
            Prompt = "consent",
            CodeChallenge = kodMeydanOkumasi,
            CodeChallengeMethod = "S256",
        }.Build();

    public async Task<BaglantiSonucu> TamamlaAsync(Guid kullaniciId, string? state, string? kod, string? googleHatasi, CancellationToken ct)
    {
        if (!ayar.Acik)
            return new BaglantiSonucu(BaglantiSonucuTuru.Kapali);
        if (string.IsNullOrEmpty(state) || state.Length > StateEnUzun)
            return new BaglantiSonucu(BaglantiSonucuTuru.StateGecersiz);

        // The row is taken first and deleted at once: a state works one time, whatever happens after.
        var ozet = Ozet(state);
        var satir = await db.GoogleYetkilendirmeleri.AsNoTracking().FirstOrDefaultAsync(y => y.StateOzeti == ozet, ct);
        if (satir is null || await db.GoogleYetkilendirmeleri.Where(y => y.StateOzeti == ozet).ExecuteDeleteAsync(ct) != 1)
            return new BaglantiSonucu(BaglantiSonucuTuru.StateGecersiz);

        if (satir.BitisAni < saat.GetUtcNow())
            return new BaglantiSonucu(BaglantiSonucuTuru.StateSuresiDolmus);
        if (satir.KullaniciId != kullaniciId)
            return new BaglantiSonucu(BaglantiSonucuTuru.KullaniciUyusmuyor);
        if (!string.IsNullOrEmpty(googleHatasi))
            return new BaglantiSonucu(BaglantiSonucuTuru.Reddedildi);
        if (string.IsNullOrEmpty(kod))
            return new BaglantiSonucu(BaglantiSonucuTuru.KodGecersiz);

        var dogrulayici = erisim.DogrulayiciAc(satir.KodDogrulayici);
        if (dogrulayici is null)
            return new BaglantiSonucu(BaglantiSonucuTuru.KodGecersiz);

        GoogleTokenSonucu token;
        try
        {
            token = await istemci.KodlaTokenAlAsync(kod, dogrulayici, ayar.DonusAdresi, ct);
        }
        catch (GoogleYetkiGecersizException)
        {
            gunluk.LogWarning("Google did not accept the authorization code of the callback.");
            return new BaglantiSonucu(BaglantiSonucuTuru.KodGecersiz);
        }

        // Granted scopes are checked against what the calendar needs, not trusted to be what was asked. The Gmail scope is not required:
        // the consent screen lets a person untick it, and the connection then works for the calendar with Gmail in "izinYok".
        if (TakvimAyari.TakvimKapsamlari.Any(k => !token.Kapsamlar.Contains(k, StringComparer.Ordinal)))
        {
            gunluk.LogWarning("Google granted fewer scopes than the calendar module needs; the connection was not made.");
            await IptalEtmeyiDeneAsync(token.YenilemeTokeni ?? token.ErisimTokeni, ct);
            return new BaglantiSonucu(BaglantiSonucuTuru.EksikIzin);
        }

        if (string.IsNullOrEmpty(token.YenilemeTokeni))
        {
            gunluk.LogWarning("Google returned no refresh token; the connection was not made.");
            await IptalEtmeyiDeneAsync(token.ErisimTokeni, ct);
            return new BaglantiSonucu(BaglantiSonucuTuru.KodGecersiz);
        }

        // The calendar kept so far may belong to another account: it goes, and the first sync fills it again.
        await using var islem = await db.Database.BeginTransactionAsync(ct);
        await db.TakvimEtkinlikleri.ExecuteDeleteAsync(ct);
        await db.TakvimEsitlemeleri.ExecuteDeleteAsync(ct);

        var baglanti = await db.GoogleBaglantilari.FirstOrDefaultAsync(ct);
        if (baglanti is null)
        {
            baglanti = new GoogleBaglantisi();
            db.GoogleBaglantilari.Add(baglanti);
        }

        baglanti.YenilemeTokeni = erisim.TokenMuhurle(token.YenilemeTokeni);
        baglanti.Durum = GoogleBaglantiDurumu.Bagli;
        baglanti.Kapsamlar = string.Join(' ', token.Kapsamlar);
        baglanti.BaglananAni = saat.GetUtcNow();
        baglanti.BaglayanId = kullaniciId;
        await db.SaveChangesAsync(ct);
        await islem.CommitAsync(ct);

        erisim.Unut();
        return new BaglantiSonucu(BaglantiSonucuTuru.Tamam);
    }

    // Cuts the connection: the token is revoked at Google (when that fails the local copy still goes, and the answer says so),
    // then the token, the synced events and the half-finished connects are deleted.
    public async Task<BaglantiKesmeSonucu> KesAsync(CancellationToken ct)
    {
        var baglanti = await db.GoogleBaglantilari.AsNoTracking().FirstOrDefaultAsync(ct);
        var iptal = false;
        if (baglanti is not null && erisim.YenilemeTokeniAc(baglanti) is { } acik)
            iptal = await IptalEtmeyiDeneAsync(acik, ct);

        await using var islem = await db.Database.BeginTransactionAsync(ct);
        await db.GoogleBaglantilari.ExecuteDeleteAsync(ct);
        await db.GoogleYetkilendirmeleri.ExecuteDeleteAsync(ct);
        await db.TakvimEtkinlikleri.ExecuteDeleteAsync(ct);
        await db.TakvimEsitlemeleri.ExecuteDeleteAsync(ct);
        await islem.CommitAsync(ct);

        erisim.Unut();
        return new BaglantiKesmeSonucu(baglanti is not null, iptal);
    }

    public async Task<GoogleDurumDto> DurumAsync(CancellationToken ct)
    {
        var baglanti = await db.GoogleBaglantilari.AsNoTracking().FirstOrDefaultAsync(ct);
        var durum = !ayar.Acik ? "kapali"
            : baglanti is null ? "bagliDegil"
            : baglanti.Durum == GoogleBaglantiDurumu.Bagli ? "bagli"
            : "yenidenBaglan";
        var sonEsitleme = await db.TakvimEsitlemeleri.AsNoTracking().MaxAsync(e => e.SonEsitleme, ct);
        var sayi = await db.TakvimEtkinlikleri.CountAsync(ct);

        var gmail = !gmailAyar.Acik || !ayar.Acik || !claudeAyar.Acik || baglanti is null ? "kapali"
            : baglanti.Durum != GoogleBaglantiDurumu.Bagli || !baglanti.KapsamVar(TakvimAyari.GmailKapsami) ? "izinYok"
            : "acik";
        var gmailIslenen = await db.GmailMesajlari.CountAsync(m => m.Sonuc != GmailSonucu.Hata, ct);
        return new GoogleDurumDto(ayar.Acik, durum, baglanti?.BaglananAni, ayar.Takvimler, sonEsitleme, sayi, gmail, gmailDurumu.SonTarama, gmailIslenen);
    }

    private async Task<bool> IptalEtmeyiDeneAsync(string token, CancellationToken ct)
    {
        try
        {
            return await istemci.TokeniIptalEtAsync(token, ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            // The exception text can carry the request; the log says only that it failed.
            gunluk.LogWarning("Revoking the Google token failed ({Tur}).", e.GetType().Name);
            return false;
        }
    }

    private static string Rastgele(int bayt) => Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(bayt));

    private static string Ozet(string state) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(state)));

    // S256: BASE64URL(SHA256(ASCII(verifier))), no padding (RFC 7636 section 4.2).
    public static string Meydanokuma(string dogrulayici) => Base64Url.EncodeToString(SHA256.HashData(Encoding.ASCII.GetBytes(dogrulayici)));
}
