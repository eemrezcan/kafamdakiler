using System.Security.Claims;
using Kafamdakiler.Aliskanliklar;
using Microsoft.AspNetCore.Identity;

namespace Kafamdakiler.Data;

public record BenDto(Guid Id, string? Email, IList<string> Roller, List<string> Izinler);

public static class BenEndpoints
{
    // Who am I: the mobile app reads the role from here to show or hide the management buttons.
    public static void MapBenEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/ben", async (ClaimsPrincipal principal, UserManager<IdentityUser<Guid>> userManager) =>
        {
            var kullanici = await userManager.GetUserAsync(principal);
            if (kullanici is null)
                return Results.Unauthorized();

            // Read from the database, not from the token, so a revoked permission disappears at once (K-0009).
            var roller = await userManager.GetRolesAsync(kullanici);
            var izinler = (await userManager.GetClaimsAsync(kullanici))
                .Where(c => c.Type == AliskanlikPolicies.IzinClaim).Select(c => c.Value).Order().ToList();

            return Results.Ok(new BenDto(kullanici.Id, kullanici.Email, roller, izinler));
        })
        .WithTags("Hesap")
        .RequireAuthorization(policy => policy
            .AddAuthenticationSchemes(IdentityConstants.BearerScheme)
            .RequireAuthenticatedUser());
    }
}
