---
kimlik: K-0031
baslik: "Web üst bar, logo ve giriş paneli"
tur: karar
soru: "Web arayüzünün üst barı, logosu ve giriş paneli nasıl yapılır?"
sonuc: kabul
kavramlar: [web, giriş-paneli, logo, üst-bar, ikon]
tags: [karar]
---

# K-0031 - Web üst bar, logo ve giriş paneli

K-0022 kaydından bölündü (2026-11-27; 8'den fazla geçerli hükmü olan kayıt tek soruluk kayıtlara bölündü). Madde eşlemesi: K-0022/m04 → m01, K-0022/r02 → r01, K-0022/r03 → r02, K-0022/r04 → r03, K-0022/r05 → r04. Maddelerin metni ve tarihi değişmedi.

## m01 - Arayüz ince çizgili şeffaf üst bar, profil-beyin logosu ve lamel gibi giriş paneliyle kurulur
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [logo, giriş-paneli, ikon]
karar-veren: kullanici
```
**Arayüz:** üst bar ince bir çizgiyle ayrılan şeffaf şerit. Logo profilden bir baş ve içinde beyin (kullanıcının seçtiği SVG, `wwwroot/img/logo.svg`; ikon setinde `brain`). Giriş paneli lamel gibi yarı saydam, üstte küçük bir mono etiket ("Oturum aç"); panelde logo, köşe işareti, "canlı" göstergesi ve dipnot yok. Form hataları yerinde gösterilir ve kartın boyunu değiştirmez: her alanın altında hata için bir satır baştan ayrılır, genel hata ("E-posta ya da şifre yanlış.") alt yazının yerine geçer. Giriş yapmamış ziyaretçide üst bar, ayarlar ve alt bilgi gösterilmez; yalnız sahne ve giriş paneli. Sahnenin kenarlarında göz merceği vinyeti. İkonlar tek bir SVG dosyasında (`wwwroot/img/icons.svg`).

## r01 - Form hatalarını sağ altta açılan pop-up (toast) ile göstermek
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kendiliğinden kaybolur, hatalı alandan uzak kalır, erişilebilirliği zayıf; kart oynamasın sorunu sabit alanla çözüldü.

## r02 - Sahne köşelerinde ölçek çubuğu (50 µm) ve görüntüleme notu ("Floresan · 40× · 488 nm")
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kullanıcı istemedi.

## r03 - Giriş kartında logo, köşe vizör işaretleri, "Canlı" göstergesi ve "Kayıt kapalı" dipnotu
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kullanıcı istemedi.

## r04 - Tek nöron çizimi ve elle çizilmiş orta hat beyin kesiti logoları, hazır ikon kütüphanelerindeki yukarıdan bakış beyinler
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Hazır ikon kütüphaneleri: Material, Phosphor, Tabler, Lucide, Remix, Iconoir, Font Awesome. Kullanıcı kendi bulduğu profil-beyin SVG'sini seçti.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-11-27
dayanak: bilinmiyor
```
Belgede yazılmamış.
