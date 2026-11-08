using System.Buffers.Text;
using System.Net;
using System.Net.Mail;
using System.Text;
using Google;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Gmail.v1;
using Google.Apis.Gmail.v1.Data;
using Google.Apis.Services;
using Kafamdakiler.Takvim;

namespace Kafamdakiler.Gmail;

// The real thing: Google's own .NET client (Google.Apis.Gmail.v1), read only. The tests never reach this class; they run on a
// fake IGmailIstemcisi.
public class GmailIstemcisi : IGmailIstemcisi
{
    private const string UygulamaAdi = "Kafamdakiler";

    // The signed-in account, whatever its address.
    private const string Ben = "me";

    // The most characters one message's text parts may add up to before the rest is dropped (the scan sends a few thousand on).
    private const int GovdeKarakterEnCok = 2_000_000;

    private static GmailService Servis(string erisimToken) => new(new BaseClientService.Initializer
    {
        HttpClientInitializer = GoogleCredential.FromAccessToken(erisimToken),
        ApplicationName = UygulamaAdi,
    });

    public async Task<IReadOnlyList<string>> KimlikleriListeleAsync(string sorgu, int enCok, string erisimToken, CancellationToken ct)
    {
        using var servis = Servis(erisimToken);
        var istek = servis.Users.Messages.List(Ben);
        istek.Q = sorgu;
        istek.MaxResults = enCok;
        try
        {
            var yanit = await istek.ExecuteAsync(ct);
            return (yanit.Messages ?? []).Select(m => m.Id).Where(id => !string.IsNullOrEmpty(id)).ToList();
        }
        catch (GoogleApiException e) when (e.HttpStatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
        {
            throw new GoogleYetkiGecersizException("Gmail refused the access token.", e);
        }
    }

    public async Task<GmailPosta?> PostaGetirAsync(string kimlik, string erisimToken, CancellationToken ct)
    {
        using var servis = Servis(erisimToken);
        var istek = servis.Users.Messages.Get(Ben, kimlik);
        istek.Format = UsersResource.MessagesResource.GetRequest.FormatEnum.Full;
        Message mesaj;
        try
        {
            mesaj = await istek.ExecuteAsync(ct);
        }
        catch (GoogleApiException e) when (e.HttpStatusCode is HttpStatusCode.NotFound)
        {
            return null;
        }
        catch (GoogleApiException e) when (e.HttpStatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
        {
            throw new GoogleYetkiGecersizException("Gmail refused the access token.", e);
        }

        return Cevir(mesaj);
    }

    // Public so a test can feed it a message built by hand.
    public static GmailPosta Cevir(Message mesaj)
    {
        string? Baslik(string ad) => mesaj.Payload?.Headers?.FirstOrDefault(h => string.Equals(h.Name, ad, StringComparison.OrdinalIgnoreCase))?.Value;

        string? gonderenAd = null, gonderenAdres = null;
        if (Baslik("From") is { Length: > 0 } from && MailAddress.TryCreate(from, out var adres))
        {
            gonderenAd = string.IsNullOrWhiteSpace(adres.DisplayName) ? null : adres.DisplayName;
            gonderenAdres = adres.Address;
        }

        // The moment Gmail received it; the Date header is whatever the sender's program wrote.
        DateTimeOffset? tarih = mesaj.InternalDate is { } ms ? DateTimeOffset.FromUnixTimeMilliseconds(ms) : null;

        var duz = new StringBuilder();
        var html = new StringBuilder();
        MetinParcalariniTopla(mesaj.Payload, duz, html);
        return new GmailPosta(
            mesaj.Id, Baslik("Subject"), gonderenAd, gonderenAdres, tarih, GmailMetni.Govde(duz.ToString(), html.ToString()),
            (mesaj.LabelIds ?? []).ToList());
    }

    // Walks the MIME tree. Attachments (a part with a file name) are skipped; the first text/plain and text/html parts are kept apart.
    private static void MetinParcalariniTopla(MessagePart? parca, StringBuilder duz, StringBuilder html)
    {
        if (parca is null)
            return;

        if (string.IsNullOrEmpty(parca.Filename) && parca.Body?.Data is { Length: > 0 } veri)
        {
            var hedef = parca.MimeType?.ToLowerInvariant() switch
            {
                "text/plain" => duz,
                "text/html" => html,
                _ => null,
            };
            if (hedef is not null && hedef.Length < GovdeKarakterEnCok)
                hedef.Append(Coz(veri, Karakterkumesi(parca))).Append('\n');
        }

        foreach (var alt in parca.Parts ?? [])
            MetinParcalariniTopla(alt, duz, html);
    }

    private static string Coz(string veri, Encoding kodlama)
    {
        try
        {
            return kodlama.GetString(Base64Url.DecodeFromChars(veri.TrimEnd('=')));
        }
        catch (FormatException)
        {
            return "";
        }
    }

    // The part's own charset (Turkish mail is often windows-1254 or iso-8859-9); UTF-8 when it names none or one this machine lacks.
    private static Encoding Karakterkumesi(MessagePart parca)
    {
        var tur = parca.Headers?.FirstOrDefault(h => string.Equals(h.Name, "Content-Type", StringComparison.OrdinalIgnoreCase))?.Value;
        const string Anahtar = "charset=";
        var yer = tur?.IndexOf(Anahtar, StringComparison.OrdinalIgnoreCase) ?? -1;
        if (tur is null || yer < 0)
            return Encoding.UTF8;

        var ad = tur[(yer + Anahtar.Length)..].Split(';')[0].Trim().Trim('"');
        try
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
            return Encoding.GetEncoding(ad);
        }
        catch (ArgumentException)
        {
            return Encoding.UTF8;
        }
    }
}
