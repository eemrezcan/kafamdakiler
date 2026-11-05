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
- `ornek-beyin/`: uydurma notlardan örnek ikinci beyin; geliştirme, test ve gösterim için (K-0023). Repodaki kopya şablondur, API Git dışı `.ornek-beyin-calisma/` kopyasında çalışır

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
- Web denemesi düzeltmeleri (2026-11-02, kullanıcının "Sonnet'e vermeden sen yap" isteğiyle, K-0022 eki): `site.css` (tek yazı tipi Inter, renkli alışkanlık kartı, açılır liste renkleri, ısı haritası durumları, ilerleme formu genişliği), `_Layout.cshtml` font önyüklemesi, `fonts/README.md`; `backend/Aliskanliklar/Gorunum.cs` içindeki `GunDurumu` ("none" durumu), `backend/Pages/Aliskanliklar/Detay.cshtml(.cs)` (grafiklerin başlangıcı, renkleri ve kare açıklama), `OgeDuzenle.cshtml` (etiketler, puanın yalnız "Bitti"de görünmesi), `Oge.cshtml` (oturum notu kaldırıldı), `_Kart.cshtml` (yer tutucu), `backend/wwwroot/js/aliskanliklar.js` (grafik rengi alışkanlıktan): Claude yazdı.
- Arayüz iyileştirmeleri, 1. paket (2026-11-02, kullanıcının isteğiyle): ana sayfadaki "Bugün" özeti (`Index.cshtml`, `IndexModel.BugunTamam`), kaydedince çıkan "Kaydedildi" bildirimi (`_Layout.cshtml` içindeki `kd-toast`, sayfa modellerindeki `[TempData] Bildirim` satırları: `Index`, `Oge`, `Duzenle`, `OgeDuzenle`), genç alışkanlıkta kısa ısı haritası (`Detay.cshtml.cs` içindeki `HaritaBasligi` ve harita başlangıcı), "Güç" açıklaması (`Detay.cshtml`, `_Kart.cshtml`) ve bunların `site.css` sınıfları: Claude yazdı.
- Arayüz iyileştirmeleri, 2. paket (2026-11-02, kullanıcının isteğiyle): sayaç kartında elle yazılan miktarın alan içindeki ✓ düğmesi (`_Kart.cshtml`, `kd-stepper-save`), oturum satırlarında kalem ikonlu düzenleme (`Oge.cshtml`, `kd-session*` sınıfları): Claude yazdı.
- Arayüz iyileştirmeleri, 3. paket (2026-11-02, kullanıcının isteğiyle): raf kartında birden çok devam eden öğe için kapak sekmeleri (`_Kart.cshtml`, yeni `_Kapak.cshtml` ve `_DevamEden.cshtml` partial'ları, `site.css` içindeki `kd-shelf-pick*` sınıfları), `AliskanlikEndpoints.DtoYapAsync` içinde devam edenlerin "en son okunan önce" sıralaması: Claude yazdı.
- Mobil uyarlama (2026-11-02, kullanıcının isteğiyle, K-0022 eki): `mobile/lib/config/app_theme.dart` (tek yazı tipi Inter; `KdYazi.sayi` ve `KdYazi.baslik`), `mobile/lib/ui/core/renkler.dart` (web'deki açık ve koyu palet, kart zemini ve çerçevesi, tamam rengi), `bugun_screen.dart` içindeki Bugün özeti, `aliskanlik_karti.dart` içindeki renkli kart ve `_DevamEdenSecici` (birden çok kitapta kapak seçimi), `aliskanlik_detay_screen.dart` içindeki Güç açıklaması ve renkli gün ızgarası, `oge_form_screen.dart` etiketleri ve puanın yalnız "Bitti"de görünmesi, `aliskanlik_liste_screen.dart` renkli kartı, `test/ui/bugun_screen_test.dart` içindeki iki test değişikliği: Claude yazdı.
- Mobil görünümün web'e eşlenmesi (2026-11-02, kullanıcının isteğiyle): `app_theme.dart` içindeki düğme, seçim, alan, çip, SnackBar ve sekme stilleri; `aliskanlik_karti.dart` içinde web düzenindeki kart başlığı (kalem, sıklık satırı), kare −/+ düğmeleri, tam genişlikte "Yaptım" düğmesi ve ilerleme çubuğu; Raf sekmesinin alt menüden kalkması ve rafın `/aliskanlik/:id/raf` sayfası olması (`router.dart`, `ana_iskele.dart`, `raf_screen.dart`, `raf_view_model.dart`); Bugün'deki tarih satırı; detaydaki çerçeveli istatistik kutuları; kitap detayındaki renkli durum etiketi, tek satırlık oturum satırları ve bitmiş kitapta gizlenen "Okumaya başla"; kronometredeki "Vazgeç" (`kronometre_gosterge.dart`, `oturum_screen.dart`, `sayac_kronometre_screen.dart`); `lib/utils/metin.dart` (`trBuyuk`); `test/routing/yetki_test.dart` ve `test/ui/bugun_screen_test.dart` güncellemeleri: Claude yazdı.
- Mobil kartlarda son 7 gün şeridi (2026-11-02, kullanıcının isteğiyle): `bugun_view_model.dart` içindeki `sonGunler` ve `_gunleriYukle`, `aliskanlik_karti.dart` içindeki `_GunSeridi` ve `_NoktaCiz`, `test/test_destek.dart` içindeki `gunleriGetir` sahtesi ve `bugun_screen_test.dart` içindeki şerit testi: Claude yazdı.
- Örnek beyin (2026-11-03, kullanıcının isteğiyle, K-0023 eki): `ornek-beyin/` klasörünün tamamı (uydurma içerik: üç proje, görevler, devir kartları, günlük, notlar, iki gün planı, iki gelen kartı, etiket sözlüğü; gizli ve finans notu kural denemesi için): Claude, beynin kendi komutlarıyla (`beyin.py`) üretti.
- Yakala (2026-11-04, kullanıcının "kodu sen yaz, en son bana anlat" isteğiyle, K-0001): Claude'un açtığı Sonnet işçileri yazdı, ana oturum her fazı denetledi; kullanıcıya anlatılacak.
  - Backend: `backend/Yakalamalar/` (`Yakalama`, `Dtos`, `YakalamaPolicies`, `YakalamaIslemleri`, `YakalamaEndpoints`, `YakalamaGorunum`, `yakalamalar.http`), migration `YakalamaEkle`, `AppDbContext` ayarı, `Program.cs` içindeki yakalama ve dosya policy'leri (`IzinPolicy` izin listesi alıyor), `DosyaEndpoints` yükleme izni, `backend.Tests/YakalamaDogrulamaTests.cs`.
  - Web: `backend/Pages/Yakalamalar/` (Index, Duzenle), `_Layout.cshtml` menü satırları.
  - Mobil: `lib/data/models/yakalama.dart`, `yakalama_repository.dart`, `fotograf_deposu.dart`, `lib/ui/yakalama/`, `esitleyici.dart` ve `bekleyen_uygula.dart` içindeki yakalama kuyruğu, `api_service.dart` uçları, `app_database.dart` şema 3, `router.dart` ve `ana_iskele.dart` (Yakalamalar sekmesi, Yakala düğmesi), `main.dart`, `profil_view_model.dart`, `pubspec.yaml` (`path_provider`), yeni testler (`yakalama_kuyruk_test`, `veritabani_yukseltme_test`, `yakalama_screen_test`) ve `test_destek.dart`, `yetki_test.dart` güncellemeleri.
  - Arayüz düzenlemesi (Claude, kullanıcının "UI/UX'i sen değerlendir, gereken yerde sen değiştir" isteğiyle): web listesinin üstündeki hızlı yakalama kutusu, güne göre gruplama, sayılı süzgeçler, hedef gösterimi (`Pages/Yakalamalar/Index.cshtml(.cs)`, `YakalamaGorunum` gün ve saat yardımcıları, `wwwroot/js/yakalamalar.js`, `site.css` sonundaki "Captures" bölümü, `icons.svg` içindeki `lucide-folder` ve `lucide-x`); mobil listede güne göre gruplama, kaydırarak silme ve yalnız gerekli durum işaretleri (`yakalama_liste_screen.dart`), Yakala ekranında boşken pasif Kaydet ve sınıra yaklaşınca görünen sayaç (`yakala_screen.dart`), Bugün, Alışkanlıklar ve Profil listelerinin altında Yakala düğmesi için boşluk, `yakalama_screen_test.dart` güncellemeleri.
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
