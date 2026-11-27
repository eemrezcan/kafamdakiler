---
kimlik: K-0032
baslik: "Giriş sahnesi: Canvas sinaps animasyonu"
tur: karar
soru: "Giriş sayfasının arka plan animasyonu nasıl yapılır?"
sonuc: kabul
kavramlar: [animasyon, synapse-canvas, nöron, canvas, hareketi-azalt]
tags: [karar]
---

# K-0032 - Giriş sahnesi: Canvas sinaps animasyonu

K-0022 kaydından bölündü (2026-11-27; 8'den fazla geçerli hükmü olan kayıt tek soruluk kayıtlara bölündü). Madde eşlemesi: K-0022/m06 → m01, K-0022/g04 → g01, K-0022/g05 → g02, K-0022/r07 → r01, K-0022/r08 → r02, K-0022/r09 → r03, K-0022/r10 → r04, K-0022/r11 → r05. Maddelerin metni ve tarihi değişmedi.

## m01 - Giriş sayfasının arka planında Canvas ile canlı nöron sahnesi çalışır
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [nöron, aksiyon-potansiyeli, hareketi-azalt, css]
karar-veren: kullanici
```
**Animasyon:** giriş sayfası gibi sahnelerde arka planda mikroskop altında canlı nöronlar: koyu modda floresan (parlayan mor hücreler, pembe ışıma), açık modda boyanmış doku kesiti. Her nöronun gövdesi, dallanan dendritleri ve başka bir nörona uzanan aksonu var; aksiyon potansiyeli akson boyunca akar, sinaps ucunda vezikül parçacıkları boşluğu geçer, alıcı hücre parlar ve zincirleme ateşleyebilir. Üç derinlik katmanı (arkadakiler bulanık), yavaş kayma ve fareyle derinlik kayması; tıklayınca en yakın nöron ateşlenir. Kendi Canvas 2D betiğimizle yapılır (`wwwroot/js/theme/synapse.js`); hücreler bir kez çizilip resim olarak saklanır, her karede yalnız kopyalanır. Arayüz geçişleri (kartın belirmesi, düğme parlaması) CSS ile yapılır. "Hareketi azalt" ayarında animasyon durur, sabit görüntü kalır; sekme arka plandayken çizim durur.

## g01 - Sinaps atımı hiçbir parçacık kütüphanesinde hazır değil, tek dosyalık betik yeter
```yaml
tur: g
durum: guncel
tarih: 2026-10-30
dayanak: cikarim
```
İstenen sinaps atımı hiçbir parçacık kütüphanesinde hazır değil; tek dosyalık Canvas betiği bağımlılık eklemeden işi görür (K-0008).

## g02 - Claude Motion yalnız video üretir, canlı arka plan için uygun değildir
```yaml
tur: g
durum: guncel
tarih: 2026-10-30
dayanak: kaynak
kavramlar: [claude-motion]
```
Claude Motion (Anthropic, 2026-10 beta) yalnız video/açıklayıcı animasyon üretir, sitenin canlı arka planı için uygun değildir; haftalık videolarda kullanılabilir.

## r01 - Nokta-çizgi parçacık ağı (ilk sürüm, 2026-10-30)
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kullanıcı daha gerçekçi bir şey istedi; nöron yapısına benzemiyordu.

## r02 - tsParticles
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Büyük paket, sinaps atımı hazır gelmiyor, üstüne yine kod gerekir.

## r03 - Three.js ile 3D beyin
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "Animasyon telefonlarda takılırsa sahne sadeleştirilir."
karar-veren: kullanici
```
Etkileyici ama ağır; telefonda pil ve ısınma, giriş sayfası için fazla.

## r04 - GSAP
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "Analiz ekranlarında zengin, sıralı geçişler gerekirse GSAP."
karar-veren: kullanici
```
Arayüz geçişleri CSS ile karşılanıyor; zengin sıralı geçiş gerekirse yeniden düşünülür.

## r05 - Yalnız CSS/SVG
```yaml
tur: r
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Nöronlar sabit kalır, atım ve etkileşim kısıtlı.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-11-27
dayanak: bilinmiyor
```
Belgede yazılmamış.

## Yeniden açma koşulu

Analiz ekranlarında zengin, sıralı geçişler gerekirse GSAP; animasyon telefonlarda takılırsa sahne sadeleştirilir.
