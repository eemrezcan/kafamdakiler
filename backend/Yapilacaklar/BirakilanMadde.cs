namespace Kafamdakiler.Yapilacaklar;

// "Bırak" on a leftover of yesterday (K-0024): the person dropped the item from today's "dünden kalanlar" list instead of carrying it over.
// Nothing is written to the brain (closing yesterday is the closing job's work); this row only hides the item from that list.
// `Tarih` is the day whose list it was dropped from (today), `MaddeId` the permanent id of yesterday's plan item.
public class BirakilanMadde
{
    public DateOnly Tarih { get; set; }
    public string MaddeId { get; set; } = "";
    public Guid KullaniciId { get; set; }
    public DateTimeOffset BirakmaAni { get; set; }
}
