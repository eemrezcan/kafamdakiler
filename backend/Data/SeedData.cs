using Microsoft.AspNetCore.Identity;

namespace Kafamdakiler.Data;

public static class SeedData
{
    public const string OwnerRole = "Sahip";
    public const string AssistantRole = "Asistan";

    public static async Task InitializeAsync(IServiceProvider services)
    {
        var roleManager = services.GetRequiredService<RoleManager<IdentityRole<Guid>>>();
        var userManager = services.GetRequiredService<UserManager<IdentityUser<Guid>>>();
        var config = services.GetRequiredService<IConfiguration>();

        foreach (var role in new[] { OwnerRole, AssistantRole })
        {
            if (!await roleManager.RoleExistsAsync(role))
                await roleManager.CreateAsync(new IdentityRole<Guid>(role));
        }

        await EnsureUserAsync(userManager, config["Seed:SahipEmail"], config["Seed:SahipPassword"], OwnerRole);
        await EnsureUserAsync(userManager, config["Seed:AsistanEmail"], config["Seed:AsistanPassword"], AssistantRole);
    }

    private static async Task EnsureUserAsync(
        UserManager<IdentityUser<Guid>> userManager, string? email, string? password, string role)
    {
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
            throw new InvalidOperationException($"Seed email or password for role '{role}' is missing.");

        if (await userManager.FindByEmailAsync(email) is not null)
            return;

        var user = new IdentityUser<Guid> { UserName = email, Email = email, EmailConfirmed = true };
        var result = await userManager.CreateAsync(user, password);
        if (!result.Succeeded)
            throw new InvalidOperationException(string.Join("; ", result.Errors.Select(e => e.Description)));

        await userManager.AddToRoleAsync(user, role);
    }
}