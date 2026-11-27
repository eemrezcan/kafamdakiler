---
kimlik: K-0014
baslik: "Zaman alanlarının türü ve saat dilimi"
tur: karar
soru: "Tarih ve saat alanları hangi türde saklanır, hangi saat dilimine göre gösterilir?"
sonuc: kabul
kavramlar: [zaman-türleri, saat-dilimi, datetimeoffset, dateonly, timeonly, timestamptz, europe-istanbul]
tags: [karar]
---

# K-0014 - Zaman alanlarının türü ve saat dilimi

## m01 - Zaman alanının türü alanın neyi anlattığına göre seçilir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
karar-veren: kullanici
```
2026-10-29, kullanıcı. Zaman alanının türü, alanın neyi anlattığına göre seçilir.

## m02 - Bir kez olan an DateTimeOffset olarak UTC saklanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [utc]
karar-veren: kullanici
```
Bir kez olan an (`CreatedAt`, antrenman başlangıcı): `DateTimeOffset`, Postgres'te `timestamptz`, UTC olarak saklanır.

## m03 - Saatsiz takvim günü DateOnly olarak saklanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [takvim-günü]
karar-veren: kullanici
```
Saatsiz takvim günü (doğum günü, hatırlatıcının günü): `DateOnly`, Postgres'te `date`.

## m04 - Her gün tekrar eden saat kuralı TimeOnly olarak saklanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [hatırlatıcı]
karar-veren: kullanici
```
Her gün tekrar eden saat kuralı (hatırlatıcının saati): `TimeOnly`, Postgres'te `time`.

## m05 - Gösterim ve gün hesabı Europe/Istanbul'a göre yapılır, yerel günün raporu UTC aralığına çevrilir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [rapor]
karar-veren: kullanici
```
Gösterim ve "gün" hesabı Europe/Istanbul saat dilimine göre yapılır. Yerel bir günün raporu, o günün UTC aralığına çevrilerek sorgulanır.

## g01 - Takvim günü ya da saat kuralı an çevrilirse tarih kayar
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
Q08 ve Q09: Takvim günü ya da saat kuralı ana çevrilirse tarih kayar (29 Ekim 00:00 İstanbul, UTC'de 28 Ekim 21:00 eder). "Ayın 15'i 09:00" gibi bir kural bir an değildir, sunucu her seferinde gerçek anı bu kuraldan hesaplar.

## g02 - Npgsql bu türlerin hepsini doğrudan eşler
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: kaynak
kavramlar: [npgsql]
```
Npgsql bu türlerin hepsini doğrudan eşler.

## r01 - Her alan için DateTime + timestamp without time zone
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "Uygulama birden çok saat diliminde kullanılmaya başlarsa (kullanıcı başına saat dilimi alanı gerekir)."
karar-veren: kullanici
```
Hangi saat diliminde olduğu belirsiz kalır, Npgsql 6 sonrası `Kind` karışıklığı yaşanır.

## r02 - Takvim günlerini ve saatleri UTC an olarak saklamak
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "Uygulama birden çok saat diliminde kullanılmaya başlarsa (kullanıcı başına saat dilimi alanı gerekir)."
karar-veren: kullanici
```
Gün ve saat kayar.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-29
dayanak: bilinmiyor
```
Belgede yazılmamış.
