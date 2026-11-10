using Kafamdakiler.Aliskanliklar;

namespace Kafamdakiler.Hatirlaticilar;

public class Hatirlatici
{
    public const int VarsayilanIsrarAraligi = 15;
    public const int VarsayilanIsrarEnCok = 3;

    public Guid Id { get; set; } = Guid.CreateVersion7();
    public string Baslik { get; set; } = "";
    public string? Not { get; set; }
    public HatirlaticiTuru Tur { get; set; }
    // Only meaningful for Soz (a promise made to someone).
    public string? Kime { get; set; }
    // First (or only) day of the rule, in Europe/Istanbul.
    public DateOnly Gun { get; set; }
    // Null means the default morning hour from the settings.
    public TimeOnly? Saat { get; set; }
    public Tekrar Tekrar { get; set; }
    public int OnceGun { get; set; }
    public HatirlaticiDurumu Durum { get; set; }
    // The next firing moment, computed from the rule and stored so lists can be sorted and filtered in SQL.
    public DateTimeOffset SonrakiAn { get; set; }
    // A snooze: when set, it comes before SonrakiAn. The rule itself is unchanged.
    public DateTimeOffset? ErteleAn { get; set; }
    // Persistent reminder (H4): the phone re-notifies every IsrarAraligiDakika minutes, at most IsrarEnCok times, until done or snoozed.
    // The server only stores these; the behaviour lives on the phone.
    public bool Israrli { get; set; }
    public int IsrarAraligiDakika { get; set; } = VarsayilanIsrarAraligi;
    public int IsrarEnCok { get; set; } = VarsayilanIsrarEnCok;
    // Urgent: the phone lets it through silent mode.
    public bool Acil { get; set; }
    // The link to the plan (K-0024): a reminder is a property of the item it is about. The plan item is named by its permanent id and the
    // day of its plan file (an id is unique inside one day file only); the task by its slug. Both may be set (an item linked to a task).
    public string? MaddeId { get; set; }
    public DateOnly? MaddeTarihi { get; set; }
    public string? GorevKimligi { get; set; }
    // The days of a weekly reminder (several per week). Only meaningful for Tekrar.Haftalik; empty means the weekday of `Gun`.
    public Gunler Gunler { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public DateTimeOffset EtkinAn => ErteleAn ?? SonrakiAn;
}
