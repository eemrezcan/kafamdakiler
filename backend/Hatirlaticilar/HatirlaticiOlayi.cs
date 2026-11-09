namespace Kafamdakiler.Hatirlaticilar;

public enum HatirlaticiOlayTuru { Yapildi, Ertelendi }

// What was done to a reminder and when: the weekly summary counts these (on time, late, snoozed). Kept apart from the reminder
// because a repeating reminder moves on after "done"; no foreign key, so deleting a reminder keeps the week's count.
public class HatirlaticiOlayi
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid HatirlaticiId { get; set; }
    public HatirlaticiOlayTuru Tur { get; set; }

    // The moment the reminder was due when it was acted on (EtkinAn before the change).
    public DateTimeOffset HedefAn { get; set; }

    public DateTimeOffset Zaman { get; set; }
}
