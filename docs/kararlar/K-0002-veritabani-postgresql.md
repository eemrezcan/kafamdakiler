---
baslik: Veritabanı PostgreSQL
tur: karar
soru: Hangi veritabanı kullanılır?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-15, kullanıcı. PostgreSQL (EF Core, Npgsql).

## Gerekçe
Dersin örnekleri SQL Server LocalDB kullanıyor ama LocalDB yalnız Windows'ta çalışıyor; geliştirme makinesi ve sunucu Linux. Hoca SQL Server şart koşmuyor. EF Core sayesinde ders örneklerinin kodu büyük ölçüde aynı kalır.

## Reddedilenler
- SQL Server (Docker'da): mümkün ama Linux sunucuda daha ağır; şart değil.

## Yeniden açma koşulu
Hoca SQL Server şartı koyarsa.
