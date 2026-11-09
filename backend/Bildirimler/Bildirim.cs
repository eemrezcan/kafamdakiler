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

    // What made it: "test", "hatirlatici" (a reminder's moment), "gorev" (a brain task), "dogrulama" (a task found done).
    public string KaynakTuru { get; set; } = "";

    // Says which occurrence this is, so the same one is never sent twice to the same user ("hatirlatici:<id>:<moment>",
    // "gorev:<path>:<day>"). Null for a notification that may repeat (the test send). Unique per user. The phone also reads it.
    public string? Anahtar { get; set; }

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
