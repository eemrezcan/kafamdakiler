namespace Kafamdakiler.Takvim;

public enum GoogleBaglantiDurumu
{
    Bagli,
    // Google refused the stored token (revoked, expired, or the key that sealed it is gone): the Sahip has to connect again.
    YenidenBaglan,
}

// The one connection to a Google account (single user: the row's key is always 1). The refresh token is stored sealed by
// Data Protection and never leaves the server; nothing reads it except GoogleErisimi and GoogleBaglanti.
public class GoogleBaglantisi
{
    public int Id { get; set; } = 1;
    public string YenilemeTokeni { get; set; } = "";
    public GoogleBaglantiDurumu Durum { get; set; } = GoogleBaglantiDurumu.Bagli;
    // The scopes Google says it granted, space separated.
    public string Kapsamlar { get; set; } = "";
    public DateTimeOffset BaglananAni { get; set; }
    public Guid? BaglayanId { get; set; }

    // Whether Google granted this scope to the stored token.
    public bool KapsamVar(string kapsam) => Kapsamlar.Split(' ', StringSplitOptions.RemoveEmptyEntries).Contains(kapsam, StringComparer.Ordinal);
}

// A connect that was started and not finished. `state` is kept only as its SHA-256 (a copy of the database does not give a
// working callback link); the PKCE code verifier is sealed. A row is good for one callback, within BaglantiSuresi.
public class GoogleYetkilendirmesi
{
    public string StateOzeti { get; set; } = "";
    public string KodDogrulayici { get; set; } = "";
    public Guid KullaniciId { get; set; }
    public DateTimeOffset BitisAni { get; set; }
}

// Where the incremental sync of one calendar stands.
public class TakvimEsitlemeDurumu
{
    public string TakvimKimligi { get; set; } = "";
    public string? SyncToken { get; set; }
    // The last full sync: a full one runs at least once a day so the 60-day window keeps moving.
    public DateTimeOffset? SonTamEsitleme { get; set; }
    public DateTimeOffset? SonEsitleme { get; set; }
}

// A Google event as the app keeps it. An all-day event has TumGun and civil dates (BitisGunu is exclusive, as in Google);
// a timed one has instants. Baslangic/Bitis are instants either way (an all-day event: midnight Istanbul), so one range query serves both.
public class TakvimEtkinligi
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public string TakvimKimligi { get; set; } = "";
    public string GoogleKimligi { get; set; } = "";
    public string Baslik { get; set; } = "";
    public DateTimeOffset Baslangic { get; set; }
    public DateTimeOffset Bitis { get; set; }
    public bool TumGun { get; set; }
    public DateOnly BaslangicGunu { get; set; }
    public DateOnly BitisGunu { get; set; }
    public string? Yer { get; set; }
    public string? Etag { get; set; }
    public DateTimeOffset GuncellemeAni { get; set; }
}
