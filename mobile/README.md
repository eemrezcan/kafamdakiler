# Kafamdakiler mobil (Flutter, yalnız Android)

Alışkanlık takibinin mobil uygulaması. Veriye yalnız kendi Web API'mizden erişir (`../backend`); çevrimdışıyken günlük girişleri telefona yazar, bağlantı gelince gönderir.

## Gerekenler

- Flutter 3.47 (stable), Dart 3.12; `flutter --version` ile bak
- Android SDK; emülatör ya da USB hata ayıklaması açık bir telefon
- Çalışan API (`../backend`, varsayılan `http://localhost:5051`)

## Çalıştırma

```bash
cd mobile
flutter pub get
dart run build_runner build      # *.g.dart dosyaları repoda hazır; model ya da drift şeması değişince yeniden üret
flutter run --dart-define=API_URL=http://localhost:5051
```

### API adresi

`API_URL` derleme zamanında `--dart-define` ile verilir; verilmezse `http://localhost:5051`.

| Cihaz | Yapılacak |
| --- | --- |
| USB'li telefon | `adb reverse tcp:5051 tcp:5051` (telefonun `localhost:5051`'i bilgisayara gider), sonra `flutter run` |
| Android emülatör | `flutter run --dart-define=API_URL=http://10.0.2.2:5051` (`10.0.2.2` emülatörde bilgisayarın adresidir) |
| Gerçek sunucu | `--dart-define=API_URL=https://...` |

Düz HTTP yalnız debug yapısında açıktır (`android/app/src/debug/AndroidManifest.xml`); release yapısında yalnız HTTPS çalışır.

## Giriş ve roller

Giriş `POST /api/hesap/login` ile yapılır, token'lar cihazın güvenli deposunda (Keystore) durur. İki rol vardır:

- **Sahip**: her şeyi yönetir (alışkanlık, öğe, oturum ekle/düzenle/sil). "+", düzenle ve sil düğmeleri ile form ekranları yalnız bu role görünür.
- **Asistan**: listeleri okur, günlük kayıt girer; yönetim ekranları gizlidir ve adresi elle açılsa bile engellenir.

Rol `GET /api/ben` ile okunur ve çevrimdışı açılış için saklanır. Seed hesaplarının şifreleri `../README.md` içinde anlatılan gizli bilgi ayarından gelir.

## Ekranlar

Alt gezinme: **Bugün / Alışkanlıklar / Raf / Profil**.

- Bugün: planlı alışkanlıklar; tik, −/+, sayı girişi, kronometre, "Okumaya başla"
- Alışkanlıklar: liste, detay (güç, seri, son 30 gün), form (yalnız Sahip)
- Raf: Devam / Sıradaki / Bitti / Bırakıldı, öğe detayı, oturum geçmişi, öğe formu (yalnız Sahip)
- Profil: e-posta, rol, çevrimdışı kuyruk, gönderilemeyen kayıtlar, çıkış

## Çevrimdışı çalışma

Günlük girişler (tik, sayı, kronometre, "nereye kadar") önce telefondaki SQLite veritabanına (drift) yazılır, ekran hemen güncellenir. Bekleyen kayıtlar bağlantı geri geldiğinde ve uygulama öne geldiğinde sunucuya gider. Sunucunun kalıcı olarak reddettiği kayıtlar Profil ekranında hatasıyla görünür. Alışkanlık/öğe oluşturma, düzenleme, silme ve fotoğraf yükleme çevrimiçi yapılır.

## Kontroller

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Yapı

`lib/` Flutter'ın resmi mimari rehberini izler (docs.flutter.dev/app-architecture):

```
lib/
  config/    API adresi, tema
  routing/   go_router, rol kapısı
  data/
    models/        API modelleri (json_serializable)
    services/      API istemcisi, token deposu, drift veritabanı
    repositories/  oturum, rol, alışkanlıklar, çevrimdışı kuyruk (eşitleyici)
  ui/<özellik>/    ekran + view model
  utils/     alışkanlık günü (05:00), doğrulama
```
