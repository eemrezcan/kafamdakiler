---
baslik: Özellik kapsamı ve fazlar
tur: karar
soru: Uygulama hangi özellikleri hangi fazda yapar?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-15, kullanıcı. Kapsam üç fazdır; maddeler `docs/gereksinimler.md` içinde. Faz 1 iki ödevi karşılar: spor kaydı (geçen hafta, dinlenme sayacı, rekor, 1RM; antrenman girişi çevrimdışı), görev ve söz, tekrarlayan hatırlatıcı (tek seferlik, aylık, yıllık), kitap ve okuma serisi, haftalık kilo ve trend, hızlı not (yazı, fotoğraf, ekran görüntüsü), giriş (tek insan kullanıcı; Sahip ve Asistan rolleri, K-0009), deploy. Web yönetim ve analiz içindir, mobil günlük giriş içindir.

## Ek (2026-11-03): kişisel bilgi yönetimi merkezli kapsam
Kullanıcı kararı. Uygulama kullanıcının kişisel bilgi sisteminin ("ikinci beyin") telefondaki yüzüdür; alışkanlık, spor ve kilo bu sistemin ölçülen alanlarıdır. Kapsamın tamamı korunur, şu modüller eklenir:
- Yakala: hemen açılan tek ekran; yazı, ses (yazıya çevrilir, yapay zekâ temizler), fotoğraf; Android Paylaş menüsü ve uygulama kısayolu; önce telefona kaydedilir.
- Gelen kutusu: yapay zekâ yer, başlık ve etiket önerir; kullanıcı onaylar, düzeltir ya da sonraya bırakır.
- Projeler: durum, sıradaki adım, nerede kalındığı, görevler, günlük; projeye hızlı not.
- Günler: bugünün planı, geçmiş günler, haftalık özet.
- Arama, not okuma ve "Beynime sor".

Sıra: Yakala (hafta 3), bilgi okuma ekranları (hafta 4), 1. gösterim, sunucu ve sesli not (hafta 5), hatırlatıcı ve yapay zekâ ile yerleştirme (hafta 6), spor temeli (hafta 7), Beynime sor, haftalık özet, kilo ve MCP (hafta 8), son hafta test ve APK. Yetişmeyen kısım (plana işaret, spor rekor ve 1RM, OAuth, widget) ders sonrasında sürer. Yakalama ders için de tam CRUD varlığıdır.

## Ek (2026-11-04): modül listesi ve sıra
Kullanıcı kararı. Senaryo çalışmasından (takvim ve son tarih, beyin ile repo köprüsü, zaman ve verim hesabı, telefon verisi, kendiliğinden konuşan yardımcı) sonra modüller ve sıraları belirlendi. Haftalık bölme kalkar: sıra bağımlılığa göredir, biten modülden sonrakine geçilir. Yukarıdaki 2026-11-03 sırası bunun yerine geçer.
- Hazır: hesap ve roller, alışkanlıklar.
- Kat 1 (1. gösterime hedef): beyin onarımı (beynin kendi reposunda, K-0023 eki 2026-11-04), Yakala, beyne ham kart (sunucuya kadar Tailscale ile laptop), beyin okuma, okuma ekranları (Projeler, Günler, Arama; Yakala'ya proje seçici), yönetim ekranları.
- Kat 2: sunucu, gelen kutusu ve yerleştirme, görevler ve hatırlatıcılar (son tarihli işi günlere bölme, geri sayım, sözler, özel tarihler, Google Takvim'den yalnız okuma), ses, repo köprüsü.
- Kat 3 (bağımsız, araya girebilir): telefon verisi (ekran süresi, adım, uyku tahmini), zaman takibi (gün paneli sayacının telefon yüzü, Claude Code oturum süreleri), spor ve kilo.
- Kat 4: proaktif yardımcı (sabah brifingi, akşam kapanışı, gün hesabı, ayarlanabilir ton; günde tek bildirimle başlar), Beynime sor ve akışlar, MCP, haftalık örüntüler.

İlkeler: kendiliğinden gelen veri elle girilenden önce gelir; her modülden sonra birkaç gün gerçek kullanım; Claude API için aylık bütçe sınırı; `gizli: true` notlar yapay zekâya gitmez. Kat 1 öğrenme kipindedir; sonraki katların kipi ayrıca konuşulur (K-0001).

## Ek (2026-11-06): Kat 1'e dört ek
Kullanıcı kararı. Benzer uygulamalar taramasından (beyinde `projects/kafamdakiler/notlar/benzer-uygulamalar-ozellik-havuzu.md`) sunucu ve yapay zekâ gerektirmeyen, Kat 1 modüllerini büyüten dört özellik Kat 1'e alındı:
- Paylaşım menüsünden yakalama: başka uygulamadan paylaşılan metin, link ya da tek görsel Yakala ekranını dolu açar.
- Uygulama kısayolu: ikona basılı tutunca "Yakala".
- Ana ekran widget'ı: tek dokunuşla Yakala. Yukarıdaki 2026-11-03 sırasında "ders sonrası" sayılan widget bununla öne alındı (yalnız yakalama düğmesi; veri gösteren widget yine sonraya).
- Sürüm uyumu: API en düşük uygulama sürümünü söyler, eski uygulama "güncelle" der. Sunucuya taşınınca APK ile API ayrı güncelleneceği için.

Ayrıntı ve sıra `docs/planlar/kat1.md` F7'de. Kalan seçimler (konum, ilgili notlar, kaydırarak ayıklama, cihaz oturumları) havuzda kalır; konum beynin `gelen ekle` komutunda alan olmadığı için Kat 1'e alınmadı.
Bu ekin yeniden açma koşulu: F7 gösterime (2026-11-18) yetişmeyecek gibi görünürse widget çıkarılır, önce anlatım yapılır (K-0001 eki 2026-11-05).

## Ek (2026-11-07): sekreter çekirdeği ve entegrasyonlar
Kullanıcı kararı. Ölçü değişti: uygulama yalnız ödev değil, kullanıcının gerçekten kullanacağı ikinci beyin, takip mekanizması ve onun adına iş hazırlayan sekreterdir. Benzer uygulama taramaları ve üç yeni araştırma (beyinde `projects/kafamdakiler/notlar/sekreter-entegrasyon-arastirmasi.md`) sonunda:
- Kat 1: veri gösteren ana ekran widget'ı (bugünün planı, yaklaşan hatırlatıcılar). 2026-11-06 ekinde "sonraya" kalan kısım bununla öne alındı.
- Kat 2'ye eklenenler:
  - Onay kuyruğu ve geri alma: Claude'un önerdiği her eylem (yerleştirme, görev, hatırlatıcı, plan maddesi, takvim) tek listede "taslak hazır, uygula" kartıdır; bildirimden Onayla/Reddet; uygulanan eylem geri alınabilir (beyinde commit'in geri çevrilmesi, veritabanında arşiv); emin olunmayan öneri işaretlidir.
  - Eylem başına izin kipi: Sor / Kendin yap / Yasak; sıra Yasak > Sor > Kendin yap; yeni eylem türü ilk seferde sorulur; "bunu yapma" kalıcıdır; art arda reddedilen asistan Sor kipine düşer. K-0009 Asistan izinlerinin üstüne kurulur.
  - Sabah brifingi (Kat 4'ten öne alındı): günde tek bildirim, 5-7 kart, kart başına 👍/👎, brifinge yazarak düzeltme, dünden kalanlara taşı/bırak, N gün üst üste taşınan görev "Bir gün"e düşer.
  - Sesten iş çıkarma: konuşmadan görev, hatırlatıcı ve plan önerileri çıkar, kaydetmeden önce önizlenir ve onay kuyruğuna düşer.
  - Israrlı hatırlatma: hatırlatıcı başına isteğe bağlı, aralıklı ve sayısı sınırlı yeniden çalma; sessiz modu yalnız "acil" olan deler.
  - Tek zaman çizelgesi: Bugün'de takvim etkinlikleri, plan maddeleri ve hatırlatıcılar saat sırasıyla; Google Takvim ile birlikte.
  - Google Takvim Kat 2'dedir (karar 10 kapandı) ve yalnız okuma değil, onay kuyruğundan geçen yazma da hedeflenir; plana yazma Kat 2'dedir (karar 9 kapandı).
- Kat 3'e eklenen: Google ve finans. Gmail'e salt okunur bağlantı; sunucu yalnız kullanıcının Gmail filtresiyle etiketlediği mailleri işler. Kredi kartı ekstresinden harcama satırları (uygulamanın veritabanı, K-0005), abonelik ve zam tespiti, taksit takibi, son ödeme hatırlatıcısı önerisi, aylık özetin beynin `finans/aylik/` alanına yazılması, mailden etkinlik ya da hatırlatıcı önerisi. Toplamları sunucu hesaplar; Claude yalnız kişisel bilgisi çıkarılmış özeti yorumlar.
- Kat 4'e eklenen: Google Drive (belgelerde arama, üretilen dosyayı kaydetme), mail yanıtını taslak olarak hazırlama.
- Havuzda kalan: Türkçe doğal dille tarih, "Geçmişten bugün" kartı, hızlı ayar kutucuğu.

Güvenlik kuralı: mail ve dış kaynaklı içerik Claude'a veri olarak gider; bu içeriği işleyen çağrıya araç verilmez, yalnız şemalı çıktı alınır; dış kaynaktan doğan her öneri izin kipinden bağımsız olarak Sor kipine düşer. Bu yüzden Gmail, onay kuyruğundan sonra gelir. Kişisel veri (kart numarası, IBAN, ad) Claude'a gitmez.

Banka entegrasyonu reddi yeniden açılmadı: o, bankanın API'sine bağlanmaktı; burada yalnız bankanın zaten mail attığı ekstre okunur.
Yeniden açma koşulu: Kat 2'nin gösterime girecek kısmı 2026-12-16'ya yetişmeyecek gibi görünürse önce sabah brifingi ve tek zaman çizelgesi Kat 2 sonrasına itilir; onay kuyruğu ve izin kipi kalır, çünkü dış içerik ve yazma işleri onlara dayanır.

## Gerekçe
Kapsam bir dönemlik ödevden büyük; teslime çalışan bir çekirdek yetişmeli. Yapılı veri uygulamada durur, Claude ona Faz 2'deki MCP kapısından özetle bağlanır (benzer uygulamaların taraması, 2026-10-15).

## Reddedilenler
- RPE, süperset, plaka ve ısınma hesaplayıcı: kullanıcı kullanmıyor.
- Banka entegrasyonu: kişisel kullanıma göre ağır.
- Mobilite geçişlerinde hazırlık süresi: geçişi kullanıcı kendisi yapıyor.

## Yeniden açma koşulu
Faz 1 teslimden önce yetişmeyecek gibi görünürse kapsam yeniden kırpılır.
