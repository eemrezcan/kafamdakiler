namespace Kafamdakiler.Mobil;

// GET /api/surum: anonymous, so an app that cannot sign in (or whose token format is old) can still learn it must update.
public static class MobilEndpoints
{
    public static void MapMobilEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/surum", (MobilAyari ayar) => Results.Ok(new SurumDto(ayar.EnAzSurumKodu)))
            .WithTags("Mobil")
            .AllowAnonymous();
    }
}

public record SurumDto(int EnAzMobilSurumKodu);
