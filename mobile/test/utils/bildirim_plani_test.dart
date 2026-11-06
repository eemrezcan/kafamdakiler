import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/utils/bildirim_plani.dart';

import '../test_destek.dart';

// Which notifications are set up for which reminder: pure planning logic, no plugin involved.

DateTime z(String s) => DateTime.parse(s);

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  // 2026-11-06 12:00 Istanbul.
  final simdi = z('2026-11-06T09:00:00Z');

  group('what is scheduled', () {
    test('an open reminder gets a notification at its moment, with its title and "bugün"', () {
      final plan = bildirimleriPlanla([ornekHatirlatici(id: 'a', baslik: 'Faturayı öde', sonrakiAn: z('2026-11-09T06:00:00Z'))], simdi);
      expect(plan, hasLength(1));
      expect(plan.single.an, z('2026-11-09T06:00:00Z'));
      expect(plan.single.baslik, 'Faturayı öde');
      expect(plan.single.govde, 'bugün');
      expect(plan.single.hatirlaticiId, 'a');
      expect(plan.single.onceUyarisi, isFalse);
      expect(plan.single.eylemler, isTrue);
    });

    test('a past moment is skipped (it would show at once or never)', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'gecmis', sonrakiAn: z('2026-11-06T06:00:00Z')),
        ornekHatirlatici(id: 'tam', sonrakiAn: simdi),
      ], simdi);
      expect(plan, isEmpty);
    });

    test('done and archived reminders are not scheduled', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', durum: HatirlaticiDurumu.tamam, sonrakiAn: z('2026-11-09T06:00:00Z')),
        ornekHatirlatici(id: 'b', durum: HatirlaticiDurumu.arsiv, sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi);
      expect(plan, isEmpty);
    });

    test('a snooze replaces the moment; its past rule moment is not scheduled', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', sonrakiAn: z('2026-11-06T06:00:00Z'), erteleAn: z('2026-11-06T10:00:00Z')),
      ], simdi);
      expect(plan.single.an, z('2026-11-06T10:00:00Z'));
    });

    test('a snooze that already passed leaves nothing, even if the rule moment is ahead', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', sonrakiAn: z('2026-11-20T06:00:00Z'), erteleAn: z('2026-11-06T08:00:00Z')),
      ], simdi);
      expect(plan, isEmpty, reason: 'the snooze is the effective moment');
    });

    test('plan is sorted by moment', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'c', sonrakiAn: z('2026-11-20T06:00:00Z')),
        ornekHatirlatici(id: 'a', sonrakiAn: z('2026-11-08T06:00:00Z')),
        ornekHatirlatici(id: 'b', sonrakiAn: z('2026-11-10T06:00:00Z')),
      ], simdi);
      expect(plan.map((b) => b.hatirlaticiId), ['a', 'b', 'c']);
    });
  });

  group('heads-up ("önce")', () {
    test('a second notification, days before at the same hour, with the days left in the title', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', baslik: 'Annemin doğum günü', onceGun: 3, sonrakiAn: z('2026-12-15T06:00:00Z')),
      ], simdi);
      expect(plan, hasLength(2));
      final once = plan.first;
      expect(once.onceUyarisi, isTrue);
      expect(once.an, z('2026-12-12T06:00:00Z'));
      expect(once.baslik, '3 gün sonra: Annemin doğum günü');
      expect(once.govde, '15 Aralık Salı, 09:00');
      expect(once.eylemler, isFalse, reason: 'Yaptım belongs to the moment itself');
      expect(plan.last.onceUyarisi, isFalse);
      expect(plan.last.an, z('2026-12-15T06:00:00Z'));
    });

    test('a heads-up that already passed is skipped but the moment itself stays', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', onceGun: 3, sonrakiAn: z('2026-11-08T06:00:00Z')),
      ], simdi);
      expect(plan, hasLength(1));
      expect(plan.single.onceUyarisi, isFalse);
    });

    test('no heads-up when onceGun is 0', () {
      final plan = bildirimleriPlanla([ornekHatirlatici(id: 'a', sonrakiAn: z('2026-12-15T06:00:00Z'))], simdi);
      expect(plan, hasLength(1));
    });

    test('a heads-up of one day reads "yarın"', () {
      final plan = bildirimleriPlanla([ornekHatirlatici(id: 'a', baslik: 'X', onceGun: 1, sonrakiAn: z('2026-11-10T06:00:00Z'))], simdi);
      expect(plan.first.baslik, 'yarın: X');
    });

    test('the heads-up stays tied to the rule when the reminder is snoozed', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', onceGun: 3, sonrakiAn: z('2026-12-15T06:00:00Z'), erteleAn: z('2026-11-07T06:00:00Z')),
      ], simdi);
      expect(plan.map((b) => b.an), [z('2026-11-07T06:00:00Z'), z('2026-12-12T06:00:00Z')]);
    });
  });

  group('texts', () {
    test('a promise says who it was made to', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', tur: HatirlaticiTuru.soz, kime: 'Ali', baslik: 'Kitabı ver', sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi);
      expect(plan.single.govde, 'bugün · Kime: Ali');
    });

    test('Kime is not shown for a task even if it were stored', () {
      final plan = bildirimleriPlanla([ornekHatirlatici(id: 'a', kime: 'Ali', sonrakiAn: z('2026-11-09T06:00:00Z'))], simdi);
      expect(plan.single.govde, 'bugün');
    });

    test('users who cannot write get no buttons', () {
      final plan = bildirimleriPlanla([ornekHatirlatici(id: 'a', sonrakiAn: z('2026-11-09T06:00:00Z'))], simdi, eylemler: false);
      expect(plan.single.eylemler, isFalse);
    });
  });

  group('ids', () {
    test('the same reminder always gets the same ids', () {
      expect(bildirimKimligi('019e2000-0000-7000-8000-000000000001'), bildirimKimligi('019e2000-0000-7000-8000-000000000001'));
      expect(bildirimKimligi('x', onceUyarisi: true), bildirimKimligi('x', onceUyarisi: true));
    });

    test('the heads-up has an id of its own, next to the moment id', () {
      final a = bildirimKimligi('abc');
      final b = bildirimKimligi('abc', onceUyarisi: true);
      expect(a, isNot(b));
      expect(a >> 1, b >> 1);
    });

    test('different reminders get different ids', () {
      final idler = {for (var i = 0; i < 500; i++) bildirimKimligi('019e2000-0000-7000-8000-${i.toString().padLeft(12, '0')}')};
      expect(idler, hasLength(500));
    });

    test('an id is a positive 31-bit number (Android)', () {
      for (final id in ['a', 'b', '019e2000-0000-7000-8000-000000000001', 'zzzzzzzzzzzzzzzzzzzz']) {
        for (final once in [false, true]) {
          final k = bildirimKimligi(id, onceUyarisi: once);
          expect(k, inInclusiveRange(0, 0x7FFFFFFF));
        }
      }
    });

    test('the plan uses the stable ids', () {
      final h = ornekHatirlatici(id: 'abc', onceGun: 3, sonrakiAn: z('2026-12-15T06:00:00Z'));
      final plan = bildirimleriPlanla([h], simdi);
      expect(plan.map((b) => b.id).toSet(), {bildirimKimligi('abc'), bildirimKimligi('abc', onceUyarisi: true)});
      // Planned again later with the same data: the same ids, so the new plan replaces the old one.
      expect(bildirimleriPlanla([h], simdi).map((b) => b.id), plan.map((b) => b.id));
    });
  });
}
