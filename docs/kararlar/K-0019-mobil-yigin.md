---
baslik: Mobil (Flutter) kütüphane yığını
tur: karar
soru: Flutter uygulamasında durum, HTTP, yerel veri, token, gezinme, bildirim ve fotoğraf için hangi araçlar kullanılır?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-29, kullanıcı (5-7. maddeler kullanıcının "sorusuz hızlıca kararlaştır" isteğiyle önerildiği gibi kabul edildi).

| Konu | Seçim | Kural |
| --- | --- | --- |
| Durum | `setState`; paylaşılan durum `provider` + `ChangeNotifier` | Tek ekranın verisi `setState`, birden çok ekranın okuduğu veri (oturum, bekleyen setler) `provider` (Q14) |
| HTTP | `dio` | Interceptor token'ı ekler; 401'de `/api/hesap/refresh` ile yeniler ve isteği **bir kez** tekrarlar, olmazsa giriş ekranına düşer (Q15) |
| Yerel veri | `drift` (SQLite) | Offline-first: set önce telefona yazılır, `gonderildi` bayrağıyla eşitlenir; Id telefonda Guid v7 (K-0013), sunucu tekrar gelen Id'de mevcut kaydı 200 ile döner (Q16) |
| Token | `flutter_secure_storage` | Access ve refresh token Keystore destekli şifreli depoda; çıkışta silinir. `shared_preferences` yalnız ayarlar için (Q17) |
| Gezinme | `go_router` | `redirect` + `refreshListenable: Oturum`: girişsiz kullanıcı giriş ekranına yönlenir |
| Bildirim | `flutter_local_notifications` + `timezone` + `flutter_timezone` | Telefonda yerel bildirim, `zonedSchedule` ile Europe/Istanbul'a göre. Kural sunucuda durur (K-0014), telefon sıradaki örnekleri hesaplayıp kurar ve uygulama her açıldığında yeniden kurar. İzinler: `POST_NOTIFICATIONS` (Android 13+), kesin alarm (`SCHEDULE_EXACT_ALARM`), yeniden başlatmada kurmak için `RECEIVE_BOOT_COMPLETED`; pil optimizasyonu için kullanıcıya ayar ekranı gösterilir |
| Fotoğraf | `image_picker` | Kamera ya da galeri; sunucuya K-0015'teki girişli uçla gider. Faz 2 Paylaş menüsü: `receive_sharing_intent` |

## Gerekçe
K-0006 ve K-0008: her biri işini yapan olgun, yaygın paketlerdir; akışı dolaştıran kalıp kütüphanesi yoktur. Ders notları `setState`, `shared_preferences`, `http`/`dio` anlatır; `shared_preferences`'ı token için kullanmayarak ve `dio`'nun interceptor'ını kullanarak ayrılıyoruz.

## Reddedilenler
- Riverpod, Bloc: daha çok tören (event, state sınıfları, kod üretimi).
- `http`: interceptor yok, token ekleme ve yenileme elle sarmalanır.
- `sqflite`: ham SQL, hata çalışma anında çıkar. `shared_preferences` liste için: sorgulanamaz.
- `shared_preferences` token için: düz metin XML.
- Firebase Cloud Messaging (sunucudan push): Firebase hesabı ve sunucu tarafı gerekir; tek kullanıcılı hatırlatıcıya yerel bildirim yeter.

## Yeniden açma koşulu
Bildirimin sunucudan anında tetiklenmesi gerekirse (ör. Asistan görev ekleyince telefon hemen öttürülsün) FCM yeniden düşünülür.
