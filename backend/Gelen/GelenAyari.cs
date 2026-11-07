namespace Kafamdakiler.Gelen;

// The "Gelen" settings: how often the server looks for new inbox cards and how hard it tries on one.
public class GelenAyari
{
    // How often the background round runs.
    public TimeSpan OneriAraligi { get; init; } = TimeSpan.FromMinutes(3);

    // The most cards one round sends to Claude; the rest wait for the next round.
    public int TurBasinaEnCok { get; init; } = 5;

    // A card whose suggestion failed this many times is left for a person (or for the manual "suggest again").
    public int EnCokDeneme { get; init; } = 3;

    // After a failed try the card waits (tries so far) times this long.
    public TimeSpan DenemeBekleme { get; init; } = TimeSpan.FromMinutes(10);

    public static GelenAyari Oku(IConfiguration config)
    {
        var bolum = config.GetSection("Gelen");
        return new GelenAyari
        {
            OneriAraligi = TimeSpan.FromMinutes(Math.Max(0.05, bolum.GetValue("OneriAraligiDakika", 3.0))),
            TurBasinaEnCok = Math.Max(1, bolum.GetValue("TurBasinaEnCok", 5)),
            EnCokDeneme = Math.Max(1, bolum.GetValue("EnCokDeneme", 3)),
            DenemeBekleme = TimeSpan.FromMinutes(Math.Max(0, bolum.GetValue("DenemeBeklemeDakika", 10.0))),
        };
    }
}
