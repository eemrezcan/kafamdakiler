---
kimlik: K-0017
baslik: "Girdi doğrulama DataAnnotations ile, sunucuda her zaman"
tur: karar
soru: "Form ve API girdisi hangi araçla, nerede doğrulanır?"
sonuc: kabul
kavramlar: [doğrulama, dataannotations, sunucu-doğrulaması, razor-pages, minimal-api]
tags: [karar]
---

# K-0017 - Girdi doğrulama DataAnnotations ile, sunucuda her zaman

## m01 - Doğrulama kuralları DTO ve form modellerinde DataAnnotations ile yazılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [dto]
karar-veren: kullanici
```
2026-10-29, kullanıcı. Doğrulama kuralları DTO ve form modellerinin üstüne DataAnnotations attribute'larıyla yazılır (`[Required]`, `[Range]`, `[StringLength]` vb.); birden çok alana bağlı kurallar `IValidatableObject` ile yazılır.

## m02 - Minimal API uçları AddValidation ile otomatik doğrulanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [addvalidation]
karar-veren: kullanici
```
Minimal API uçları .NET 10'un `AddValidation()` özelliğiyle otomatik doğrulanır, hatalı istekte 400 ve alan hataları döner.

## m03 - Razor Pages'te sunucuda ModelState.IsValid kontrol edilir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [modelstate, jquery-validation]
karar-veren: kullanici
```
Razor Pages'te sunucuda `ModelState.IsValid` kontrol edilir, tarayıcıda şablonun jQuery Validation'ı aynı kuralları gösterir.

## m04 - Sunucu doğrulaması hiçbir uçta atlanmaz
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [istemci-doğrulaması]
karar-veren: kullanici
```
İstemci doğrulaması yalnız kolaylıktır; sunucu doğrulaması hiçbir uçta atlanmaz.

## k01 - Hatırlatıcının ısrar alanlarını sunucunun denetlediği test edilir
```yaml
tur: k
durum: guncel
tarih: 2026-10-29
```
`backend.Tests/HatirlaticiIsrarTests.cs` (sunucu ısrarlı hatırlatma alanlarını saklar ve denetler).

## g01 - T06 ve K-0008 girdi doğrulanmasını ister, istek formu atlayabilir
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: kaynak
```
T06 ve K-0008 ("girdi doğrulanır"). Q12: istek formu atlayıp doğrudan API'ye gelebilir (curl, geliştirici araçları, Asistan hesabı).

## g02 - DataAnnotations çatıyla gelir ve iki yerde aynı kuralı kullanır
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
DataAnnotations çatıyla birlikte gelir, ek paket gerektirmez, Razor Pages ile Minimal API'de aynı kuralı kullanır ve tarayıcı tarafı doğrulamayı bedava verir.

## g03 - Ders örnekleri de bu yolu izler
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: kaynak
kavramlar: [ders-örnekleri]
```
Ders örnekleri (Hafta02) de bu yolu izler.

## r01 - FluentValidation (teknik yığın önerisinde ve K-0008'de örnek olarak anılmıştı)
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "Kurallar attribute'larla okunamaz hâle gelirse (çok sayıda koşullu ya da veritabanına bakan kural) FluentValidation yeniden düşünülür."
karar-veren: kullanici
```
Otomatik doğrulama paketi `FluentValidation.AspNetCore` artık desteklenmiyor, her uçta elle çağırmak gerekir ve tarayıcı tarafı doğrulama kaybolur.

## r02 - Yalnız istemci tarafı doğrulama
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Atlanabilir, güvenlik sağlamaz.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-29
dayanak: bilinmiyor
```
Belgede yazılmamış.
