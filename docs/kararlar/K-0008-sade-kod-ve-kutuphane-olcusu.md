---
baslik: Sade kod ve kütüphane ölçüsü
tur: karar
soru: Hangi kütüphane ve katman eklenir, hangisi eklenmez?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-16, kullanıcı. K-0006'yı tamamlar. İşi bizim yerimize güvenli şekilde yapan olgun bir kütüphane varsa kullanılır ve en basit hâliyle kurulur (ör. ASP.NET Core Identity, FluentValidation, Swashbuckle). Kodun akışını dolaştıran kalıp kütüphaneleri (ör. MediatR, AutoMapper) ve ek katmanlar (repository, servis arayüzleri) somut bir ihtiyaç doğmadan eklenmez. Yapı, junior seviyede okunup açıklanabilir kalır. Güvenlikten ve istenen özelliklerden ödün verilmez: entity dışarı verilmez (DTO), girdi doğrulanır, giriş ve yetki kütüphaneyle yapılır.

## Gerekçe
Kullanıcı junior seviyede ve her satırı açıklayabilmeli (S07). Kütüphane kullanmayı öğrenmek de amaçlardan biri. EF Core'un `DbContext`'i zaten repository ve unit of work işini görür; üstüne kat eklemek kodu büyütür ama yeni bir şey kazandırmaz. Kalıp kütüphaneleri hata ayıklarken akışı gizler; MediatR ve AutoMapper 2025'te ticari lisansa geçti.

## Reddedilenler
- Her şeyi elle yazmak: K-0006 ile çelişir, güvenlik riski.
- Kurumsal katmanlı mimari (Controller, Service, Repository, MediatR, AutoMapper): tek kişilik projede tören.
- AutoMapper ve Mapster: entity'den DTO'ya kopyalama birkaç satır, elle yazılınca görünür kalır.

## Yeniden açma koşulu
Aynı kural ya da çapraz iş (log, yetki, işlem) birçok uçta tekrar ederse MediatR gibi bir kalıp yeniden konuşulur.
