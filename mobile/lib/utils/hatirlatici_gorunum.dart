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

// Turkish possessive-locative suffix of a day number: "31'inde", "2'sinde", "3'ünde" (by how the number is read).
const _ayGunuEki = [
  '', "'inde", "'sinde", "'ünde", "'ünde", "'inde", "'sında", "'sinde", "'inde", "'unda", "'unda", //
  "'inde", "'sinde", "'ünde", "'ünde", "'inde", "'sında", "'sinde", "'inde", "'unda", "'sinde",
  "'inde", "'sinde", "'ünde", "'ünde", "'inde", "'sında", "'sinde", "'inde", "'unda", "'unda", "'inde",
];

/// "her gün", "her hafta Pazartesi", "her ay 31'inde", "her yıl 29 Şubat"; null for a one-off.
String? tekrarOzeti(Tekrar tekrar, DateTime gun) => switch (tekrar) {
      Tekrar.yok => null,
      Tekrar.gunluk => 'her gün',
      Tekrar.haftalik => 'her hafta ${DateFormat('EEEE', 'tr').format(gun)}',
      Tekrar.aylik => 'her ay ${gun.day}${_ayGunuEki[gun.day]}',
      Tekrar.yillik => 'her yıl ${DateFormat('d MMMM', 'tr').format(gun)}',
    };

/// "3 gün önce de haber verilir"; null when there is no heads-up.
String? onceNotu(int onceGun) {
  if (onceGun <= 0) return null;
  return '$onceGun gün önce de haber verilir';
}

/// "6 Kas Cum 09:00": a moment in Istanbul time (K-0014), whatever the phone's own time zone is.
String hatirlaticiZamani(DateTime an) =>
    DateFormat('d MMM EEE HH:mm', 'tr').format(an.toUtc().add(const Duration(hours: 3)));

/// "15 Aralık 2026 Salı": a reminder's day.
String hatirlaticiGunu(DateTime gun) => DateFormat('d MMMM y EEEE', 'tr').format(gun);
