using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Takvim;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Eylemler;

// What undo needs: where the event is, and the etag it had when the action made it.
public record TakvimEkleGeriAlmaBilgisi(string Takvim, string Kimlik, string? Etag, string Baslik);

// "takvim-ekle": puts an event on a Google calendar (events.insert). Undo deletes it (events.delete), and only while it is still
// as the action made it: an event the person has since edited on Google (its etag changed) is left alone and the undo is
// refused with a 409. The synced copy in the database is not written here; the next sync brings the event in (one row per Google id).
public class TakvimEkleTuru(TakvimAyari ayar, GoogleErisimi erisim, IGoogleTakvimIstemcisi istemci, ILogger<TakvimEkleTuru> gunluk) : IEylemTuru
{
    public const string Anahtar = "takvim-ekle";

    private static readonly JsonSerializerOptions Secenekler = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public string Ad => Anahtar;

    public string GorunenAd => "Takvime etkinlik ekle";

    public Sonuc Dogrula(JsonElement yuk) => Coz(yuk, out _, out _, out _, out _, out _);

    public async Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct)
    {
        var sonuc = Coz(yuk, out var takvim, out var baslik, out var yer, out var bas, out var bit);
        if (!sonuc.Basarili)
            throw new InvalidOperationException(sonuc.Mesaj);

        var token = await erisim.TokenAlAsync(ct);
        if (!token.Basarili)
            throw new InvalidOperationException(token.Mesaj);

        GoogleEtkinlik olusan;
        try
        {
            olusan = await istemci.EtkinlikEkleAsync(takvim, new GoogleEtkinlikGirdisi(baslik, bas!, bit!, yer), token.Token!, ct);
        }
        catch (GoogleYetkiGecersizException)
        {
            erisim.Unut();
            throw new InvalidOperationException("Google erişimi reddetti.");
        }

        // From here on the event exists on Google, so nothing below may throw.
        if (olusan.Etag is null)
            gunluk.LogWarning("Google returned no etag for the event it created; the undo of this action will be refused.");

        return JsonSerializer.SerializeToElement(new TakvimEkleGeriAlmaBilgisi(takvim, olusan.Kimlik, olusan.Etag, baslik), JsonSerializerOptions.Web);
    }

    public async Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct)
    {
        var bilgi = geriAlmaBilgisi.Deserialize<TakvimEkleGeriAlmaBilgisi>(JsonSerializerOptions.Web)
            ?? throw new InvalidOperationException("Geri alma bilgisi okunamadı.");

        var token = await erisim.TokenAlAsync(ct);
        if (!token.Basarili)
            throw new InvalidOperationException(token.Mesaj);

        try
        {
            var etkinlik = await istemci.EtkinlikGetirAsync(bilgi.Takvim, bilgi.Kimlik, token.Token!, ct);
            // Gone already (the person deleted it): there is nothing to take back.
            if (etkinlik is not null && !etkinlik.Iptal)
            {
                if (bilgi.Etag is null || etkinlik.Etag != bilgi.Etag)
                    throw new GeriAlmaCatismasiException("Etkinlik Google'da sonradan değiştirilmiş; silinmedi. Gerekirse Google Takvim'den sil.");

                await istemci.EtkinlikSilAsync(bilgi.Takvim, bilgi.Kimlik, bilgi.Etag, token.Token!, ct);
            }
        }
        catch (GoogleEtagUyusmazligiException)
        {
            throw new GeriAlmaCatismasiException("Etkinlik Google'da sonradan değiştirilmiş; silinmedi. Gerekirse Google Takvim'den sil.");
        }
        catch (GoogleYetkiGecersizException)
        {
            erisim.Unut();
            throw new InvalidOperationException("Google erişimi reddetti.");
        }

        // The copy in the database goes too, so the timeline does not show the event until the next sync. Not part of the queue's save:
        // the sync may be deleting the same row, and that must not fail an undo that has already happened on Google.
        await baglam.Db.TakvimEtkinlikleri
            .Where(e => e.TakvimKimligi == bilgi.Takvim && e.GoogleKimligi == bilgi.Kimlik)
            .ExecuteDeleteAsync(ct);
    }

    private Sonuc Coz(JsonElement yuk, out string takvim, out string baslik, out string? yer, out GoogleZaman? bas, out GoogleZaman? bit)
    {
        takvim = ayar.VarsayilanTakvim;
        baslik = "";
        yer = null;
        bas = bit = null;

        TakvimEkleYuku? y;
        try
        {
            y = yuk.Deserialize<TakvimEkleYuku>(Secenekler);
        }
        catch (JsonException e)
        {
            return Sonuc.Gecersiz("yuk", $"Yük takvim etkinliği biçimine uymuyor ({e.Path}).");
        }

        if (y is null || y.Baslik is null)
            return Sonuc.Gecersiz("yuk", "Yük baslik içermeli.");

        var sonuc = TakvimYukuDenetimi.Acik(ayar);
        if (!sonuc.Basarili)
            return sonuc;
        sonuc = TakvimYukuDenetimi.Takvim(y.Takvim, ayar, out takvim);
        if (!sonuc.Basarili)
            return sonuc;
        sonuc = TakvimYukuDenetimi.Baslik(y.Baslik, out baslik);
        if (!sonuc.Basarili)
            return sonuc;
        sonuc = TakvimYukuDenetimi.Yer(y.Yer, out yer);
        if (!sonuc.Basarili)
            return sonuc;

        return TakvimYukuDenetimi.Zaman(y.TumGun, y.Baslangic, y.Bitis, y.Gun, y.BitisGunu, out bas, out bit);
    }
}
