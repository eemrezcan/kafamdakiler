---
kimlik: K-0027
baslik: "İkinci beyin merkezli modüller ve katlar"
tur: karar
soru: "Uygulamanın ikinci beyin merkezli modülleri neler, hangi katta ve hangi sırayla yapılır?"
sonuc: kabul
kavramlar: [ikinci-beyin, kat-planı, yakalama, gelen-kutusu, bağımlılık-sırası, widget, sürüm-uyumu]
tags: [karar]
---

# K-0027 - İkinci beyin merkezli modüller ve katlar

K-0004 kaydından bölündü (2026-11-27; 8'den fazla geçerli hükmü olan kayıt tek soruluk kayıtlara bölündü). Madde eşlemesi: K-0004/m04 → m01, K-0004/m05 → m02, K-0004/m06 → m03, K-0004/m07 → m04, K-0004/m08 → m05, K-0004/m09 → m06, K-0004/m10 → m07, K-0004/m11 → m08, K-0004/d01 → d01. Maddelerin metni ve tarihi değişmedi.

## m01 - Uygulama kullanıcının ikinci beyninin telefondaki yüzüdür
```yaml
tur: m
durum: guncel
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [kişisel-bilgi-yönetimi, alışkanlık, spor, kilo]
karar-veren: kullanici
```
Ek (2026-11-03): kişisel bilgi yönetimi merkezli kapsam. Kullanıcı kararı. Uygulama kullanıcının kişisel bilgi sisteminin ("ikinci beyin") telefondaki yüzüdür; alışkanlık, spor ve kilo bu sistemin ölçülen alanlarıdır. Kapsamın tamamı korunur, şu modüller eklenir.

## m02 - Yakala, Gelen kutusu, Projeler, Günler ve Arama modülleri eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [gelen-kutusu, projeler, günler, arama, beynime-sor, paylaş-menüsü]
karar-veren: kullanici
```
Ek (2026-11-03): modüller:
- Yakala: hemen açılan tek ekran; yazı, ses (yazıya çevrilir, yapay zekâ temizler), fotoğraf; Android Paylaş menüsü ve uygulama kısayolu; önce telefona kaydedilir.
- Gelen kutusu: yapay zekâ yer, başlık ve etiket önerir; kullanıcı onaylar, düzeltir ya da sonraya bırakır.
- Projeler: durum, sıradaki adım, nerede kalındığı, görevler, günlük; projeye hızlı not.
- Günler: bugünün planı, geçmiş günler, haftalık özet.
- Arama, not okuma ve "Beynime sor".

## m03 - Haftalık sıra yazılır ve yetişmeyen kısım ders sonrasında sürer
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [haftalık-sıra, gösterim, widget]
karar-veren: kullanici
```
Ek (2026-11-03): Sıra: Yakala (hafta 3), bilgi okuma ekranları (hafta 4), 1. gösterim, sunucu ve sesli not (hafta 5), hatırlatıcı ve yapay zekâ ile yerleştirme (hafta 6), spor temeli (hafta 7), Beynime sor, haftalık özet, kilo ve MCP (hafta 8), son hafta test ve APK. Yetişmeyen kısım (plana işaret, spor rekor ve 1RM, OAuth, widget) ders sonrasında sürer. (2026-11-04 eki bu sırayı değiştirdi: "Yukarıdaki 2026-11-03 sırası bunun yerine geçer.")

## m04 - Yakalama ders için de tam CRUD varlığıdır
```yaml
tur: m
durum: guncel
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [crud, ders]
karar-veren: kullanici
```
Ek (2026-11-03): Yakalama ders için de tam CRUD varlığıdır.

## m05 - Haftalık bölme kalkar, sıra bağımlılığa göredir
```yaml
tur: m
durum: guncel
tarih: 2026-11-04
dayanak: kullanici
kavramlar: [bağımlılık-sırası]
karar-veren: kullanici
```
Ek (2026-11-04): modül listesi ve sıra. Kullanıcı kararı. Senaryo çalışmasından (takvim ve son tarih, beyin ile repo köprüsü, zaman ve verim hesabı, telefon verisi, kendiliğinden konuşan yardımcı) sonra modüller ve sıraları belirlendi. Haftalık bölme kalkar: sıra bağımlılığa göredir, biten modülden sonrakine geçilir. Yukarıdaki 2026-11-03 sırası bunun yerine geçer.

## m06 - Modüller dört kata ayrılır
```yaml
tur: m
durum: guncel
tarih: 2026-11-04
dayanak: kullanici
kavramlar: [kat-1, kat-2, kat-3, kat-4]
karar-veren: kullanici
```
Ek (2026-11-04):
- Hazır: hesap ve roller, alışkanlıklar.
- Kat 1 (1. gösterime hedef): beyin onarımı (beynin kendi reposunda, K-0035 eki 2026-11-04), Yakala, beyne ham kart (sunucuya kadar Tailscale ile laptop), beyin okuma, okuma ekranları (Projeler, Günler, Arama; Yakala'ya proje seçici), yönetim ekranları.
- Kat 2: sunucu, gelen kutusu ve yerleştirme, görevler ve hatırlatıcılar (son tarihli işi günlere bölme, geri sayım, sözler, özel tarihler, Google Takvim'den yalnız okuma), ses, repo köprüsü.
- Kat 3 (bağımsız, araya girebilir): telefon verisi (ekran süresi, adım, uyku tahmini), zaman takibi (gün paneli sayacının telefon yüzü, Claude Code oturum süreleri), spor ve kilo.
- Kat 4: proaktif yardımcı (sabah brifingi, akşam kapanışı, gün hesabı, ayarlanabilir ton; günde tek bildirimle başlar), Beynime sor ve akışlar, MCP, haftalık örüntüler.

## m07 - Kendiliğinden gelen veri, gerçek kullanım, bütçe sınırı ve gizli notlar ilkeleri geçerlidir
```yaml
tur: m
durum: guncel
tarih: 2026-11-04
dayanak: kullanici
kavramlar: [gizli-not, bütçe-sınırı, öğrenme-kipi]
karar-veren: kullanici
```
Ek (2026-11-04): İlkeler: kendiliğinden gelen veri elle girilenden önce gelir; her modülden sonra birkaç gün gerçek kullanım; Claude API için aylık bütçe sınırı; `gizli: true` notlar yapay zekâya gitmez. Kat 1 öğrenme kipindedir; sonraki katların kipi ayrıca konuşulur (K-0001).

## m08 - Kat 1'e paylaşımdan yakalama, kısayol, widget ve sürüm uyumu eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-11-06
dayanak: kullanici
kavramlar: [paylaşımdan-yakalama, uygulama-kısayolu, widget, sürüm-uyumu]
karar-veren: kullanici
```
Ek (2026-11-06): Kat 1'e dört ek. Kullanıcı kararı. Benzer uygulamalar taramasından (beyinde `projects/kafamdakiler/notlar/benzer-uygulamalar-ozellik-havuzu.md`) sunucu ve yapay zekâ gerektirmeyen, Kat 1 modüllerini büyüten dört özellik Kat 1'e alındı:
- Paylaşım menüsünden yakalama: başka uygulamadan paylaşılan metin, link ya da tek görsel Yakala ekranını dolu açar.
- Uygulama kısayolu: ikona basılı tutunca "Yakala".
- Ana ekran widget'ı: tek dokunuşla Yakala. Yukarıdaki 2026-11-03 sırasında "ders sonrası" sayılan widget bununla öne alındı (yalnız yakalama düğmesi; veri gösteren widget yine sonraya).
- Sürüm uyumu: API en düşük uygulama sürümünü söyler, eski uygulama "güncelle" der. Sunucuya taşınınca APK ile API ayrı güncelleneceği için.

Ayrıntı ve sıra `docs/planlar/kat1.md` F7'de. Bu ekin yeniden açma koşulu: F7 gösterime (2026-11-18) yetişmeyecek gibi görünürse widget çıkarılır, önce anlatım yapılır (K-0001 eki 2026-11-05).

## d01 - Konum, ilgili notlar, kaydırarak ayıklama ve cihaz oturumları havuzda kalır
```yaml
tur: d
durum: guncel
tarih: 2026-11-06
kavramlar: [özellik-havuzu]
```
Ek (2026-11-06): Kalan seçimler (konum, ilgili notlar, kaydırarak ayıklama, cihaz oturumları) havuzda kalır; konum beynin `gelen ekle` komutunda alan olmadığı için Kat 1'e alınmadı.
