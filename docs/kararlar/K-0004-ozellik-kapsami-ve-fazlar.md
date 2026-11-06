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

## Gerekçe
Kapsam bir dönemlik ödevden büyük; teslime çalışan bir çekirdek yetişmeli. Yapılı veri uygulamada durur, Claude ona Faz 2'deki MCP kapısından özetle bağlanır (benzer uygulamaların taraması, 2026-10-15).

## Reddedilenler
- RPE, süperset, plaka ve ısınma hesaplayıcı: kullanıcı kullanmıyor.
- Banka entegrasyonu: kişisel kullanıma göre ağır.
- Mobilite geçişlerinde hazırlık süresi: geçişi kullanıcı kendisi yapıyor.

## Yeniden açma koşulu
Faz 1 teslimden önce yetişmeyecek gibi görünürse kapsam yeniden kırpılır.
