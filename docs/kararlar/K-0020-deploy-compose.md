---
kimlik: K-0020
baslik: "Deploy tek VPS üzerinde Docker Compose"
tur: karar
soru: "Uygulama nereye ve nasıl kurulur?"
sonuc: kabul
kavramlar: [deploy, docker-compose, vps, tailscale, yedek, sunucu, postgresql, caddy]
tags: [karar]
---

# K-0020 - Deploy tek VPS üzerinde Docker Compose

## m01 - Tek bir VPS üzerinde Docker Compose kullanılır: uygulama, Postgres ve Caddy
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
karar-veren: kullanici
```
2026-10-15 öneri, 2026-10-29 kayıt, kullanıcı. Tek bir VPS üzerinde Docker Compose: uygulama, Postgres ve otomatik HTTPS için Caddy.

## m02 - Her gece veritabanı ve dosya klasörü sunucu dışına yedeklenir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [pg_dump]
karar-veren: kullanici
```
Her gece `pg_dump` ile veritabanı ve dosya klasörü (K-0015) sunucu dışına yedeklenir.

## m03 - Önce elle docker compose up ile kurulur, oturunca GitHub Actions eklenir
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [github-actions]
karar-veren: kullanici
```
Önce elle `docker compose up --build` ile kurulur; oturunca GitHub Actions eklenir.

## m04 - APK telefona doğrudan kurulur, Play Store yok
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [apk, play-store]
karar-veren: kullanici
```
APK telefona doğrudan kurulur, Play Store yok.

## m05 - Sunucu ve alan adı alınana kadar yerelde çalışılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
kavramlar: [alan-adı]
karar-veren: kullanici
```
Sunucu ve alan adı henüz yok; o zamana kadar yerelde çalışılır, geliştirmede yalnız Postgres Compose ile çalışır.

## m06 - Sağlayıcı Google Cloud Compute Engine'dir, ücreti kredi karşılar
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [google-cloud, kredi]
karar-veren: kullanici
```
Ek (2026-11-03): Sağlayıcı Google Cloud Compute Engine (kullanıcı kararı). Ücreti kullanıcının Google Developer Program Premium üyeliğindeki aylık $10 GenAI ve Cloud kredisi ile ücretsiz katman karşılar; kredinin kapsamı ve süresi konsolda (Faturalandırma → Krediler) doğrulanacak.

## m07 - Önce e2-micro denenir, yetmezse e2-small'a geçilir
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [google-cloud, e2-micro]
karar-veren: kullanici
```
Ek (2026-11-03): Önce ücretsiz katmandaki e2-micro (yalnız ABD bölgeleri, 1 GB bellek) denenir; uygulama, Postgres ve Python'a yetmezse e2-small'a geçilir. Kurulum aynı kalır: tek makine, Docker Compose, Caddy, Postgres.

## m08 - Gecelik yedekler Cloud Storage'a gider
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [cloud-storage]
karar-veren: kullanici
```
Ek (2026-11-03): Gecelik yedekler Cloud Storage'a gider.

## m09 - Sesi yazıya çevirmede Google Speech-to-Text aday, kullanıcının sesiyle denenip seçilir
```yaml
tur: m
durum: guncel
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [ses, speech-to-text]
karar-veren: kullanici
```
Ek (2026-11-03): Sesi yazıya çevirmede Google Speech-to-Text (Chirp 3, `tr-TR`) aday; OpenAI gpt-4o-transcribe ile kullanıcının kendi sesiyle denenip seçilir.

## m10 - İlk iş 10 dolarlık bütçe uyarısıdır, veri ABD bölgesinde durur
```yaml
tur: m
durum: yerini-aldi
tarih: 2026-11-03
dayanak: kullanici
kavramlar: [bütçe-uyarısı, google-cloud]
karar-veren: kullanici
```
Ek (2026-11-03): İlk iş $10'luk bütçe uyarısı. Kredi aboneliğe bağlıdır; abonelik biterse ücret karta geçer. Veri ABD bölgesinde durur.

## u01 - Kurulum zamanı ve alan adı belirlenmedi
```yaml
tur: u
durum: guncel
tarih: 2026-11-03
```
Ek (2026-11-03): Kurulum zamanı ve alan adı ayrıca kararlaştırılacak.

## r01 - Cloud Run + Cloud SQL
```yaml
tur: r
durum: guncel
tarih: 2026-11-03
dayanak: kullanici
yeniden-ac: "Sunucu alınırken seçilen sağlayıcı Compose çalıştıramıyorsa."
karar-veren: kullanici
```
Ek (2026-11-03): Alınmayan: Cloud Run + Cloud SQL. Konteynerin diski kalıcı değil (beynin klonu ve yüklenen dosyalar için kod değişir), Cloud SQL'in ücretsiz katmanı yok; yukarıdaki "bulut PaaS" reddiyle aynı gerekçe.

## m11 - Sağlayıcı kiralık VPS'tir: Hosting Dünyam TR-VPS4, Ubuntu 24.04
```yaml
tur: m
durum: guncel
tarih: 2026-11-06
dayanak: kullanici
kavramlar: [hosting-dünyam, ubuntu]
karar-veren: kullanici
```
Ek (2026-11-06, kayıt 2026-11-07): Sağlayıcı değişti: Google Cloud yerine kiralık VPS, Hosting Dünyam TR-VPS4, Ubuntu 24.04 (kullanıcı kararı; makine 2026-11-06'da alındı). 2026-11-03 ekindeki Google Cloud, e2-micro, $10 kredi ve bütçe uyarısı maddeleri geçersiz.

## m12 - Erişim yalnız Tailscale ile olur, HTTPS tailscale serve ile verilir
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [tailscale-serve, tailnet]
karar-veren: kullanici
```
Ek (2026-11-06, kayıt 2026-11-07): Kurulum aynı kalır: tek makine, Docker Compose, Postgres. Erişim yalnız Tailscale (Kat 2 karar 3, 2026-11-07): kapılar `127.0.0.1`'e bağlı, HTTPS `tailscale serve` ile (`*.ts.net` sertifikası); Caddy ve alan adı şimdilik yok. Yeniden açma: uygulamaya tailnet dışından erişim gerekirse.

## m13 - Gece yedeği restic ile şifreli olarak Backblaze B2'ye gider
```yaml
tur: m
durum: guncel
tarih: 2026-11-07
dayanak: kullanici
kavramlar: [restic, backblaze-b2]
karar-veren: kullanici
```
Ek (2026-11-06, kayıt 2026-11-07): Gece yedeği (Kat 2 karar 5, 2026-11-07): restic ile şifreli olarak Backblaze B2'ye (Cloud Storage yerine). Ses sağlayıcısı Kat 2 karar 8'de ayrıca seçilir.

## o01 - Makinenin bellek, disk ve takas boyutu ölçüldü
```yaml
tur: o
durum: guncel
tarih: 2026-11-07
dayanak: olcum
```
Ek (2026-11-06, kayıt 2026-11-07): Makine (2026-11-07): 3.8 GB bellek, 39 GB disk, Ubuntu 24.04.5, sağlayıcı imajında 2 GB `/swap.img` hazır.

## o02 - Çalışan servislerin yükü ölçüldü, 2 GB bellekli makine yoğun anda sıkışır
```yaml
tur: o
durum: guncel
tarih: 2026-11-06
dayanak: olcum
```
Ek (2026-11-06, kayıt 2026-11-07): Ölçülen yük (2026-11-06): API ~210 MB, Postgres ~65 MB, `beyin.py` ~30 MB; 2 GB bellekli makine yoğun anda sıkışır.

## g01 - Tek kullanıcılı uygulamaya tek sunucu yeter
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
Tek kullanıcılı uygulamaya tek sunucu yeter.

## g02 - Compose geliştirme ve sunucu kurulumunu aynı dosya biçiminde tutar
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: cikarim
```
Compose, geliştirmedeki Postgres ile sunucudaki kurulumu aynı dosya biçiminde tutar.

## g03 - Caddy sertifikayı kendisi alır ve yeniler
```yaml
tur: g
durum: guncel
tarih: 2026-10-29
dayanak: kaynak
```
Caddy, sertifikayı kendisi alır ve yeniler.

## r02 - Kubernetes, bulut PaaS
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "Sunucu alınırken seçilen sağlayıcı Compose çalıştıramıyorsa."
karar-veren: kullanici
```
Bu ölçekte gereksiz karmaşa ya da ücret.

## r03 - Nginx + elle certbot
```yaml
tur: r
durum: guncel
tarih: 2026-10-29
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
karar-veren: kullanici
```
Caddy aynı işi tek satırla yapar.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-29
dayanak: bilinmiyor
```
Belgede yazılmamış.
