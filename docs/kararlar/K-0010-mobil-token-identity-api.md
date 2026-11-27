---
kimlik: K-0010
baslik: "Mobil ve Asistan girişi MapIdentityApi ile"
tur: karar
soru: "Mobil uygulama ve Asistan hesabı API'ye hangi token ile girer?"
sonuc: kabul
kavramlar: [mobil, token, identity, asistan, bearer-token, refresh-token]
tags: [karar]
---

# K-0010 - Mobil ve Asistan girişi MapIdentityApi ile

## m01 - Web Identity'nin cookie girişini kullanır
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [web, cookie]
karar-veren: kullanici
```
2026-10-16, kullanıcı. Web (Razor Pages) Identity'nin cookie girişini kullanır.

## m02 - Mobil ve Asistan girişi Identity'nin hazır uçlarıyla (MapIdentityApi) yapılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [mapidentityapi]
karar-veren: kullanici
```
Mobil ve Asistan, Identity'nin hazır uçlarını (`AddIdentityApiEndpoints` + `MapIdentityApi`, `/api/hesap` altında) kullanır: `/login` ile bearer token ve refresh token alınır, `/refresh` ile yenilenir.

## m03 - Herkese açık register ucu kapatılır
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [register]
karar-veren: kullanici
```
Herkese açık `/register` ucu bir endpoint filter ile kapatılır.

## m04 - Sahip ve Asistan hesapları ilk çalıştırmada seed ile oluşturulur
```yaml
tur: m
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
kavramlar: [seed, gizli-bilgiler]
karar-veren: kullanici
```
Sahip ve Asistan hesapları ilk çalıştırmada seed ile oluşturulur, şifreleri gizli bilgiden okunur (S03).

## g01 - Hazır, test edilmiş kod; izin değişikliği refresh'te kendiliğinden işler
```yaml
tur: g
durum: guncel
tarih: 2026-10-16
dayanak: cikarim
kavramlar: [security-stamp]
```
Hazır, Microsoft'un test ettiği kod; login, refresh ve security stamp kontrolü hazır gelir, K-0009'daki izin değişikliği refresh'te kendiliğinden işler (K-0008).

## r01 - Elle JWT üretimi
```yaml
tur: r
durum: guncel
tarih: 2026-10-16
dayanak: kullanici
yeniden-ac: "Token'ın başka bir servis tarafından okunması (JWT) gerekirse ya da hazır uçların şekli yetmezse. Faz 2'de MCP için gelecek OAuth (OpenIddict) bu kararı etkilemez, ayrı bir giriş yoludur."
karar-veren: kullanici
```
Token, anahtar ve refresh token yönetimini yazmak gerekir; hata alanı geniş, tekerleği icat etmek.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-16
dayanak: bilinmiyor
```
Belgede yazılmamış.
