---
baslik: Birincil anahtar her tabloda Guid v7
tur: karar
soru: Tabloların birincil anahtarı hangi tiptedir, Id kim tarafından üretilir?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-27, kullanıcı. Her tablonun birincil anahtarı `Guid` olur, değeri UUID sürüm 7'dir (Postgres'te `uuid`). Sunucuda Id'yi EF Core üretir (Npgsql sağlayıcısının varsayılanı; A01'de doğrulanır, gerekirse `Guid.CreateVersion7()`). Çevrimdışı girilen kayıtların Id'sini telefon üretir (Dart `uuid` paketi, v7). Gelen Id zaten varsa sunucu yeni kayıt açmaz, mevcut kaydı döndürür. Tutarlılık için Identity tabloları da `Guid` anahtar kullanır (`IdentityUser<Guid>`, `IdentityRole<Guid>`).

## Gerekçe
G05: Çevrimdışıyken telefon sunucudan Id alamaz, kendisi üretmelidir. Aynı istek tekrar gönderildiğinde Id sayesinde kopya oluşmaz. v7'nin başı zaman damgası olduğu için Id'ler sıralı gelir ve index'i parçalamaz. Tek kural bütün tablolarda geçerli olduğundan akılda tutması kolaydır. Ders örnekleri `int` kullanıyor; çevrimdışı giriş yüzünden ayrılıyoruz.

## Reddedilenler
- `int` sayaç: çevrimdışı Id üretilemez, tekrar gönderimde kopya kayıt oluşur.
- Guid v4: rastgele olduğu için index'i parçalar.
- `int` birincil anahtar + ek `Guid ClientId`: her tabloda iki kimlik olur, ilişkilerde hangisinin kullanılacağı karışır.

## Yeniden açma koşulu
Yok.

Kaybolan: Id'ler ekranda okunaklı değil; kullanıcıya Id gösterilmez.
