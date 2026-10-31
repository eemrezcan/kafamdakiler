using Kafamdakiler.Data;
using Kafamdakiler.OpenApi;
using Microsoft.AspNetCore.Identity;
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
        .RequireRole(SeedData.OwnerRole));

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
});

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

app.Run();