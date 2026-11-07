namespace Kafamdakiler.Eylemler;

public enum EylemDurumu { Bekliyor, Uygulandi, Reddedildi, GeriAlindi, Hatali }

// What the Asistan may do for a kind of action without asking (K2.6).
public enum EylemKipi { Sor, KendinYap, Yasak }

// One suggested action waiting in the approval queue, or already decided. Claude (or a voice command, a mail...)
// only ever suggests; nothing happens until the action is applied.
public class Eylem
{
    public Guid Id { get; set; } = Guid.CreateVersion7();

    // The key of an IEylemTuru, e.g. "hatirlatici-kur".
    public string Tur { get; set; } = "";

    // The payload, a JSON object in the shape its kind expects (jsonb).
    public string Yuk { get; set; } = "{}";

    // One line a person reads before approving.
    public string Ozet { get; set; } = "";

    // Where the suggestion came from: "kullanici", "ses", "gelen", "brifing", "mail"...
    public string Kaynak { get; set; } = "";

    // True when the suggestion was drawn from text someone else wrote (a mail, a web page). Such an action is never
    // applied by itself, whatever the kind's mode says.
    public bool DisKaynak { get; set; }

    public string? Gerekce { get; set; }

    // 0 to 1, when the source can tell.
    public double? Guven { get; set; }

    public EylemDurumu Durum { get; set; } = EylemDurumu.Bekliyor;

    // What undo needs (jsonb); set when the action is applied.
    public string? GeriAlmaBilgisi { get; set; }

    public string? HataMesaji { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    // When it was approved, rejected or applied by itself.
    public DateTimeOffset? KararAni { get; set; }
    public DateTimeOffset? UygulamaAni { get; set; }
    public DateTimeOffset? GeriAlmaAni { get; set; }

    // The user who decided; null when the action was applied by itself.
    public Guid? KararVerenId { get; set; }
}

// The mode of one kind. No row means Sor.
public class EylemIzni
{
    public string Tur { get; set; } = "";
    public EylemKipi Kip { get; set; } = EylemKipi.Sor;

    // Rejections of this kind in a row, reset by an approval or by choosing a mode.
    public int ArdArdaRed { get; set; }

    public DateTimeOffset GuncellemeAni { get; set; } = DateTimeOffset.UtcNow;
}

public enum EylemOlayi { Onerildi, YasakAtlandi, Uygulandi, OtomatikUygulandi, Reddedildi, GeriAlindi, Hatali, KipDegisti }

// Every step an action takes, and every mode change. EylemId has no foreign key: a suggestion skipped for a forbidden
// kind never becomes an Eylem, and the log outlives them.
public class EylemGunlugu
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid? EylemId { get; set; }
    public string Tur { get; set; } = "";
    public EylemOlayi Olay { get; set; }
    public string Aciklama { get; set; } = "";

    // Who did it; null means the system.
    public Guid? KullaniciId { get; set; }

    public DateTimeOffset Zaman { get; set; } = DateTimeOffset.UtcNow;
}
