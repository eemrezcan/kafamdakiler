---
baslik: API belgesi Microsoft OpenAPI, arayüz Scalar
tur: karar
soru: API belgesi nasıl üretilir ve hangi arayüzle test edilir?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-26, kullanıcı. OpenAPI belgesini .NET'in kendi aracı üretir (`AddOpenApi` + `MapOpenApi`, `/openapi/v1.json`). Test arayüzü yalnız Scalar'dır (`MapScalarApiReference`, `/scalar`); Swagger UI eklenmez. Belge ve arayüz yalnız Development ortamında açıktır. Bearer token girişi için belgeye bir document transformer ile güvenlik şeması eklenir.

## Gerekçe
Belgeyi framework'ün kendi aracı üretir; .NET 9'dan beri şablonun yolu budur. Kullanıcı Scalar'ı kendi projelerinde kullanıyor ve daha pratik buluyor. Scalar aynı OpenAPI belgesini okur; uçlar tarayıcıdan denenebilir, yani T05'in işlevi karşılanır.

## Reddedilenler
- Microsoft belgesi + Swashbuckle Swagger UI (Claude'un önerisi): T05'i adıyla karşılar ama kullanıcı Scalar'ı tercih etti.
- Tam Swashbuckle: şablonun hazır belge üreticisini söküp yerine eskisini koymak demek.
- Scalar + Swagger UI birlikte: T05 riskini sıfırlar, ama kullanıcı tek arayüz istedi.

## Yeniden açma koşulu
Hoca T05 için Swagger UI'ı adıyla isterse: `UseSwaggerUI` aynı `/openapi/v1.json` dosyasına bağlanarak birkaç satırla eklenir.

Kaybolan: T05 metnindeki "Swagger" kelimesiyle birebir eşleşme; gösterimde Scalar'ın aynı OpenAPI belgesini okuduğu söylenir.
