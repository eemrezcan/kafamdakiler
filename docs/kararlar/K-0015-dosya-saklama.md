---
baslik: Yüklenen dosyalar wwwroot dışında, girişli uçtan
tur: karar
soru: Yüklenen dosyalar (vücut fotoğrafı vb.) nerede saklanır ve nasıl verilir?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-29, kullanıcı. Dosyalar sunucu diskinde, `wwwroot` dışındaki bir klasörde durur. Klasörün yolu yapılandırmadan okunur (`Dosyalar:Klasor`); Docker'da bu klasör volume olarak bağlanır. Dosyalar yalnız girişli ve policy'li bir uç noktadan verilir (`Results.PhysicalFile`). Veritabanında dosyanın kendisi değil, bilgisi tutulur: Id (Guid v7, K-0013), disk yolu, içerik türü, boyut ve yükleme anı (`timestamptz`, K-0014). Diskteki adı sunucu Guid olarak üretir; kullanıcının gönderdiği ad diske yazılmaz. Yalnız jpg, png ve webp kabul edilir, dosya başına en çok 10 MB.

## Gerekçe
Q10: `wwwroot` içindeki dosyayı `UseStaticFiles` giriş istemeden verir; adresi bilen herkes görür ve K-0009'daki izin matrisi hiç devreye girmez. Adı gizlemek koruma değildir. Girişli uç, her istekte izni kontrol eder. Sunucunun ürettiği ad, yol aşımını (`../`) ve ad çakışmasını önler.

## Reddedilenler
- `wwwroot` altında saklamak: policy atlanır.
- Veritabanında `bytea`: yedeği şişirir, sorguları yavaşlatır.
- Nesne depolama (S3 vb.): bugünkü ölçekte gereksiz.

## Yeniden açma koşulu
Diskteki dosyalar için ayrı yedek gerekirse ya da tek sunucu yetmezse nesne depolama yeniden düşünülür.
