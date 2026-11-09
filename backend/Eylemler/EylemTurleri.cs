using System.Text.Json;
using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Data;

namespace Kafamdakiler.Eylemler;

// One kind of action the approval queue can hold. A later module adds a kind by writing one class and listing it
// in EylemServisleri below; nothing else changes.
public interface IEylemTuru
{
    // The key stored in Eylem.Tur.
    string Ad { get; }

    // What the screens call it.
    string GorunenAd { get; }

    // Checks a payload against the shape of this kind (also used on a payload a person corrected).
    Sonuc Dogrula(JsonElement yuk);

    // The same check for a kind that has to look outside the payload (the brain, say). The queue calls this one, before it
    // stores a suggestion and before it applies one; most kinds need nothing beyond Dogrula.
    Task<Sonuc> DogrulaAsync(JsonElement yuk, CancellationToken ct) => Task.FromResult(Dogrula(yuk));

    // False when the effect cannot be taken back. Such a kind is never applied by itself, whatever its mode says,
    // and the undo is refused (409).
    bool GeriAlinabilir => true;

    // Puts the effect on the context without saving; the caller saves it together with the status change, so both
    // happen or neither does. Returns what undo needs.
    Task<JsonElement> UygulaAsync(JsonElement yuk, EylemBaglami baglam, CancellationToken ct);

    // Takes the effect back (also without saving). Never deletes what the user may have worked on since.
    Task GeriAlAsync(JsonElement geriAlmaBilgisi, EylemBaglami baglam, CancellationToken ct);
}

public record EylemBaglami(AppDbContext Db, DateTimeOffset Simdi);

// A failure of an effect whose message is a fixed sentence written for the person (no paths, no text of the brain). The queue
// shows it as the action's error; any other exception is shown as the generic "unexpected error" and only logged.
public class EylemHatasi(string mesaj) : InvalidOperationException(mesaj);

// The one registry of kinds.
public class EylemTurleri(IEnumerable<IEylemTuru> turler)
{
    private readonly Dictionary<string, IEylemTuru> _turler = turler.ToDictionary(t => t.Ad);

    public IReadOnlyCollection<IEylemTuru> Tumu => _turler.Values;

    public IEylemTuru? Bul(string ad) => _turler.GetValueOrDefault(ad);
}

public static class EylemServisleri
{
    public static IServiceCollection AddEylemler(this IServiceCollection services)
    {
        // The kinds. A new module adds its own line here.
        services.AddSingleton<IEylemTuru, HatirlaticiKurTuru>();
        services.AddSingleton<IEylemTuru, YerlestirTuru>();
        services.AddSingleton<IEylemTuru, PlanEkleTuru>();
        services.AddSingleton<IEylemTuru, GorevEkleTuru>();
        services.AddSingleton<IEylemTuru, TakvimEkleTuru>();
        services.AddSingleton<IEylemTuru, TakvimTasiTuru>();

        services.AddSingleton<EylemTurleri>();
        services.AddScoped<EylemServisi>();
        return services;
    }
}
