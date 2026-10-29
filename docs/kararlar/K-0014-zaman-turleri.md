---
baslik: Zaman alanlarının türü ve saat dilimi
tur: karar
soru: Tarih ve saat alanları hangi türde saklanır, hangi saat dilimine göre gösterilir?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-29, kullanıcı. Zaman alanının türü, alanın neyi anlattığına göre seçilir:
- Bir kez olan an (`CreatedAt`, antrenman başlangıcı): `DateTimeOffset`, Postgres'te `timestamptz`, UTC olarak saklanır.
- Saatsiz takvim günü (doğum günü, hatırlatıcının günü): `DateOnly`, Postgres'te `date`.
- Her gün tekrar eden saat kuralı (hatırlatıcının saati): `TimeOnly`, Postgres'te `time`.

Gösterim ve "gün" hesabı Europe/Istanbul saat dilimine göre yapılır. Yerel bir günün raporu, o günün UTC aralığına çevrilerek sorgulanır.

## Gerekçe
Q08 ve Q09: Takvim günü ya da saat kuralı ana çevrilirse tarih kayar (29 Ekim 00:00 İstanbul, UTC'de 28 Ekim 21:00 eder). "Ayın 15'i 09:00" gibi bir kural bir an değildir, sunucu her seferinde gerçek anı bu kuraldan hesaplar. Npgsql bu türlerin hepsini doğrudan eşler.

## Reddedilenler
- Her alan için `DateTime` + `timestamp without time zone`: hangi saat diliminde olduğu belirsiz kalır, Npgsql 6 sonrası `Kind` karışıklığı yaşanır.
- Takvim günlerini ve saatleri UTC an olarak saklamak: gün ve saat kayar.

## Yeniden açma koşulu
Uygulama birden çok saat diliminde kullanılmaya başlarsa (kullanıcı başına saat dilimi alanı gerekir).
