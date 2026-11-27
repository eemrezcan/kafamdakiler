---
kimlik: K-0006
baslik: "Sektörün yolu ve hazır kütüphane, ders birebir izlenmez"
tur: karar
soru: "Ders örnekleri ile sektördeki yerleşik yol ayrıştığında hangisi izlenir, hazır kütüphane kullanılır mı?"
sonuc: kabul
kavramlar: [best-practice, hazır-kütüphane, ders-örnekleri, ödev-şartları]
tags: [karar]
---

# K-0006 - Sektörün yolu ve hazır kütüphane, ders birebir izlenmez

## m01 - Ders örnekleri referanstır, birebir izlenmez
```yaml
tur: m
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
karar-veren: kullanici
```
2026-10-15, kullanıcı. Ders slaytları ve örnek kodları referanstır; birebir aynısı yapılmaz.

## m02 - Sektörde kabul görmüş yol ve olgun hazır kütüphane esastır
```yaml
tur: m
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
karar-veren: kullanici
```
Sektörde kabul görmüş yol (best practice) ve olgun, bakımı süren hazır kütüphaneler esastır; tekerlek yeniden icat edilmez.

## m03 - Ödevin puanlanan şartı bir kütüphane ya da yöntemin önüne geçer
```yaml
tur: m
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
karar-veren: kullanici
```
Tek sınır, ödevin puanlanan şartlarıdır (`docs/gereksinimler.md`): kütüphane ya da yöntem bir şartı karşılamıyorsa şart kazanır.

## g01 - Kullanıcı sektörde geçerli beceri kazanmak istiyor
```yaml
tur: g
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
```
Kullanıcı projeyi kendisi de kullanacak ve sektörde geçerli beceri kazanmak istiyor.

## g02 - Proje kuralları hazır şablon ve yapay zekâ kullanımına izin veriyor
```yaml
tur: g
durum: guncel
tarih: 2026-10-15
dayanak: kaynak
```
Proje kuralları hazır şablon ve yapay zekâ kullanımına izin veriyor; değerlendirme işlevsellik ve mühendislik üzerinden.

## g03 - Hazır kütüphane öğrenmeyi azaltmaz
```yaml
tur: g
durum: guncel
tarih: 2026-10-15
dayanak: cikarim
```
Hazır kütüphane kullanmak öğrenmeyi azaltmaz: kullanıcı her satırı açıklayabilmek zorunda (kural 8), bu yüzden kütüphanenin ne yaptığı da anlatılır.

## r01 - Dersin örneklerini birebir izlemek
```yaml
tur: r
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
yeniden-ac: "Bir hoca belirli bir yöntemi zorunlu tutarsa."
karar-veren: kullanici
```
Örnekler kısa ders gösterimi için yazılmış (ör. SQL Server LocalDB), gerçek projenin ihtiyacını karşılamıyor.

## r02 - Kimlik doğrulama gibi altyapıyı elle yazmak
```yaml
tur: r
durum: guncel
tarih: 2026-10-15
dayanak: kullanici
yeniden-ac: "belgede yazılmamış"
kavramlar: [kimlik-doğrulama]
karar-veren: kullanici
```
Güvenlik açığı riski, sektör pratiği değil.

## b01 - Seçilenin bedeli belgede yazılmamış
```yaml
tur: b
durum: guncel
tarih: 2026-10-15
dayanak: bilinmiyor
```
Belgede yazılmamış.
