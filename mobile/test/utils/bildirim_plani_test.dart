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

  group('nagging (Israrlı)', () {
    test('a plain reminder gets no nags', () {
      final plan = bildirimleriPlanla([ornekHatirlatici(id: 'a', sonrakiAn: z('2026-11-09T06:00:00Z'))], simdi);
      expect(plan, hasLength(1));
      expect(plan.single.israrNo, 0);
    });

    test('up to israrEnCok nags follow the moment, israrAraligiDakika apart', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', israrli: true, israrAraligiDakika: 15, israrEnCok: 3, sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi);
      expect(plan.map((b) => b.an), [
        z('2026-11-09T06:00:00Z'),
        z('2026-11-09T06:15:00Z'),
        z('2026-11-09T06:30:00Z'),
        z('2026-11-09T06:45:00Z'),
      ]);
      expect(plan.map((b) => b.israrNo), [0, 1, 2, 3]);
      expect(plan[1].govde, 'hâlâ yapılmadı (1/3)');
      expect(plan[1].baslik, plan[0].baslik);
      expect(plan.every((b) => b.eylemler), isTrue, reason: 'every nag offers Yaptım and the snoozes');
      expect(plan.map((b) => b.id).toSet(), hasLength(4), reason: 'each nag has an id of its own');
    });

    test('the interval is the stored one (5, 15 or 60 minutes)', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', israrli: true, israrAraligiDakika: 60, israrEnCok: 2, sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi);
      expect(plan.map((b) => b.an), [z('2026-11-09T06:00:00Z'), z('2026-11-09T07:00:00Z'), z('2026-11-09T08:00:00Z')]);
    });

    test('more than four nags are never planned', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', israrli: true, israrAraligiDakika: 5, israrEnCok: 9, sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi);
      expect(plan, hasLength(1 + enCokIsrarSayisi));
    });

    test('after the moment passed, the nags still ahead stay planned', () {
      // 09:00Z is "now"; the moment was 08:40Z, so the 08:55Z nag is gone and 09:10Z and 09:25Z remain.
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', israrli: true, israrAraligiDakika: 15, israrEnCok: 3, sonrakiAn: z('2026-11-06T08:40:00Z')),
      ], simdi);
      expect(plan.map((b) => b.an), [z('2026-11-06T09:10:00Z'), z('2026-11-06T09:25:00Z')]);
      expect(plan.map((b) => b.israrNo), [2, 3]);
    });

    test('a snooze moves the nags with it; the old ones are not planned any more', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(
          id: 'a',
          israrli: true,
          israrEnCok: 2,
          sonrakiAn: z('2026-11-06T08:50:00Z'),
          erteleAn: z('2026-11-06T12:00:00Z'),
        ),
      ], simdi);
      expect(plan.map((b) => b.an), [z('2026-11-06T12:00:00Z'), z('2026-11-06T12:15:00Z'), z('2026-11-06T12:30:00Z')]);
    });

    test('a reminder marked done has no nags left', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', israrli: true, durum: HatirlaticiDurumu.tamam, sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi);
      expect(plan, isEmpty);
    });

    test('the heads-up is never nagged', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', israrli: true, israrEnCok: 1, onceGun: 3, sonrakiAn: z('2026-12-15T06:00:00Z')),
      ], simdi);
      expect(plan.where((b) => b.onceUyarisi), hasLength(1));
      expect(plan.firstWhere((b) => b.onceUyarisi).israrNo, 0);
      expect(plan.firstWhere((b) => b.onceUyarisi).acil, isFalse);
      expect(plan.where((b) => b.israrNo > 0), hasLength(1));
    });

    test('users who cannot write get no buttons on the nags either', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', israrli: true, sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi, eylemler: false);
      expect(plan.every((b) => !b.eylemler), isTrue);
    });
  });

  group('urgent (Acil)', () {
    test('the moment and its nags are marked urgent; a plain reminder and the heads-up are not', () {
      final plan = bildirimleriPlanla([
        ornekHatirlatici(id: 'a', acil: true, israrli: true, israrEnCok: 1, onceGun: 3, sonrakiAn: z('2026-12-15T06:00:00Z')),
        ornekHatirlatici(id: 'b', sonrakiAn: z('2026-11-09T06:00:00Z')),
      ], simdi);
      final acilOlanlar = plan.where((b) => b.acil).map((b) => (b.hatirlaticiId, b.onceUyarisi, b.israrNo)).toList();
      expect(acilOlanlar, unorderedEquals([('a', false, 0), ('a', false, 1)]));
      expect(plan.where((b) => b.hatirlaticiId == 'b').single.acil, isFalse);
    });

    test('Acil on its own does not nag', () {
      final plan = bildirimleriPlanla([ornekHatirlatici(id: 'a', acil: true, sonrakiAn: z('2026-11-09T06:00:00Z'))], simdi);
      expect(plan, hasLength(1));
    });
  });

  group('nag ids', () {
    test('the nag ids differ from the moment id and from each other, and stay the same between plans', () {
      final kimlikler = {for (var n = 0; n <= 4; n++) bildirimKimligi('abc', israrNo: n)};
      expect(kimlikler, hasLength(5));
      expect(bildirimKimligi('abc', israrNo: 2), bildirimKimligi('abc', israrNo: 2));
      expect(bildirimKimligi('abc', israrNo: 0), bildirimKimligi('abc'));
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
