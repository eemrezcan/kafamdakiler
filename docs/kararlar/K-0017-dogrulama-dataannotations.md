---
baslik: Girdi doğrulama DataAnnotations ile, sunucuda her zaman
tur: karar
soru: Form ve API girdisi hangi araçla, nerede doğrulanır?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-29, kullanıcı. Doğrulama kuralları DTO ve form modellerinin üstüne DataAnnotations attribute'larıyla yazılır (`[Required]`, `[Range]`, `[StringLength]` vb.); birden çok alana bağlı kurallar `IValidatableObject` ile yazılır. Minimal API uçları .NET 10'un `AddValidation()` özelliğiyle otomatik doğrulanır, hatalı istekte 400 ve alan hataları döner. Razor Pages'te sunucuda `ModelState.IsValid` kontrol edilir, tarayıcıda şablonun jQuery Validation'ı aynı kuralları gösterir. İstemci doğrulaması yalnız kolaylıktır; sunucu doğrulaması hiçbir uçta atlanmaz.

## Gerekçe
T06 ve K-0008 ("girdi doğrulanır"). Q12: istek formu atlayıp doğrudan API'ye gelebilir (curl, geliştirici araçları, Asistan hesabı). DataAnnotations çatıyla birlikte gelir, ek paket gerektirmez, Razor Pages ile Minimal API'de aynı kuralı kullanır ve tarayıcı tarafı doğrulamayı bedava verir. Ders örnekleri (Hafta02) de bu yolu izler.

## Reddedilenler
- FluentValidation (teknik yığın önerisinde ve K-0008'de örnek olarak anılmıştı): otomatik doğrulama paketi `FluentValidation.AspNetCore` artık desteklenmiyor, her uçta elle çağırmak gerekir ve tarayıcı tarafı doğrulama kaybolur.
- Yalnız istemci tarafı doğrulama: atlanabilir, güvenlik sağlamaz.

## Yeniden açma koşulu
Kurallar attribute'larla okunamaz hâle gelirse (çok sayıda koşullu ya da veritabanına bakan kural) FluentValidation yeniden düşünülür.
