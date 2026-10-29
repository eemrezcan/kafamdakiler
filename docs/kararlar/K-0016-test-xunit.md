---
baslik: Testler xUnit ile, önce saf hesap kuralları
tur: karar
soru: Backend nasıl test edilir, Faz 1'de neyin testi yazılır?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-29, kullanıcı. Testler `backend.Tests` projesinde xUnit ile yazılır ve `dotnet test` ile koşar. Faz 1'de saf hesap kuralları test edilir: 1RM, geçen haftanın seti, günlük sayfa, ayın son günü, alışkanlık gücü. Her kural için sınır durumları da (30 çeken ay, artık yılın şubatı gibi) `[Theory]` + `[InlineData]` ile sınanır. Kontrol için xUnit'in kendi `Assert`'i kullanılır.

## Gerekçe
Saf fonksiyonların girdisi ve çıktısı bellidir; veritabanı ve HTTP gerektirmeden hızlı koşarlar. Hata en çok sınır durumlarında çıkar (Q11). xUnit, .NET şablonlarında yaygın ve hazır gelen seçenektir (K-0006). Ek kontrol kütüphanesine bugün ihtiyaç yoktur (K-0008).

## Reddedilenler
- FluentAssertions: 8. sürümden beri ticari lisans ister, `Assert` yeterlidir.
- NUnit, MSTest: işlevleri denk; xUnit daha yaygın.

## Yeniden açma koşulu
API uçlarının (policy, 401/403) testi gerektiğinde `WebApplicationFactory` ve gerçek Postgres için Testcontainers eklenir; bu yeni bir karar olur.
