---
kimlik: K-0016
baslik: "Testler xUnit ile, önce saf hesap kuralları"
tur: karar
soru: "Backend nasıl test edilir, Faz 1'de neyin testi yazılır?"
sonuc: kabul
kavramlar: [test, xunit, saf-hesap-kuralları, sınır-durumları, assert]
tags: [karar]
---

# K-0016 - Testler xUnit ile, önce saf hesap kuralları

## m01 - Testler backend.Tests projesinde xUnit ile yazılır ve dotnet test ile koşar
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
karar-veren: kullanici
```
2026-10-29, kullanıcı. Testler `backend.Tests` projesinde xUnit ile yazılır ve `dotnet test` ile koşar.

## m02 - Faz 1'de saf hesap kuralları test edilir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [faz-1]
karar-veren: kullanici
```
Faz 1'de saf hesap kuralları test edilir: 1RM, geçen haftanın seti, günlük sayfa, ayın son günü, alışkanlık gücü.

## m03 - Her kuralın sınır durumları Theory ve InlineData ile sınanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [theory]
karar-veren: kullanici
```
Her kural için sınır durumları da (30 çeken ay, artık yılın şubatı gibi) `[Theory]` + `[InlineData]` ile sınanır.

## m04 - Kontrol için xUnit'in kendi Assert'i kullanılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
karar-veren: kullanici
```
Kontrol için xUnit'in kendi `Assert`'i kullanılır.

## g01 - Saf fonksiyonlar veritabanı ve HTTP gerektirmeden hızlı koşar, hata sınırda çıkar
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
Saf fonksiyonların girdisi ve çıktısı bellidir; veritabanı ve HTTP gerektirmeden hızlı koşarlar. Hata en çok sınır durumlarında çıkar (Q11).

## g02 - xUnit yaygın ve hazır gelir, ek kontrol kütüphanesi gerekmez
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
xUnit, .NET şablonlarında yaygın ve hazır gelen seçenektir (K-0006). Ek kontrol kütüphanesine bugün ihtiyaç yoktur (K-0008).

## r01 - FluentAssertions
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
8. sürümden beri ticari lisans ister, `Assert` yeterlidir.

## r02 - NUnit, MSTest
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
İşlevleri denk; xUnit daha yaygın.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-29
dayanak: bilinmiyor
```
Belgede yazılmamış.

## Yeniden açma koşulu

API uçlarının (policy, 401/403) testi gerektiğinde `WebApplicationFactory` ve gerçek Postgres için Testcontainers eklenir; bu yeni bir karar olur.
