using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.OpenApi;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Localization;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;

const string OwnerPolicy = SeedData.OwnerRole;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizeFolder("/", OwnerPolicy);
    options.Conventions.AllowAnonymousToFolder("/Hesap");
    options.Conventions.AllowAnonymousToPage("/Error");
});

builder.Services.AddAuthorizationBuilder()
    // Challenge with the cookie scheme so the browser is redirected to the login and access denied pages.
    .AddPolicy(OwnerPolicy, policy => policy
        .AddAuthenticationSchemes(IdentityConstants.ApplicationScheme)
        .RequireRole(SeedData.OwnerRole))
    // API policies: the Sahip role or the matching `izin` claim (K-0009). Bearer token, so no redirects.
    .AddPolicy(AliskanlikPolicies.Oku, policy => IzinPolicy(policy, AliskanlikPolicies.Oku, IdentityConstants.BearerScheme))
    .AddPolicy(AliskanlikPolicies.Yaz, policy => IzinPolicy(policy, AliskanlikPolicies.Yaz, IdentityConstants.BearerScheme))
    // Photos are read by <img> tags (cookie) and by the mobile app (bearer).
    .AddPolicy(AliskanlikPolicies.DosyaOku, policy => IzinPolicy(policy, AliskanlikPolicies.Oku, IdentityConstants.BearerScheme, IdentityConstants.ApplicationScheme));

// Enums travel as camelCase text in the API ("enAz", "pzt").
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase)));

builder.Services.AddValidation();
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    if (context.ProblemDetails is HttpValidationProblemDetails sorun)
        HataAnahtarlari.CamelCaseYap(sorun);
});
builder.Services.AddScoped<DosyaDeposu>();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddIdentityApiEndpoints<IdentityUser<Guid>>()
    .AddRoles<IdentityRole<Guid>>()
    .AddEntityFrameworkStores<AppDbContext>();

// Must come after AddIdentityApiEndpoints, which sets its own LoginPath (/Account/Login).
builder.Services.ConfigureApplicationCookie(options =>
{
    options.LoginPath = "/Hesap/Giris";
    options.AccessDeniedPath = "/Hesap/Erisim";

    // API calls get 401/403 instead of a redirect to a login page.
    options.Events.OnRedirectToLogin = context => YonlendirYaDaReddet(context, StatusCodes.Status401Unauthorized);
    options.Events.OnRedirectToAccessDenied = context => YonlendirYaDaReddet(context, StatusCodes.Status403Forbidden);
});

// A malformed JSON body is a 400 ProblemDetails in development too, not an exception page.
builder.Services.Configure<RouteHandlerOptions>(options => options.ThrowOnBadRequest = false);

builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>();

builder.Services.AddOpenApi(options => options.AddDocumentTransformer<BearerSecuritySchemeTransformer>());

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    await SeedData.InitializeAsync(scope.ServiceProvider);
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

// Numbers in forms use a dot (<input type="number">), whatever the server's locale is; messages stay Turkish.
app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture(culture: "en-US", uiCulture: "tr-TR"),
    SupportedCultures = [new CultureInfo("en-US")],
    SupportedUICultures = [new CultureInfo("tr-TR")],
    RequestCultureProviders = [],
});

// Empty 4xx API responses (a malformed JSON body, 404) get a ProblemDetails body.
app.UseWhen(context => context.Request.Path.StartsWithSegments("/api"), api => api.UseStatusCodePages());

app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();
app.MapRazorPages()
   .WithStaticAssets();

app.MapHealthChecks("/saglik");

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

// Accounts are seeded; public registration is disabled.
var hesap = app.MapGroup("/api/hesap");
hesap.MapIdentityApi<IdentityUser<Guid>>();
hesap.AddEndpointFilter(async (context, next) =>
    context.HttpContext.Request.Path.Value!.EndsWith("/register")
        ? Results.NotFound()
        : await next(context));

app.MapBenEndpoints();
app.MapAliskanlikEndpoints();
app.MapOgeEndpoints();
app.MapDosyaEndpoints();

app.Run();

static Task YonlendirYaDaReddet(RedirectContext<CookieAuthenticationOptions> context, int apiDurumKodu)
{
    if (context.Request.Path.StartsWithSegments("/api"))
        context.Response.StatusCode = apiDurumKodu;
    else
        context.Response.Redirect(context.RedirectUri);

    return Task.CompletedTask;
}

static void IzinPolicy(AuthorizationPolicyBuilder policy, string izin, params string[] schemes) => policy
    .AddAuthenticationSchemes(schemes)
    .RequireAuthenticatedUser()
    .RequireAssertion(context =>
        context.User.IsInRole(SeedData.OwnerRole) || context.User.HasClaim(AliskanlikPolicies.IzinClaim, izin));