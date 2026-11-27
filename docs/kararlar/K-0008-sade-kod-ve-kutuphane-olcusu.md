---
kimlik: K-0008
baslik: "Sade kod ve kütüphane ölçüsü"
tur: karar
soru: "Hangi kütüphane ve katman eklenir, hangisi eklenmez?"
sonuc: kabul
kavramlar: [sade-kod, kütüphane-ölçüsü, kalıp-kütüphaneleri, junior-seviye, güvenlik]
tags: [karar]
---

# K-0008 - Sade kod ve kütüphane ölçüsü

## m01 - Güvenli işi yapan olgun kütüphane varsa en basit hâliyle kullanılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [olgun-kütüphane]
karar-veren: kullanici
```
2026-10-16, kullanıcı. K-0006'yı tamamlar. İşi bizim yerimize güvenli şekilde yapan olgun bir kütüphane varsa kullanılır ve en basit hâliyle kurulur (ör. ASP.NET Core Identity, FluentValidation, Swashbuckle).

## m02 - Kalıp kütüphaneleri ve ek katmanlar somut ihtiyaç doğmadan eklenmez
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [mediatr, automapper, repository]
karar-veren: kullanici
```
Kodun akışını dolaştıran kalıp kütüphaneleri (ör. MediatR, AutoMapper) ve ek katmanlar (repository, servis arayüzleri) somut bir ihtiyaç doğmadan eklenmez.

## m03 - Yapı junior seviyede okunup açıklanabilir kalır
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
karar-veren: kullanici
```
Yapı, junior seviyede okunup açıklanabilir kalır.

## m04 - Güvenlikten ve istenen özelliklerden ödün verilmez
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [dto, doğrulama, yetki]
karar-veren: kullanici
```
Güvenlikten ve istenen özelliklerden ödün verilmez: entity dışarı verilmez (DTO), girdi doğrulanır, giriş ve yetki kütüphaneyle yapılır.

## g01 - Kullanıcı junior seviyede ve her satırı açıklayabilmeli
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
```
Kullanıcı junior seviyede ve her satırı açıklayabilmeli (S07). Kütüphane kullanmayı öğrenmek de amaçlardan biri.

## g02 - DbContext zaten repository ve unit of work işini görür
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: cikarim
kavramlar: [ef-core]
```
EF Core'un `DbContext`'i zaten repository ve unit of work işini görür; üstüne kat eklemek kodu büyütür ama yeni bir şey kazandırmaz.

## g03 - Kalıp kütüphaneleri akışı gizler, ikisi ticari lisansa geçti
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: kaynak
```
Kalıp kütüphaneleri hata ayıklarken akışı gizler; MediatR ve AutoMapper 2025'te ticari lisansa geçti.

## r01 - Her şeyi elle yazmak
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
K-0006 ile çelişir, güvenlik riski.

## r02 - Kurumsal katmanlı mimari (Controller, Service, Repository, MediatR, AutoMapper)
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "Aynı kural ya da çapraz iş (log, yetki, işlem) birçok uçta tekrar ederse MediatR gibi bir kalıp yeniden konuşulur."
karar-veren: kullanici
```
Tek kişilik projede tören.

## r03 - AutoMapper ve Mapster
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Entity'den DTO'ya kopyalama birkaç satır, elle yazılınca görünür kalır.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-16
dayanak: bilinmiyor
```
Belgede yazılmamış.
