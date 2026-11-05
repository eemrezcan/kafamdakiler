using Kafamdakiler.Aliskanliklar;
using Kafamdakiler.Dosyalar;
using Kafamdakiler.Yakalamalar;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Kafamdakiler.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options)
    : IdentityDbContext<IdentityUser<Guid>, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<Aliskanlik> Aliskanliklar => Set<Aliskanlik>();
    public DbSet<AliskanlikKaydi> AliskanlikKayitlari => Set<AliskanlikKaydi>();
    public DbSet<Oge> Ogeler => Set<Oge>();
    public DbSet<Oturum> Oturumlar => Set<Oturum>();
    public DbSet<Dosya> Dosyalar => Set<Dosya>();
    public DbSet<Yakalama> Yakalamalar => Set<Yakalama>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<Aliskanlik>(e =>
        {
            e.Property(x => x.Ad).HasMaxLength(100);
            e.Property(x => x.Ikon).HasMaxLength(50);
            e.Property(x => x.Renk).HasMaxLength(30);
            e.Property(x => x.GunlukHedef).HasPrecision(10, 2);
            e.Property(x => x.Birim).HasMaxLength(30);
            e.Property(x => x.OgeEtiketi).HasMaxLength(30);
            e.Property(x => x.AltBaslikEtiketi).HasMaxLength(30);
            e.Property(x => x.Tur).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.Olcu).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.HedefYonu).HasConversion<string>().HasMaxLength(20);
            e.Property(x => x.Siklik).HasConversion<string>().HasMaxLength(20);
            // Gunler is a [Flags] enum; EF stores it as one int bit field.

            e.HasMany(x => x.Kayitlar).WithOne().HasForeignKey(x => x.AliskanlikId).OnDelete(DeleteBehavior.Cascade);
            e.HasMany(x => x.Ogeler).WithOne(x => x.Aliskanlik).HasForeignKey(x => x.AliskanlikId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<AliskanlikKaydi>(e =>
        {
            e.Property(x => x.Miktar).HasPrecision(10, 2);
            e.HasIndex(x => new { x.AliskanlikId, x.Tarih }).IsUnique();
        });

        builder.Entity<Oge>(e =>
        {
            e.Property(x => x.Ad).HasMaxLength(200);
            e.Property(x => x.AltBaslik).HasMaxLength(200);
            e.Property(x => x.Not).HasMaxLength(2000);
            e.Property(x => x.Toplam).HasPrecision(10, 2);
            e.Property(x => x.BaslangicKonumu).HasPrecision(10, 2);
            e.Property(x => x.Durum).HasConversion<string>().HasMaxLength(20);

            e.HasOne(x => x.Fotograf).WithMany().HasForeignKey(x => x.FotografId).OnDelete(DeleteBehavior.SetNull);
            e.HasMany(x => x.Oturumlar).WithOne(x => x.Oge).HasForeignKey(x => x.OgeId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<Oturum>(e =>
        {
            e.Property(x => x.BaslangicKonum).HasPrecision(10, 2);
            e.Property(x => x.BitisKonum).HasPrecision(10, 2);
            e.HasIndex(x => new { x.OgeId, x.BitisKonum });
        });

        builder.Entity<Yakalama>(e =>
        {
            e.Property(x => x.Metin).HasMaxLength(5000);
            e.Property(x => x.Hedef).HasMaxLength(100);
            e.Property(x => x.Durum).HasConversion<string>().HasMaxLength(20);
            e.HasIndex(x => new { x.Durum, x.YakalandiAt });

            e.HasOne(x => x.Fotograf).WithMany().HasForeignKey(x => x.FotografId).OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<Dosya>(e =>
        {
            e.Property(x => x.DiskAdi).HasMaxLength(100);
            e.Property(x => x.IcerikTuru).HasMaxLength(50);
        });
    }
}
