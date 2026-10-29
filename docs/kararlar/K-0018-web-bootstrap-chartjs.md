---
baslik: Web arayüzü Bootstrap ve Chart.js, ayrı SPA yok
tur: karar
soru: Web tarafının (panel, analiz) görünümü ve grafikleri hangi araçlarla yapılır?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-29, kullanıcı. Sayfaları sunucu Razor Pages ile üretir. Görünüm, şablonla gelen Bootstrap 5'tir ve mobile-first ızgarayla yazılır (`col-12 col-md-6` gibi). Grafikler Chart.js ile çizilir; dosya `wwwroot/lib/chart.js` altında yerel kopya olarak durur. Grafiğin verisi sayfaya `@Json.Serialize` ile gömülür. Sayfayı yenilemeden güncelleme gerekirse htmx eklenir, gerekmedikçe eklenmez.

## Gerekçe
T01 (Razor Pages), T09 (responsive), G09 (4 haftalık kilo trendi), G11 (yönetim ve analiz ekranları). Bootstrap şablonda hazır gelir, ek kurulum istemez. Chart.js tek bir dosyadır, olgun ve yaygın bir kütüphanedir (K-0006). JavaScript yalnız grafikte kullanıldığı için yapı sade kalır (K-0008).

## Reddedilenler
- Ayrı SPA (React, Blazor WebAssembly): ikinci bir ön yüz projesi ve ayrı derleme demektir; T01 Razor Pages ister.
- Chart.js'i CDN'den yüklemek: CDN ya da internet erişilemezse grafik de görünmez.
- Tailwind vb. başka CSS çatısı: şablon zaten Bootstrap ile geliyor.

## Yeniden açma koşulu
Web tarafında, çok sayıda sayfa içi etkileşim gerektiren bir ekran çıkarsa (canlı tablo düzenleme gibi) htmx'in ötesi düşünülür.
