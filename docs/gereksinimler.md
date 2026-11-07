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
| T01 | ASP.NET Core, Razor Pages ya da MVC | hayır | |
| T02 | PostgreSQL ya da SQL Server | hayır | K-0002 |
| T03 | EF Core ile erişim, veritabanı migration ile oluşturulur | hayır | |
| T04 | En az 4-5 tablo, en az bir bire-çok ilişki | hayır | |
| T05 | Kendi yazdığımız Web API: en az bir varlık için tam CRUD, Swagger'dan test edilebilir | hayır | |
| T06 | Formlarda doğrulama | hayır | |
| T07 | Kullanıcı girişi ve en az iki rol (ör. yönetici, kullanıcı) | hayır | |
| T08 | Portal içeriğini yöneten yönetici paneli | hayır | |
| T09 | Arayüz mobilde düzgün görünür (responsive) | hayır | |

### Süreç şartları
| No | Şart | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| S01 | GitHub deposu herkese açık (public), erişim izni istemez | hayır | |
| S02 | En az haftada bir push; tek seferde yükleme kabul edilmez | hayır | |
| S03 | Gizli bilgi (şifre, bağlantı dizesi, API anahtarı) depoda yok | hayır | |
| S04 | `README.md`: nasıl çalıştırılır, veritabanı kurulumu, migration adımları | hayır | |
| S05 | Her hafta en az 5 dakikalık video, Drive'da "bağlantıya sahip herkes görüntüleyebilir"; ad `HaftaNN_AhmetEmreOzcan` | hayır | |
| S06 | Videoda: lider, işi kim yaptı, çalışan uygulama, gelecek haftanın planı; kod yorum satırı okunmadan anlatılır | hayır | |
| S07 | Her kodu ve her soruyu açıklayabilmek (yapay zekâ serbest, açıklanamayan kısım öğrencinin sayılmaz) | hayır | |
| S08 | Plan belgesi: ana sayfa (ders, proje adı, ad, numara, GitHub kullanıcı adı, repo ve Drive bağlantısı), özet, teknolojiler, tablo listesi, liderlik dağılımı, 9 haftalık plan | hayır | |

Puanlama: vize = plan belgesi 15, hafta 1-4 videoları 30, GitHub düzenliliği 30, 1. gösterim 25; final = hafta 5-9 videoları 30, GitHub düzenliliği 15, teknik isterler 30, 2. gösterim 25.

## BLM4587 proje kuralları (puanlanan şartlar)
Kaynak: `Proje kuralları (Flutter).pdf` (yolu `giris.md` içinde), 2026-2027 Güz, 2026-10-31'de geldi. Takvim, plan belgesi, video, GitHub ve puanlama BLM4581 ile aynıdır (yukarıdaki S01-S08 bu derste de geçerli); farklar ve ek şartlar aşağıda.

### Süreç farkları
| No | Şart | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| MS01 | Videoda mobil uygulama emülatörde ya da gerçek cihazda çalışırken gösterilir; ad `HaftaNN_AhmetEmreOzcan` | hayır | |
| MS02 | Depoda Web API ve mobil ayrı klasörlerde (ör. `/api`, `/mobile`) | evet | `backend/`, `mobile/` |
| MS03 | README: API için veritabanı kurulumu ve migration; mobil için Flutter sürümü, `flutter pub get`, `flutter run`, API adresinin nasıl ayarlanacağı | hayır | |

### Teknik isterler
| No | Şart | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| M01 | Kendi yazdığımız Web API + onu kullanan Flutter uygulaması; en az Android | hayır | |
| M02 | PostgreSQL ya da SQL Server; ORM ve migration; en az 4-5 tablo, en az bir bire-çok | hayır | T02-T04 ile ortak |
| M03 | En az bir varlık için tam CRUD, Swagger/OpenAPI'den test edilebilir | hayır | T05 ile ortak |
| M04 | Mobil veriye yalnız kendi API'miz üzerinden erişir; **CRUD işlemlerinin tamamı mobilden yapılabilir** | hayır | |
| M05 | Mobil formlarda doğrulama; API'de de doğrulama | hayır | |
| M06 | Giriş Web API üzerinden (ör. JWT) ve en az iki rol | hayır | Identity bearer token (K-0010) |
| M07 | **Mobilde yalnız yönetici rolüne açık, içeriğin yönetildiği yönetim ekranları** | hayır | |
| M08 | Mobilde en az 5-6 ekran ve aralarında gezinme | hayır | |
| M09 | Arayüz farklı ekran boyutlarında düzgün | hayır | |

Tasarımda hazır UI paketleri serbest; değerlendirme işlevsellik ve mühendislik üzerinden. Yapay zekâ serbest, her kod ve soru açıklanabilmeli (S07).

## Ürün kapsamı: Faz 1 (K-0004)

| No | Madde | Karşılandı mı | Kanıt |
| --- | --- | --- | --- |
| G01 | Giriş: web'e cookie, mobile token; Sahip ve Asistan rolleri, Asistan izinleri panelden (K-0009, T07) | hayır | |
| G02 | Spor: program, hareket (kas grubu alanıyla), antrenman, set set kg ve tekrar | hayır | |
| G03 | Spor: her setin yanında geçen haftanın değeri | hayır | |
| G04 | Spor: dinlenme sayacı, rekor işareti, 1RM tahmini | hayır | |
| G05 | Spor: antrenman girişi çevrimdışı çalışır, internet gelince eşitlenir | hayır | |
| G06 | Görev ve söz: ne, kime, ne zaman; telefona bildirim | hayır | |
| G07 | Tekrarlayan hatırlatıcı: tek seferlik, aylık (olmayan gün ayın son gününe kayar), yıllık, kaç gün önce | hayır | |
| G08 | Kitap: güncel sayfa girişi, günlük sayfa hesaplanır, kaçırılan günle sıfırlanmayan seri | hayır | |
| G09 | Kilo: haftalık tartı, 4 haftalık trend | hayır | |
| G10 | Hızlı not: yazı, fotoğraf, ekran görüntüsü; dosyalar herkese açık değil | hayır | |
| G11 | Web: yönetim ve analiz ekranları (Razor Pages) | hayır | |
| G12 | Mobil: günlük giriş ekranları (Flutter) | hayır | |
| G13 | Deploy: HTTPS, yedek | evet | HTTPS: `tailscale serve` (`*.ts.net` sertifikası), 2026-11-07. Yedek: her sabah 06:00 `pg_dump` + restic → Backblaze B2 (`deploy/yedek/`); ilk yedek `dfdf1487` alındı, geri yükleme denendi (dosyalar birebir, döküm boş Postgres'e yüklendi: 15 tablo, 2 kullanıcı, 6 migration), 2026-11-07 |

## Faz 2
- MCP kapısı (Claude bölgesi), haftalık değerlendirme, hayat dersleri günlüğü, vücut fotoğrafı, adım, kas grubu başına haftalık set grafiği, mobilite oynatıcısı (Claude bölgesi), günlük ruh hali ve enerji, Android "Paylaş" menüsü (öneri).

## Faz 3
- Yemek kaydı, ekran süresi (telefon toplamı ve uygulama bazında), finans (elle giriş, PDF ek, Claude taslağı), bakım kalorisi tahmini.
