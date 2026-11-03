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

## Gerekçe
Kapsam bir dönemlik ödevden büyük; teslime çalışan bir çekirdek yetişmeli. Yapılı veri uygulamada durur, Claude ona Faz 2'deki MCP kapısından özetle bağlanır (benzer uygulamaların taraması, 2026-10-15).

## Reddedilenler
- RPE, süperset, plaka ve ısınma hesaplayıcı: kullanıcı kullanmıyor.
- Banka entegrasyonu: kişisel kullanıma göre ağır.
- Mobilite geçişlerinde hazırlık süresi: geçişi kullanıcı kendisi yapıyor.

## Yeniden açma koşulu
Faz 1 teslimden önce yetişmeyecek gibi görünürse kapsam yeniden kırpılır.
