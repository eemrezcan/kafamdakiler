---
kimlik: K-0022
baslik: "Web teması: açık/koyu mod, mor-pembe vurgu, tek yazı tipi"
tur: karar
soru: "Web arayüzünün renkleri, açık/koyu modu ve yazı tipi nasıl olur?"
sonuc: kabul
kavramlar: [web, tema, açık-koyu-mod, mikroskop, yazı-tipi, vurgu-rengi]
tags: [karar]
---

# K-0022 - Web teması: açık/koyu mod, mor-pembe vurgu, tek yazı tipi

Kapsamı bölündü, devamı K-0031, K-0032. Bu kayıtta kalan maddeler yerinde durur; taşınan maddelerin metni yeni kayıtlardadır (2026-11-27).

2026-10-30, kullanıcı. Tema beyin temalıdır.

## m01 - Açık ve koyu mod birlikte sunulur, varsayılan Sistem'dir
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [prefers-color-scheme, bootstrap]
karar-veren: kullanici
```
**Mod:** açık ve koyu mod birlikte. Varsayılan "Sistem": cihazın ayarı izlenir (`prefers-color-scheme`). Üst bardaki ayarlar düğmesi sağdan bir çekmece açar; "Görünüm" bölümünde Sistem, Açık ya da Koyu küçük önizlemeli kartlarla seçilir, seçim tarayıcıda (`localStorage`) saklanır. Bootstrap 5.3'ün kendi renk modu yolu kullanılır (`data-bs-theme`); tema, sayfa çizilmeden önce `<head>` içindeki küçük betikle ayarlanır.

## m02 - Görsel dil mikroskoptur: sakin, ince çizgili, gradyansız
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [floresan, hairline]
karar-veren: kullanici
```
**Görsel dil: mikroskop.** Rengi nöron sahnesi taşır; arayüz bir ölçüm yazılımı gibi sakin ve kesindir: ince çizgiler (hairline), az renk, gradyan ve parıltı yok. Koyu mod floresan görüntüleme (siyah alan), açık mod boyalı doku lamı (sıcak kırık beyaz). Ana düğme düz mürekkep rengi (koyuda açık, açıkta koyu).

## m03 - Yazı tipleri Instrument Serif, Inter ve IBM Plex Mono'dur, yerel kopya olarak durur
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [inter, instrument-serif, ibm-plex-mono, ofl]
karar-veren: kullanici
```
**Yazı:** başlıklar Instrument Serif (italik vurgu), metin Inter, etiket ve ölçüm yazıları IBM Plex Mono. Hepsi OFL lisanslı, yerel kopya (`wwwroot/fonts/`, lisans metinleriyle).

## m04 - Arayüz ince çizgili şeffaf üst bar, profil-beyin logosu ve lamel gibi giriş paneliyle kurulur
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [logo, giriş-paneli, ikon]
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0031/m01 olarak taşındı.

## m05 - Vurgu mordur, pembe yalnız nöron sinyallerindedir
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [mor, pembe]
karar-veren: kullanici
```
**Vurgu:** mor; pembe yalnız nöron sinyallerinde. Bootstrap'in birincil rengi mor.

## m06 - Giriş sayfasının arka planında Canvas ile canlı nöron sahnesi çalışır
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [nöron, aksiyon-potansiyeli, hareketi-azalt, css]
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0032/m01 olarak taşındı.

## m07 - Mobil aynı renkleri ve ThemeMode.system ile kullanıcı seçimini kullanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [mobil, flutter]
karar-veren: kullanici
```
**Mobil:** Flutter tarafı aynı renkleri ve `ThemeMode.system` + kullanıcı seçimini kullanır; mobil adımında uygulanır.

## m08 - Yazı tipi tektir: her yerde Inter
```yaml
tur: m
durum: guncel
tarih: 2026-11-02
dayanak: kullanici
kavramlar: [inter, tabular-nums]
karar-veren: kullanici
```
Ek (2026-11-02), kullanıcı kararı, web denemesinden sonra: Yazı tipi tek: her yerde Inter. Başlıklar kalın (600), etiketler küçük büyük harf (500), sayılar eşit genişlikte (`tabular-nums`); başlıklardaki vurgu italik değil, mor. Instrument Serif ve IBM Plex Mono kaldırıldı.

## g01 - Serif başlık ve mono etiketler garip bulundu, 1 rakamı l harfine benziyordu
```yaml
tur: g
durum: guncel
tarih: 2026-11-02
dayanak: kullanici
```
Gerekçe (Ek 2026-11-02): kullanıcı serif başlığı ve mono etiketleri garip buldu; Instrument Serif'te "1" rakamı "l" harfine benziyordu ("Seri 1").

## m09 - Alışkanlık kartı seçilen rengi taşır
```yaml
tur: m
durum: guncel
tarih: 2026-11-02
dayanak: kullanici
kavramlar: [alışkanlık-kartı, renkli-kart, wcag]
karar-veren: kullanici
```
Ek (2026-11-02): Alışkanlık kartı seçilen rengi taşır: zemin rengin hafif tonu (açıkta %9, koyuda %12), çerçeve biraz daha belirgin; yazı renkleri temadan gelir, sekiz rengin hepsinde metin ve soluk metin WCAG AA kontrastını geçer. Kırmızı pembeden ayrıldı.

## m10 - Açılır listelerin seçenekleri de tema renklerini alır
```yaml
tur: m
durum: guncel
tarih: 2026-11-02
dayanak: kullanici
kavramlar: [açılır-liste, chrome]
karar-veren: kullanici
```
Ek (2026-11-02): Açılır listelerin seçenekleri de tema renklerini alır (Linux'ta Chrome listeyi beyaz çiziyordu).

## m11 - Mobil aynı kuralları uygular: yalnız Inter, web'deki palet, renkli kart
```yaml
tur: m
durum: guncel
tarih: 2026-11-02
dayanak: kullanici
kavramlar: [mobil]
karar-veren: kullanici
```
Ek (2026-11-02): Mobil aynı kuralları uygular: yalnız Inter, web'deki açık ve koyu palet, renkli kart.

## g02 - Kullanıcı gece ve gündüz kullanacak, cihaz ayarına uyum ve elle değişiklik istendi
```yaml
tur: g
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
```
Kullanıcı uygulamayı gece ve gündüz kullanacak, cihaz ayarına uyması ve elle değiştirilebilmesi istendi.

## g03 - Bootstrap'in renk modu şablonda hazır gelir
```yaml
tur: g
durum: guncel
tarih: 2026-10-30
dayanak: cikarim
```
Bootstrap'in renk modu şablonda hazır gelir (K-0006, K-0018).

## g04 - Sinaps atımı hiçbir parçacık kütüphanesinde hazır değil, tek dosyalık betik yeter
```yaml
tur: g
durum: yerini-aldi
tarih: 2026-10-30
dayanak: cikarim
```
Kapsamı bölündü: bu madde K-0032/g01 olarak taşındı.

## g05 - Claude Motion yalnız video üretir, canlı arka plan için uygun değildir
```yaml
tur: g
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kaynak
kavramlar: [claude-motion]
```
Kapsamı bölündü: bu madde K-0032/g02 olarak taşındı.

## r01 - Parlak mor-pembe gradyanlı arayüz (yüzen hap üst bar, dönen gradyan kenarlı kart, gradyan düğme; 2026-10-30)
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kullanıcı "cırtlak" ve gerçekçi sahneyle uyumsuz buldu.

## r02 - Form hatalarını sağ altta açılan pop-up (toast) ile göstermek
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0031/r01 olarak taşındı.

## r03 - Sahne köşelerinde ölçek çubuğu (50 µm) ve görüntüleme notu ("Floresan · 40× · 488 nm")
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0031/r02 olarak taşındı.

## r04 - Giriş kartında logo, köşe vizör işaretleri, "Canlı" göstergesi ve "Kayıt kapalı" dipnotu
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0031/r03 olarak taşındı.

## r05 - Tek nöron çizimi ve elle çizilmiş orta hat beyin kesiti logoları, hazır ikon kütüphanelerindeki yukarıdan bakış beyinler
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0031/r04 olarak taşındı.

## r06 - Tema düğmesinin üst barda durması (ilk sürüm)
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kullanıcı ayarlar alanında olmasını istedi.

## r07 - Nokta-çizgi parçacık ağı (ilk sürüm, 2026-10-30)
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0032/r01 olarak taşındı.

## r08 - tsParticles
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0032/r02 olarak taşındı.

## r09 - Three.js ile 3D beyin
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "Animasyon telefonlarda takılırsa sahne sadeleştirilir."
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0032/r03 olarak taşındı.

## r10 - GSAP
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "Analiz ekranlarında zengin, sıralı geçişler gerekirse GSAP."
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0032/r04 olarak taşındı.

## r11 - Yalnız CSS/SVG
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0032/r05 olarak taşındı.

## r12 - Turkuaz-mavi ve turuncu-mercan vurgular
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kullanıcı mor-pembeyi seçti.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-30
dayanak: bilinmiyor
```
Belgede yazılmamış.

## Yeniden açma koşulu

Kapsamı bölündü: bu bölüm K-0032 kaydına taşındı.
