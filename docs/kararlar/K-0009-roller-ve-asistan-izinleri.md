---
baslik: Roller Sahip ve Asistan, izinler claim ile
tur: karar
soru: Uygulamada hangi roller var ve yetki nasıl yönetilir?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-16, kullanıcı. ASP.NET Core Identity ile iki rol: **Sahip** (kullanıcının kendisi; her şeyi görür ve yönetir, yönetici paneli onundur) ve **Asistan** (yapay zekâ için ayrı hesap; yalnız API'ye token ile girer). Asistan'ın izinleri Faz 1'den itibaren panelden açılıp kapanır: her izin Identity'nin hazır `AspNetUserClaims` tablosunda bir claim'dir (`izin` = `kilo.oku` gibi). Her izin için bir policy vardır; policy Sahip rolünü ya da ilgili claim'i ister. Panelde izin değişince `UserManager.AddClaimAsync` / `RemoveClaimAsync` ve ardından `UpdateSecurityStampAsync` çağrılır, eski token geçersiz olur. Faz 2'deki MCP kapısı Asistan hesabıyla bağlanır.

## Gerekçe
T07 (giriş ve en az iki rol) ve T08 (yönetici paneli) karşılanır. İnsan ve makine istemcisi ayrılır, en az ayrıcalık ilkesine uyar. Kullanıcı izin matrisinin baştan hazır olmasını istedi. Claim ve policy Identity'nin hazır parçaları; özel yetki tablosu ya da altyapısı yazılmaz (K-0008). Tek insan kullanıcı olduğu için tablolara kullanıcı sahipliği (UserId) eklenmez.

## Reddedilenler
- Faz 1'de sabit policy, izin matrisi Faz 2'de: daha az iş ama kullanıcı baştan hazır olmasını istedi.
- Özel izin tablosu ve kendi yetki işleyicisi: Identity claim'leri aynı işi görüyor.
- Yönetici ve kullanıcı adında iki insan rolü: ikinci bir insan kullanıcı yok.

## Yeniden açma koşulu
Hoca iki insan rolü şart koşarsa ya da uygulama başka kullanıcılara açılırsa (o zaman tablolara UserId gerekir).
