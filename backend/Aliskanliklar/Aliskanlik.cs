namespace Kafamdakiler.Aliskanliklar;

public class Aliskanlik
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public string Ad { get; set; } = "";
    public AliskanlikTuru Tur { get; set; }
    public string Ikon { get; set; } = "";
    public string Renk { get; set; } = "";
    public Olcu Olcu { get; set; }
    public HedefYonu HedefYonu { get; set; }
    public decimal? GunlukHedef { get; set; }
    public string? Birim { get; set; }
    public string? OgeEtiketi { get; set; }
    public string? AltBaslikEtiketi { get; set; }
    public Siklik Siklik { get; set; }
    public int? HaftalikSayi { get; set; }
    public Gunler? Gunler { get; set; }
    public int Sira { get; set; }
    public bool Arsivlendi { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public List<AliskanlikKaydi> Kayitlar { get; set; } = [];
    public List<Oge> Ogeler { get; set; } = [];
}

// Daily entry of a Sayac habit.
public class AliskanlikKaydi
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid AliskanlikId { get; set; }
    public DateOnly Tarih { get; set; }
    public decimal Miktar { get; set; }
    public int? Dakika { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

// Item of a Raf habit (a book, a series, a course).
public class Oge
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid AliskanlikId { get; set; }
    public string Ad { get; set; } = "";
    public string? AltBaslik { get; set; }
    public decimal? Toplam { get; set; }
    public decimal BaslangicKonumu { get; set; }
    public Guid? FotografId { get; set; }
    public OgeDurumu Durum { get; set; }
    public DateOnly? BaslamaTarihi { get; set; }
    public DateOnly? BitisTarihi { get; set; }
    public int? Puan { get; set; }
    public string? Not { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public Aliskanlik? Aliskanlik { get; set; }
    public Dosyalar.Dosya? Fotograf { get; set; }
    public List<Oturum> Oturumlar { get; set; } = [];
}

public class Oturum
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public Guid OgeId { get; set; }
    public DateOnly Tarih { get; set; }
    public decimal BaslangicKonum { get; set; }
    public decimal BitisKonum { get; set; }
    public int? Dakika { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Derived, not stored.
    public decimal Miktar => BitisKonum - BaslangicKonum;

    public Oge? Oge { get; set; }
}
