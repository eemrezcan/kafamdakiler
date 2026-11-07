using IPNetwork = System.Net.IPNetwork;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.HttpOverrides;

namespace Kafamdakiler.Uretim;

// The "Vekil" settings. The app runs behind a reverse proxy that ends TLS and forwards plain HTTP.
// GuvenilenAglar is the list of networks (CIDR) the proxy connects from; only requests from there are allowed
// to set X-Forwarded-For and X-Forwarded-Proto. Empty: the forwarded headers are ignored and no middleware is added.
public class VekilAyari
{
    public IReadOnlyList<IPNetwork> GuvenilenAglar { get; init; } = [];

    public bool Acik => GuvenilenAglar.Count > 0;

    // An invalid CIDR stops the startup with a clear message; it is never skipped silently.
    public static VekilAyari Oku(IConfiguration config)
    {
        var aglar = new List<IPNetwork>();
        foreach (var metin in config.GetSection("Vekil:GuvenilenAglar").Get<string[]>() ?? [])
        {
            if (string.IsNullOrWhiteSpace(metin))
                continue;

            if (!IPNetwork.TryParse(metin.Trim(), out var ag))
                throw new InvalidOperationException(
                    $"Vekil:GuvenilenAglar has an invalid network: \"{metin}\". Expected CIDR, e.g. \"172.16.0.0/12\".");

            aglar.Add(ag);
        }

        return new VekilAyari { GuvenilenAglar = aglar };
    }

    public void Uygula(ForwardedHeadersOptions secenekler)
    {
        secenekler.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

        // Drop the defaults (loopback) so that only the configured networks are trusted.
        secenekler.KnownProxies.Clear();
        secenekler.KnownIPNetworks.Clear();
        foreach (var ag in GuvenilenAglar)
            secenekler.KnownIPNetworks.Add(ag);
    }
}
