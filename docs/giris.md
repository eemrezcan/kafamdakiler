# Kafamdakiler: giriş

Kurulum tarihi: 2026-10-15. Bu dosya kısa tutulur; ayrıntı ilgili belgeye bağlanır.

## Amaç
Kişisel takip uygulaması: spor, görev ve sözler, hatırlatıcılar, alışkanlıklar (kitap), kilo, notlar; ileride mobilite, beslenme, ekran süresi ve finans. Tek kullanıcılı, kullanıcının kendisi için. Aynı zamanda BLM4581 (ASP.NET Core Razor Pages + EF Core) ve BLM4587 (Flutter) derslerinin bireysel projesi.

## Kapsam
- Dahil: `gereksinimler.md` içindeki üç faz (K-0004)
- Hariç: RPE, süperset, plaka hesaplayıcı, banka entegrasyonu, iOS, Play Store

## Nasıl çalıştırılır
Kurulum ve çalıştırma komutları, beklenen sonuçla birlikte.

```sh
# komutlar buraya
```

## Yapı
Önemli klasörler ve ne işe yaradıkları.

- `docs/`: bu belgeler
- `docs/kararlar/`: kararlar
- `backend/`: ASP.NET Core (Razor Pages + `/api`), henüz yok
- `mobile/`: Flutter uygulaması, henüz yok
- `backend.Tests/`: xUnit testleri (K-0016), henüz yok
- `compose.yaml`: geliştirmede Postgres (K-0012, K-0020), henüz yok
- `deploy/`: sunucuya özgü dosyalar (Caddy vb.), henüz yok

## Yapay zekânın yazdığı kısımlar
Proje kuralları yapay zekâ kullanımına izin veriyor; bu kısımlar açıkça burada listelenir, geri kalan kodu öğrenci yazmıştır.

- `README.md`: Claude yazdı (2026-10-29, kullanıcının isteğiyle); içeriği A01'de kullanıcının koştuğu komutlardır.
- Planlanan: `mobile/packages/mobilite/`, `mcp/`.

## Ders kaynakları
Hocaların slaytları, kaynak kodları ve notları (repo dışında, yalnız okunur). Bunlar referanstır; birebir izlenmez (K-0006).

- BLM4581 proje kuralları (puanlanan şartlar, takvim): `/home/eemrezcan/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4581) Ağ Tabanlı Teknolojiler Ve Uygulamaları/Proje kuralları.pdf`; özeti `gereksinimler.md` içinde

- BLM4581 Ağ Tabanlı Teknolojiler ve Uygulamaları: `/home/eemrezcan/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4581) Ağ Tabanlı Teknolojiler Ve Uygulamaları/`
  - `Slaytlar/`: Hafta01 ASP.NET Core Razor Pages giriş, Hafta02 doğrulama ve model geçişi, Hafta03 EF Core ve veritabanı (PDF)
  - `Kaynak Kodlar/`: haftalık örnek projeler (`Hafta02_BLM4581Web`, `Hafta03_BLM4581Web`; .NET 10, EF Core, SQL Server LocalDB)
- BLM4587 iOS ile Mobil Uygulama Geliştirme I (Flutter/Dart): `/home/eemrezcan/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4587) IOS İle Mobil Uygulama Geliştirme I/Ders Notları/FlutterVeDart_v2.pdf` (143 sayfa)

Yeni hafta eklendikçe bu klasörlere bakılır.

## Bağlantılar
- Kararlar: `docs/kararlar/`
