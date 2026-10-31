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
- `backend/Program.cs` içindeki `/api/hesap` grubu (`MapIdentityApi` ve `/register`'ı kapatan endpoint filter): Claude'un açtığı Sonnet işçisi yazdı (2026-10-30, kullanıcının "sen yaz, ben inceleyeyim" isteğiyle); kullanıcı inceledi.
- `backend/Pages/Hesap/Giris.cshtml.cs`: `InputModel` (form alanları ve doğrulama kuralları) Claude'un açtığı Sonnet işçisi, `OnPostAsync` (SignInManager ile giriş, güvenli yönlendirme) ve görünümü `Giris.cshtml` Claude yazdı; `backend/Pages/Hesap/Cikis.cshtml(.cs)` (POST ile çıkış) Claude yazdı (2026-10-30, kullanıcının "sen yaz, ben inceleyeyim" isteğiyle).
- Web teması (K-0021, K-0022): `backend/wwwroot/css/site.css`, `backend/wwwroot/js/theme/color-mode.js`, `backend/wwwroot/js/theme/synapse.js`, `backend/wwwroot/js/theme/ui.js`, `backend/wwwroot/img/logo.svg`, `backend/wwwroot/img/icons.svg`, `backend/wwwroot/fonts/README.md` (yazı tipi dosyaları OFL lisanslı, Fontsource'tan), `backend/Pages/Shared/_Layout.cshtml` ve `_Layout.cshtml.css`: Claude yazdı (2026-10-30).
- `backend/Program.cs` içindeki Sahip policy'si, Razor Pages klasör kuralları ve cookie yolları (A04 adım 3): Claude'un açtığı Sonnet işçisi yazdı, policy'nin cookie şeması ve cookie ayarının sırası Claude düzeltti (2026-10-31, kullanıcının "sen yaz, ben inceleyeyim" isteğiyle); kullanıcı inceledi.
- `backend/Pages/Hesap/Erisim.cshtml` (erişim reddedildi sayfası, A04 adım 4): Claude yazdı (2026-10-31, kullanıcının "sen yaz, ben inceleyeyim" isteğiyle); kullanıcı inceledi.
- Alışkanlıklar, 1. ve 2. tur (web işçisi): `backend/Aliskanliklar/` (entity'ler, enum'lar, `AliskanlikHesap`, `OgeHesap`, `AliskanlikIslemleri`, `Gorunum`, DTO'lar, uçlar, `AliskanlikPolicies`, `aliskanliklar.http`), `backend/Dosyalar/`, `backend/Data/BenEndpoints.cs`, `backend/Data/AppDbContext.cs` ayarları, migration'lar `AddHabits` ve `DecimalQuantities`, `backend/OpenApi/HataAnahtarlari.cs`, `Program.cs` içindeki alışkanlık ve dosya policy'leri, JSON enum ayarı, `AddValidation()`, ProblemDetails, kültür ayarı, cookie yönlendirme olayları ve uç eşlemeleri, `backend/Pages/Index.cshtml(.cs)` yönlendirmesi, `backend/Pages/Aliskanliklar/` (Index, _Kart, Duzenle, Detay, Raf, Oge, OgeDuzenle), `_Layout.cshtml` menü satırları, `site.css` sonundaki "Alışkanlıklar" bölümü, `backend/wwwroot/js/aliskanliklar.js`, `backend/wwwroot/img/icons.svg` içindeki `lucide-*` sembolleri ve `LICENSE-lucide.txt`, `backend/wwwroot/lib/chart.js/`, `backend.Tests/AliskanlikHesapTests.cs` ve `OgeHesapTests.cs`, `README.md` tamamlaması: Claude'un açtığı Sonnet işçisi yazdı (2026-10-31, K-0001 eki).
- Mobil uygulama, 1. ve 2. tur (mobil işçisi): `mobile/` klasörünün tamamı (`flutter create` iskeleti üzerine `lib/`, `test/`, `mobile/README.md`): Claude'un açtığı Sonnet işçisi yazdı (2026-10-31, K-0001 eki); ana oturum denetledi; kullanıcı inceleyecek. Alışkanlık ekranlarındaki küçük UX düzeltmeleri (yer tutucu metinler, menüden "Ana sayfa"nın çıkması, `slate` rengi) Claude yazdı.
- Planlanan: `mobile/packages/mobilite/`, `mcp/`.

## Ders kaynakları
Hocaların slaytları, kaynak kodları ve notları (repo dışında, yalnız okunur). Bunlar referanstır; birebir izlenmez (K-0006).

- BLM4581 proje kuralları (puanlanan şartlar, takvim): `/home/eemrezcan/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4581) Ağ Tabanlı Teknolojiler Ve Uygulamaları/Proje kuralları.pdf`; özeti `gereksinimler.md` içinde

- BLM4581 Ağ Tabanlı Teknolojiler ve Uygulamaları: `/home/eemrezcan/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4581) Ağ Tabanlı Teknolojiler Ve Uygulamaları/`
  - `Slaytlar/`: Hafta01 ASP.NET Core Razor Pages giriş, Hafta02 doğrulama ve model geçişi, Hafta03 EF Core ve veritabanı (PDF)
  - `Kaynak Kodlar/`: haftalık örnek projeler (`Hafta02_BLM4581Web`, `Hafta03_BLM4581Web`; .NET 10, EF Core, SQL Server LocalDB)
- BLM4587 proje kuralları: `/home/eemrezcan/İndirilenler/Proje kuralları (Flutter).pdf` (2026-10-31; ders klasörüne taşınabilir); özeti `gereksinimler.md` içinde
- BLM4587 iOS ile Mobil Uygulama Geliştirme I (Flutter/Dart): `/home/eemrezcan/Belgeler/Okul/Dersler/2026-2027 Güz Dönemi/(BLM4587) IOS İle Mobil Uygulama Geliştirme I/Ders Notları/FlutterVeDart_v2.pdf` (143 sayfa)

Yeni hafta eklendikçe bu klasörlere bakılır.

## Bağlantılar
- Kararlar: `docs/kararlar/`
