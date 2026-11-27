---
kimlik: K-0028
baslik: "Sekreter çekirdeği ve entegrasyonlar"
tur: karar
soru: "Uygulama kullanılacak ikinci beyin ve sekreter olarak hangi işleri ve entegrasyonları hangi katta yapar?"
sonuc: kabul
kavramlar: [sekreter, entegrasyon, onay-kuyruğu, izin-kipi, gmail, google-takvim, finans, dış-içerik]
tags: [karar]
---

# K-0028 - Sekreter çekirdeği ve entegrasyonlar

K-0004 kaydından bölündü (2026-11-27; 8'den fazla geçerli hükmü olan kayıt tek soruluk kayıtlara bölündü). Madde eşlemesi: K-0004/m12 → m01, K-0004/m13 → m02, K-0004/m14 → m03, K-0004/m15 → m04, K-0004/m16 → m05, K-0004/m17 → m06, K-0004/r02 → r01, K-0004/d02 → d01. Maddelerin metni ve tarihi değişmedi.

## m01 - Ölçü sekreter çekirdeğine kayar: uygulama kullanılacak ikinci beyin ve sekreterdir
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [sekreter-çekirdeği, ölçü-değişikliği]
karar-veren: kullanici
```
Ek (2026-11-07): sekreter çekirdeği ve entegrasyonlar. Kullanıcı kararı. Ölçü değişti: uygulama yalnız ödev değil, kullanıcının gerçekten kullanacağı ikinci beyin, takip mekanizması ve onun adına iş hazırlayan sekreterdir. Benzer uygulama taramaları ve üç yeni araştırma (beyinde `projects/kafamdakiler/notlar/sekreter-entegrasyon-arastirmasi.md`) sonunda aşağıdaki maddeler belirlendi.

## m02 - Kat 1'e veri gösteren ana ekran widget'ı eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [widget]
karar-veren: kullanici
```
Ek (2026-11-07): Kat 1: veri gösteren ana ekran widget'ı (bugünün planı, yaklaşan hatırlatıcılar). 2026-11-06 ekinde "sonraya" kalan kısım bununla öne alındı.

## m03 - Kat 2'ye onay kuyruğu, izin kipi, sabah brifingi, sesten iş çıkarma, ısrarlı hatırlatma, tek zaman çizelgesi ve Google Takvim eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [izin-kipi, sabah-brifingi, sesten-iş-çıkarma, ısrarlı-hatırlatma, zaman-çizelgesi, google-takvim]
karar-veren: kullanici
```
Ek (2026-11-07): Kat 2'ye eklenenler:
- Onay kuyruğu ve geri alma: Claude'un önerdiği her eylem (yerleştirme, görev, hatırlatıcı, plan maddesi, takvim) tek listede "taslak hazır, uygula" kartıdır; bildirimden Onayla/Reddet; uygulanan eylem geri alınabilir (beyinde commit'in geri çevrilmesi, veritabanında arşiv); emin olunmayan öneri işaretlidir.
- Eylem başına izin kipi: Sor / Kendin yap / Yasak; sıra Yasak > Sor > Kendin yap; yeni eylem türü ilk seferde sorulur; "bunu yapma" kalıcıdır; art arda reddedilen asistan Sor kipine düşer. K-0009 Asistan izinlerinin üstüne kurulur.
- Sabah brifingi (Kat 4'ten öne alındı): günde tek bildirim, 5-7 kart, kart başına 👍/👎, brifinge yazarak düzeltme, dünden kalanlara taşı/bırak, N gün üst üste taşınan görev "Bir gün"e düşer.
- Sesten iş çıkarma: konuşmadan görev, hatırlatıcı ve plan önerileri çıkar, kaydetmeden önce önizlenir ve onay kuyruğuna düşer.
- Israrlı hatırlatma: hatırlatıcı başına isteğe bağlı, aralıklı ve sayısı sınırlı yeniden çalma; sessiz modu yalnız "acil" olan deler.
- Tek zaman çizelgesi: Bugün'de takvim etkinlikleri, plan maddeleri ve hatırlatıcılar saat sırasıyla; Google Takvim ile birlikte.
- Google Takvim Kat 2'dedir (karar 10 kapandı) ve yalnız okuma değil, onay kuyruğundan geçen yazma da hedeflenir; plana yazma Kat 2'dedir (karar 9 kapandı).

Yeniden açma koşulu (bu ek için): Kat 2'nin gösterime girecek kısmı 2026-12-16'ya yetişmeyecek gibi görünürse önce sabah brifingi ve tek zaman çizelgesi Kat 2 sonrasına itilir; onay kuyruğu ve izin kipi kalır, çünkü dış içerik ve yazma işleri onlara dayanır.

## m04 - Kat 3'e Gmail salt okunur bağlantısı ve kredi kartı ekstresinden finans takibi eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [gmail, finans, ekstre, abonelik, taksit]
karar-veren: kullanici
```
Ek (2026-11-07): Kat 3'e eklenen: Google ve finans. Gmail'e salt okunur bağlantı; sunucu yalnız kullanıcının Gmail filtresiyle etiketlediği mailleri işler. Kredi kartı ekstresinden harcama satırları (uygulamanın veritabanı, K-0005), abonelik ve zam tespiti, taksit takibi, son ödeme hatırlatıcısı önerisi, aylık özetin beynin `finans/aylik/` alanına yazılması, mailden etkinlik ya da hatırlatıcı önerisi. Toplamları sunucu hesaplar; Claude yalnız kişisel bilgisi çıkarılmış özeti yorumlar.

## m05 - Kat 4'e Google Drive ve mail yanıtı taslağı eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [google-drive, mail-taslağı]
karar-veren: kullanici
```
Ek (2026-11-07): Kat 4'e eklenen: Google Drive (belgelerde arama, üretilen dosyayı kaydetme), mail yanıtını taslak olarak hazırlama.

## m06 - Dış kaynaklı içerik Claude'a veri olarak gider, bu çağrıya araç verilmez, öneriler Sor kipine düşer
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [güvenlik, dış-içerik, kişisel-veri]
karar-veren: kullanici
```
Ek (2026-11-07): Güvenlik kuralı: mail ve dış kaynaklı içerik Claude'a veri olarak gider; bu içeriği işleyen çağrıya araç verilmez, yalnız şemalı çıktı alınır; dış kaynaktan doğan her öneri izin kipinden bağımsız olarak Sor kipine düşer. Bu yüzden Gmail, onay kuyruğundan sonra gelir. Kişisel veri (kart numarası, IBAN, ad) Claude'a gitmez.

## r01 - Banka entegrasyonu
```yaml
tur: r
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kişisel kullanıma göre ağır. Ek (2026-11-07): Banka entegrasyonu reddi yeniden açılmadı: o, bankanın API'sine bağlanmaktı; burada yalnız bankanın zaten mail attığı ekstre okunur.

## d01 - Türkçe doğal dille tarih, Geçmişten bugün kartı ve hızlı ayar kutucuğu havuzda kalır
```yaml
tur: d
durum: guncel
tarih: 2026-11-07
kavramlar: [özellik-havuzu]
```
Ek (2026-11-07): Havuzda kalan: Türkçe doğal dille tarih, "Geçmişten bugün" kartı, hızlı ayar kutucuğu.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-11-27
dayanak: bilinmiyor
```
Belgede yazılmamış.
