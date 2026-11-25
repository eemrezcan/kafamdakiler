# Kafamdakiler: gereksinimler

Teslim için karşılanması gereken maddeler. Her madde için kanıt (dosya yolu, commit, test ya da ekran görüntüsü) yazılmadan "karşılandı" denmez.

## BLM4581 proje kuralları (puanlanan şartlar)
Kaynak: `Proje kuralları.pdf` (yolu `giris.md` içinde), 2026-2027 Güz. Tarihler hocanın ilanıyla değişebilir.

### Takvim
| Ne | Tarih |
| --- | --- |
| Plan belgesi teslimi (Word şablonu, çıktı, imzayla, ders saatinde) | 2026-10-21 Çarşamba |
| 9 haftalık planın başlangıcı | 2026-10-21 |
| İlk haftalık video son yükleme | 2026-10-25 Pazar 23:59 |
| 1. sınıf içi gösterim (25 puan, vize) | 2026-11-18 Çarşamba |
| 2. sınıf içi gösterim (25 puan, final) ve planın bitişi | 2026-12-23 Çarşamba |
| Kasım vize haftası planda yok, video yüklenmez | tarihi belirsiz |

### Teknik isterler
| No | Şart | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| T01 | ASP.NET Core, Razor Pages ya da MVC | evet | `backend/Pages/` (Razor Pages), `backend/Kafamdakiler.csproj` (.NET 10) |
| T02 | PostgreSQL ya da SQL Server | evet | PostgreSQL (K-0002): `compose.yaml`, `UseNpgsql` (`backend/Program.cs`) |
| T03 | EF Core ile erişim, veritabanı migration ile oluşturulur | evet | `backend/Data/AppDbContext.cs`; `backend/Migrations/` (19 migration, ilki `Initial` 2026-10-29) |
| T04 | En az 4-5 tablo, en az bir bire-çok ilişki | evet | 25+ tablo (`AppDbContext.cs`); bire-çok: Aliskanlik → AliskanlikKaydi ve Oge, Oge → Oturum (`backend/Aliskanliklar/Aliskanlik.cs`) |
| T05 | Kendi yazdığımız Web API: en az bir varlık için tam CRUD, Swagger'dan test edilebilir | evet | `/api/aliskanliklar` GET, POST, PUT, DELETE (`backend/Aliskanliklar/AliskanlikEndpoints.cs`); OpenAPI + Scalar `/scalar` (K-0011: Swagger UI yerine, aynı OpenAPI belgesi) |
| T06 | Formlarda doğrulama | evet | DataAnnotations ve `IValidatableObject` (`backend/Aliskanliklar/Dtos.cs`, K-0017); web formunda `ModelState.IsValid` (`backend/Pages/Aliskanliklar/Duzenle.cshtml.cs`) |
| T07 | Kullanıcı girişi ve en az iki rol (ör. yönetici, kullanıcı) | evet | ASP.NET Core Identity; roller Sahip ve Asistan (`backend/Data/SeedData.cs`); policy'ler `backend/Program.cs` |
| T08 | Portal içeriğini yöneten yönetici paneli | evet | `backend/Pages/Yonetim/Index.cshtml`: Asistan izinleri, eylem kipleri, oturumlar, bağlantılar |
| T09 | Arayüz mobilde düzgün görünür (responsive) | evet | Bootstrap ızgarası ve dar ekran düzeni (K-0018, `backend/wwwroot/css/site.css`) |

### Süreç şartları
| No | Şart | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| S01 | GitHub deposu herkese açık (public), erişim izni istemez | evet | github.com/eemrezcan/kafamdakiler herkese açık (kontrol 2026-11-25) |
| S02 | En az haftada bir push; tek seferde yükleme kabul edilmez | kısmen | Commit'ler haftalara yayılı: 26 Eki-1 Kas 11, 2-8 Kas 59, 9-15 Kas 49; 16-22 Kas haftasında push yok (kontrol 2026-11-25) |
| S03 | Gizli bilgi (şifre, bağlantı dizesi, API anahtarı) depoda yok | evet | Gizli bilgiler user-secrets ve `.env` içinde, depoda yalnız `.env.example` (K-0012); git geçmişinde `.env` yok (kontrol 2026-11-25) |
| S04 | `README.md`: nasıl çalıştırılır, veritabanı kurulumu, migration adımları | evet | `README.md`: Requirements, Database, Migrations, Run |
| S05 | Her hafta en az 5 dakikalık video, Drive'da "bağlantıya sahip herkes görüntüleyebilir"; ad `HaftaNN_AhmetEmreOzcan` | hayır | |
| S06 | Videoda: lider, işi kim yaptı, çalışan uygulama, gelecek haftanın planı; kod yorum satırı okunmadan anlatılır | hayır | |
| S07 | Her kodu ve her soruyu açıklayabilmek (yapay zekâ serbest, açıklanamayan kısım öğrencinin sayılmaz) | hayır | |
| S08 | Plan belgesi: ana sayfa (ders, proje adı, ad, numara, GitHub kullanıcı adı, repo ve Drive bağlantısı), özet, teknolojiler, tablo listesi, liderlik dağılımı, 9 haftalık plan | evet | Plan belgesi teslim edildi (2026-10-21); güncel sürümler web 2026-11-03, mobil 2026-11-10 |

Puanlama: vize = plan belgesi 15, hafta 1-4 videoları 30, GitHub düzenliliği 30, 1. gösterim 25; final = hafta 5-9 videoları 30, GitHub düzenliliği 15, teknik isterler 30, 2. gösterim 25.

## BLM4587 proje kuralları (puanlanan şartlar)
Kaynak: `Proje kuralları (Flutter).pdf` (yolu `giris.md` içinde), 2026-2027 Güz, 2026-10-31'de geldi. Takvim, plan belgesi, video, GitHub ve puanlama BLM4581 ile aynıdır (yukarıdaki S01-S08 bu derste de geçerli); farklar ve ek şartlar aşağıda.

### Süreç farkları
| No | Şart | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| MS01 | Videoda mobil uygulama emülatörde ya da gerçek cihazda çalışırken gösterilir; ad `HaftaNN_AhmetEmreOzcan` | hayır | |
| MS02 | Depoda Web API ve mobil ayrı klasörlerde (ör. `/api`, `/mobile`) | evet | `backend/`, `mobile/` |
| MS03 | README: API için veritabanı kurulumu ve migration; mobil için Flutter sürümü, `flutter pub get`, `flutter run`, API adresinin nasıl ayarlanacağı | evet | `README.md` (Database, Migrations, Mobile app: `flutter pub get`, `flutter run --dart-define=API_URL=...`); Flutter sürümü `mobile/README.md` (3.47) |

### Teknik isterler
| No | Şart | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| M01 | Kendi yazdığımız Web API + onu kullanan Flutter uygulaması; en az Android | evet | `backend/` Web API + `mobile/` Flutter; Android APK telefonda kurulu |
| M02 | PostgreSQL ya da SQL Server; ORM ve migration; en az 4-5 tablo, en az bir bire-çok | evet | T02-T04 ile ortak |
| M03 | En az bir varlık için tam CRUD, Swagger/OpenAPI'den test edilebilir | evet | T05 ile ortak |
| M04 | Mobil veriye yalnız kendi API'miz üzerinden erişir; **CRUD işlemlerinin tamamı mobilden yapılabilir** | evet | Mobil yalnız API'yi kullanır (`mobile/lib/data/services/api_service.dart`); alışkanlık ve hatırlatıcı için ekle, listele, düzenle, sil mobilden (`mobile/lib/data/repositories/aliskanlik_repository.dart`) |
| M05 | Mobil formlarda doğrulama; API'de de doğrulama | evet | Mobilde `validator` (`mobile/lib/ui/aliskanliklar/aliskanlik_form_screen.dart`); API'de DTO doğrulaması (T06) |
| M06 | Giriş Web API üzerinden (ör. JWT) ve en az iki rol | evet | Identity bearer token ve yenileme (K-0010, `mobile/lib/data/services/token_interceptor.dart`); Sahip ve Asistan |
| M07 | **Mobilde yalnız yönetici rolüne açık, içeriğin yönetildiği yönetim ekranları** | evet | `mobile/lib/ui/yonetim/`; Sahip dışı kullanıcı rotadan geri çevrilir (`yetkiYonlendirme`, `mobile/lib/routing/router.dart`); API tarafı `/api/yonetim` yalnız Sahip |
| M08 | Mobilde en az 5-6 ekran ve aralarında gezinme | evet | 5 sekme (Bugün, Takvim, Asistan, Alışkanlıklar, Beyin) ve 20'den fazla ekran, go_router (`mobile/lib/routing/router.dart`) |
| M09 | Arayüz farklı ekran boyutlarında düzgün | kısmen | Android telefonda denendi, sistem çubuğu payı (K-0024); tablet ve yatay ekran denenmedi |

Tasarımda hazır UI paketleri serbest; değerlendirme işlevsellik ve mühendislik üzerinden. Yapay zekâ serbest, her kod ve soru açıklanabilmeli (S07).

## Ürün kapsamı: Faz 1 (K-0004)

| No | Madde | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| G01 | Giriş: web'e cookie, mobile token; Sahip ve Asistan rolleri, Asistan izinleri panelden (K-0009, T07) | evet | T07; web cookie, mobil token (K-0010); Asistan izinleri `backend/Yonetim/Izinler.cs` ve yönetim paneli |
| G02 | Spor: program, hareket (kas grubu alanıyla), antrenman, set set kg ve tekrar | hayır | Planda 7. hafta |
| G03 | Spor: her setin yanında geçen haftanın değeri | hayır | Planda 7. hafta |
| G04 | Spor: dinlenme sayacı, rekor işareti, 1RM tahmini | hayır | Planda 7. hafta |
| G05 | Spor: antrenman girişi çevrimdışı çalışır, internet gelince eşitlenir | hayır | Planda 7. hafta; mobilin genel çevrimdışı kuyruğu hazır (`mobile/lib/data/repositories/esitleyici.dart`) |
| G06 | Görev ve söz: ne, kime, ne zaman; telefona bildirim | evet | Hatırlatıcıda `Kime` alanı (`backend/Hatirlaticilar/Hatirlatici.cs`); telefona yerel ve FCM bildirimi (`backend/Bildirimler/`) |
| G07 | Tekrarlayan hatırlatıcı: tek seferlik, aylık (olmayan gün ayın son gününe kayar), yıllık, kaç gün önce | evet | `backend/Hatirlaticilar/HatirlaticiHesap.cs` (`OnceGun`, aylık ay sonuna kayar); testler `backend.Tests/HatirlaticiHesapTests.cs` |
| G08 | Kitap: güncel sayfa girişi, günlük sayfa hesaplanır, kaçırılan günle sıfırlanmayan seri | evet | Öğe ve okuma oturumu (`backend/Aliskanliklar/OgeEndpoints.cs`, `OgeHesap.cs`); kaçırılan günde sıfırlanmayan güç serisi (`AliskanlikHesap.GucSerisi`) |
| G09 | Kilo: haftalık tartı, 4 haftalık trend | hayır | Planda 8. hafta |
| G10 | Hızlı not: yazı, fotoğraf, ekran görüntüsü; dosyalar herkese açık değil | evet | Yakalama yazı ve fotoğraf (`backend/Yakalamalar/`); dosyalar yetkiyle okunur (`backend/Dosyalar/DosyaEndpoints.cs`) |
| G11 | Web: yönetim ve analiz ekranları (Razor Pages) | kısmen | Yönetim paneli var; analiz şimdilik alışkanlık detayındaki grafikler (Chart.js, `backend/Pages/Aliskanliklar/Detay.cshtml`) |
| G12 | Mobil: günlük giriş ekranları (Flutter) | evet | `mobile/lib/ui/bugun/`, `mobile/lib/ui/aliskanliklar/`, `mobile/lib/ui/yakalama/` |
| G13 | Deploy: HTTPS, yedek | evet | HTTPS: `tailscale serve` (`*.ts.net` sertifikası), 2026-11-07. Yedek: her sabah 06:00 `pg_dump` + restic → Backblaze B2 (`deploy/yedek/`); ilk yedek `dfdf1487` alındı, geri yükleme denendi (dosyalar birebir, döküm boş Postgres'e yüklendi: 15 tablo, 2 kullanıcı, 6 migration), 2026-11-07 |

## Faz 2
- MCP kapısı, haftalık değerlendirme, hayat dersleri günlüğü, vücut fotoğrafı, adım, kas grubu başına haftalık set grafiği, mobilite oynatıcısı, günlük ruh hali ve enerji, Android "Paylaş" menüsü (öneri).

## Faz 3
- Yemek kaydı, ekran süresi (telefon toplamı ve uygulama bazında), finans (elle giriş, PDF ek, Claude taslağı), bakım kalorisi tahmini.
