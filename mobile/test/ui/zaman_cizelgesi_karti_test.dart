import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/zaman_cizelgesi.dart';
import 'package:kafamdakiler/ui/bugun/zaman_cizelgesi_karti.dart';
import 'package:kafamdakiler/ui/bugun/zaman_cizelgesi_view_model.dart';

import '../data/zaman_cizelgesi_test.dart' show ornek;
import '../test_destek.dart';

// The timeline card of the Today tab (K2.3c): timed items on the strip in the server's order, the unhoured under them, the
// detail sheet, the offline note, the empty state when Google is not connected, and the card hiding when the read fails.

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  Future<ZamanCizelgesiViewModel> goster(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = ZamanCizelgesiViewModel(repo: ortam.zamanCizelgesi);
    addTearDown(vm.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ZamanCizelgesiKarti(viewModel: vm)))));
    await tester.runAsync(vm.yukle);
    await tester.pump();
    return vm;
  }

  testWidgets('timed items sit on the strip in order, the unhoured are listed under them, the capacity warning shows', (tester) async {
    ortam.api.zamanCizelgesiYaniti = ornek();
    await goster(tester);

    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Ekip toplantısı')).dy, lessThan(tester.getTopLeft(find.text('İlaç')).dy));
    expect(find.text('09:30 - 10:30 · 1 sa · Ofis'), findsOneWidget);
    expect(tester.getTopLeft(find.text('İlaç')).dy, lessThan(tester.getTopLeft(find.text('Rapor')).dy));
    expect(find.text('Saatsiz'), findsOneWidget);
    expect(find.byKey(const Key('zaman-kapasite')), findsOneWidget);
    expect(find.byKey(const Key('zaman-cevrimdisi')), findsNothing);
  });

  testWidgets('tapping an event opens its detail', (tester) async {
    ortam.api.zamanCizelgesiYaniti = ornek();
    await goster(tester);

    await tester.tap(find.text('Ekip toplantısı'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('zaman-ayrinti')), findsOneWidget);
    expect(find.text('Takvim etkinliği'), findsOneWidget);
    expect(find.text('Ofis'), findsOneWidget);
  });

  testWidgets('offline, the last kept timeline is shown with a note', (tester) async {
    ortam.api.zamanCizelgesiYaniti = ornek();
    await ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun);
    ortam.api.cevrimdisi = true;
    await goster(tester);

    expect(find.text('Ekip toplantısı'), findsOneWidget);
    expect(find.byKey(const Key('zaman-cevrimdisi')), findsOneWidget);
  });

  testWidgets('Google not connected: the reminders and the plan still show, with an explanation', (tester) async {
    ortam.api.zamanCizelgesiYaniti = ZamanCizelgesi(
      gun: '2026-10-31',
      google: GoogleDurumu.bagliDegil,
      plan: 'tamam',
      saatli: ornek().saatli.sublist(1),
      saatsiz: const [],
    );
    await goster(tester);

    expect(find.byKey(const Key('zaman-google')), findsOneWidget);
    expect(find.text('İlaç'), findsOneWidget);
  });

  testWidgets('an empty day takes no room: the plan card below already tells what the day holds', (tester) async {
    ortam.api.zamanCizelgesiYaniti = const ZamanCizelgesi(gun: '2026-10-31', google: GoogleDurumu.bagliDegil, plan: 'yok', saatli: [], saatsiz: []);
    await goster(tester);

    expect(find.byKey(const Key('zaman-cizelgesi')), findsNothing);
    expect(find.byKey(const Key('zaman-google')), findsNothing);
  });

  testWidgets('a refused read (403) hides the card', (tester) async {
    ortam.api.zamanCizelgesiYaniti = ornek();
    ortam.api.zamanCizelgesiHatasi = 403;
    await goster(tester);

    expect(find.byKey(const Key('zaman-cizelgesi')), findsNothing);
  });
}
