---
baslik: Backend tek proje
tur: karar
soru: Web arayüzü (Razor Pages) ve Web API ayrı projeler mi olur, tek proje mi?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-16, kullanıcı. Backend tek ASP.NET Core projesidir: Razor Pages (web arayüzü, yönetici paneli) ve `/api` uçları (Minimal API; mobil ve Swagger için) aynı projede, tek `DbContext` ile çalışır. Testler ayrı `backend.Tests/` projesindedir.

## Gerekçe
Tek kişi geliştiriyor ve uygulama tek kullanıcılı. Tek proje, tek deploy demek ve dersin yapısına yakın. Identity tek yerde kurulur; web'e cookie, mobile token aynı uygulamadan verilir. Küçük uygulamalarda sektördeki yaygın başlangıç da budur (modüler monolit). Kod, özellik başına klasörlerle düzenli tutulur.

## Reddedilenler
- Ayrı Web, Api ve Data projeleri: üç proje, iki deploy, giriş iki yerde kurulur; tek kişiye fazla tören, junior seviyede takibi zor.

## Yeniden açma koşulu
API'yi web arayüzünden bağımsız ölçeklemek ya da ayrı bir ekibin geliştirmesi gerekirse.
