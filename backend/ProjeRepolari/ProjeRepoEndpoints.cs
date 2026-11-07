using Kafamdakiler.Beyin;
using Kafamdakiler.Data;
using Microsoft.EntityFrameworkCore;
using static Kafamdakiler.Aliskanliklar.AliskanlikEndpoints;

namespace Kafamdakiler.ProjeRepolari;

// The repository bridge (K2.5): the Sahip maps a project of the brain to `owner/repo` (/api/yonetim/proje-repolari), and anyone
// with `beyin.oku` reads the repository card of a project (/api/beyin/projeler/{kimlik}/repo). Read only on GitHub.
public static class ProjeRepoEndpoints
{
    // Mounted on the Sahip group of /api/yonetim.
    public static void MapProjeRepoYonetimEndpoints(this RouteGroupBuilder yonetim)
    {
        yonetim.MapGet("/proje-repolari", async (AppDbContext db, CancellationToken ct) =>
            Results.Ok((await db.ProjeRepolari.AsNoTracking().OrderBy(r => r.ProjeKimligi).ToListAsync(ct)).Select(Dto).ToList()));

        // Sets or replaces the repository of a project. The project must exist in the brain (hidden ones do not count as existing).
        yonetim.MapPut("/proje-repolari/{kimlik}", async (string kimlik, ProjeRepoYazDto dto, AppDbContext db, BeyinIstemcisi beyin,
            TimeProvider saat, ILogger<BeyinIstemcisi> log, CancellationToken ct) =>
        {
            var sonuc = await ProjeRepoIslemleri.AyarlaAsync(db, beyin, saat, log, kimlik, dto.Depo, ct);
            return sonuc.Tur switch
            {
                RepoEslemeTuru.Tamam => Results.Ok(Dto(sonuc.Satir!)),
                RepoEslemeTuru.GecersizKimlik => Sorun("kimlik", sonuc.Mesaj!),
                RepoEslemeTuru.GecersizDepo => Sorun("depo", sonuc.Mesaj!),
                RepoEslemeTuru.ProjeYok => Results.Problem(title: "Bulunamadı", detail: sonuc.Mesaj, statusCode: StatusCodes.Status404NotFound),
                _ => sonuc.BeyinYaniti!.Sonuc(),
            };
        });

        yonetim.MapDelete("/proje-repolari/{kimlik}", async (string kimlik, AppDbContext db, CancellationToken ct) =>
        {
            var satir = await db.ProjeRepolari.FindAsync([kimlik], ct);
            if (satir is null)
                return Results.NotFound();

            db.ProjeRepolari.Remove(satir);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }

    // Mounted on the `beyin.oku` group of /api/beyin. 404 when the project has no repository linked.
    public static void MapProjeRepoOkumaEndpoints(this RouteGroupBuilder beyin)
    {
        beyin.MapGet("/projeler/{kimlik}/repo", async (string kimlik, AppDbContext db, RepoOzetServisi servis, CancellationToken ct) =>
        {
            if (!KimlikGecerli(kimlik))
                return Sorun("kimlik", "Proje kimliği küçük harf, rakam ve tire olmalı.");

            var satir = await db.ProjeRepolari.AsNoTracking().FirstOrDefaultAsync(r => r.ProjeKimligi == kimlik, ct);
            if (satir is null)
                return Results.Problem(title: "Bulunamadı", detail: "Bu projeye bir depo bağlanmamış.", statusCode: StatusCodes.Status404NotFound);

            return Results.Ok(await servis.OzetAsync(kimlik, satir.Depo, ct));
        });
    }

    private static bool KimlikGecerli(string kimlik) => ProjeRepoIslemleri.KimlikGecerli(kimlik);

    private static ProjeRepoDto Dto(ProjeRepo r) => new(r.ProjeKimligi, r.Depo, RepoOzetServisi.Baglanti(r.Depo));

    public static IServiceCollection AddProjeRepolari(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton(GitHubAyari.Oku(config));
        services.AddSingleton<IGitHubIstemcisi>(_ =>
        {
            var http = new HttpClient(new SocketsHttpHandler { PooledConnectionLifetime = TimeSpan.FromMinutes(15) })
            {
                BaseAddress = new Uri(GitHubIstemcisi.TabanAdres),
                Timeout = TimeSpan.FromSeconds(10),
            };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("Kafamdakiler");
            http.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
            http.DefaultRequestHeaders.Add("X-GitHub-Api-Version", "2022-11-28");
            return new GitHubIstemcisi(http);
        });
        services.AddSingleton<RepoOzetServisi>();
        return services;
    }
}
