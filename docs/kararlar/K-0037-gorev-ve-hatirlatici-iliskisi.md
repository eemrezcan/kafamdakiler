---
kimlik: K-0037
baslik: "Görev ve hatırlatıcı ilişkisi"
tur: karar
soru: "Görev ile hatırlatıcı nasıl bir ilişkidedir?"
sonuc: kabul
kavramlar: [görev, hatırlatıcı, yaptım, veri-sahipliği, birleşik-liste]
tags: [karar]
---

# K-0037 - Görev ve hatırlatıcı ilişkisi

K-0024 kaydından bölündü (2026-11-27; 8'den fazla geçerli hükmü olan kayıt tek soruluk kayıtlara bölündü). Madde eşlemesi: K-0024/m03 → m01, K-0024/k01 → k01, K-0024/r01 → r01, K-0024/r02 → r02, K-0024/r03 → r03. Maddelerin metni ve tarihi değişmedi.

## m01 - Hatırlatıcı görevin özelliğidir, yaptım ikisini birlikte kapatır
```yaml
tur: m
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
kavramlar: [yaptım, veri-sahipliği, birleşik-liste]
karar-veren: kullanici
```
**Görev ile hatırlatıcı: hatırlatıcı görevin özelliğidir.** Görev beyinde durur (K-0023); saat, tekrar ve bildirim uygulamanın veritabanında, göreve bağlı. "Yaptım" görevi bitirir, hatırlatıcı susar; görev bitince hatırlatıcı da kapanır. Bugün ve Takvim'de plan maddesi, görev, hatırlatıcı ve takvim etkinliği tek listede, tek "yaptım" ile görünür. Hatırlatıcı elle (işin sayfasından, yeni iş formundan) ya da asistanla kurulur.

## k01 - Görev ile hatırlatıcı zincirinin testleri
```yaml
tur: k
durum: guncel
tarih: 2026-11-10
```
m01: `backend.Tests/HatirlaticiZinciriTests.cs` (görevi bitirmenin her yolu hatırlatıcıları kapatır), `backend.Tests/GunYaptimApiTests.cs` (günün tek "yaptım"ı ve görev ile hatırlatıcı arasındaki zincir), `backend.Tests/HatirlaticiBagiApiTests.cs` (hatırlatıcının plan maddesine ya da göreve bağı).

## r01 - Görev ile hatırlatıcının yalnız görünümde birleşmesi
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
"Yaptım" iki kayda yazılır, ayrışma sürer.

## r02 - Hatırlatıcıyı beyne taşımak
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
İnternetsiz bildirim zorlaşır, iş büyür.

## r03 - Hepsini uygulamanın veritabanına taşımak
```yaml
tur: r
durum: guncel
tarih: 2026-11-10
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
K-0023'te reddedildi.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-11-27
dayanak: bilinmiyor
```
Belgede yazılmamış.
