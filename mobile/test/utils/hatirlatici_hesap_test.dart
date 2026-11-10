import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/utils/hatirlatici_gorunum.dart';
import 'package:kafamdakiler/utils/hatirlatici_hesap.dart';
import 'package:kafamdakiler/utils/hatirlatici_islemleri.dart';

import '../test_destek.dart';

// The Dart port of the server's recurrence math (backend.Tests/HatirlaticiHesapTests.cs): the same cases, so the
// phone and the server agree on every moment.

DateTime z(String s) => DateTime.parse(s);

DateTime ist(String gun, [String saat = '09:00']) => hatirlaticiAni(DateTime.parse('${gun}T00:00:00Z'), Saat.coz(saat));

DateTime gun(int y, int m, int d) => DateTime.utc(y, m, d);

const dokuz = Saat(9, 0);

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  test('hatirlaticiAni converts Istanbul to UTC', () {
    expect(ist('2026-11-06'), z('2026-11-06T06:00:00Z'));
  });

  group('sonrakiHatirlaticiAni', () {
    test('a one-off is its own moment, even when past', () {
      expect(sonrakiHatirlaticiAni(Tekrar.yok, gun(2026, 1, 1), dokuz, z('2026-11-06T00:00:00Z')), ist('2026-01-01'));
    });

    test('daily: today if not yet passed, else tomorrow', () {
      final b = gun(2026, 11, 1);
      expect(sonrakiHatirlaticiAni(Tekrar.gunluk, b, dokuz, z('2026-11-06T05:59:00Z')), ist('2026-11-06'));
      expect(sonrakiHatirlaticiAni(Tekrar.gunluk, b, dokuz, z('2026-11-06T06:00:00Z')), ist('2026-11-07'));
    });

    test('a start in the future is the start itself', () {
      expect(sonrakiHatirlaticiAni(Tekrar.gunluk, gun(2027, 3, 1), dokuz, z('2026-11-06T00:00:00Z')), ist('2027-03-01'));
      expect(sonrakiHatirlaticiAni(Tekrar.aylik, gun(2027, 3, 31), dokuz, z('2026-11-06T00:00:00Z')), ist('2027-03-31'));
    });

    test('weekly keeps the weekday', () {
      final sonuc = sonrakiHatirlaticiAni(Tekrar.haftalik, gun(2026, 11, 2), dokuz, z('2026-11-06T00:00:00Z'));
      expect(sonuc, ist('2026-11-09'));
      expect(istanbulGunu(sonuc).weekday, DateTime.monday);
    });

    for (final (simdi, beklenen) in [
      ('2026-12-31T10:00:00Z', '2027-01-31'),
      ('2027-01-31T10:00:00Z', '2027-02-28'), // 31 -> end of a common February
      ('2027-02-28T10:00:00Z', '2027-03-31'), // and back to the 31st: counted from the start day
      ('2027-03-31T10:00:00Z', '2027-04-30'),
      ('2027-12-31T10:00:00Z', '2028-01-31'),
      ('2028-01-31T10:00:00Z', '2028-02-29'), // leap year
    ]) {
      test('monthly from the 31st: $simdi -> $beklenen', () {
        expect(sonrakiHatirlaticiAni(Tekrar.aylik, gun(2026, 10, 31), dokuz, z(simdi)), ist(beklenen));
      });
    }

    test('monthly from the 30th gives the end of February', () {
      expect(sonrakiHatirlaticiAni(Tekrar.aylik, gun(2026, 11, 30), dokuz, z('2027-01-30T10:00:00Z')), ist('2027-02-28'));
      expect(sonrakiHatirlaticiAni(Tekrar.aylik, gun(2026, 11, 30), dokuz, z('2028-01-30T10:00:00Z')), ist('2028-02-29'));
    });

    for (final (simdi, beklenen) in [('2026-03-10T00:00:00Z', '2026-03-15'), ('2026-03-15T10:00:00Z', '2027-03-15')]) {
      test('yearly repeats on the same date: $simdi', () {
        expect(sonrakiHatirlaticiAni(Tekrar.yillik, gun(2024, 3, 15), dokuz, z(simdi)), ist(beklenen));
      });
    }

    for (final (simdi, beklenen) in [
      ('2027-01-01T00:00:00Z', '2027-02-28'), // common year
      ('2028-01-01T00:00:00Z', '2028-02-29'), // leap year
      ('2028-03-01T00:00:00Z', '2029-02-28'),
      ('2031-03-01T00:00:00Z', '2032-02-29'),
    ]) {
      test('yearly from 29 Feb: $simdi -> $beklenen', () {
        expect(sonrakiHatirlaticiAni(Tekrar.yillik, gun(2024, 2, 29), dokuz, z(simdi)), ist(beklenen));
      });
    }

    test('far in the past still finds the next turn', () {
      expect(sonrakiHatirlaticiAni(Tekrar.gunluk, gun(2000, 1, 1), dokuz, z('2026-11-06T10:00:00Z')), ist('2026-11-07'));
      expect(sonrakiHatirlaticiAni(Tekrar.aylik, gun(2000, 1, 31), dokuz, z('2026-11-06T10:00:00Z')), ist('2026-11-30'));
      expect(sonrakiHatirlaticiAni(Tekrar.aylik, gun(2000, 1, 31), dokuz, z('2026-12-31T10:00:00Z')), ist('2027-01-31'));
      expect(sonrakiHatirlaticiAni(Tekrar.yillik, gun(1990, 1, 1), dokuz, z('2026-11-06T10:00:00Z')), ist('2027-01-01'));
    });

    test('uses the Istanbul midnight, not UTC', () {
      // 22:30Z on Nov 5 is already 01:30 on Nov 6 in Istanbul. A 00:30 daily reminder fired at 00:30 Nov 6 (21:30Z).
      const yarimGece = Saat(0, 30);
      final b = gun(2026, 11, 1);
      expect(sonrakiHatirlaticiAni(Tekrar.gunluk, b, yarimGece, z('2026-11-05T22:30:00Z')), ist('2026-11-07', '00:30'));
      expect(sonrakiHatirlaticiAni(Tekrar.gunluk, b, yarimGece, z('2026-11-05T21:00:00Z')), ist('2026-11-06', '00:30'));
    });
  });

  // The weekly rule with several weekdays (UI revision, sözleşme §2): the same cases as the server's HatirlaticiHesapTests,
  // so the phone and the server agree on every moment. 2026-11-02 is a Monday.
  group('weekly on several days', () {
    const salPer = [HaftaGunu.sal, HaftaGunu.per];

    DateTime sonraki(String baslangic, String simdi, [List<HaftaGunu>? gunler = salPer]) {
      final b = DateTime.parse('${baslangic}T00:00:00Z');
      return sonrakiHatirlaticiAni(Tekrar.haftalik, b, dokuz, z(simdi), gunler: gunler);
    }

    test('before the first chosen day it is that day; on it, before the hour, it is today', () {
      expect(sonraki('2026-11-02', '2026-11-02T10:00:00Z'), ist('2026-11-03'), reason: 'Monday -> Tuesday');
      expect(sonraki('2026-11-02', '2026-11-03T05:00:00Z'), ist('2026-11-03'), reason: 'Tuesday 08:00 Istanbul, hour not reached');
    });

    test('after the hour of a chosen day the next chosen day comes, across the weekend into the next week', () {
      expect(sonraki('2026-11-02', '2026-11-03T07:00:00Z'), ist('2026-11-05'), reason: 'Tuesday after 09:00 -> Thursday');
      expect(sonraki('2026-11-02', '2026-11-05T07:00:00Z'), ist('2026-11-10'), reason: 'Thursday after 09:00 -> next Tuesday');
    });

    test('a start in the future waits for its first chosen weekday', () {
      expect(sonraki('2026-12-01', '2026-11-06T00:00:00Z'), ist('2026-12-01'), reason: 'the start day is a Tuesday');
      expect(sonraki('2026-12-02', '2026-11-06T00:00:00Z'), ist('2026-12-03'), reason: 'a Wednesday start -> Thursday');
    });

    test('no days chosen (null or empty) is the old rule: the weekday of the start', () {
      final eski = sonrakiHatirlaticiAni(Tekrar.haftalik, gun(2026, 11, 2), dokuz, z('2026-11-06T00:00:00Z'));
      expect(sonraki('2026-11-02', '2026-11-06T00:00:00Z', null), eski);
      expect(sonraki('2026-11-02', '2026-11-06T00:00:00Z', const []), eski);
    });

    test('days only count for a weekly repeat', () {
      final b = gun(2026, 11, 2);
      expect(sonrakiHatirlaticiAni(Tekrar.gunluk, b, dokuz, z('2026-11-06T06:00:00Z'), gunler: salPer), ist('2026-11-07'));
    });

    test('the Istanbul day decides, not the UTC one', () {
      // Tuesday 23:30 UTC is Wednesday 02:30 in Istanbul: Tuesday is over, the next one is Thursday.
      expect(sonraki('2026-11-02', '2026-11-03T23:30:00Z'), ist('2026-11-05'));
    });

    test('Yaptım on a multi-day reminder moves to the next chosen day; a new one built from a write gets its first moment', () {
      final yaz = HatirlaticiYaz(id: 'h', baslik: 'Spor', gun: gun(2026, 11, 2), tekrar: Tekrar.haftalik, gunler: salPer);
      final h = hatirlaticiYazdan(yaz, z('2026-11-02T10:00:00Z'));
      expect(h.sonrakiAn, ist('2026-11-03'));
      expect(h.gunler, salPer);

      final sonra = hatirlaticiYaptim(h, z('2026-11-03T07:00:00Z'));
      expect(sonra.sonrakiAn, ist('2026-11-05'));
      expect(sonra.gunler, salPer);
    });
  });

  test('istanbulGunu rolls over at UTC+3', () {
    expect(istanbulGunu(z('2026-11-05T20:59:59Z')), gun(2026, 11, 5));
    expect(istanbulGunu(z('2026-11-05T21:00:00Z')), gun(2026, 11, 6));
  });

  test('hatirlaticiKalanGun counts Istanbul days', () {
    final simdi = z('2026-11-05T22:00:00Z'); // 01:00 on Nov 6 in Istanbul
    expect(hatirlaticiKalanGun(ist('2026-11-06'), simdi), 0);
    expect(hatirlaticiKalanGun(ist('2026-11-09', '00:10'), simdi), 3);
    expect(hatirlaticiKalanGun(ist('2026-11-05', '23:00'), simdi), -1);
  });

  test('hatirlaticiOnceAni is days before, at the same hour', () {
    expect(hatirlaticiOnceAni(ist('2026-12-15'), 3), ist('2026-12-12'));
    expect(hatirlaticiOnceAni(ist('2026-03-02', '18:45'), 3), ist('2026-02-27', '18:45'));
    expect(hatirlaticiOnceAni(ist('2026-12-15'), 0), isNull);
  });

  test('hatirlaticiErteleAni: one hour, tomorrow at the rule hour', () {
    final simdi = z('2026-11-05T22:00:00Z'); // 01:00 on Nov 6 in Istanbul
    expect(hatirlaticiErteleAni('1s', simdi, dokuz), z('2026-11-05T23:00:00Z'));
    expect(hatirlaticiErteleAni('yarin', simdi, dokuz), ist('2026-11-07'));
    expect(hatirlaticiErteleAni('2s', simdi, dokuz), isNull);
    expect(hatirlaticiErteleAni(null, simdi, dokuz), isNull);
  });

  group('Yaptım and Ertele', () {
    Hatirlatici yeni(Tekrar tekrar, [String baslangic = '2026-11-10']) {
      final g = DateTime.parse('${baslangic}T00:00:00Z');
      return ornekHatirlatici(
        gun: g,
        tekrar: tekrar,
        sonrakiAn: sonrakiHatirlaticiAni(tekrar, g, dokuz, z('2026-11-06T00:00:00Z')),
      );
    }

    test('a one-off becomes tamam and loses its snooze', () {
      final h = hatirlaticiYaptim(yeni(Tekrar.yok).copyWith(erteleAn: z('2026-11-09T00:00:00Z')), z('2026-11-10T07:00:00Z'));
      expect(h.durum, HatirlaticiDurumu.tamam);
      expect(h.erteleAn, isNull);
    });

    test('a repeating one moves to the next turn and clears the snooze', () {
      final h = hatirlaticiYaptim(yeni(Tekrar.gunluk).copyWith(erteleAn: z('2026-11-10T08:00:00Z')), z('2026-11-10T09:00:00Z'));
      expect(h.durum, HatirlaticiDurumu.acik);
      expect(h.sonrakiAn, ist('2026-11-11'));
      expect(h.erteleAn, isNull);
    });

    test('marked early, the turn that was due is skipped', () {
      final h = hatirlaticiYaptim(yeni(Tekrar.haftalik), z('2026-11-06T10:00:00Z'));
      expect(h.sonrakiAn, ist('2026-11-17'));
    });

    test('monthly from the 31st keeps the start day', () {
      var h = yeni(Tekrar.aylik, '2026-10-31');
      expect(h.sonrakiAn, ist('2026-11-30'));
      h = hatirlaticiYaptim(h, z('2026-11-30T09:00:00Z'));
      expect(h.sonrakiAn, ist('2026-12-31'));
    });

    test('a closed reminder stays as it is', () {
      final h = yeni(Tekrar.yok).copyWith(durum: HatirlaticiDurumu.arsiv);
      expect(identical(hatirlaticiYaptim(h, z('2026-11-10T07:00:00Z')), h), isTrue);
      expect(identical(hatirlaticiErtele(h, '1s', z('2026-11-10T07:00:00Z')), h), isTrue);
    });

    test('Ertele sets erteleAn and leaves the rule alone', () {
      final h = yeni(Tekrar.gunluk);
      final simdi = z('2026-11-10T10:00:00Z');

      final bir = hatirlaticiErtele(h, '1s', simdi);
      expect(bir.erteleAn, z('2026-11-10T11:00:00Z'));
      expect(bir.sonrakiAn, h.sonrakiAn);
      expect(bir.etkinAn, bir.erteleAn);

      final yarin = hatirlaticiErtele(h, 'yarin', simdi);
      expect(yarin.erteleAn, ist('2026-11-11'));
      expect(yarin.sonrakiAn, h.sonrakiAn);
    });

    test('an unknown duration changes nothing', () {
      final h = yeni(Tekrar.yok);
      expect(identical(hatirlaticiErtele(h, '2s', z('2026-11-10T10:00:00Z')), h), isTrue);
    });
  });

  test('hatirlaticiYazdan builds the reminder: trims, keeps Kime only for Söz, computes the next moment', () {
    final h = hatirlaticiYazdan(
      HatirlaticiYaz(
        id: 'h9',
        baslik: '  Kitabı geri ver ',
        not: '  ',
        tur: HatirlaticiTuru.gorev,
        kime: 'Ali',
        gun: gun(2026, 11, 30),
        tekrar: Tekrar.aylik,
      ),
      z('2026-12-05T00:00:00Z'),
    );
    expect(h.baslik, 'Kitabı geri ver');
    expect(h.not, isNull);
    expect(h.kime, isNull, reason: 'Kime is for Söz only');
    expect(h.sonrakiAn, ist('2026-12-30'));
    expect(h.createdAt, z('2026-12-05T00:00:00Z'));
  });

  group('display texts', () {
    test('kalanGunMetni', () {
      expect(kalanGunMetni(0), 'bugün');
      expect(kalanGunMetni(1), 'yarın');
      expect(kalanGunMetni(3), '3 gün sonra');
      expect(kalanGunMetni(-1), '1 gün gecikti');
      expect(kalanGunMetni(-2), '2 gün gecikti');
    });

    test('the names', () {
      expect(hatirlaticiTurAdi(HatirlaticiTuru.ozelTarih), 'Özel tarih');
      expect(hatirlaticiDurumAdi(HatirlaticiDurumu.arsiv), 'Arşiv');
      expect(tekrarAdi(Tekrar.yillik), 'Her yıl');
    });
  });
}
