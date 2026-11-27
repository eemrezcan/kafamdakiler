---
kimlik: K-0019
baslik: "Mobil (Flutter) kütüphane yığını"
tur: karar
soru: "Flutter uygulamasında durum, HTTP, yerel veri, token, gezinme, bildirim ve fotoğraf için hangi araçlar kullanılır?"
sonuc: kabul
kavramlar: [mobil, flutter, kütüphane-yığını, offline-first, token, bildirim]
tags: [karar]
---

# K-0019 - Mobil (Flutter) kütüphane yığını

2026-10-29, kullanıcı (5-7. maddeler kullanıcının "sorusuz hızlıca kararlaştır" isteğiyle önerildiği gibi kabul edildi).

## m01 - Durum için setState, paylaşılan durum için provider + ChangeNotifier kullanılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [durum-yönetimi, provider]
karar-veren: kullanici
```
Seçim: `setState`; paylaşılan durum `provider` + `ChangeNotifier`. Kural: Tek ekranın verisi `setState`, birden çok ekranın okuduğu veri (oturum, bekleyen setler) `provider` (Q14).

## m02 - HTTP için dio kullanılır, 401'de bir kez yenileyip tekrarlanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [dio, interceptor, refresh-token]
karar-veren: kullanici
```
Seçim: `dio`. Kural: Interceptor token'ı ekler; 401'de `/api/hesap/refresh` ile yeniler ve isteği **bir kez** tekrarlar, olmazsa giriş ekranına düşer (Q15).

## m03 - Yerel veri drift (SQLite) ile tutulur, set önce telefona yazılıp eşitlenir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [drift, sqlite, eşitleme, guid-v7]
karar-veren: kullanici
```
Seçim: `drift` (SQLite). Kural: Offline-first: set önce telefona yazılır, `gonderildi` bayrağıyla eşitlenir; Id telefonda Guid v7 (K-0013), sunucu tekrar gelen Id'de mevcut kaydı 200 ile döner (Q16).

## m04 - Token flutter_secure_storage ile şifreli depoda tutulur
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [flutter-secure-storage, keystore, shared-preferences]
karar-veren: kullanici
```
Seçim: `flutter_secure_storage`. Kural: Access ve refresh token Keystore destekli şifreli depoda; çıkışta silinir. `shared_preferences` yalnız ayarlar için (Q17).

## m05 - Gezinme go_router ile yapılır, girişsiz kullanıcı giriş ekranına yönlenir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [go-router, gezinme]
karar-veren: kullanici
```
Seçim: `go_router`. Kural: `redirect` + `refreshListenable: Oturum`: girişsiz kullanıcı giriş ekranına yönlenir.

## m06 - Bildirim yerel bildirimle kurulur, kural sunucuda durur
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [flutter-local-notifications, hatırlatıcı, android-izinleri]
karar-veren: kullanici
```
Seçim: `flutter_local_notifications` + `timezone` + `flutter_timezone`. Kural: Telefonda yerel bildirim, `zonedSchedule` ile Europe/Istanbul'a göre. Kural sunucuda durur (K-0014), telefon sıradaki örnekleri hesaplayıp kurar ve uygulama her açıldığında yeniden kurar. İzinler: `POST_NOTIFICATIONS` (Android 13+), kesin alarm (`SCHEDULE_EXACT_ALARM`), yeniden başlatmada kurmak için `RECEIVE_BOOT_COMPLETED`; pil optimizasyonu için kullanıcıya ayar ekranı gösterilir.

## m07 - Fotoğraf image_picker ile alınır, sunucuya girişli uçla gider
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [image-picker, fotoğraf, paylaş-menüsü]
karar-veren: kullanici
```
Seçim: `image_picker`. Kural: Kamera ya da galeri; sunucuya K-0015'teki girişli uçla gider. Faz 2 Paylaş menüsü: `receive_sharing_intent`.

## g01 - Hepsi işini yapan olgun, yaygın paketlerdir
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
K-0006 ve K-0008: her biri işini yapan olgun, yaygın paketlerdir; akışı dolaştıran kalıp kütüphanesi yoktur.

## g02 - Ders notlarından iki yerde ayrılınır
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: kaynak
kavramlar: [ders-örnekleri]
```
Ders notları `setState`, `shared_preferences`, `http`/`dio` anlatır; `shared_preferences`'ı token için kullanmayarak ve `dio`'nun interceptor'ını kullanarak ayrılıyoruz.

## r01 - Riverpod, Bloc
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Daha çok tören (event, state sınıfları, kod üretimi).

## r02 - http paketi
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Interceptor yok, token ekleme ve yenileme elle sarmalanır.

## r03 - sqflite, ve liste için shared_preferences
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
`sqflite`: ham SQL, hata çalışma anında çıkar. `shared_preferences` liste için: sorgulanamaz.

## r04 - shared_preferences token için
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Düz metin XML.

## r05 - Firebase Cloud Messaging (sunucudan push)
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "Bildirimin sunucudan anında tetiklenmesi gerekirse (ör. Asistan görev ekleyince telefon hemen öttürülsün) FCM yeniden düşünülür."
kavramlar: [fcm]
karar-veren: kullanici
```
Firebase hesabı ve sunucu tarafı gerekir; tek kullanıcılı hatırlatıcıya yerel bildirim yeter.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-29
dayanak: bilinmiyor
```
Belgede yazılmamış.
