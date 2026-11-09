using Kafamdakiler.Bildirimler;

namespace Kafamdakiler.Tests;

// A fake FCM sender: the same contract as the real one (IPushGondericisi). It records what would have been sent and answers what
// the test sets per token (sent by default). Nothing in the tests reaches Google, and no service account key is read.
public sealed class SahtePushGondericisi : IPushGondericisi
{
    private readonly Lock _kilit = new();
    private readonly List<(string Token, Guid BildirimId)> _gonderilenler = [];

    public Dictionary<string, PushSonucu> Sonuclar { get; } = [];

    public IReadOnlyList<(string Token, Guid BildirimId)> Gonderilenler
    {
        get
        {
            lock (_kilit)
                return [.. _gonderilenler];
        }
    }

    public Task<PushSonucu> GonderAsync(string token, Guid bildirimId, CancellationToken ct)
    {
        lock (_kilit)
            _gonderilenler.Add((token, bildirimId));

        return Task.FromResult(Sonuclar.GetValueOrDefault(token, PushSonucu.Gitti));
    }
}
