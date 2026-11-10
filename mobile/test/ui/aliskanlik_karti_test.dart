import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/ui/bugun/aliskanlik_karti.dart';

import '../test_destek.dart';

/// The habit card of the Alışkanlıklar list: progress, strength, the tick and the shelf card.
void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  Future<void> goster(WidgetTester tester, Aliskanlik a, {Size boyut = const Size(360, 800)}) async {
    tester.view.physicalSize = boyut;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [AliskanlikKarti(aliskanlik: a, onTik: () {}, onMiktar: (_, _) {}, onSayiGir: () {})],
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
}
