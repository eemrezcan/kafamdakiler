---
kimlik: K-0002
baslik: "Veritabanı PostgreSQL"
tur: karar
soru: "Hangi veritabanı kullanılır?"
sonuc: kabul
kavramlar: [postgresql, veritabanı, ef-core, ders-örnekleri]
tags: [karar]
---

# K-0002 - Veritabanı PostgreSQL

## m01 - Veritabanı olarak PostgreSQL kullanılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
karar-veren: kullanici
```
2026-10-15, kullanıcı. PostgreSQL (EF Core, Npgsql).

## g01 - LocalDB yalnız Windows'ta çalışır, makine ve sunucu Linux
```yaml
tur: g
durum: guncel
tarih: 2026-10-15
dayanak: kaynak
```
Dersin örnekleri SQL Server LocalDB kullanıyor ama LocalDB yalnız Windows'ta çalışıyor; geliştirme makinesi ve sunucu Linux. Hoca SQL Server şart koşmuyor.

## g02 - EF Core ders örneklerinin kodunu büyük ölçüde korur
```yaml
tur: g
durum: guncel
tarih: 2026-10-15
dayanak: cikarim
```
EF Core sayesinde ders örneklerinin kodu büyük ölçüde aynı kalır.

## r01 - SQL Server (Docker'da)
```yaml
tur: r
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
yeniden-ac: "Hoca SQL Server şartı koyarsa."
karar-veren: kullanici
```
Mümkün ama Linux sunucuda daha ağır; şart değil.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-15
dayanak: bilinmiyor
```
Belgede yazılmamış.
