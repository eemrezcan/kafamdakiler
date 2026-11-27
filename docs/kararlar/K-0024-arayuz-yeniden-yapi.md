---
kimlik: K-0024
baslik: "Arayüzün yeniden yapısı (mobil ve web)"
tur: karar
soru: "Uygulamanın bilgi mimarisi ve gezinmesi nasıl olsun?"
sonuc: kabul
kavramlar: [arayüz, bilgi-mimarisi, gezinme, bugün, takvim, asistan, alışkanlık]
tags: [karar]
---

# K-0024 - Arayüzün yeniden yapısı (mobil ve web)

Kapsamı bölündü, devamı K-0037, K-0038. Bu kayıtta kalan maddeler yerinde durur; taşınan maddelerin metni yeni kayıtlardadır (2026-11-27).

Kullanıcı, 2026-11-10. Maket: `docs/planlar/maket/index.html`, gerekçeli taslak: `docs/planlar/ui-vizyon.md` (iş bitince silinir; özü bu karardadır).

## m01 - Uygulama dört fiil üzerine kurulur, her biri tek yerde
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [söyle, yap, planla, izle, beyin-okuma]
karar-veren: kullanici
```
**Dört fiil, her biri tek yerde.** Söyle (Asistan), Yap (Bugün), Planla (Takvim), İzle (Alışkanlıklar). Beyin okuma ikincil.

## m02 - Mobilde alt menü Bugün, Takvim, Asistan, Alışkanlıklar, Beyin olur
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [alt-menü, bildirim-merkezi, arama, web, mobil]
karar-veren: kullanici
```
**Gezinme.** Mobilde alt menü: Bugün · Takvim · ortada belirgin Asistan · Alışkanlıklar · Beyin. Üst sağda 🔔 Bildirimler ve profil. Arama yalnız Beyin'de. Hatırlatıcılar, Gelen ve "Daha fazla" sekmeleri kalkar; içerikleri Takvim'e, Asistan'a ve profil sayfasına dağılır. Web aynı yapıyı kendi düzeninde izler.

## m03 - Hatırlatıcı görevin özelliğidir, yaptım ikisini birlikte kapatır
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [yaptım, veri-sahipliği, birleşik-liste]
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0037/m01 olarak taşındı.

## m04 - Bugün asistan özeti, gün yükü ve birleşik yapılacaklar listesini taşır
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [gün-yükü, devret, alışkanlık-şeridi]
karar-veren: kullanici
```
**Bugün.** Üstte asistanın kısa özeti ve gün yükü (açık işlerin tahmini ile günlük kapasite; aşınca devret, azsa boşluk). Dünden kalanlar, alışkanlık şeridi, birleşik yapılacaklar listesi. Yaklaşanlar ve zaman çizelgesi kartları kalkar.

## m05 - Asistan tek akıştır, kullanıcının girdisinden doğan geri alınabilir işleri sormadan yapar
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [geri-al, onay-kuyruğu, yakala, gelen, brifing, izin-kipi, dış-kaynak]
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0038/m01 olarak taşındı.

## m06 - Raflı alışkanlığın detayı rafı içerir, okudum kaydı tek alt sayfadadır
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [alışkanlık, raf, okudum]
karar-veren: kullanici
```
**Alışkanlıklar.** Raflı alışkanlığın detayı rafı içerir. "Okudum" kaydı tek alt sayfada: kitap, sayfa, süre.

## m07 - Projeler şimdilik Beyin sekmesinde yalnız okunur
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [projeler]
karar-veren: kullanici
```
**Projeler** şimdilik Beyin sekmesinde yalnız okunur; işlevli hali ayrı iş.

## m08 - Tema korunur, değişen deneyim ve yapıdır
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [tema, k-0022]
karar-veren: kullanici
```
**Tema korunur.** Renkler, yazı tipi ve genel görünüş (K-0022) değişmez; değişen deneyim ve yapıdır.

## m09 - Dört faz birlikte yazılır, main'e birleştirme kullanıcının telefondaki denemesinden sonra olur
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [uygulama-planı, sonnet-işçileri, ui-yeniden, merge]
karar-veren: kullanici
```
**Uygulama.** Dört faz (arayüz, görev-hatırlatıcı verisi, asistan akışı, web) birlikte yazılır; `h/ui-yeniden` dalında, Sonnet işçileri yazar, Opus denetler ve arayüzü son elden geçirir. Main'e birleştirme kullanıcı telefonda denedikten sonra, onayıyla.

## k01 - Görev ile hatırlatıcı zincirinin testleri
```yaml
tur: k
durum: yerini-aldi
tarih: 2026-11-10
```
Kapsamı bölündü: bu madde K-0037/k01 olarak taşındı.

## k02 - Bugün ve Takvim görünümlerinin testleri
```yaml
tur: k
durum: guncel
tarih: 2026-11-10
```
m02 ve m04: `backend.Tests/GunGorunumuApiTests.cs` (gün görünümü ve dünden kalanlar), `backend.Tests/TakvimAraligiApiTests.cs` (takvimin aralık görünümü), `backend.Tests/BugunSayfasiTests.cs` (web menüsü ve Bugün sayfası), `backend.Tests/GunSayfalariTests.cs` (Bugün'ün tek listesi, Takvim, gün kapasitesi).

## k03 - Asistan akışının testleri
```yaml
tur: k
durum: yerini-aldi
tarih: 2026-11-10
```
Kapsamı bölündü: bu madde K-0038/k01 olarak taşındı.

## g01 - Kullanıcı uygulamayı kullanması zor buldu
```yaml
tur: g
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
```
Kullanıcı uygulamayı kullanması zor buldu: her şey her yerde, Bugün bir çorba, görevler ile hatırlatıcılar birbirinden habersiz, yapay zekâ özellikleri beş ayrı ekrana dağılmış ve her biri seçim istiyor.

## g02 - Kök nedenler: modül modül büyüme, veri sahipliğinin arayüze sızması, ekran ekran yapay zekâ
```yaml
tur: g
durum: guncel
tarih: 2026-11-10
dayanak: cikarim
kavramlar: [veri-sahipliği, k-0023]
```
Kök nedenler: modül modül büyüyüp ekran tasarımı yapılmaması, K-0023'teki veri sahipliği ayrımının arayüze sızması, yapay zekânın ekran ekran eklenmesi. Veri sahipliği kararı doğru kalır; arayüz onu gizler.

## r01 - Görev ile hatırlatıcının yalnız görünümde birleşmesi
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0037/r01 olarak taşındı.

## r02 - Hatırlatıcıyı beyne taşımak
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0037/r02 olarak taşındı.

## r03 - Hepsini uygulamanın veritabanına taşımak
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0037/r03 olarak taşındı.

## r04 - Sol üstte hamburger çekmeceyle ana gezinme
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "Kullanıcı yeni yapıyı telefonda bir hafta kullandıktan sonra bir fiilin yerini yanlış bulursa ya da asistanın sormadan yaptığı işlerde geri alma sık gerekiyorsa (yetki sınırı yeniden konuşulur)."
karar-veren: kullanici
```
Her iş bir dokunuş uzar, ne nerede görünmez.

## r05 - Her şeyin yalnız asistandan yapıldığı tek ekran
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "Kullanıcı yeni yapıyı telefonda bir hafta kullandıktan sonra bir fiilin yerini yanlış bulursa ya da asistanın sormadan yaptığı işlerde geri alma sık gerekiyorsa (yetki sınırı yeniden konuşulur)."
karar-veren: kullanici
```
M04 (mobilden CRUD) ve M08 (ekranlar arası gezinme) gösterilemez, asistan hata yapınca kaçış yolu kalmaz.

## r06 - Asistanın her şeyi onaya sorması
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "Kullanıcı yeni yapıyı telefonda bir hafta kullandıktan sonra bir fiilin yerini yanlış bulursa ya da asistanın sormadan yaptığı işlerde geri alma sık gerekiyorsa (yetki sınırı yeniden konuşulur)."
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0038/r01 olarak taşındı.

## r07 - Asistanın dış kaynak dahil tam özerk olması
```yaml
tur: r
durum: yerini-aldi
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Kapsamı bölündü: bu madde K-0038/r02 olarak taşındı.

## r08 - Projeleri şimdi işlevli yapmak ya da tamamen kaldırmak
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Revizyonu uzatır ya da web ile mobil ayrışır.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-11-10
dayanak: bilinmiyor
```
Belgede yazılmamış.
