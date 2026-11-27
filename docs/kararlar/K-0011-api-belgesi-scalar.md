---
kimlik: K-0011
baslik: "API belgesi Microsoft OpenAPI, arayüz Scalar"
tur: karar
soru: "API belgesi nasıl üretilir ve hangi arayüzle test edilir?"
sonuc: kabul
kavramlar: [openapi, scalar, api-belgesi, swagger, development-ortamı]
tags: [karar]
---

# K-0011 - API belgesi Microsoft OpenAPI, arayüz Scalar

## m01 - OpenAPI belgesini .NET'in kendi aracı üretir
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [addopenapi]
karar-veren: kullanici
```
2026-10-26, kullanıcı. OpenAPI belgesini .NET'in kendi aracı üretir (`AddOpenApi` + `MapOpenApi`, `/openapi/v1.json`).

## m02 - Test arayüzü yalnız Scalar'dır, Swagger UI eklenmez
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [swashbuckle]
karar-veren: kullanici
```
Test arayüzü yalnız Scalar'dır (`MapScalarApiReference`, `/scalar`); Swagger UI eklenmez.

## m03 - Belge ve arayüz yalnız Development ortamında açıktır
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
karar-veren: kullanici
```
Belge ve arayüz yalnız Development ortamında açıktır.

## m04 - Bearer token girişi için belgeye document transformer ile güvenlik şeması eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
kavramlar: [bearer-token, document-transformer]
karar-veren: kullanici
```
Bearer token girişi için belgeye bir document transformer ile güvenlik şeması eklenir.

## m05 - ApiBelgesi:Acik true ise belge ve Scalar sunucuda da açılır
```yaml
tur: m
durum: guncel
tarih: 2026-11-25
dayanak: kullanici
kavramlar: [sunucu, deploy, tailnet]
karar-veren: kullanici
```
Ek (2026-11-25): Sunucuda da açılabilir: `ApiBelgesi:Acik` true ise (compose'da `API_BELGESI_ACIK=true`) belge ve Scalar Development dışında da açılır. Neden: gösterimde telefon, web ve Scalar aynı sunucu verisini göstersin. Sunucuya yalnız tailnet içinden ulaşılır; uçlar yine token ve policy ister.

## g01 - .NET 9'dan beri şablonun yolu framework'ün kendi belge aracıdır
```yaml
tur: g
durum: guncel
tarih: 2026-10-26
dayanak: kaynak
```
Belgeyi framework'ün kendi aracı üretir; .NET 9'dan beri şablonun yolu budur.

## g02 - Kullanıcı Scalar'ı kendi projelerinde kullanıyor ve daha pratik buluyor
```yaml
tur: g
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
```
Kullanıcı Scalar'ı kendi projelerinde kullanıyor ve daha pratik buluyor.

## g03 - Scalar uçların tarayıcıdan denenmesini sağlar, T05 karşılanır
```yaml
tur: g
durum: guncel
tarih: 2026-10-26
dayanak: kaynak
```
Scalar aynı OpenAPI belgesini okur; uçlar tarayıcıdan denenebilir, yani T05'in işlevi karşılanır.

## r01 - Microsoft belgesi + Swashbuckle Swagger UI (ilk öneri)
```yaml
tur: r
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
yeniden-ac: "Hoca T05 için Swagger UI'ı adıyla isterse: `UseSwaggerUI` aynı `/openapi/v1.json` dosyasına bağlanarak birkaç satırla eklenir."
karar-veren: kullanici
```
T05'i adıyla karşılar ama kullanıcı Scalar'ı tercih etti.

## r02 - Tam Swashbuckle
```yaml
tur: r
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Şablonun hazır belge üreticisini söküp yerine eskisini koymak demek.

## r03 - Scalar + Swagger UI birlikte
```yaml
tur: r
durum: guncel
tarih: 2026-10-26
dayanak: kullanici
yeniden-ac: "Hoca T05 için Swagger UI'ı adıyla isterse: `UseSwaggerUI` aynı `/openapi/v1.json` dosyasına bağlanarak birkaç satırla eklenir."
karar-veren: kullanici
```
T05 riskini sıfırlar, ama kullanıcı tek arayüz istedi.

## b01 - T05 metnindeki "Swagger" kelimesiyle birebir eşleşme kaybolur
```yaml
tur: b
durum: guncel
tarih: 2026-10-26
dayanak: cikarim
```
Kaybolan: T05 metnindeki "Swagger" kelimesiyle birebir eşleşme; gösterimde Scalar'ın aynı OpenAPI belgesini okuduğu söylenir.
