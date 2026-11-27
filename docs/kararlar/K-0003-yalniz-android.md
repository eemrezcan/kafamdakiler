---
kimlik: K-0003
baslik: "Yalnız Android, Play Store yok"
tur: karar
soru: "Mobil uygulama hangi platformda çalışır ve nasıl dağıtılır?"
sonuc: kabul
kavramlar: [android, mobil, apk, play-store]
tags: [karar]
---

# K-0003 - Yalnız Android, Play Store yok

## m01 - Mobil uygulama yalnız Android için hedeflenir
```yaml
tur: m
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
karar-veren: kullanici
```
2026-10-15, kullanıcı (telefon Android). Mobil uygulama yalnız Android için hedeflenir.

## m02 - APK telefona doğrudan kurulur, Play Store'a yüklenmez
```yaml
tur: m
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
karar-veren: kullanici
```
APK telefona doğrudan kurulur, Play Store'a yüklenmez.

## g01 - Android'de adım ve ekran süresi okunabiliyor
```yaml
tur: g
durum: guncel
tarih: 2026-10-15
dayanak: kaynak
kavramlar: [health-connect, ekran-süresi]
```
Tek kullanıcı. Adım (Health Connect) ve ekran süresi (UsageStatsManager) Android'de okunabiliyor; iOS'ta ekran süresinin karşılığı yok.

## g02 - Mağazaya yüklenmeyince izin beyanı gerekmez
```yaml
tur: g
durum: guncel
tarih: 2026-10-15
dayanak: cikarim
```
Play Store'a yüklenmeyince Health Connect ve kullanım istatistiği izinlerinin mağaza beyanı gerekmez (çıkarım).

## r01 - iOS desteği
```yaml
tur: r
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
yeniden-ac: "Uygulama başka kullanıcılara açılırsa ya da kullanıcı iPhone kullanmaya başlarsa."
karar-veren: kullanici
```
Ekran süresi verisi alınamıyor, kullanıcının cihazı yok.

## r02 - Play Store yayını
```yaml
tur: r
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
yeniden-ac: "Uygulama başka kullanıcılara açılırsa ya da kullanıcı iPhone kullanmaya başlarsa."
karar-veren: kullanici
```
Kişisel kullanım için gereksiz, izin politikası yükü getirir.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-15
dayanak: bilinmiyor
```
Belgede yazılmamış.
