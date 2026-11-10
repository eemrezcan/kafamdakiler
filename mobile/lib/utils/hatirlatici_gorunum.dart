import 'package:intl/intl.dart';

import '../data/models/hatirlatici.dart';

// Display texts of reminders, the same words as backend/Hatirlaticilar/HatirlaticiGorunum.cs (the web list).

String hatirlaticiTurAdi(HatirlaticiTuru tur) => switch (tur) {
      HatirlaticiTuru.gorev => 'Yapılacak',
      HatirlaticiTuru.soz => 'Söz',
      HatirlaticiTuru.ozelTarih => 'Özel tarih',
    };

String hatirlaticiDurumAdi(HatirlaticiDurumu durum) => switch (durum) {
      HatirlaticiDurumu.acik => 'Açık',
      HatirlaticiDurumu.tamam => 'Tamam',
      HatirlaticiDurumu.arsiv => 'Arşiv',
    };

String tekrarAdi(Tekrar tekrar) => switch (tekrar) {
      Tekrar.yok => 'Tekrarlanmaz',
      Tekrar.gunluk => 'Her gün',
      Tekrar.haftalik => 'Her hafta',
      Tekrar.aylik => 'Her ay',
      Tekrar.yillik => 'Her yıl',
    };

/// "bugün", "yarın", "3 gün sonra", "2 gün gecikti".
String kalanGunMetni(int kalanGun) {
  if (kalanGun == 0) return 'bugün';
  if (kalanGun == 1) return 'yarın';
  if (kalanGun > 1) return '$kalanGun gün sonra';
  return '${-kalanGun} gün gecikti';
}

/// "15 Aralık 2026 Salı": a reminder's day.
String hatirlaticiGunu(DateTime gun) => DateFormat('d MMMM y EEEE', 'tr').format(gun);
