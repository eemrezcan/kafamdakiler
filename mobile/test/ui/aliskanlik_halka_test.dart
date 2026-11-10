import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/ui/bugun/aliskanlik_seridi.dart';

import '../test_destek.dart';

/// The ring of a habit on Bugün's strip: one calculation ([halkaDurumu]) and what the strip shows with it.
void main() {
  Aliskanlik halka({
    AliskanlikTuru tur = AliskanlikTuru.sayac,
    Olcu olcu = Olcu.sayili,
    HedefYonu yon = HedefYonu.enAz,
    double? hedef = 8,
    double miktar = 0,
    double deger = 0,
  }) =>
      ornekAliskanlik(tur: tur, olcu: olcu, yon: yon, hedef: hedef, miktar: miktar).copyWith(
        bugun: BugunDurumu(tarih: DateTime.utc(2026, 10, 31), miktar: miktar, deger: deger, planli: true),
      );

  group('halkaDurumu', () {
    test('a yes/no habit follows `deger`', () {
      expect(halkaDurumu(halka(olcu: Olcu.evetHayir, deger: 0)), (oran: 0.0, asildi: false, tamam: false));
      expect(halkaDurumu(halka(olcu: Olcu.evetHayir, deger: 1)), (oran: 1.0, asildi: false, tamam: true));
    });

    test('a counter is the amount against the daily goal, not `deger`', () {
      expect(halkaDurumu(halka(miktar: 2, hedef: 8, deger: 1)), (oran: 0.25, asildi: false, tamam: false));
      expect(halkaDurumu(halka(miktar: 8, hedef: 8, deger: 0)), (oran: 1.0, asildi: false, tamam: true));
      expect(halkaDurumu(halka(miktar: 12, hedef: 8)), (oran: 1.0, asildi: false, tamam: true), reason: 'past the goal stays full');
    });

    test('a shelf habit is today\'s reading against the goal', () {
      expect(halkaDurumu(halka(tur: AliskanlikTuru.raf, miktar: 12, hedef: 30)), (oran: 0.4, asildi: false, tamam: false));
      expect(halkaDurumu(halka(tur: AliskanlikTuru.raf, miktar: 30, hedef: 30)).tamam, isTrue);
      expect(halkaDurumu(halka(tur: AliskanlikTuru.raf, miktar: 0, hedef: 30)).oran, 0);
    });

    test('a limit habit fills towards its limit and is over (red) only past it', () {
      expect(halkaDurumu(halka(yon: HedefYonu.enCok, miktar: 1, hedef: 3)), (oran: 1 / 3, asildi: false, tamam: false));
      expect(halkaDurumu(halka(yon: HedefYonu.enCok, miktar: 3, hedef: 3)), (oran: 1.0, asildi: false, tamam: false), reason: 'at the limit is still fine');
      expect(halkaDurumu(halka(yon: HedefYonu.enCok, miktar: 4, hedef: 3)), (oran: 1.0, asildi: true, tamam: false));
    });

    test('without a goal it falls back to `deger`', () {
      expect(halkaDurumu(halka(hedef: null, miktar: 5, deger: 0.5)), (oran: 0.5, asildi: false, tamam: false));
    });
  });

  group('the strip', () {
    Future<void> goster(WidgetTester tester, List<Aliskanlik> liste) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AliskanlikSeridi(aliskanliklar: liste, onTik: (_) {}, onArti: (_) {}, onSayiGir: (_) {}, onRafAc: (_) {}),
        ),
      ));
    }

    testWidgets('an item is 76 dp wide and a long name takes two centred lines, not cut', (tester) async {
      final uzun = ornekAliskanlik(id: 'u', ad: 'Şekerli içecek içmeme', yon: HedefYonu.enCok, hedef: 1, birim: 'bardak');
      await goster(tester, [uzun]);

      expect(tester.getSize(find.byKey(const ValueKey('serit-u'))).width, 76);
      final ad = tester.widget<Text>(find.text('Şekerli içecek içmeme'));
      expect(ad.maxLines, 2);
      expect(ad.textAlign, TextAlign.center);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the ring of a counter is drawn from the amount; a limit habit past its limit is red', (tester) async {
      final su = halka(miktar: 2, hedef: 8, deger: 1);
      final sinir = halka(yon: HedefYonu.enCok, miktar: 4, hedef: 3);
      await goster(tester, [
        su.copyWith(),
        // A second habit needs its own id: a copy with another id through the constructor of the fixture.
        ornekAliskanlik(id: 'b', yon: HedefYonu.enCok, hedef: 3, miktar: 4).copyWith(bugun: sinir.bugun),
      ]);

      final halkalar = tester.widgetList<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).toList();
      expect(halkalar[0].value, 0.25, reason: 'amount/goal, not `deger` (1)');
      expect(halkalar[1].value, 1.0);
      final tema = Theme.of(tester.element(find.byType(AliskanlikSeridi)));
      expect(halkalar[1].color, tema.colorScheme.error);
    });
  });
}
