using System.Globalization;
using System.Net;
using Google;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Flows;
using Google.Apis.Auth.OAuth2.Responses;
using Google.Apis.Calendar.v3;
using Google.Apis.Calendar.v3.Data;
using Google.Apis.Services;
using Google.Apis.Util.Store;

namespace Kafamdakiler.Takvim;

// The real thing: Google's own .NET clients (Google.Apis.Auth and Google.Apis.Calendar.v3). The tests never reach this class; they
// run on a fake IGoogleTakvimIstemcisi, so no call in the tests goes to Google.
public class GoogleTakvimIstemcisi(TakvimAyari ayar) : IGoogleTakvimIstemcisi
{
    private const string UygulamaAdi = "Kafamdakiler";

    // The flow wants a user key for its store; there is one user and, below, no store at all.
    private const string KullaniciAnahtari = "sahip";

    private const int SayfaBuyuklugu = 250;

    // The flow's default store is a file under the user profile that keeps the tokens in clear text. The app keeps its token in the
    // database, sealed, so this one is told to keep nothing.
    private PkceGoogleAuthorizationCodeFlow Akis() => new(new GoogleAuthorizationCodeFlow.Initializer
    {
        ClientSecrets = new ClientSecrets { ClientId = ayar.ClientId, ClientSecret = ayar.ClientSecret },
        Scopes = TakvimAyari.Kapsamlar,
        DataStore = new NullDataStore(),
    });

    private static CalendarService Servis(string erisimToken) => new(new BaseClientService.Initializer
    {
        HttpClientInitializer = GoogleCredential.FromAccessToken(erisimToken),
        ApplicationName = UygulamaAdi,
    });

    public async Task<GoogleTokenSonucu> KodlaTokenAlAsync(string kod, string kodDogrulayici, string donusAdresi, CancellationToken ct)
    {
        using var akis = Akis();
        TokenResponse yanit;
        try
        {
            yanit = await akis.ExchangeCodeForTokenAsync(KullaniciAnahtari, kod, kodDogrulayici, donusAdresi, ct);
        }
        catch (TokenResponseException e)
        {
            throw new GoogleYetkiGecersizException("Google did not accept the authorization code.", e);
        }

        var kapsamlar = (yanit.Scope ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var bitis = yanit.IssuedUtc.AddSeconds(yanit.ExpiresInSeconds ?? 3600);
        return new GoogleTokenSonucu(yanit.RefreshToken, yanit.AccessToken, new DateTimeOffset(bitis, TimeSpan.Zero), kapsamlar);
    }

    public async Task<GoogleErisimTokeni> ErisimTokeniAlAsync(string yenilemeTokeni, CancellationToken ct)
    {
        using var akis = Akis();
        try
        {
            var yanit = await akis.RefreshTokenAsync(KullaniciAnahtari, yenilemeTokeni, ct);
            var bitis = yanit.IssuedUtc.AddSeconds(yanit.ExpiresInSeconds ?? 3600);
            return new GoogleErisimTokeni(yanit.AccessToken, new DateTimeOffset(bitis, TimeSpan.Zero));
        }
        catch (TokenResponseException e) when (e.Error?.Error is "invalid_grant" or "invalid_client" or "unauthorized_client")
        {
            throw new GoogleYetkiGecersizException("Google refused the refresh token.", e);
        }
    }

    public async Task<bool> TokeniIptalEtAsync(string token, CancellationToken ct)
    {
        using var akis = Akis();
        try
        {
            // No exception is Google saying it revoked the token.
            await akis.RevokeTokenAsync(KullaniciAnahtari, token, ct);
            return true;
        }
        catch (TokenResponseException)
        {
            return false;
        }
    }

    public async Task<GoogleEtkinlikSayfasi> EtkinlikleriListeleAsync(GoogleListeIstegi istek, string erisimToken, CancellationToken ct)
    {
        using var servis = Servis(erisimToken);
        var liste = servis.Events.List(istek.Takvim);
        liste.MaxResults = SayfaBuyuklugu;
        liste.PageToken = istek.SayfaToken;
        // Recurring events come as their separate instances, so each row is one occurrence.
        liste.SingleEvents = true;
        if (istek.SyncToken is not null)
        {
            // Google keeps the window and the other options of the first full sync inside the token; sending them again is an error.
            liste.SyncToken = istek.SyncToken;
            liste.ShowDeleted = true;
        }
        else
        {
            liste.TimeMinDateTimeOffset = istek.ZamanMin;
            liste.TimeMaxDateTimeOffset = istek.ZamanMax;
        }

        try
        {
            var yanit = await liste.ExecuteAsync(ct);
            return new GoogleEtkinlikSayfasi((yanit.Items ?? []).Select(Cevir).ToList(), yanit.NextPageToken, yanit.NextSyncToken);
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.Gone)
        {
            throw new GoogleSyncTokenGecersizException(e);
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.Unauthorized)
        {
            throw new GoogleYetkiGecersizException("Google refused the access token.", e);
        }
    }

    public async Task<GoogleEtkinlik?> EtkinlikGetirAsync(string takvim, string kimlik, string erisimToken, CancellationToken ct)
    {
        using var servis = Servis(erisimToken);
        try
        {
            return Cevir(await servis.Events.Get(takvim, kimlik).ExecuteAsync(ct));
        }
        catch (GoogleApiException e) when (e.HttpStatusCode is HttpStatusCode.NotFound or HttpStatusCode.Gone)
        {
            return null;
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.Unauthorized)
        {
            throw new GoogleYetkiGecersizException("Google refused the access token.", e);
        }
    }

    public async Task<GoogleEtkinlik> EtkinlikEkleAsync(string takvim, GoogleEtkinlikGirdisi girdi, string erisimToken, CancellationToken ct)
    {
        using var servis = Servis(erisimToken);
        var yeni = new Event
        {
            Summary = girdi.Baslik,
            Location = girdi.Yer,
            Start = Cevir(girdi.Baslangic),
            End = Cevir(girdi.Bitis),
        };

        try
        {
            return Cevir(await servis.Events.Insert(yeni, takvim).ExecuteAsync(ct));
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.Unauthorized)
        {
            throw new GoogleYetkiGecersizException("Google refused the access token.", e);
        }
    }

    public async Task EtkinlikSilAsync(string takvim, string kimlik, string etag, string erisimToken, CancellationToken ct)
    {
        using var servis = Servis(erisimToken);
        var istek = servis.Events.Delete(takvim, kimlik);
        istek.ModifyRequest = mesaj => mesaj.Headers.TryAddWithoutValidation("If-Match", etag);

        try
        {
            await istek.ExecuteAsync(ct);
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.PreconditionFailed)
        {
            throw new GoogleEtagUyusmazligiException(e);
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.Unauthorized)
        {
            throw new GoogleYetkiGecersizException("Google refused the access token.", e);
        }
    }

    public async Task<GoogleEtkinlik> EtkinlikTasiAsync(
        string takvim, string kimlik, GoogleZaman baslangic, GoogleZaman bitis, string etag, string erisimToken, CancellationToken ct)
    {
        using var servis = Servis(erisimToken);
        var degisiklik = new Event { Start = Cevir(baslangic), End = Cevir(bitis) };
        var istek = servis.Events.Patch(degisiklik, takvim, kimlik);
        istek.ModifyRequest = mesaj => mesaj.Headers.TryAddWithoutValidation("If-Match", etag);

        try
        {
            return Cevir(await istek.ExecuteAsync(ct));
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.PreconditionFailed)
        {
            throw new GoogleEtagUyusmazligiException(e);
        }
        catch (GoogleApiException e) when (e.HttpStatusCode == HttpStatusCode.Unauthorized)
        {
            throw new GoogleYetkiGecersizException("Google refused the access token.", e);
        }
    }

    private static GoogleEtkinlik Cevir(Event e) => new(
        e.Id, e.ETag, e.Status ?? "confirmed", e.Summary, Cevir(e.Start), Cevir(e.End), e.Location);

    private static GoogleZaman? Cevir(EventDateTime? z)
    {
        if (z is null)
            return null;
        if (z.DateTimeDateTimeOffset is { } an)
            return new GoogleZaman(an, null);
        if (z.Date is { } gun && DateOnly.TryParseExact(gun, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var tarih))
            return new GoogleZaman(null, tarih);
        return null;
    }

    private static EventDateTime Cevir(GoogleZaman z) => z.Gun is { } gun
        ? new EventDateTime { Date = $"{gun:yyyy-MM-dd}" }
        : new EventDateTime { DateTimeDateTimeOffset = z.An };
}
