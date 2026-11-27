---
kimlik: K-0015
baslik: "Yüklenen dosyalar wwwroot dışında, girişli uçtan"
tur: karar
soru: "Yüklenen dosyalar (vücut fotoğrafı vb.) nerede saklanır ve nasıl verilir?"
sonuc: kabul
kavramlar: [dosya-saklama, yükleme, wwwroot, policy, volume, fotoğraf]
tags: [karar]
---

# K-0015 - Yüklenen dosyalar wwwroot dışında, girişli uçtan

## m01 - Yüklenen dosyalar sunucu diskinde wwwroot dışında durur
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
karar-veren: kullanici
```
2026-10-29, kullanıcı. Dosyalar sunucu diskinde, `wwwroot` dışındaki bir klasörde durur.

## m02 - Klasörün yolu yapılandırmadan okunur, Docker'da volume olarak bağlanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [docker, yapılandırma]
karar-veren: kullanici
```
Klasörün yolu yapılandırmadan okunur (`Dosyalar:Klasor`); Docker'da bu klasör volume olarak bağlanır.

## m03 - Dosyalar yalnız girişli ve policy'li bir uçtan verilir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [giriş, results-physicalfile]
karar-veren: kullanici
```
Dosyalar yalnız girişli ve policy'li bir uç noktadan verilir (`Results.PhysicalFile`).

## m04 - Veritabanında dosyanın kendisi değil bilgisi tutulur
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [veritabanı, guid-v7, timestamptz]
karar-veren: kullanici
```
Veritabanında dosyanın kendisi değil, bilgisi tutulur: Id (Guid v7, K-0013), disk yolu, içerik türü, boyut ve yükleme anı (`timestamptz`, K-0014).

## m05 - Diskteki adı sunucu Guid olarak üretir, kullanıcının gönderdiği ad diske yazılmaz
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [yol-aşımı]
karar-veren: kullanici
```
Diskteki adı sunucu Guid olarak üretir; kullanıcının gönderdiği ad diske yazılmaz.

## m06 - Yalnız jpg, png ve webp kabul edilir, dosya başına en çok 10 MB
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [dosya-türü, boyut-sınırı]
karar-veren: kullanici
```
Yalnız jpg, png ve webp kabul edilir, dosya başına en çok 10 MB.

## g01 - wwwroot içindeki dosya girişsiz verilir, izin matrisi devreye girmez
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
kavramlar: [izin]
```
Q10: `wwwroot` içindeki dosyayı `UseStaticFiles` giriş istemeden verir; adresi bilen herkes görür ve K-0009'daki izin matrisi hiç devreye girmez. Adı gizlemek koruma değildir.

## g02 - Girişli uç her istekte izni kontrol eder, sunucu adı yol aşımını önler
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
Girişli uç, her istekte izni kontrol eder. Sunucunun ürettiği ad, yol aşımını (`../`) ve ad çakışmasını önler.

## r01 - wwwroot altında saklamak
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Policy atlanır.

## r02 - Veritabanında bytea
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Yedeği şişirir, sorguları yavaşlatır.

## r03 - Nesne depolama (S3 vb.)
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "Diskteki dosyalar için ayrı yedek gerekirse ya da tek sunucu yetmezse nesne depolama yeniden düşünülür."
karar-veren: kullanici
```
Bugünkü ölçekte gereksiz.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-29
dayanak: bilinmiyor
```
Belgede yazılmamış.
