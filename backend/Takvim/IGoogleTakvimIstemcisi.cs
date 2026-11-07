namespace Kafamdakiler.Takvim;

// What the app needs from Google, and nothing more. Everything that touches the network sits behind this one interface, so the
// tests run the whole module on a fake and never call Google. The real one is GoogleTakvimIstemcisi.

public record GoogleTokenSonucu(string? YenilemeTokeni, string ErisimTokeni, DateTimeOffset BitisAni, IReadOnlyList<string> Kapsamlar);

public record GoogleErisimTokeni(string Token, DateTimeOffset BitisAni);

// A moment of an event: an instant (timed) or a civil date (all-day). Exactly one is set.
public record GoogleZaman(DateTimeOffset? An, DateOnly? Gun)
{
    public bool TumGun => Gun is not null;
}

// `Durum` is Google's own: confirmed, tentative or cancelled. A cancelled one in a sync answer is a deletion.
public record GoogleEtkinlik(string Kimlik, string? Etag, string Durum, string? Baslik, GoogleZaman? Baslangic, GoogleZaman? Bitis, string? Yer)
{
    public bool Iptal => Durum == "cancelled";
}

public record GoogleEtkinlikGirdisi(string Baslik, GoogleZaman Baslangic, GoogleZaman Bitis, string? Yer);

// With a SyncToken the window (ZamanMin/ZamanMax) must not be sent: Google keeps the one the first full sync had.
public record GoogleListeIstegi(string Takvim, string? SyncToken, DateTimeOffset? ZamanMin, DateTimeOffset? ZamanMax, string? SayfaToken);

public record GoogleEtkinlikSayfasi(IReadOnlyList<GoogleEtkinlik> Etkinlikler, string? SonrakiSayfaToken, string? SonrakiSyncToken);

// Google refused the token or the credentials (invalid_grant, 401): the person has to connect again.
public class GoogleYetkiGecersizException(string mesaj, Exception? ic = null) : Exception(mesaj, ic);

// 410: the sync token is too old. The sync starts over with a full one.
public class GoogleSyncTokenGecersizException(Exception? ic = null) : Exception("Google sync token is no longer valid.", ic);

// 412: the event is not the version the caller saw (its etag changed), so nothing was written.
public class GoogleEtagUyusmazligiException(Exception? ic = null) : Exception("The event changed on Google since it was read.", ic);

public interface IGoogleTakvimIstemcisi
{
    // The authorization code of the callback, with the PKCE verifier that belongs to this connect.
    Task<GoogleTokenSonucu> KodlaTokenAlAsync(string kod, string kodDogrulayici, string donusAdresi, CancellationToken ct);

    // A new access token from the refresh token. Throws GoogleYetkiGecersizException when Google refuses it.
    Task<GoogleErisimTokeni> ErisimTokeniAlAsync(string yenilemeTokeni, CancellationToken ct);

    // Revokes a token at Google; false when Google did not accept the call.
    Task<bool> TokeniIptalEtAsync(string token, CancellationToken ct);

    // Throws GoogleSyncTokenGecersizException on 410.
    Task<GoogleEtkinlikSayfasi> EtkinlikleriListeleAsync(GoogleListeIstegi istek, string erisimToken, CancellationToken ct);

    // Null when the event is gone (404/410).
    Task<GoogleEtkinlik?> EtkinlikGetirAsync(string takvim, string kimlik, string erisimToken, CancellationToken ct);

    Task<GoogleEtkinlik> EtkinlikEkleAsync(string takvim, GoogleEtkinlikGirdisi girdi, string erisimToken, CancellationToken ct);

    // Sent with If-Match: GoogleEtagUyusmazligiException when the event is no longer at that etag.
    Task EtkinlikSilAsync(string takvim, string kimlik, string etag, string erisimToken, CancellationToken ct);

    // events.patch with If-Match, on the start and the end only. Returns the event as it is after the change.
    Task<GoogleEtkinlik> EtkinlikTasiAsync(string takvim, string kimlik, GoogleZaman baslangic, GoogleZaman bitis, string etag, string erisimToken, CancellationToken ct);
}
