---
baslik: Gizli bilgiler user-secrets ve ortam değişkeninde
tur: karar
soru: Şifreler ve bağlantı dizesi nerede durur, uygulamaya nasıl verilir?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-26, kullanıcı. Gizli bilgiler koddan ayrı durur ve repoya hiç girmez (S03). Bunlar Postgres bağlantı dizesi, Sahip ve Asistan seed şifreleri:
- Uygulama, geliştirmede `dotnet user-secrets` kullanır; değerler repo dışında, `~/.microsoft/usersecrets/` altında durur.
- Docker Compose (geliştirmede Postgres, sunucuda tüm yığın) değerleri gitignore'daki `.env` dosyasından okur. Repoya yalnız boş değerli `.env.example` girer, dosya izni sunucuda `600` olur.
- Sunucuda uygulama aynı anahtarları ortam değişkeni olarak alır (`ConnectionStrings__Default`, `Seed__SahipPassword`).
- `appsettings.json` dosyasında yalnız anahtarlar durur, değerleri boştur. Kod değeri hep `IConfiguration` üzerinden okur.
- Uygulamanın veritabanı kullanıcısı süper kullanıcı değildir; yalnız kendi veritabanına yetkisi vardır.
- Repo GitHub'da açılınca secret scanning ve push protection açılır.

## Gerekçe
.NET'in yerleşik yolu, kütüphane gerektirmez (K-0008). user-secrets proje klasörünün dışında durduğu için yanlışlıkla commit'lenemez. Ortam değişkeni, tek sunuculu bir projede sektörün olağan yoludur (12-factor). Repo public olduğu için push protection ücretsiz bir ikinci emniyettir.

## Reddedilenler
- Her şey tek `.env` dosyasında, DotNetEnv ile: dosya proje klasöründe durduğu için sızma riski taşır; framework'ün zaten yaptığı iş için ek kütüphane gerekir.
- Gitignore'a alınmış `appsettings.Development.json`: aynı sızma riski; gizli olmayan geliştirme ayarları da repodan düşer.
- Secret manager (Key Vault, Vault, Infisical): tek kişilik, tek sunuculu projede tören.
- gitleaks pre-commit: şimdilik gerekmez, push protection yeterli.

## Yeniden açma koşulu
Birden fazla sunucu ya da ortam olursa veya gizli bilgi döndürme (rotation) gerekirse.
