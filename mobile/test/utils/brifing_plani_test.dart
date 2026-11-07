import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/utils/bildirim_plani.dart';

// When the morning briefing notification comes: pure planning logic, no plugin involved. Istanbul time is UTC+3.

DateTime z(String s) => DateTime.parse(s);

void main() {
  group('the next moment', () {
    test('before the hour today: today at 06:30 Istanbul (03:30Z), repeating daily', () {
      final b = brifingBildirimiPlanla(BrifingAyari.varsayilan, z('2026-11-08T02:00:00Z'), okuyabilir: true)!;
      expect(b.an, z('2026-11-08T03:30:00Z'));
      expect(b.gunlukTekrar, isTrue);
      expect(b.brifingMi, isTrue);
      expect(b.hatirlaticiId, brifingBildirimYuku);
      expect(b.eylemler, isFalse);
    });

    test('after the hour: tomorrow', () {
      final b = brifingBildirimiPlanla(BrifingAyari.varsayilan, z('2026-11-08T05:00:00Z'), okuyabilir: true)!;
      expect(b.an, z('2026-11-09T03:30:00Z'));
    });

    test('exactly at the hour counts as passed', () {
      final b = brifingBildirimiPlanla(BrifingAyari.varsayilan, z('2026-11-08T03:30:00Z'), okuyabilir: true)!;
      expect(b.an, z('2026-11-09T03:30:00Z'));
    });

    test('a changed hour is followed, including one before 03:00 (the UTC day before)', () {
      final b = brifingBildirimiPlanla(const BrifingAyari(saat: 7, dakika: 5), z('2026-11-08T00:00:00Z'), okuyabilir: true)!;
      expect(b.an, z('2026-11-08T04:05:00Z'));
      final gece = brifingBildirimiPlanla(const BrifingAyari(saat: 1, dakika: 0), z('2026-11-08T12:00:00Z'), okuyabilir: true)!;
      expect(gece.an, z('2026-11-08T22:00:00Z'), reason: '01:00 Istanbul is 22:00Z the evening before');
    });
  });

  group('when there is none', () {
    test('turned off', () {
      expect(brifingBildirimiPlanla(const BrifingAyari(acik: false), z('2026-11-08T02:00:00Z'), okuyabilir: true), isNull);
    });

    test('the user may not read the briefing', () {
      expect(brifingBildirimiPlanla(BrifingAyari.varsayilan, z('2026-11-08T02:00:00Z'), okuyabilir: false), isNull);
    });
  });

  group('the stored setting', () {
    test('a missing or unusable value is the default; "kapali" is off; an hour round-trips', () {
      expect(BrifingAyari.oku(null).saatMetni, '06:30');
      expect(BrifingAyari.oku('abc').saatMetni, '06:30');
      expect(BrifingAyari.oku('25:00').saatMetni, '06:30');
      expect(BrifingAyari.oku('kapali').acik, isFalse);
      expect(BrifingAyari.oku('07:05').saatMetni, '07:05');
      expect(const BrifingAyari(acik: false).depolama, 'kapali');
      expect(const BrifingAyari(saat: 7, dakika: 5).depolama, '07:05');
    });
  });
}
