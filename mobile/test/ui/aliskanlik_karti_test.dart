import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/gun.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/ui/bugun/aliskanlik_karti.dart';

import '../test_destek.dart';

/// The habit card (the habits list of the next phase builds on it): progress, strength, the tick, the shelf card and the
/// last 7 days strip. It used to be tested through the old Bugün screen.
void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  Future<void> goster(WidgetTester tester, Aliskanlik a, {List<Gun>? gunler, Size boyut = const Size(360, 800)}) async {
    tester.view.physicalSize = boyut;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [AliskanlikKarti(aliskanlik: a, sonGunler: gunler, onTik: () {}, onMiktar: (_, _) {}, onSayiGir: () {})],
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('shows progress, strength and the counter\'s buttons; no overflow at 360 dp', (tester) async {
    await goster(tester, ornekAliskanlik(ad: 'Çok uzun bir alışkanlık adı taşmamalı ekranda', miktar: 6));

    expect(find.textContaining('Güç %50'), findsOneWidget);
    expect(find.byTooltip('Bir artır'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a yes/no habit has the tick button', (tester) async {
    await goster(tester, ornekAliskanlik(ad: 'Yoga', olcu: Olcu.evetHayir));
    expect(find.byTooltip('Yapıldı olarak işaretle'), findsOneWidget);
  });

  testWidgets('shelf card with several books: covers pick the book, the first one opens selected', (tester) async {
    const ilk = OgeOzet(id: 'k1', ad: 'Kürk Mantolu Madonna', guncelKonum: 59, toplam: 356, ilerleme: 0.17);
    const ikinci = OgeOzet(id: 'k2', ad: 'Tutunamayanlar', guncelKonum: 120, toplam: 724, ilerleme: 0.17);
    await goster(
      tester,
      ornekAliskanlik(id: 'r', ad: 'Kitap oku', tur: AliskanlikTuru.raf, birim: 'sayfa', hedef: 30, devamEdenler: const [ilk, ikinci]),
    );

    // Only the chosen book's details are shown; the API sends the most recent one first.
    expect(find.text('Kürk Mantolu Madonna'), findsOneWidget);
    expect(find.text('Tutunamayanlar'), findsNothing);

    await tester.tap(find.byTooltip('Tutunamayanlar'));
    await tester.pump();
    expect(find.text('Tutunamayanlar'), findsOneWidget);
    expect(find.text('Kürk Mantolu Madonna'), findsNothing);
    expect(find.text('Okudum'), findsOneWidget);
    expect(find.text('Kronometre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last 7 days strip: day names under the card, none without the days', (tester) async {
    // 25-31 October 2026, ending on the fixed "today" (a Saturday).
    final gunler = [
      for (var i = 6; i >= 0; i--)
        Gun(tarih: sabitBugun.subtract(Duration(days: i)), miktar: i.isEven ? 8 : 0, deger: i.isEven ? 1 : 0, planli: true, guc: 0.5),
    ];
    await goster(tester, ornekAliskanlik(id: 'a', ad: 'Su', miktar: 3), gunler: gunler);

    for (final ad in ['PAZ', 'PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT']) {
      expect(find.text(ad), findsOneWidget, reason: ad);
    }
    expect(tester.takeException(), isNull);

    await goster(tester, ornekAliskanlik(id: 'a', ad: 'Su', miktar: 3));
    expect(find.text('CMT'), findsNothing);
  });
}
