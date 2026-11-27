---
kimlik: K-0009
baslik: "Roller Sahip ve Asistan, izinler claim ile"
tur: karar
soru: "Uygulamada hangi roller var ve yetki nasıl yönetilir?"
sonuc: kabul
kavramlar: [roller, asistan, izin, claim, identity, policy, sahip, yetki]
tags: [karar]
---

# K-0009 - Roller Sahip ve Asistan, izinler claim ile

## m01 - İki rol vardır: Sahip ve Asistan
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
karar-veren: kullanici
```
2026-10-16, kullanıcı. ASP.NET Core Identity ile iki rol: **Sahip** (kullanıcının kendisi; her şeyi görür ve yönetir, yönetici paneli onundur) ve **Asistan** (yapay zekâ için ayrı hesap; yalnız API'ye token ile girer).

## m02 - Asistan'ın izinleri Faz 1'den itibaren panelden açılıp kapanır, her izin bir claim'dir
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [aspnetuserclaims, faz-1]
karar-veren: kullanici
```
Asistan'ın izinleri Faz 1'den itibaren panelden açılıp kapanır: her izin Identity'nin hazır `AspNetUserClaims` tablosunda bir claim'dir (`izin` = `kilo.oku` gibi).

## m03 - Her izin için bir policy vardır, policy Sahip rolünü ya da ilgili claim'i ister
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
karar-veren: kullanici
```
Her izin için bir policy vardır; policy Sahip rolünü ya da ilgili claim'i ister.

## m04 - Panelde izin değişince security stamp güncellenir ve eski token geçersiz olur
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [security-stamp, token]
karar-veren: kullanici
```
Panelde izin değişince `UserManager.AddClaimAsync` / `RemoveClaimAsync` ve ardından `UpdateSecurityStampAsync` çağrılır, eski token geçersiz olur.

## m05 - Faz 2'deki MCP kapısı Asistan hesabıyla bağlanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [mcp, faz-2]
karar-veren: kullanici
```
Faz 2'deki MCP kapısı Asistan hesabıyla bağlanır.

## m06 - Web bütünüyle yalnız Sahip'e açıktır, Asistan yalnız API'ye girer
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [web]
karar-veren: kullanici
```
Ek (2026-10-30): Web (Razor Pages) bütünüyle yalnız Sahip'e açık; yalnız `/Hesap` (giriş, çıkış) herkese açık. Asistan web'e girmez, yalnız API (kullanıcı kararı; Asistan'ı izinli web sayfalarına salt okunur sokma önerisi şimdilik alınmadı).

## m07 - Bearer token izinlerin kopyasını taşır, API istekleri izin claim'lerini veritabanından okur
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [bearer-token, veritabanı]
karar-veren: kullanici
```
Ek (2026-10-30): Bearer token izinlerin kopyasını taşır ve 1 saat geçerlidir; izin kapanınca hemen etkili olsun diye API isteklerinde izin claim'leri token'dan değil veritabanından okunacak (izin adımında).

## m08 - T07 gösterimi izin açıp kapatarak yapılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [gösterim]
karar-veren: kullanici
```
Ek (2026-10-30): T07 gösterimi: Sahip panelden Asistan'ın bir iznini açar, Asistan (1. gösterimde Scalar'dan, 2. gösterimde MCP üzerinden Claude) veriye erişir; izni kapatınca aynı istek 403 alır.

## m09 - Derste hocaya iki rol şartının karşılanıp karşılanmadığı sorulur
```yaml
tur: m
durum: guncel
tarih: 2026-10-30
dayanak: kullanici
kavramlar: [hoca]
karar-veren: kullanici
```
Ek (2026-10-30): Kullanıcıya öneri: derste hocaya "ikinci rol yapay zekâ asistanı, izinleri yönetici panelinden veriliyor; iki rol şartını karşılar mı?" diye sorulacak.

## k01 - Asistan izinlerinin veritabanından okunması ve Yönetim ucunun yalnız Sahip'e açıklığı test edilir
```yaml
tur: k
durum: guncel
tarih: 2026-10-30
```
`backend.Tests/YonetimApiTests.cs` (Asistan'ın izinleri her istekte veritabanından okunur, `/api/yonetim` yalnız Sahip'e açık); `backend.Tests/IzinGruplariTests.cs` (izin tablosu her izni bir kez kapsar, seçimler doğru claim'leri yazar).

## g01 - T07 ve T08 karşılanır, en az ayrıcalık uygulanır
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: kaynak
```
T07 (giriş ve en az iki rol) ve T08 (yönetici paneli) karşılanır. İnsan ve makine istemcisi ayrılır, en az ayrıcalık ilkesine uyar.

## g02 - Kullanıcı izin matrisinin baştan hazır olmasını istedi
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
```
Kullanıcı izin matrisinin baştan hazır olmasını istedi.

## g03 - Claim ve policy Identity'nin hazır parçalarıdır, özel yetki altyapısı yazılmaz
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: cikarim
```
Claim ve policy Identity'nin hazır parçaları; özel yetki tablosu ya da altyapısı yazılmaz (K-0008). Tek insan kullanıcı olduğu için tablolara kullanıcı sahipliği (UserId) eklenmez.

## r01 - Faz 1'de sabit policy, izin matrisi Faz 2'de
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Daha az iş ama kullanıcı baştan hazır olmasını istedi.

## r02 - Özel izin tablosu ve kendi yetki işleyicisi
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Identity claim'leri aynı işi görüyor.

## r03 - Yönetici ve kullanıcı adında iki insan rolü
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "Hoca iki insan rolü şart koşarsa ya da uygulama başka kullanıcılara açılırsa (o zaman tablolara UserId gerekir)."
karar-veren: kullanici
```
İkinci bir insan kullanıcı yok.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-16
dayanak: bilinmiyor
```
Belgede yazılmamış.
