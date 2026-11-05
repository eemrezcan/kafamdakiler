using System.Security.Claims;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Yonetim;

// The bearer token carries a copy of the `izin` claims from the moment of the login (1 hour, K-0009). Trusting it
// would let the Asistan keep a permission the Sahip already took away. So on every request the token's `izin` claims
// are thrown away and the current ones are read from the database (AspNetUserClaims, Identity's own table).
// Fail closed: the old claims are dropped before the lookup, and a failed lookup throws (500), it never lets them through.
// It can run more than once per request, so it works on a copy and gives the same answer each time.
public class IzinleriVeritabanindanOku(AppDbContext db) : IClaimsTransformation
{
    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        if (principal.Identity?.IsAuthenticated != true)
            return principal;

        var kopya = new ClaimsPrincipal(principal.Identities.Select(i => i.Clone()));
        var kimlik = (ClaimsIdentity)kopya.Identity!;
        foreach (var eski in kimlik.FindAll(AliskanlikPolicies.IzinClaim).ToList())
            kimlik.RemoveClaim(eski);

        if (Guid.TryParse(kimlik.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var kullaniciId))
        {
            var izinler = await db.UserClaims
                .Where(c => c.UserId == kullaniciId && c.ClaimType == AliskanlikPolicies.IzinClaim && c.ClaimValue != null)
                .Select(c => c.ClaimValue!).ToListAsync();
            foreach (var izin in izinler)
                kimlik.AddClaim(new Claim(AliskanlikPolicies.IzinClaim, izin));
        }

        return kopya;
    }
}
