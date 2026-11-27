---
kimlik: K-0018
baslik: "Web arayüzü Bootstrap ve Chart.js, ayrı SPA yok"
tur: karar
soru: "Web tarafının (panel, analiz) görünümü ve grafikleri hangi araçlarla yapılır?"
sonuc: kabul
kavramlar: [web, bootstrap, chartjs, razor-pages, responsive, htmx]
tags: [karar]
---

# K-0018 - Web arayüzü Bootstrap ve Chart.js, ayrı SPA yok

## m01 - Sayfaları sunucu Razor Pages ile üretir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [spa]
karar-veren: kullanici
```
2026-10-29, kullanıcı. Sayfaları sunucu Razor Pages ile üretir.

## m02 - Görünüm Bootstrap 5 ile mobile-first ızgarada yazılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [mobile-first, ızgara]
karar-veren: kullanici
```
Görünüm, şablonla gelen Bootstrap 5'tir ve mobile-first ızgarayla yazılır (`col-12 col-md-6` gibi).

## m03 - Grafikler Chart.js ile çizilir, dosya yerel kopya olarak durur
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [yerel-kopya]
karar-veren: kullanici
```
Grafikler Chart.js ile çizilir; dosya `wwwroot/lib/chart.js` altında yerel kopya olarak durur.

## m04 - Grafiğin verisi sayfaya Json.Serialize ile gömülür
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [json-serialize]
karar-veren: kullanici
```
Grafiğin verisi sayfaya `@Json.Serialize` ile gömülür.

## m05 - Sayfayı yenilemeden güncelleme gerekirse htmx eklenir, gerekmedikçe eklenmez
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
karar-veren: kullanici
```
Sayfayı yenilemeden güncelleme gerekirse htmx eklenir, gerekmedikçe eklenmez.

## g01 - Kapsam T01, T09, G09 ve G11 şartlarını karşılar
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: kaynak
```
T01 (Razor Pages), T09 (responsive), G09 (4 haftalık kilo trendi), G11 (yönetim ve analiz ekranları).

## g02 - Bootstrap şablonda hazır, Chart.js tek dosyalık olgun kütüphane
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
Bootstrap şablonda hazır gelir, ek kurulum istemez. Chart.js tek bir dosyadır, olgun ve yaygın bir kütüphanedir (K-0006). JavaScript yalnız grafikte kullanıldığı için yapı sade kalır (K-0008).

## r01 - Ayrı SPA (React, Blazor WebAssembly)
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "Web tarafında, çok sayıda sayfa içi etkileşim gerektiren bir ekran çıkarsa (canlı tablo düzenleme gibi) htmx'in ötesi düşünülür."
karar-veren: kullanici
```
İkinci bir ön yüz projesi ve ayrı derleme demektir; T01 Razor Pages ister.

## r02 - Chart.js'i CDN'den yüklemek
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
CDN ya da internet erişilemezse grafik de görünmez.

## r03 - Tailwind vb. başka CSS çatısı
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Şablon zaten Bootstrap ile geliyor.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-29
dayanak: bilinmiyor
```
Belgede yazılmamış.
