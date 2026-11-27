---
kimlik: K-0007
baslik: "Backend tek proje"
tur: karar
soru: "Web arayüzü (Razor Pages) ve Web API ayrı projeler mi olur, tek proje mi?"
sonuc: kabul
kavramlar: [backend, tek-proje, razor-pages, minimal-api, dbcontext]
tags: [karar]
---

# K-0007 - Backend tek proje

## m01 - Backend tek ASP.NET Core projesidir
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
karar-veren: kullanici
```
2026-10-16, kullanıcı. Backend tek ASP.NET Core projesidir: Razor Pages (web arayüzü, yönetici paneli) ve `/api` uçları (Minimal API; mobil ve Swagger için) aynı projede, tek `DbContext` ile çalışır.

## m02 - Testler ayrı backend.Tests projesinde durur
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [test]
karar-veren: kullanici
```
Testler ayrı `backend.Tests/` projesindedir.

## g01 - Tek kişi, tek kullanıcı, tek deploy
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [deploy]
```
Tek kişi geliştiriyor ve uygulama tek kullanıcılı. Tek proje, tek deploy demek ve dersin yapısına yakın.

## g02 - Identity tek yerde kurulur
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: cikarim
kavramlar: [identity]
```
Identity tek yerde kurulur; web'e cookie, mobile token aynı uygulamadan verilir.

## g03 - Küçük uygulamalarda yaygın başlangıç budur
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: kaynak
```
Küçük uygulamalarda sektördeki yaygın başlangıç da budur (modüler monolit). Kod, özellik başına klasörlerle düzenli tutulur.

## r01 - Ayrı Web, Api ve Data projeleri
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "API'yi web arayüzünden bağımsız ölçeklemek ya da ayrı bir ekibin geliştirmesi gerekirse."
karar-veren: kullanici
```
Üç proje, iki deploy, giriş iki yerde kurulur; tek kişiye fazla tören, junior seviyede takibi zor.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-16
dayanak: bilinmiyor
```
Belgede yazılmamış.
