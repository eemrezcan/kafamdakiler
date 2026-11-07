using System.Globalization;
using Kafamdakiler.Takvim;

namespace Kafamdakiler.Tests;

// A fake Google: the same contract as the real client (IGoogleTakvimIstemcisi), kept in memory. It behaves like the parts of Google the
// app leans on: events have etags that change with every write, a delete leaves a "cancelled" tombstone, an incremental list returns what
// changed since a sync token (and refuses the window options when a token is sent), If-Match is honoured. No call in the tests goes
// to Google; this is the only thing that answers.
public sealed class SahteGoogle : IGoogleTakvimIstemcisi
{
    public const string YenilemeTokeni = "yenileme-gizli-1";

    private readonly Lock _kilit = new();
    private readonly Dictionary<string, Dictionary<string, Kayit>> _takvimler = new(StringComparer.Ordinal);
    private int _sayac;
    private long _surum;
    private int _erisimSayaci;

    private sealed record Kayit(GoogleEtkinlik Etkinlik, long Surum);

    // What was asked of Google, in order and in detail.
    public List<string> Cagrilar { get; } = [];
    public List<(string Kod, string Dogrulayici, string Donus)> KodCagrilari { get; } = [];
    public List<GoogleListeIstegi> ListeIstekleri { get; } = [];
    public List<string> IptalEdilenler { get; } = [];
    public List<string> KullanilanErisimTokenleri { get; } = [];

    // How the fake answers.
    public GoogleTokenSonucu TokenSonucu { get; set; } = new(
        YenilemeTokeni, "erisim-ilk", DateTimeOffset.UtcNow.AddHours(1), [.. TakvimAyari.Kapsamlar]);
    public bool KodGecersiz { get; set; }
    public bool YenilemeGecersiz { get; set; }
    public bool IptalHatasi { get; set; }
    public bool SyncTokenEskidi { get; set; }
    public int SayfaBuyuklugu { get; set; } = 100;
    // The page (0, 1, ...) of a list at which the fake fails, as a network error halfway through would.
    public int? HataSayfasi { get; set; }
    public DateTimeOffset ErisimBitisi { get; set; } = DateTimeOffset.UtcNow.AddHours(1);
    // Runs inside a delete or a move, just before it checks the etag: the person editing the event at the worst moment.
    public Action? YazmadanOnce { get; set; }

    // The person's own edits on Google, outside the app.

    public GoogleEtkinlik Olustur(string takvim, string kimlik, string baslik, GoogleZaman bas, GoogleZaman bit, string? yer = null)
    {
        lock (_kilit)
        {
            var etkinlik = new GoogleEtkinlik(kimlik, YeniEtag(), "confirmed", baslik, bas, bit, yer);
            Yaz(takvim, etkinlik);
            return etkinlik;
        }
    }

    public GoogleEtkinlik Degistir(string takvim, string kimlik, string yeniBaslik)
    {
        lock (_kilit)
        {
            var mevcut = Al(takvim, kimlik) ?? throw new InvalidOperationException("No such event in the fake.");
            var yeni = mevcut with { Baslik = yeniBaslik, Etag = YeniEtag() };
            Yaz(takvim, yeni);
            return yeni;
        }
    }

    public void Kaldir(string takvim, string kimlik)
    {
        lock (_kilit)
        {
            var mevcut = Al(takvim, kimlik) ?? throw new InvalidOperationException("No such event in the fake.");
            Yaz(takvim, mevcut with { Durum = "cancelled", Etag = YeniEtag() });
        }
    }

    public GoogleEtkinlik? Bak(string takvim, string kimlik)
    {
        lock (_kilit)
        {
            return Al(takvim, kimlik);
        }
    }

    public IReadOnlyList<GoogleEtkinlik> Canlilar(string takvim)
    {
        lock (_kilit)
        {
            return _takvimler.GetValueOrDefault(takvim)?.Values.Select(k => k.Etkinlik).Where(e => !e.Iptal).ToList() ?? [];
        }
    }

    // IGoogleTakvimIstemcisi

    public Task<GoogleTokenSonucu> KodlaTokenAlAsync(string kod, string kodDogrulayici, string donusAdresi, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("kod");
            KodCagrilari.Add((kod, kodDogrulayici, donusAdresi));
            return KodGecersiz ? throw new GoogleYetkiGecersizException("fake: bad code") : Task.FromResult(TokenSonucu);
        }
    }

    public Task<GoogleErisimTokeni> ErisimTokeniAlAsync(string yenilemeTokeni, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("erisim");
            if (YenilemeGecersiz || yenilemeTokeni != YenilemeTokeni)
                throw new GoogleYetkiGecersizException("fake: invalid_grant");

            return Task.FromResult(new GoogleErisimTokeni($"erisim-{++_erisimSayaci}", ErisimBitisi));
        }
    }

    public Task<bool> TokeniIptalEtAsync(string token, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("iptal");
            IptalEdilenler.Add(token);
            return Task.FromResult(!IptalHatasi);
        }
    }

    public Task<GoogleEtkinlikSayfasi> EtkinlikleriListeleAsync(GoogleListeIstegi istek, string erisimToken, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("liste");
            ListeIstekleri.Add(istek);
            KullanilanErisimTokenleri.Add(erisimToken);

            IEnumerable<GoogleEtkinlik> secilen;
            var kayitlar = _takvimler.GetValueOrDefault(istek.Takvim)?.Values ?? (IEnumerable<Kayit>)[];
            if (istek.SyncToken is null)
            {
                if (istek.ZamanMin is null || istek.ZamanMax is null)
                    throw new InvalidOperationException("fake: a full list needs the window.");
                secilen = kayitlar.Where(k => !k.Etkinlik.Iptal).OrderBy(k => k.Surum).Select(k => k.Etkinlik).ToList();
            }
            else
            {
                // Google refuses the window options next to a sync token.
                if (istek.ZamanMin is not null || istek.ZamanMax is not null)
                    throw new InvalidOperationException("fake: the window must not be sent with a sync token.");
                if (SyncTokenEskidi)
                    throw new GoogleSyncTokenGecersizException();

                var surum = long.Parse(istek.SyncToken["sync-".Length..], CultureInfo.InvariantCulture);
                secilen = kayitlar.Where(k => k.Surum > surum).OrderBy(k => k.Surum).Select(k => k.Etkinlik).ToList();
            }

            var liste = secilen.ToList();
            var bas = istek.SayfaToken is null ? 0 : int.Parse(istek.SayfaToken[1..], CultureInfo.InvariantCulture);
            if (HataSayfasi is { } hata && bas / SayfaBuyuklugu == hata)
                throw new HttpRequestException("fake: network error");

            var sayfa = liste.Skip(bas).Take(SayfaBuyuklugu).ToList();
            return Task.FromResult(bas + SayfaBuyuklugu < liste.Count
                ? new GoogleEtkinlikSayfasi(sayfa, $"p{bas + SayfaBuyuklugu}", null)
                : new GoogleEtkinlikSayfasi(sayfa, null, $"sync-{_surum}"));
        }
    }

    public Task<GoogleEtkinlik?> EtkinlikGetirAsync(string takvim, string kimlik, string erisimToken, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("getir");
            return Task.FromResult(Al(takvim, kimlik));
        }
    }

    public Task<GoogleEtkinlik> EtkinlikEkleAsync(string takvim, GoogleEtkinlikGirdisi girdi, string erisimToken, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("ekle");
            KullanilanErisimTokenleri.Add(erisimToken);
            var etkinlik = new GoogleEtkinlik($"ev{++_sayac}", YeniEtag(), "confirmed", girdi.Baslik, girdi.Baslangic, girdi.Bitis, girdi.Yer);
            Yaz(takvim, etkinlik);
            return Task.FromResult(etkinlik);
        }
    }

    public Task EtkinlikSilAsync(string takvim, string kimlik, string etag, string erisimToken, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("sil");
            YazmadanOnce?.Invoke();
            var mevcut = Al(takvim, kimlik) ?? throw new InvalidOperationException("fake: no such event");
            if (mevcut.Etag != etag)
                throw new GoogleEtagUyusmazligiException();

            Yaz(takvim, mevcut with { Durum = "cancelled", Etag = YeniEtag() });
            return Task.CompletedTask;
        }
    }

    public Task<GoogleEtkinlik> EtkinlikTasiAsync(string takvim, string kimlik, GoogleZaman baslangic, GoogleZaman bitis, string etag, string erisimToken, CancellationToken ct)
    {
        lock (_kilit)
        {
            Cagrilar.Add("tasi");
            YazmadanOnce?.Invoke();
            var mevcut = Al(takvim, kimlik) ?? throw new InvalidOperationException("fake: no such event");
            if (mevcut.Etag != etag)
                throw new GoogleEtagUyusmazligiException();

            var yeni = mevcut with { Baslangic = baslangic, Bitis = bitis, Etag = YeniEtag() };
            Yaz(takvim, yeni);
            return Task.FromResult(yeni);
        }
    }

    private GoogleEtkinlik? Al(string takvim, string kimlik) => _takvimler.GetValueOrDefault(takvim)?.GetValueOrDefault(kimlik)?.Etkinlik;

    private void Yaz(string takvim, GoogleEtkinlik etkinlik)
    {
        if (!_takvimler.TryGetValue(takvim, out var sozluk))
            _takvimler[takvim] = sozluk = new Dictionary<string, Kayit>(StringComparer.Ordinal);

        sozluk[etkinlik.Kimlik] = new Kayit(etkinlik, ++_surum);
    }

    private string YeniEtag() => $"\"etag-{++_sayac}\"";

    // A moment in Istanbul time (UTC+3) as Google's own shape, and an all-day date.
    public static GoogleZaman Ist(int yil, int ay, int gun, int saat, int dakika = 0) =>
        new(new DateTimeOffset(yil, ay, gun, saat, dakika, 0, TimeSpan.FromHours(3)), null);

    public static GoogleZaman Gun(int yil, int ay, int gun) => new(null, new DateOnly(yil, ay, gun));
}
