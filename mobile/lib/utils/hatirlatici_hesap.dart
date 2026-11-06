import '../data/models/hatirlatici.dart';

// Reminder date math, a Dart port of backend/Hatirlaticilar/HatirlaticiHesap.cs. The phone needs it so a reminder
// made or changed offline gets its next moment at once (and its notifications are set up without the server).
// Pure functions: no clock, "now" is always passed in. Days are date-only UTC values, moments are UTC.
// Europe/Istanbul is a fixed UTC+3 (no daylight saving since 2016), like in aliskanlik_gunu.dart.

/// The hour of the day a reminder without an hour of its own fires at (the server setting `Hatirlatici:VarsayilanSaat`).
const varsayilanHatirlaticiSaati = Saat(9, 0);

const _istanbulFarki = Duration(hours: 3);

/// The moment (UTC) of an Istanbul day and hour.
DateTime hatirlaticiAni(DateTime gun, Saat saat) =>
    DateTime.utc(gun.year, gun.month, gun.day, saat.saat, saat.dakika).subtract(_istanbulFarki);

/// The Istanbul calendar day of a moment (date-only UTC value).
DateTime istanbulGunu(DateTime an) {
  final yerel = an.toUtc().add(_istanbulFarki);
  return DateTime.utc(yerel.year, yerel.month, yerel.day);
}

Saat istanbulSaati(DateTime an) {
  final yerel = an.toUtc().add(_istanbulFarki);
  return Saat(yerel.hour, yerel.minute);
}

int _aySonu(int yil, int ay) => DateTime.utc(yil, ay + 1, 0).day;

/// The n-th day of the rule, counted from the start day. Months and years count from the start day each time, so a
/// rule starting on the 31st gives 31 Jan, 28 Feb, 31 Mar; 29 Feb gives 28 Feb in common years.
DateTime hatirlaticiOlusumu(Tekrar tekrar, DateTime baslangic, int n) {
  switch (tekrar) {
    case Tekrar.gunluk:
      return DateTime.utc(baslangic.year, baslangic.month, baslangic.day + n);
    case Tekrar.haftalik:
      return DateTime.utc(baslangic.year, baslangic.month, baslangic.day + 7 * n);
    case Tekrar.aylik:
      final ayIndeksi = baslangic.year * 12 + (baslangic.month - 1) + n;
      final yil = ayIndeksi ~/ 12;
      final ay = ayIndeksi % 12 + 1;
      return DateTime.utc(yil, ay, baslangic.day <= _aySonu(yil, ay) ? baslangic.day : _aySonu(yil, ay));
    case Tekrar.yillik:
      final yil = baslangic.year + n;
      return DateTime.utc(
        yil,
        baslangic.month,
        baslangic.day <= _aySonu(yil, baslangic.month) ? baslangic.day : _aySonu(yil, baslangic.month),
      );
    case Tekrar.yok:
      return baslangic;
  }
}

/// The first firing moment strictly after [sonra]. A one-off has only its own moment, even when it is past.
DateTime sonrakiHatirlaticiAni(Tekrar tekrar, DateTime baslangic, Saat saat, DateTime sonra) {
  if (tekrar == Tekrar.yok) return hatirlaticiAni(baslangic, saat);

  final gunFark = istanbulGunu(sonra).difference(baslangic).inDays;
  final tahmin = switch (tekrar) {
    Tekrar.gunluk => gunFark,
    Tekrar.haftalik => gunFark ~/ 7,
    Tekrar.aylik => gunFark ~/ 31,
    _ => gunFark ~/ 366,
  };
  var n = tahmin - 1 < 0 ? 0 : tahmin - 1;
  while (!hatirlaticiAni(hatirlaticiOlusumu(tekrar, baslangic, n), saat).isAfter(sonra)) {
    n++;
  }
  return hatirlaticiAni(hatirlaticiOlusumu(tekrar, baslangic, n), saat);
}

/// The heads-up moment: [onceGun] days before the firing day, at the same hour. Null when there is none.
DateTime? hatirlaticiOnceAni(DateTime asilAn, int onceGun) {
  if (onceGun <= 0) return null;
  final gun = istanbulGunu(asilAn);
  return hatirlaticiAni(DateTime.utc(gun.year, gun.month, gun.day - onceGun), istanbulSaati(asilAn));
}

/// Days from today (Istanbul) to the moment's day; negative when it is past.
int hatirlaticiKalanGun(DateTime an, DateTime simdi) => istanbulGunu(an).difference(istanbulGunu(simdi)).inDays;

/// Snooze target: "1s" is one hour from now, "yarin" is tomorrow at the reminder's hour. Null for any other value.
DateTime? hatirlaticiErteleAni(String? sure, DateTime simdi, Saat saat) {
  switch (sure) {
    case '1s':
      return simdi.toUtc().add(const Duration(hours: 1));
    case 'yarin':
      final bugun = istanbulGunu(simdi);
      return hatirlaticiAni(DateTime.utc(bugun.year, bugun.month, bugun.day + 1), saat);
    default:
      return null;
  }
}
