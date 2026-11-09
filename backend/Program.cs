using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Beyin;
using Kafamdakiler.Brifing;
using Kafamdakiler.Claude;
using Kafamdakiler.Data;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.Eylemler;
using Kafamdakiler.Gelen;
using Kafamdakiler.Gmail;
using Kafamdakiler.Hatirlaticilar;
using Kafamdakiler.ProjeRepolari;
using Kafamdakiler.Mobil;
using Kafamdakiler.OpenApi;
using Kafamdakiler.Ozet;
using Kafamdakiler.Ses;
using Kafamdakiler.Takvim;
using Kafamdakiler.Uretim;
using Kafamdakiler.Yakalamalar;
using Kafamdakiler.Yonetim;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
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
    // /api/yonetim: the Sahip role only, whatever permissions anyone holds. Bearer token.
    .AddPolicy(YonetimPolicies.Sahip, policy => policy
        .AddAuthenticationSchemes(IdentityConstants.BearerScheme)
        .RequireAuthenticatedUser()
        .RequireRole(SeedData.OwnerRole))
    // API policies: the Sahip role or the matching `izin` claim (K-0009). Bearer token, so no redirects.
    .AddPolicy(AliskanlikPolicies.Oku, policy => IzinPolicy(policy, [AliskanlikPolicies.Oku], IdentityConstants.BearerScheme))
    .AddPolicy(AliskanlikPolicies.Yaz, policy => IzinPolicy(policy, [AliskanlikPolicies.Yaz], IdentityConstants.BearerScheme))
    .AddPolicy(YakalamaPolicies.Oku, policy => IzinPolicy(policy, [YakalamaPolicies.Oku], IdentityConstants.BearerScheme))
    .AddPolicy(YakalamaPolicies.Yaz, policy => IzinPolicy(policy, [YakalamaPolicies.Yaz], IdentityConstants.BearerScheme))
    .AddPolicy(HatirlaticiPolicies.Oku, policy => IzinPolicy(policy, [HatirlaticiPolicies.Oku], IdentityConstants.BearerScheme))
    .AddPolicy(HatirlaticiPolicies.Yaz, policy => IzinPolicy(policy, [HatirlaticiPolicies.Yaz], IdentityConstants.BearerScheme))
    .AddPolicy(BeyinPolicies.Oku, policy => IzinPolicy(policy, [BeyinPolicies.Oku], IdentityConstants.BearerScheme))
    .AddPolicy(BeyinPolicies.PlanYaz, policy => IzinPolicy(policy, [BeyinPolicies.PlanYaz], IdentityConstants.BearerScheme))
    .AddPolicy(BeyinPolicies.GorevYaz, policy => IzinPolicy(policy, [BeyinPolicies.GorevYaz], IdentityConstants.BearerScheme))
    .AddPolicy(EylemPolicies.Oku, policy => IzinPolicy(policy, [EylemPolicies.Oku], IdentityConstants.BearerScheme))
    .AddPolicy(EylemPolicies.Onayla, policy => IzinPolicy(policy, [EylemPolicies.Onayla], IdentityConstants.BearerScheme))
    .AddPolicy(GelenPolicies.Oku, policy => IzinPolicy(policy, [GelenPolicies.Oku], IdentityConstants.BearerScheme))
    .AddPolicy(GelenPolicies.Yaz, policy => IzinPolicy(policy, [GelenPolicies.Yaz], IdentityConstants.BearerScheme))
    // Voice and text (K2.4): the Claude calls need `asistan.kullan`; applying what a person chose needs one of the three write permissions
    // (each suggestion is then checked against the permission of its own kind).
    .AddPolicy(SesPolicies.AsistanKullan, policy => IzinPolicy(policy, [SesPolicies.AsistanKullan], IdentityConstants.BearerScheme))
    .AddPolicy(SesPolicies.Uygula, policy => IzinPolicy(policy, [HatirlaticiPolicies.Yaz, BeyinPolicies.PlanYaz, BeyinPolicies.GorevYaz, TakvimPolicies.Yaz], IdentityConstants.BearerScheme))
    // The morning briefing (K2.7): reading it and voting on its cards. Asking for a new one is the Sahip's (YonetimPolicies.Sahip).
    .AddPolicy(BrifingPolicies.Oku, policy => IzinPolicy(policy, [BrifingPolicies.Oku], IdentityConstants.BearerScheme))
    // Google Calendar (K2.3c): the one timeline is read with `takvim.oku`; `takvim.yaz` is the write permission of the calendar action kinds
    // (checked for the voice route; the approval queue itself asks `eylem.onayla`). Connecting and cutting Google is the Sahip's (YonetimPolicies.Sahip).
    .AddPolicy(TakvimPolicies.Oku, policy => IzinPolicy(policy, [TakvimPolicies.Oku], IdentityConstants.BearerScheme))
    .AddPolicy(TakvimPolicies.Yaz, policy => IzinPolicy(policy, [TakvimPolicies.Yaz], IdentityConstants.BearerScheme))
    // Photos are read by <img> tags (cookie) and by the mobile app (bearer). Habits and captures share them.
    .AddPolicy(AliskanlikPolicies.DosyaOku, policy => IzinPolicy(policy, [AliskanlikPolicies.Oku, YakalamaPolicies.Oku], IdentityConstants.BearerScheme, IdentityConstants.ApplicationScheme))
    .AddPolicy(AliskanlikPolicies.DosyaYaz, policy => IzinPolicy(policy, [AliskanlikPolicies.Yaz, YakalamaPolicies.Yaz], IdentityConstants.BearerScheme));

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
builder.Services.AddHostedService<YetimDosyaTemizleyici>();

// The brain (K-0023): off when Beyin:Komut or Beyin:Vault is empty.
var beyinAyari = BeyinAyari.Oku(builder.Configuration, builder.Environment.ContentRootPath);
builder.Services.AddSingleton(beyinAyari);
builder.Services.AddSingleton<BeyinIstemcisi>();
// The day plan and task writes (K2.3a): the day's capacity setting and the Idempotency-Key guard.
builder.Services.AddBeyinYazma(builder.Configuration);
// Claude Code as a child process (K2.6): off when Claude:Komut is empty. Its answers only ever become suggestions in the approval queue.
builder.Services.AddSingleton(ClaudeAyari.Oku(builder.Configuration, builder.Environment.ContentRootPath));
builder.Services.AddSingleton<ClaudeIstemcisi>();
builder.Services.AddEylemler();
// The inbox (K2.2): new cards get a suggestion from Claude, which waits in the approval queue.
builder.Services.AddGelen(builder.Configuration);
// Voice (K2.4): work out of dictated text, and rewriting it.
builder.Services.AddSes();
// The morning briefing (K2.7): made once a day at the set hour, by Claude or, failing that, by fixed rules.
builder.Services.AddBrifing(builder.Configuration);
builder.Services.AddHaftalikOzet(builder.Configuration);
// Google Calendar (K2.3c): off until the Google settings are given. Events are synced into the database; writes go through the approval queue.
builder.Services.AddTakvim(builder.Configuration);
// Gmail (read only): off until Gmail:Acik is set. New mail of the primary inbox is read by Claude; whatever it finds waits in the approval queue.
builder.Services.AddGmail(builder.Configuration);
builder.Services.AddProjeRepolari(builder.Configuration);
builder.Services.AddSingleton(MobilAyari.Oku(builder.Configuration));
builder.Services.AddSingleton(HatirlaticiAyari.Oku(builder.Configuration));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddHostedService<YakalamaGondericisi>();

// Production behind a TLS-ending proxy (K2.1). Both are off when their setting is empty.
var veriKoruma = VeriKorumaAyari.Oku(builder.Configuration, builder.Environment.ContentRootPath);
if (veriKoruma.Acik)
{
    // Persistent keys: the login cookies and antiforgery tokens survive a container restart.
    builder.Services.AddDataProtection()
        .SetApplicationName("Kafamdakiler")
        .PersistKeysToFileSystem(veriKoruma.KlasoruHazirla());
}

var vekil = VekilAyari.Oku(builder.Configuration);
if (vekil.Acik)
    builder.Services.Configure<ForwardedHeadersOptions>(vekil.Uygula);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.AddIdentityApiEndpoints<IdentityUser<Guid>>()
    .AddRoles<IdentityRole<Guid>>()
    .AddErrorDescriber<TurkceIdentityHatalari>()
    .AddEntityFrameworkStores<AppDbContext>();

// The `izin` claims are read from the database on every request, not from the token (K-0009 eki).
builder.Services.AddScoped<IClaimsTransformation, IzinleriVeritabanindanOku>();

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

if (app.Environment.IsDevelopment())
    OrnekBeyinKopyasi.HazirlaGerekirse(beyinAyari);

using (var scope = app.Services.CreateScope())
{
    await SeedData.InitializeAsync(scope.ServiceProvider);
}

// Configure the HTTP request pipeline.
// First, so that everything after it sees the client's scheme and address (not the proxy's).
if (vekil.Acik)
    app.UseForwardedHeaders();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

// Behind the proxy TLS ends outside the app, so a redirect is meaningless there; HSTS above covers production.
if (app.Environment.IsDevelopment())
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
app.MapYakalamaEndpoints();
app.MapHatirlaticiEndpoints();
app.MapBeyinEndpoints();
app.MapEylemEndpoints();
app.MapGelenEndpoints();
app.MapSesEndpoints();
app.MapBrifingEndpoints();
app.MapTakvimEndpoints();
app.MapYonetimEndpoints();
app.MapMobilEndpoints();

app.Run();

static Task YonlendirYaDaReddet(RedirectContext<CookieAuthenticationOptions> context, int apiDurumKodu)
{
    if (context.Request.Path.StartsWithSegments("/api"))
        context.Response.StatusCode = apiDurumKodu;
    else
        context.Response.Redirect(context.RedirectUri);

    return Task.CompletedTask;
}

static void IzinPolicy(AuthorizationPolicyBuilder policy, string[] izinler, params string[] schemes) => policy
    .AddAuthenticationSchemes(schemes)
    .RequireAuthenticatedUser()
    .RequireAssertion(context =>
        context.User.IsInRole(SeedData.OwnerRole) || izinler.Any(izin => context.User.HasClaim(AliskanlikPolicies.IzinClaim, izin)));

// The integration tests start the app through this class.
public partial class Program;
