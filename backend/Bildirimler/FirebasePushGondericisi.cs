using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Requests;

namespace Kafamdakiler.Bildirimler;

// Sends a data-only, high priority message through the Firebase Admin SDK. The app is created on the first send, so a missing
// or broken key file shows up as a failed send in Yönetim, not as a crash at startup.
public sealed class FirebasePushGondericisi(PushAyari ayar, ILogger<FirebasePushGondericisi> gunluk) : IPushGondericisi
{
    private readonly Lock _kilit = new();
    private FirebaseMessaging? _mesajlasma;

    public async Task<PushSonucu> GonderAsync(string token, Guid bildirimId, CancellationToken ct)
    {
        try
        {
            await Mesajlasma().SendAsync(MesajYap(token, bildirimId), ct);
            return PushSonucu.Gitti;
        }
        catch (FirebaseMessagingException e) when (e.MessagingErrorCode is MessagingErrorCode.Unregistered or MessagingErrorCode.SenderIdMismatch
            or MessagingErrorCode.InvalidArgument)
        {
            gunluk.LogInformation("FCM refused a token ({Kod}); the device is dropped.", e.MessagingErrorCode);
            return PushSonucu.GecersizToken;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            gunluk.LogWarning(e, "FCM send failed.");
            return PushSonucu.Hata;
        }
    }

    // Data only: no `Notification` block, so Android never draws anything by itself and the text never passes through Google.
    public static Message MesajYap(string token, Guid bildirimId)
    {
        // The SDK marks Token as deprecated in favour of Fid (a Firebase installation id), but firebase_messaging hands the app a
        // registration token, which is what Token targets.
#pragma warning disable CS0618
        return new Message
        {
            Token = token,
            Data = new Dictionary<string, string> { ["bildirimId"] = bildirimId.ToString() },
            Android = new AndroidConfig { Priority = Priority.High },
        };
#pragma warning restore CS0618
    }

    private FirebaseMessaging Mesajlasma()
    {
        lock (_kilit)
        {
            return _mesajlasma ??= FirebaseMessaging.GetMessaging(
                FirebaseApp.Create(new AppOptions { Credential = CredentialFactory.FromFile<ServiceAccountCredential>(ayar.AnahtarDosyasi).ToGoogleCredential() }));
        }
    }
}
