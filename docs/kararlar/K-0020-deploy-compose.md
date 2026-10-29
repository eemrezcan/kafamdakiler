---
baslik: Deploy tek VPS üzerinde Docker Compose
tur: karar
soru: Uygulama nereye ve nasıl kurulur?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-15 öneri, 2026-10-29 kayıt, kullanıcı. Tek bir VPS üzerinde Docker Compose: uygulama, Postgres ve otomatik HTTPS için Caddy. Her gece `pg_dump` ile veritabanı ve dosya klasörü (K-0015) sunucu dışına yedeklenir. Önce elle `docker compose up --build` ile kurulur; oturunca GitHub Actions eklenir. APK telefona doğrudan kurulur, Play Store yok. Sunucu ve alan adı henüz yok; o zamana kadar yerelde çalışılır, geliştirmede yalnız Postgres Compose ile çalışır.

## Gerekçe
Tek kullanıcılı uygulamaya tek sunucu yeter. Compose, geliştirmedeki Postgres ile sunucudaki kurulumu aynı dosya biçiminde tutar. Caddy, sertifikayı kendisi alır ve yeniler.

## Reddedilenler
- Kubernetes, bulut PaaS: bu ölçekte gereksiz karmaşa ya da ücret.
- Nginx + elle certbot: Caddy aynı işi tek satırla yapar.

## Yeniden açma koşulu
Sunucu alınırken seçilen sağlayıcı Compose çalıştıramıyorsa.
