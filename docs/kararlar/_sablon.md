---
kimlik: K-0000
baslik: "Karar başlığı (konu, cevap değil)"
tur: karar
soru: "Bu kararın cevapladığı tek cümlelik soru?"
sonuc: kabul
kavramlar: [ana-konu, ikinci-kavram]
tags: [karar]
---

# K-0000 - Karar başlığı (konu, cevap değil)

## m01 - Seçilen yol uygulanabilir tek cümleyle yazılır ("… yapılır")
```yaml
tur: m
durum: guncel
tarih: 2026-01-01
dayanak: kullanici
karar-veren: kullanici
```
Hüküm: neyin kararlaştırıldığı, bir iki cümle.

## g01 - Seçimin sebebi
```yaml
tur: g
durum: guncel
tarih: 2026-01-01
dayanak: cikarim
```
Neden bu seçildi? Hangi kısıt ya da bilgi belirleyici oldu?

## r01 - Elenen seçenek
```yaml
tur: r
durum: guncel
tarih: 2026-01-01
dayanak: kullanici
yeniden-ac: "Hangi durum bu seçeneği yeniden açar? Yazılmadıysa: belgede yazılmamış."
karar-veren: kullanici
```
Neden elendi?

## b01 - Seçilenin eksisi
```yaml
tur: b
durum: guncel
tarih: 2026-01-01
dayanak: cikarim
```
Bu seçimle neyi kaybettik? Yazılmadıysa: "Belgede yazılmamış." ve `dayanak: bilinmiyor`.
