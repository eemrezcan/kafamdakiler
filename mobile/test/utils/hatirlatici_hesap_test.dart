import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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

    test('tekrarOzeti', () {
      expect(tekrarOzeti(Tekrar.yok, gun(2026, 10, 31)), isNull);
      expect(tekrarOzeti(Tekrar.gunluk, gun(2026, 10, 31)), 'her gün');
      expect(tekrarOzeti(Tekrar.haftalik, gun(2026, 11, 2)), 'her hafta Pazartesi');
      expect(tekrarOzeti(Tekrar.aylik, gun(2026, 10, 31)), "her ay 31'inde");
      expect(tekrarOzeti(Tekrar.aylik, gun(2026, 10, 2)), "her ay 2'sinde");
      expect(tekrarOzeti(Tekrar.aylik, gun(2026, 10, 3)), "her ay 3'ünde");
      expect(tekrarOzeti(Tekrar.aylik, gun(2026, 10, 6)), "her ay 6'sında");
      expect(tekrarOzeti(Tekrar.aylik, gun(2026, 10, 30)), "her ay 30'unda");
      expect(tekrarOzeti(Tekrar.yillik, gun(2024, 2, 29)), 'her yıl 29 Şubat');
    });

    test('onceNotu and names', () {
      expect(onceNotu(0), isNull);
      expect(onceNotu(3), '3 gün önce de haber verilir');
      expect(hatirlaticiTurAdi(HatirlaticiTuru.ozelTarih), 'Özel tarih');
      expect(hatirlaticiDurumAdi(HatirlaticiDurumu.arsiv), 'Arşiv');
      expect(tekrarAdi(Tekrar.yillik), 'Her yıl');
    });
  });
}
