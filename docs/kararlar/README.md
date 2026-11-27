# Kararlar

Bu projede alınan kararlar burada durur. Bir karar, tek sorunun cevabıdır.

## Adlandırma
- Dosya adı `K-0001-<konu>.md` biçimindedir: önek, dört haneli sıra numarası, kısa konu (küçük harf, ASCII, tireli).
- Numara yeniden kullanılmaz. Sıradaki karar, en yüksek numaranın bir fazlasını alır.
- İptal edilen karar silinmez; `sonuc` alanı değişir (`kabul` yerine `ret`) ve gerekçesi yazılır.
- Yeni karar için `_sablon.md` dosyasını kopyala. `_` ile başlayan dosyalar karar sayılmaz.

## Üst bilgi
- `kimlik`: dosya adındaki `K-NNNN`.
- `baslik`: konuyu söyler, cevabı değil.
- `soru`: kararın cevapladığı tek cümlelik soru.
- `sonuc`: `kabul` ya da `ret`. Sonucu ret olan kayıtta hüküm yerine ret (`r`) maddesi bulunur.
- `kavramlar`: kaydın kavramları, önem sırasıyla (ilki ana konu), en çok 8; Türkçe, küçük harf, tireli. Ayrı alandır, takma ad değil.

## Maddeler
Her madde `## <harf><NN> - <başlık>` başlığıdır, altında küçük bir yaml bloğu (`tur`, `durum`, `tarih`; türüne göre `dayanak`, `yeniden-ac`, `karar-veren`, `kavramlar`), sonra gövde. Tek madde tek iddia.

| Harf | Tür | Not |
| --- | --- | --- |
| `m` | hüküm | seçilen yol; başlığı uygulanabilir tek cümle ("… yapılır") |
| `g` | gerekçe | `dayanak` zorunlu |
| `r` | ret | başlığı elenen seçenek; `yeniden-ac` zorunlu |
| `b` | bedel | ret varsa en az bir tane: seçilenin eksisi |
| `k` | doğrulama | yalnız gerçek bağ varsa (test yolu); uydurulmaz |
| `o` | ölçüm | sayının yanında tarih ve komut |
| `d` | kapsam dışı | konuşulup bu karara alınmayan konu |
| `u` | belirlemediği | cevapsız kalan |
| `e` | ertelendi | "şimdi değil"; tetik zorunlu |

Numara harfin içindedir: `m01`, `g01`, `r01`. Atıf `K-0012/m01` biçimindedir.

## Dayanak
`kullanici` (kullanıcı kararı; ana sohbet ya da işçi kendi başına değiştirmez, sorar), `olcum`, `kaynak` (şart metni, araştırma), `cikarim`, `bilinmiyor`. Dayanak bilinmiyorsa tahminle `kullanici` yazılmaz.

## Kavram
Kayıt kavramları kaydın konusunu söyler; madde kavramı yalnız o maddeye özgü olanı söyler ve kayıt kavramını tekrar etmez (miras alır). Madde başına en çok 8; gerekmiyorsa yazılmaz. Aynı şeye her kayıtta aynı ad verilir.

## Ret ve yeniden açma
Reddedilen her seçenek ayrı `r` maddesidir; yaml'daki `yeniden-ac` o seçeneği hangi durumun yeniden açacağını söyler. Kayıtta ret yoksa ve yeniden açma koşulu anlamlıysa kayıt sonunda maddesiz `## Yeniden açma koşulu` bölümü kalır.

## Güncelleme
Kabul edilen kayıt donar; güncelleme `## Ek (tarih)` yerine yeni bir madde (kendi `tarih`iyle) olarak eklenir. Yerini alınan madde silinmez, `durum: yerini-aldi` olur.
