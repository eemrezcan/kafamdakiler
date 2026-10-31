---
baslik: Web teması: açık/koyu mod, mor-pembe vurgu, Canvas sinaps sahnesi
tur: karar
soru: Web arayüzünün renkleri, açık/koyu modu ve animasyonları nasıl yapılır?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-30, kullanıcı. Tema beyin temalıdır.
- **Mod:** açık ve koyu mod birlikte. Varsayılan "Sistem": cihazın ayarı izlenir (`prefers-color-scheme`). Üst bardaki ayarlar düğmesi sağdan bir çekmece açar; "Görünüm" bölümünde Sistem, Açık ya da Koyu küçük önizlemeli kartlarla seçilir, seçim tarayıcıda (`localStorage`) saklanır. Bootstrap 5.3'ün kendi renk modu yolu kullanılır (`data-bs-theme`); tema, sayfa çizilmeden önce `<head>` içindeki küçük betikle ayarlanır.
- **Görsel dil: mikroskop.** Rengi nöron sahnesi taşır; arayüz bir ölçüm yazılımı gibi sakin ve kesindir: ince çizgiler (hairline), az renk, gradyan ve parıltı yok. Koyu mod floresan görüntüleme (siyah alan), açık mod boyalı doku lamı (sıcak kırık beyaz). Ana düğme düz mürekkep rengi (koyuda açık, açıkta koyu).
- **Yazı:** başlıklar Instrument Serif (italik vurgu), metin Inter, etiket ve ölçüm yazıları IBM Plex Mono. Hepsi OFL lisanslı, yerel kopya (`wwwroot/fonts/`, lisans metinleriyle).
- **Arayüz:** üst bar ince bir çizgiyle ayrılan şeffaf şerit. Logo profilden bir baş ve içinde beyin (kullanıcının seçtiği SVG, `wwwroot/img/logo.svg`; ikon setinde `brain`). Giriş paneli lamel gibi yarı saydam, üstte küçük bir mono etiket ("Oturum aç"); panelde logo, köşe işareti, "canlı" göstergesi ve dipnot yok. Form hataları yerinde gösterilir ve kartın boyunu değiştirmez: her alanın altında hata için bir satır baştan ayrılır, genel hata ("E-posta ya da şifre yanlış.") alt yazının yerine geçer. Giriş yapmamış ziyaretçide üst bar, ayarlar ve alt bilgi gösterilmez; yalnız sahne ve giriş paneli. Sahnenin kenarlarında göz merceği vinyeti. İkonlar tek bir SVG dosyasında (`wwwroot/img/icons.svg`).
- **Vurgu:** mor; pembe yalnız nöron sinyallerinde. Bootstrap'in birincil rengi mor.
- **Animasyon:** giriş sayfası gibi sahnelerde arka planda mikroskop altında canlı nöronlar: koyu modda floresan (parlayan mor hücreler, pembe ışıma), açık modda boyanmış doku kesiti. Her nöronun gövdesi, dallanan dendritleri ve başka bir nörona uzanan aksonu var; aksiyon potansiyeli akson boyunca akar, sinaps ucunda vezikül parçacıkları boşluğu geçer, alıcı hücre parlar ve zincirleme ateşleyebilir. Üç derinlik katmanı (arkadakiler bulanık), yavaş kayma ve fareyle derinlik kayması; tıklayınca en yakın nöron ateşlenir. Kendi Canvas 2D betiğimizle yapılır (`wwwroot/js/theme/synapse.js`); hücreler bir kez çizilip resim olarak saklanır, her karede yalnız kopyalanır. Arayüz geçişleri (kartın belirmesi, düğme parlaması) CSS ile yapılır. "Hareketi azalt" ayarında animasyon durur, sabit görüntü kalır; sekme arka plandayken çizim durur.
- **Mobil:** Flutter tarafı aynı renkleri ve `ThemeMode.system` + kullanıcı seçimini kullanır; mobil adımında uygulanır.

## Gerekçe
Kullanıcı uygulamayı gece ve gündüz kullanacak, cihaz ayarına uyması ve elle değiştirilebilmesi istendi. Bootstrap'in renk modu şablonda hazır gelir (K-0006, K-0018). İstenen sinaps atımı hiçbir parçacık kütüphanesinde hazır değil; tek dosyalık Canvas betiği bağımlılık eklemeden işi görür (K-0008). Claude Motion (Anthropic, 2026-10 beta) yalnız video/açıklayıcı animasyon üretir, sitenin canlı arka planı için uygun değildir; haftalık videolarda kullanılabilir.

## Reddedilenler
- Parlak mor-pembe gradyanlı arayüz (yüzen hap üst bar, dönen gradyan kenarlı kart, gradyan düğme; 2026-10-30): kullanıcı "cırtlak" ve gerçekçi sahneyle uyumsuz buldu.
- Form hatalarını sağ altta açılan pop-up (toast) ile göstermek: kendiliğinden kaybolur, hatalı alandan uzak kalır, erişilebilirliği zayıf; kart oynamasın sorunu sabit alanla çözüldü.
- Sahne köşelerinde ölçek çubuğu (50 µm) ve görüntüleme notu ("Floresan · 40× · 488 nm"): kullanıcı istemedi.
- Giriş kartında logo, köşe vizör işaretleri, "Canlı" göstergesi ve "Kayıt kapalı" dipnotu: kullanıcı istemedi.
- Tek nöron çizimi ve elle çizilmiş orta hat beyin kesiti logoları; hazır ikon kütüphanelerindeki (Material, Phosphor, Tabler, Lucide, Remix, Iconoir, Font Awesome) yukarıdan bakış beyinler: kullanıcı kendi bulduğu profil-beyin SVG'sini seçti.
- Tema düğmesinin üst barda durması (ilk sürüm): kullanıcı ayarlar alanında olmasını istedi.
- Nokta-çizgi parçacık ağı (ilk sürüm, 2026-10-30): kullanıcı daha gerçekçi bir şey istedi; nöron yapısına benzemiyordu.
- tsParticles: büyük paket, sinaps atımı hazır gelmiyor, üstüne yine kod gerekir.
- Three.js ile 3D beyin: etkileyici ama ağır; telefonda pil ve ısınma, giriş sayfası için fazla.
- GSAP: arayüz geçişleri CSS ile karşılanıyor; zengin sıralı geçiş gerekirse yeniden düşünülür.
- Yalnız CSS/SVG: nöronlar sabit kalır, atım ve etkileşim kısıtlı.
- Turkuaz-mavi ve turuncu-mercan vurgular: kullanıcı mor-pembeyi seçti.

## Yeniden açma koşulu
Analiz ekranlarında zengin, sıralı geçişler gerekirse GSAP; animasyon telefonlarda takılırsa sahne sadeleştirilir.
