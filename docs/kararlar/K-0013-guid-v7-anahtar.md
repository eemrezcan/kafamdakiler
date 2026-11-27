---
kimlik: K-0013
baslik: "Birincil anahtar her tabloda Guid v7"
tur: karar
soru: "Tabloların birincil anahtarı hangi tiptedir, Id kim tarafından üretilir?"
sonuc: kabul
kavramlar: [guid-v7, birincil-anahtar, çevrimdışı, uuid, postgresql, identity]
tags: [karar]
---

# K-0013 - Birincil anahtar her tabloda Guid v7

## m01 - Her tablonun birincil anahtarı Guid v7 olur
```yaml
tur: m
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
karar-veren: kullanici
```
2026-10-27, kullanıcı. Her tablonun birincil anahtarı `Guid` olur, değeri UUID sürüm 7'dir (Postgres'te `uuid`).

## m02 - Sunucuda Id'yi EF Core üretir
```yaml
tur: m
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
kavramlar: [ef-core, npgsql]
karar-veren: kullanici
```
Sunucuda Id'yi EF Core üretir (Npgsql sağlayıcısının varsayılanı; A01'de doğrulanır, gerekirse `Guid.CreateVersion7()`).

## m03 - Çevrimdışı girilen kayıtların Id'sini telefon üretir
```yaml
tur: m
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
kavramlar: [mobil, dart]
karar-veren: kullanici
```
Çevrimdışı girilen kayıtların Id'sini telefon üretir (Dart `uuid` paketi, v7).

## m04 - Gelen Id zaten varsa sunucu yeni kayıt açmaz, mevcut kaydı döndürür
```yaml
tur: m
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
kavramlar: [idempotans, kopya-kayıt]
karar-veren: kullanici
```
Gelen Id zaten varsa sunucu yeni kayıt açmaz, mevcut kaydı döndürür.

## m05 - Identity tabloları da Guid anahtar kullanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
kavramlar: [identityuser]
karar-veren: kullanici
```
Tutarlılık için Identity tabloları da `Guid` anahtar kullanır (`IdentityUser<Guid>`, `IdentityRole<Guid>`).

## g01 - Çevrimdışıyken telefon sunucudan Id alamaz, kendisi üretmelidir
```yaml
tur: g
durum: guncel
tarih: 2026-10-27
dayanak: kaynak
```
G05: Çevrimdışıyken telefon sunucudan Id alamaz, kendisi üretmelidir.

## g02 - Id tekrar gönderimde kopya oluşturmaz, v7 index'i parçalamaz
```yaml
tur: g
durum: guncel
tarih: 2026-10-27
dayanak: cikarim
```
Aynı istek tekrar gönderildiğinde Id sayesinde kopya oluşmaz. v7'nin başı zaman damgası olduğu için Id'ler sıralı gelir ve index'i parçalamaz.

## g03 - Tek kural bütün tablolarda geçerlidir
```yaml
tur: g
durum: guncel
tarih: 2026-10-27
dayanak: cikarim
```
Tek kural bütün tablolarda geçerli olduğundan akılda tutması kolaydır. Ders örnekleri `int` kullanıyor; çevrimdışı giriş yüzünden ayrılıyoruz.

## r01 - int sayaç
```yaml
tur: r
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
yeniden-ac: "Yok."
karar-veren: kullanici
```
Çevrimdışı Id üretilemez, tekrar gönderimde kopya kayıt oluşur.

## r02 - Guid v4
```yaml
tur: r
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
yeniden-ac: "Yok."
karar-veren: kullanici
```
Rastgele olduğu için index'i parçalar.

## r03 - int birincil anahtar + ek Guid ClientId
```yaml
tur: r
durum: guncel
tarih: 2026-10-27
dayanak: kullanici
yeniden-ac: "Yok."
karar-veren: kullanici
```
Her tabloda iki kimlik olur, ilişkilerde hangisinin kullanılacağı karışır.

## b01 - Id'ler ekranda okunaklı değildir, kullanıcıya gösterilmez
```yaml
tur: b
durum: guncel
tarih: 2026-10-27
dayanak: cikarim
```
Kaybolan: Id'ler ekranda okunaklı değil; kullanıcıya Id gösterilmez.
