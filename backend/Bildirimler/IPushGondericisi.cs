namespace Kafamdakiler.Bildirimler;

public enum PushSonucu
{
    Gitti,
    // FCM says the token is dead (UNREGISTERED, or it is not a token of this project): the device row is deleted.
    GecersizToken,
    // Anything else (network, quota, server error, a broken key file): the row stays, the next send tries again.
    Hata,
}

// Everything that touches Firebase sits behind this interface; the tests run on a fake and never call Google.
// The real one is FirebasePushGondericisi. The message carries data only: the id of the notification, no text.
public interface IPushGondericisi
{
    Task<PushSonucu> GonderAsync(string token, Guid bildirimId, CancellationToken ct);
}
