# Kafamdakiler: giriş

Kurulum tarihi: 2026-10-15. Bu dosya kısa tutulur; ayrıntı ilgili belgeye bağlanır.

## Amaç
Kişisel takip uygulaması: spor, görev ve sözler, hatırlatıcılar, alışkanlıklar (kitap), kilo, notlar; ileride mobilite, beslenme, ekran süresi ve finans. Tek kullanıcılı, kullanıcının kendisi için. Aynı zamanda BLM4581 (ASP.NET Core Razor Pages + EF Core) ve BLM4587 (Flutter) derslerinin bireysel projesi.

## Kapsam
- Dahil: `gereksinimler.md` içindeki üç faz (K-0004)
- Hariç: RPE, süperset, plaka hesaplayıcı, banka entegrasyonu, iOS, Play Store

## Nasıl çalıştırılır
Kurulum, veritabanı, migration ve çalıştırma adımları kök dizindeki `README.md` içindedir; mobil için `mobile/README.md`. Kısaca:

```sh
docker compose up -d                       # geliştirme Postgres'i
dotnet ef database update --project backend
dotnet run --project backend --launch-profile http   # web ve API: http://localhost:5051, API belgesi /scalar
cd mobile && flutter pub get && flutter run --dart-define=API_URL=http://localhost:5051
```

## Yapı
Önemli klasörler ve ne işe yaradıkları.

- `docs/`: bu belgeler
- `docs/kararlar/`: kararlar
- `backend/`: ASP.NET Core (Razor Pages + `/api`), tek proje (K-0007)
- `mobile/`: Flutter uygulaması (Android)
- `backend.Tests/`: xUnit testleri (K-0016)
- `compose.yaml`: geliştirmede Postgres (K-0012, K-0020)
- `deploy/`: sunucuya özgü dosyalar: Dockerfile, Compose, gece yedeği (K-0020)
- `ornek-beyin/`: uydurma notlardan örnek ikinci beyin; geliştirme ve testler için (K-0034). Repodaki kopya şablondur, API Git dışı `.ornek-beyin-calisma/` kopyasında çalışır

## Ders kaynakları
Hocaların slaytları, kaynak kodları ve notları (repo dışında, yalnız okunur). Bunlar referanstır; birebir izlenmez (K-0006).

- BLM4581 proje kuralları (puanlanan şartlar, takvim): `~/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4581) Ağ Tabanlı Teknolojiler Ve Uygulamaları/Proje kuralları.pdf`; özeti `gereksinimler.md` içinde

- BLM4581 Ağ Tabanlı Teknolojiler ve Uygulamaları: `~/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4581) Ağ Tabanlı Teknolojiler Ve Uygulamaları/`
  - `Slaytlar/`: Hafta01 ASP.NET Core Razor Pages giriş, Hafta02 doğrulama ve model geçişi, Hafta03 EF Core ve veritabanı (PDF)
  - `Kaynak Kodlar/`: haftalık örnek projeler (`Hafta02_BLM4581Web`, `Hafta03_BLM4581Web`; .NET 10, EF Core, SQL Server LocalDB)
- BLM4587 proje kuralları: `~/İndirilenler/Proje kuralları (Flutter).pdf` (2026-10-31; ders klasörüne taşınabilir); özeti `gereksinimler.md` içinde
- BLM4587 iOS ile Mobil Uygulama Geliştirme I (Flutter/Dart): `~/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4587) IOS İle Mobil Uygulama Geliştirme I/Ders Notları/FlutterVeDart_v2.pdf` (143 sayfa)

Yeni hafta eklendikçe bu klasörlere bakılır.

## Bağlantılar
- Kararlar: `docs/kararlar/`
