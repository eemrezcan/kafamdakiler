---
baslik: Roller Sahip ve Asistan, izinler claim ile
tur: karar
soru: Uygulamada hangi roller var ve yetki nasıl yönetilir?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-16, kullanıcı. ASP.NET Core Identity ile iki rol: **Sahip** (kullanıcının kendisi; her şeyi görür ve yönetir, yönetici paneli onundur) ve **Asistan** (yapay zekâ için ayrı hesap; yalnız API'ye token ile girer). Asistan'ın izinleri Faz 1'den itibaren panelden açılıp kapanır: her izin Identity'nin hazır `AspNetUserClaims` tablosunda bir claim'dir (`izin` = `kilo.oku` gibi). Her izin için bir policy vardır; policy Sahip rolünü ya da ilgili claim'i ister. Panelde izin değişince `UserManager.AddClaimAsync` / `RemoveClaimAsync` ve ardından `UpdateSecurityStampAsync` çağrılır, eski token geçersiz olur. Faz 2'deki MCP kapısı Asistan hesabıyla bağlanır.

## Ek (2026-10-30)
- Web (Razor Pages) bütünüyle yalnız Sahip'e açık; yalnız `/Hesap` (giriş, çıkış) herkese açık. Asistan web'e girmez, yalnız API (kullanıcı kararı; Asistan'ı izinli web sayfalarına salt okunur sokma önerisi şimdilik alınmadı).
- T07 gösterimi: Sahip panelden Asistan'ın bir iznini açar, Asistan (1. gösterimde Scalar'dan, 2. gösterimde MCP üzerinden Claude) veriye erişir; izni kapatınca aynı istek 403 alır.
- Bearer token izinlerin kopyasını taşır ve 1 saat geçerlidir; izin kapanınca hemen etkili olsun diye API isteklerinde izin claim'leri token'dan değil veritabanından okunacak (izin adımında).
- Kullanıcıya öneri: derste hocaya "ikinci rol yapay zekâ asistanı, izinleri yönetici panelinden veriliyor; iki rol şartını karşılar mı?" diye sorulacak.

## Gerekçe
T07 (giriş ve en az iki rol) ve T08 (yönetici paneli) karşılanır. İnsan ve makine istemcisi ayrılır, en az ayrıcalık ilkesine uyar. Kullanıcı izin matrisinin baştan hazır olmasını istedi. Claim ve policy Identity'nin hazır parçaları; özel yetki tablosu ya da altyapısı yazılmaz (K-0008). Tek insan kullanıcı olduğu için tablolara kullanıcı sahipliği (UserId) eklenmez.

## Reddedilenler
- Faz 1'de sabit policy, izin matrisi Faz 2'de: daha az iş ama kullanıcı baştan hazır olmasını istedi.
- Özel izin tablosu ve kendi yetki işleyicisi: Identity claim'leri aynı işi görüyor.
- Yönetici ve kullanıcı adında iki insan rolü: ikinci bir insan kullanıcı yok.

## Yeniden açma koşulu
Hoca iki insan rolü şart koşarsa ya da uygulama başka kullanıcılara açılırsa (o zaman tablolara UserId gerekir).
