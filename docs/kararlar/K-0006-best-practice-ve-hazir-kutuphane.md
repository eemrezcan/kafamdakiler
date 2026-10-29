---
baslik: Sektörün yolu ve hazır kütüphane, ders birebir izlenmez
tur: karar
soru: Ders örnekleri ile sektördeki yerleşik yol ayrıştığında hangisi izlenir, hazır kütüphane kullanılır mı?
sonuc: kabul
tags: [karar]
---

## Karar
2026-10-15, kullanıcı. Ders slaytları ve örnek kodları referanstır; birebir aynısı yapılmaz. Sektörde kabul görmüş yol (best practice) ve olgun, bakımı süren hazır kütüphaneler esastır; tekerlek yeniden icat edilmez. Tek sınır, ödevin puanlanan şartlarıdır (`docs/gereksinimler.md`): kütüphane ya da yöntem bir şartı karşılamıyorsa şart kazanır.

## Gerekçe
Kullanıcı projeyi kendisi de kullanacak ve sektörde geçerli beceri kazanmak istiyor. Proje kuralları hazır şablon ve yapay zekâ kullanımına izin veriyor; değerlendirme işlevsellik ve mühendislik üzerinden. Hazır kütüphane kullanmak öğrenmeyi azaltmaz: kullanıcı her satırı açıklayabilmek zorunda (kural 8), bu yüzden kütüphanenin ne yaptığı da anlatılır.

## Reddedilenler
- Dersin örneklerini birebir izlemek: örnekler kısa ders gösterimi için yazılmış (ör. SQL Server LocalDB), gerçek projenin ihtiyacını karşılamıyor.
- Kimlik doğrulama gibi altyapıyı elle yazmak: güvenlik açığı riski, sektör pratiği değil.

## Yeniden açma koşulu
Bir hoca belirli bir yöntemi zorunlu tutarsa.
