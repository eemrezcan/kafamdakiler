---
kimlik: K-0038
baslik: "Asistanın akışı ve yetkisi"
tur: karar
soru: "Asistan hangi işleri sormadan yapar, hangileri onaya düşer?"
sonuc: kabul
kavramlar: [asistan, izin-kipi, onay-kuyruğu, geri-al, dış-kaynak]
tags: [karar]
---

# K-0038 - Asistanın akışı ve yetkisi

K-0024 kaydından bölündü (2026-11-27; 8'den fazla geçerli hükmü olan kayıt tek soruluk kayıtlara bölündü). Madde eşlemesi: K-0024/m05 → m01, K-0024/k03 → k01, K-0024/r06 → r01, K-0024/r07 → r02. Maddelerin metni ve tarihi değişmedi.

## m01 - Asistan tek akıştır, kullanıcının girdisinden doğan geri alınabilir işleri sormadan yapar
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [geri-al, onay-kuyruğu, yakala, gelen, brifing, izin-kipi, dış-kaynak]
karar-veren: kullanici
```
**Asistan tek akıştır.** Yakala, Gelen, onay kuyruğu, iş kartları ve brifing aynı ekranda. Kullanıcının kendi girdisinden doğan, geri alınabilir işleri (görev, hatırlatıcı, not, takvim girdisi) **sormadan yapar** ve Geri al / Düzelt gösterir. Dış kaynaktan gelen içerik (mail vb.), silme, kod, push ve deploy onaya düşer (K-0009 izin kipi bunun üstünde çalışır). Emin olmadığında tek soru sorar; seçenek listesi sunmaz.

## k01 - Asistan akışının testleri
```yaml
tur: k
durum: guncel
tarih: 2026-11-10
```
m01: `backend.Tests/AsistanGirdiApiTests.cs` (asistanın tek girişi), `backend.Tests/AsistanAkisApiTests.cs` (akış ve rozet), `backend.Tests/AsistanPaylasApiTests.cs` (paylaşım menüsünden gelen metin yalnız not olur, gerisi onay kuyruğunda bekler), `backend.Tests/AsistanSayfalariTests.cs` (web Asistan sayfası).

## r01 - Asistanın her şeyi onaya sorması
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "Kullanıcı yeni yapıyı telefonda bir hafta kullandıktan sonra bir fiilin yerini yanlış bulursa ya da asistanın sormadan yaptığı işlerde geri alma sık gerekiyorsa (yetki sınırı yeniden konuşulur)."
karar-veren: kullanici
```
Kullanıcının şikâyet ettiği seçim yorgunluğu sürer.

## r02 - Asistanın dış kaynak dahil tam özerk olması
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Dışarıdan gelen metin asistanı yanlış işe yönlendirebilir.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-11-27
dayanak: bilinmiyor
```
Belgede yazılmamış.
