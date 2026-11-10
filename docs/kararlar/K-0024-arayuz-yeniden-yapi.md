---
baslik: Arayüzün yeniden yapısı (mobil ve web)
tur: karar
soru: Uygulamanın bilgi mimarisi, görev ile hatırlatıcı ilişkisi ve asistanın yetkisi nasıl olsun?
sonuc: kabul
tags: [karar]
---

## Karar
Kullanıcı, 2026-11-10. Maket: `docs/planlar/maket/index.html`, gerekçeli taslak: `docs/planlar/ui-vizyon.md` (iş bitince silinir; özü bu karardadır).

1. **Dört fiil, her biri tek yerde.** Söyle (Asistan), Yap (Bugün), Planla (Takvim), İzle (Alışkanlıklar). Beyin okuma ikincil.
2. **Gezinme.** Mobilde alt menü: Bugün · Takvim · ortada belirgin Asistan · Alışkanlıklar · Beyin. Üst sağda 🔔 Bildirimler ve profil. Arama yalnız Beyin'de. Hatırlatıcılar, Gelen ve "Daha fazla" sekmeleri kalkar; içerikleri Takvim'e, Asistan'a ve profil sayfasına dağılır. Web aynı yapıyı kendi düzeninde izler.
3. **Görev ile hatırlatıcı: hatırlatıcı görevin özelliğidir.** Görev beyinde durur (K-0023); saat, tekrar ve bildirim uygulamanın veritabanında, göreve bağlı. "Yaptım" görevi bitirir, hatırlatıcı susar; görev bitince hatırlatıcı da kapanır. Bugün ve Takvim'de plan maddesi, görev, hatırlatıcı ve takvim etkinliği tek listede, tek "yaptım" ile görünür. Hatırlatıcı elle (işin sayfasından, yeni iş formundan) ya da asistanla kurulur.
4. **Bugün.** Üstte asistanın kısa özeti ve gün yükü (açık işlerin tahmini ile günlük kapasite; aşınca devret, azsa boşluk). Dünden kalanlar, alışkanlık şeridi, birleşik yapılacaklar listesi. Yaklaşanlar ve zaman çizelgesi kartları kalkar.
5. **Asistan tek akıştır.** Yakala, Gelen, onay kuyruğu, iş kartları ve brifing aynı ekranda. Kullanıcının kendi girdisinden doğan, geri alınabilir işleri (görev, hatırlatıcı, not, takvim girdisi) **sormadan yapar** ve Geri al / Düzelt gösterir. Dış kaynaktan gelen içerik (mail vb.), silme, kod, push ve deploy onaya düşer (K-0009 izin kipi bunun üstünde çalışır). Emin olmadığında tek soru sorar; seçenek listesi sunmaz.
6. **Alışkanlıklar.** Raflı alışkanlığın detayı rafı içerir. "Okudum" kaydı tek alt sayfada: kitap, sayfa, süre.
7. **Projeler** şimdilik Beyin sekmesinde yalnız okunur; işlevli hali ayrı iş.
8. **Tema korunur.** Renkler, yazı tipi ve genel görünüş (K-0021, K-0022) değişmez; değişen deneyim ve yapıdır.
9. **Uygulama.** Dört faz (arayüz, görev-hatırlatıcı verisi, asistan akışı, web) birlikte yazılır; `h/ui-yeniden` dalında, Sonnet işçileri yazar, Opus denetler ve arayüzü son elden geçirir. Main'e birleştirme kullanıcı telefonda denedikten sonra, onayıyla.

## Gerekçe
Kullanıcı uygulamayı kullanması zor buldu: her şey her yerde, Bugün bir çorba, görevler ile hatırlatıcılar birbirinden habersiz, yapay zekâ özellikleri beş ayrı ekrana dağılmış ve her biri seçim istiyor. Kök nedenler: modül modül büyüyüp ekran tasarımı yapılmaması, K-0023'teki veri sahipliği ayrımının arayüze sızması, yapay zekânın ekran ekran eklenmesi. Veri sahipliği kararı doğru kalır; arayüz onu gizler.

## Reddedilenler
- Görev ile hatırlatıcının yalnız görünümde birleşmesi: "yaptım" iki kayda yazılır, ayrışma sürer.
- Hatırlatıcıyı beyne taşımak: internetsiz bildirim zorlaşır, iş büyür.
- Hepsini uygulamanın veritabanına taşımak: K-0023'te reddedildi.
- Sol üstte hamburger çekmeceyle ana gezinme: her iş bir dokunuş uzar, ne nerede görünmez.
- Her şeyin yalnız asistandan yapıldığı tek ekran: M04 (mobilden CRUD) ve M08 (ekranlar arası gezinme) gösterilemez, asistan hata yapınca kaçış yolu kalmaz.
- Asistanın her şeyi onaya sorması: kullanıcının şikâyet ettiği seçim yorgunluğu sürer.
- Asistanın dış kaynak dahil tam özerk olması: dışarıdan gelen metin asistanı yanlış işe yönlendirebilir.
- Projeleri şimdi işlevli yapmak ya da tamamen kaldırmak: revizyonu uzatır ya da web ile mobil ayrışır.

## Yeniden açma koşulu
Kullanıcı yeni yapıyı telefonda bir hafta kullandıktan sonra bir fiilin yerini yanlış bulursa ya da asistanın sormadan yaptığı işlerde geri alma sık gerekiyorsa (yetki sınırı yeniden konuşulur).
