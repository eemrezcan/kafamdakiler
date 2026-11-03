---
baslik: Deploy tek VPS üzerinde Docker Compose
tur: karar
soru: Uygulama nereye ve nasıl kurulur?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-15 öneri, 2026-10-29 kayıt, kullanıcı. Tek bir VPS üzerinde Docker Compose: uygulama, Postgres ve otomatik HTTPS için Caddy. Her gece `pg_dump` ile veritabanı ve dosya klasörü (K-0015) sunucu dışına yedeklenir. Önce elle `docker compose up --build` ile kurulur; oturunca GitHub Actions eklenir. APK telefona doğrudan kurulur, Play Store yok. Sunucu ve alan adı henüz yok; o zamana kadar yerelde çalışılır, geliştirmede yalnız Postgres Compose ile çalışır.

## Ek (2026-11-03)
- Sağlayıcı Google Cloud Compute Engine (kullanıcı kararı). Ücreti kullanıcının Google Developer Program Premium üyeliğindeki aylık $10 GenAI ve Cloud kredisi ile ücretsiz katman karşılar; kredinin kapsamı ve süresi konsolda (Faturalandırma → Krediler) doğrulanacak.
- Önce ücretsiz katmandaki e2-micro (yalnız ABD bölgeleri, 1 GB bellek) denenir; uygulama, Postgres ve Python'a yetmezse e2-small'a geçilir. Kurulum aynı kalır: tek makine, Docker Compose, Caddy, Postgres.
- Gecelik yedekler Cloud Storage'a gider.
- Sesi yazıya çevirmede Google Speech-to-Text (Chirp 3, `tr-TR`) aday; OpenAI gpt-4o-transcribe ile kullanıcının kendi sesiyle denenip seçilir.
- İlk iş $10'luk bütçe uyarısı. Kredi aboneliğe bağlıdır; abonelik biterse ücret karta geçer. Veri ABD bölgesinde durur.
- Kurulum zamanı ve alan adı ayrıca kararlaştırılacak.
- Alınmayan: Cloud Run + Cloud SQL. Konteynerin diski kalıcı değil (beynin klonu ve yüklenen dosyalar için kod değişir), Cloud SQL'in ücretsiz katmanı yok; yukarıdaki "bulut PaaS" reddiyle aynı gerekçe.

## Gerekçe
Tek kullanıcılı uygulamaya tek sunucu yeter. Compose, geliştirmedeki Postgres ile sunucudaki kurulumu aynı dosya biçiminde tutar. Caddy, sertifikayı kendisi alır ve yeniler.

## Reddedilenler
- Kubernetes, bulut PaaS: bu ölçekte gereksiz karmaşa ya da ücret.
- Nginx + elle certbot: Caddy aynı işi tek satırla yapar.

## Yeniden açma koşulu
Sunucu alınırken seçilen sağlayıcı Compose çalıştıramıyorsa.
