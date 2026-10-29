---
baslik: Mobil ve Asistan girişi MapIdentityApi ile
tur: karar
soru: Mobil uygulama ve Asistan hesabı API'ye hangi token ile girer?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-16, kullanıcı. Web (Razor Pages) Identity'nin cookie girişini kullanır. Mobil ve Asistan, Identity'nin hazır uçlarını (`AddIdentityApiEndpoints` + `MapIdentityApi`, `/api/hesap` altında) kullanır: `/login` ile bearer token ve refresh token alınır, `/refresh` ile yenilenir. Herkese açık `/register` ucu bir endpoint filter ile kapatılır; Sahip ve Asistan hesapları ilk çalıştırmada seed ile oluşturulur, şifreleri gizli bilgiden okunur (S03).

## Gerekçe
Hazır, Microsoft'un test ettiği kod; login, refresh ve security stamp kontrolü hazır gelir, K-0009'daki izin değişikliği refresh'te kendiliğinden işler (K-0008).

## Reddedilenler
- Elle JWT üretimi: token, anahtar ve refresh token yönetimini yazmak gerekir; hata alanı geniş, tekerleği icat etmek.

## Yeniden açma koşulu
Token'ın başka bir servis tarafından okunması (JWT) gerekirse ya da hazır uçların şekli yetmezse. Faz 2'de MCP için gelecek OAuth (OpenIddict) bu kararı etkilemez, ayrı bir giriş yoludur.
