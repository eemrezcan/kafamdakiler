---
kimlik: K-0012
baslik: "Gizli bilgiler user-secrets ve ortam değişkeninde"
tur: karar
soru: "Şifreler ve bağlantı dizesi nerede durur, uygulamaya nasıl verilir?"
sonuc: kabul
kavramlar: [gizli-bilgiler, user-secrets, ortam-değişkeni, env-dosyası, secret-scanning]
tags: [karar]
---

# K-0012 - Gizli bilgiler user-secrets ve ortam değişkeninde

## m01 - Gizli bilgiler koddan ayrı durur ve repoya hiç girmez
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [repo]
karar-veren: kullanici
```
2026-10-26, kullanıcı. Gizli bilgiler koddan ayrı durur ve repoya hiç girmez (S03). Bunlar Postgres bağlantı dizesi, Sahip ve Asistan seed şifreleri.

## m02 - Geliştirmede dotnet user-secrets kullanılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [geliştirme]
karar-veren: kullanici
```
Uygulama, geliştirmede `dotnet user-secrets` kullanır; değerler repo dışında, `~/.microsoft/usersecrets/` altında durur.

## m03 - Docker Compose değerleri gitignore'daki .env dosyasından okur
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [docker-compose]
karar-veren: kullanici
```
Docker Compose (geliştirmede Postgres, sunucuda tüm yığın) değerleri gitignore'daki `.env` dosyasından okur. Repoya yalnız boş değerli `.env.example` girer, dosya izni sunucuda `600` olur.

## m04 - Sunucuda uygulama aynı anahtarları ortam değişkeni olarak alır
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [sunucu]
karar-veren: kullanici
```
Sunucuda uygulama aynı anahtarları ortam değişkeni olarak alır (`ConnectionStrings__Default`, `Seed__SahipPassword`).

## m05 - appsettings.json'da yalnız anahtarlar durur, kod değeri IConfiguration'dan okur
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [appsettings, iconfiguration]
karar-veren: kullanici
```
`appsettings.json` dosyasında yalnız anahtarlar durur, değerleri boştur. Kod değeri hep `IConfiguration` üzerinden okur.

## m06 - Uygulamanın veritabanı kullanıcısı süper kullanıcı olmaz
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [veritabanı, en-az-ayrıcalık]
karar-veren: kullanici
```
Uygulamanın veritabanı kullanıcısı süper kullanıcı değildir; yalnız kendi veritabanına yetkisi vardır.

## m07 - Repo GitHub'da açılınca secret scanning ve push protection açılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [github, push-protection]
karar-veren: kullanici
```
Repo GitHub'da açılınca secret scanning ve push protection açılır.

## g01 - user-secrets .NET'in yerleşik yoludur ve yanlışlıkla commit'lenemez
```yaml
tur: g
durum: guncel
tarih: 2026-10-26
dayanak: cikarim
```
.NET'in yerleşik yolu, kütüphane gerektirmez (K-0008). user-secrets proje klasörünün dışında durduğu için yanlışlıkla commit'lenemez.

## g02 - Ortam değişkeni tek sunuculu projede olağan yoldur
```yaml
tur: g
durum: guncel
tarih: 2026-10-26
dayanak: kaynak
kavramlar: [12-factor]
```
Ortam değişkeni, tek sunuculu bir projede sektörün olağan yoludur (12-factor).

## g03 - Push protection ücretsiz bir ikinci emniyettir
```yaml
tur: g
durum: guncel
tarih: 2026-10-26
dayanak: cikarim
```
Repo public olduğu için push protection ücretsiz bir ikinci emniyettir.

## r01 - Her şey tek .env dosyasında, DotNetEnv ile
```yaml
tur: r
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Dosya proje klasöründe durduğu için sızma riski taşır; framework'ün zaten yaptığı iş için ek kütüphane gerekir.

## r02 - Gitignore'a alınmış appsettings.Development.json
```yaml
tur: r
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Aynı sızma riski; gizli olmayan geliştirme ayarları da repodan düşer.

## r03 - Secret manager (Key Vault, Vault, Infisical)
```yaml
tur: r
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
yeniden-ac: "Birden fazla sunucu ya da ortam olursa veya gizli bilgi döndürme (rotation) gerekirse."
karar-veren: kullanici
```
Tek kişilik, tek sunuculu projede tören.

## r04 - gitleaks pre-commit
```yaml
tur: r
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Şimdilik gerekmez, push protection yeterli.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-26
dayanak: bilinmiyor
```
Belgede yazılmamış.
