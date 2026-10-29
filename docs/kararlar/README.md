# Kararlar

Bu projede alınan kararlar burada durur. Bir karar, tek sorunun cevabıdır.

## Adlandırma
- Dosya adı `K-0001-<konu>.md` biçimindedir: önek, dört haneli sıra numarası, kısa konu (küçük harf, ASCII, tireli).
- Numara yeniden kullanılmaz. Sıradaki karar, en yüksek numaranın bir fazlasını alır.
- İptal edilen karar silinmez; `sonuc` alanı değişir (`kabul` yerine `ret`) ve gerekçesi yazılır.
- Yeni karar için `_sablon.md` dosyasını kopyala. `_` ile başlayan dosyalar karar sayılmaz.

## Alanlar
- `soru`: kararın cevapladığı tek cümlelik soru.
- `sonuc`: `kabul` ya da `ret`.
- Ret ise "Yeniden açma koşulu" bölümünde hangi durumun soruyu yeniden açacağını yaz.
