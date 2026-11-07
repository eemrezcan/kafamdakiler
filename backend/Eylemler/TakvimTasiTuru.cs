using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Takvim;

namespace Kafamdakiler.Eylemler;

// What undo needs: the event, the etag it has after the move, and the time it had before.
public record TakvimTasiGeriAlmaBilgisi(string Takvim, string Kimlik, string? EtagSonra, GoogleZaman EskiBaslangic, GoogleZaman EskiBitis);

// "takvim-tasi": moves an event to a new time (events.patch on the start and the end, sent with If-Match so an event edited between
// the read and the write is not overwritten). Undo patches the old time back, and only while the event is still as the move left it.
// A timed event stays timed and an all-day one stays all-day.
public class TakvimTasiTuru(TakvimAyari ayar, GoogleErisimi erisim, IGoogleTakvimIstemcisi istemci, ILogger<TakvimTasiTuru> gunluk) : IEylemTuru
{
    public const string Anahtar = "takvim-tasi";

    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public string Ad => Anahtar;

    public string GorunenAd => "Takvim etkinliğini taşı";

    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _, out _, out _, out _);

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var takvim, out var kimlik, out var yeniBas, out var yeniBit);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        var token = await erisim.TokenAlAsync(ct);
        if (!token.Basarili)
            throw new InvalidOperationException(token.Mesaj);

        try
        {
            var etkinlik = await istemci.EtkinlikGetirAsync(takvim, kimlik, token.Token!, ct);
            if (etkinlik is null || etkinlik.Iptal)
                throw new InvalidOperationException("Etkinlik Google'da bulunamadı.");
            if (etkinlik.Baslangic is not { } eskiBas || etkinlik.Bitis is not { } eskiBit || etkinlik.Etag is null)
                throw new InvalidOperationException("Etkinliğin zamanı okunamadı.");
            if (eskiBas.TumGun != yeniBas!.TumGun)
                throw new InvalidOperationException("Etkinliğin türü (tüm gün ya da saatli) değiştirilemez.");

            var tasinan = await istemci.EtkinlikTasiAsync(takvim, kimlik, yeniBas, yeniBit!, etkinlik.Etag, token.Token!, ct);
            if (tasinan.Etag is null)
                gunluk.LogWarning("Google returned no etag for the moved event; the undo of this action will be refused.");

            return JsonSerializer.SerializeToElement(new TakvimTasiGeriAlmaBilgisi(takvim, kimlik, tasinan.Etag, eskiBas, eskiBit), JsonSerializerOptions.Web);
        }
        catch (GoogleEtagUyusmazligiException)
        {
            throw new InvalidOperationException("Etkinlik okunduktan sonra Google'da değişti; taşınmadı.");
        }
        catch (GoogleYetkiGecersizException)
        {
            erisim.Unut();
            throw new InvalidOperationException("Google erişimi reddetti.");
        }
    }

    public async Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct)
    {
        var bilgi = geriAlmaBilgisi.Deserialize<TakvimTasiGeriAlmaBilgisi>(JsonSerializerOptions.Web)
            ?? throw new InvalidOperationException("Geri alma bilgisi okunamadı.");

        var token = await erisim.TokenAlAsync(ct);
        if (!token.Basarili)
            throw new InvalidOperationException(token.Mesaj);

        const string Cakisma = "Etkinlik Google'da sonradan değiştirilmiş; eski zamanına döndürülmedi.";
        try
        {
            var etkinlik = await istemci.EtkinlikGetirAsync(bilgi.Takvim, bilgi.Kimlik, token.Token!, ct);
            // Gone (the person deleted it): there is no time to restore.
            if (etkinlik is null || etkinlik.Iptal)
                return;
            if (bilgi.EtagSonra is null || etkinlik.Etag != bilgi.EtagSonra)
                throw new GeriAlmaCatismasiException(Cakisma);

            await istemci.EtkinlikTasiAsync(bilgi.Takvim, bilgi.Kimlik, bilgi.EskiBaslangic, bilgi.EskiBitis, bilgi.EtagSonra, token.Token!, ct);
        }
        catch (GoogleEtagUyusmazligiException)
        {
            throw new GeriAlmaCatismasiException(Cakisma);
        }
        catch (GoogleYetkiGecersizException)
        {
            erisim.Unut();
            throw new InvalidOperationException("Google erişimi reddetti.");
        }
    }

    private Sonuc Coz(JsonElement yuk, out string takvim, out string kimlik, out GoogleZaman? bas, out GoogleZaman? bit)
    {
        takvim = ayar.VarsayilanTakvim;
        kimlik = "";
        bas = bit = null;

        TakvimTasiYuku? y;
        try
        {
            y = yuk.Deserialize<TakvimTasiYuku>(Secenekler);
        }
        catch (JsonException e)
        {
            return Sonuc.Gecersiz("yuk", $"Yük takvim etkinliği biçimine uymuyor ({e.Path}).");
        }

        if (y is null || y.Kimlik is null)
            return Sonuc.Gecersiz("yuk", "Yük kimlik içermeli.");

        var sonuc = TakvimYukuDenetimi.Acik(ayar);
        if (!sonuc.Basarili)
            return sonuc;
        sonuc = TakvimYukuDenetimi.Takvim(y.Takvim, ayar, out takvim);
        if (!sonuc.Basarili)
            return sonuc;
        sonuc = TakvimYukuDenetimi.Kimlik(y.Kimlik, out kimlik);
        if (!sonuc.Basarili)
            return sonuc;

        return TakvimYukuDenetimi.Zaman(y.TumGun, y.Baslangic, y.Bitis, y.Gun, y.BitisGunu, out bas, out bit);
    }
}
