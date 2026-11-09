namespace Kafamdakiler.Ozet;

// A week whose summary note is in the brain. One row per week, so the week is written once whatever the number of rounds or restarts.
public class HaftalikOzetKaydi
{
    // The Monday of the week (the app's day, GunSiniri).
    public DateOnly Hafta { get; set; }

    public DateTimeOffset YazilmaAni { get; set; }
}
