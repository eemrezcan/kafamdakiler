namespace Kafamdakiler.Bildirimler;

// A notification born on the server. The phone is woken with only its id (FCM carries no text) and reads the rest from
// GET /api/bildirimler/{id}. `Rota` and `HedefKimligi` say where a tap goes inside the app (null: the Bugün screen).
public class Bildirim
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid KullaniciId { get; set; }

    public string Baslik { get; set; } = "";

    public string Metin { get; set; } = "";

    public string? Rota { get; set; }

    public string? HedefKimligi { get; set; }

    // What made it: "test", later "hatirlatici", "beyin"... (F wires the real sources).
    public string KaynakTuru { get; set; } = "";

    public DateTimeOffset OlusmaAni { get; set; }
}

// A phone that can be woken: its FCM token. One row per token; a token that comes again is updated, not added.
public class BildirimCihazi
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid KullaniciId { get; set; }

    public string Token { get; set; } = "";

    public string? CihazAdi { get; set; }

    public DateTimeOffset KayitAni { get; set; }

    public DateTimeOffset GuncellemeAni { get; set; }
}
