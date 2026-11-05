import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_screen.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  const projeler = [
    ProjeOzet(kimlik: 'balkon-bahcesi', baslik: 'Balkon Bahçesi Sulama'),
    ProjeOzet(kimlik: 'kitap-kulubu', baslik: 'Kitap Kulübü Sitesi'),
  ];

  /// Drift needs real time; the fake-async zone of a widget test would never finish its queries.
  Future<void> gercekZaman(WidgetTester tester, [int ms = 100]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }

  /// The project list was read once while online; now the phone has no connection.
  Future<void> cevrimdisiHazirla(WidgetTester tester) async {
    ortam.api.projeler = projeler;
    await tester.runAsync(ortam.beyin.projeleriGetir);
    ortam.api.cevrimdisi = true;
    ortam.api.cagrilar.clear();
  }

  Future<YakalaViewModel> goster(WidgetTester tester, {String? duzenlenenId}) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = YakalaViewModel(
      repo: ortam.yakalamalar,
      esitleyici: ortam.esitleyici,
      beyin: ortam.beyin,
      duzenlenenId: duzenlenenId,
    );
    if (duzenlenenId != null) await tester.runAsync(vm.yukle);
    await tester.pumpWidget(MaterialApp(home: YakalaScreen(viewModel: vm)));
    await gercekZaman(tester);
    return vm;
  }

  Future<Map<String, dynamic>> kuyrukGovdesi(WidgetTester tester) async {
    final satirlar = await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get());
    return jsonDecode(satirlar!.last.govde) as Map<String, dynamic>;
  }

  testWidgets('offline, the picker is filled from the phone and opening made no API call', (tester) async {
    await cevrimdisiHazirla(tester);
    await goster(tester);

    expect(find.text('Proje (isteğe bağlı)'), findsOneWidget);
    await tester.tap(find.text('Proje (isteğe bağlı)'));
    await tester.pumpAndSettle();

    expect(find.text('Balkon Bahçesi Sulama'), findsOneWidget);
    expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);
    expect(find.text('Projesiz'), findsOneWidget);
    expect(ortam.api.cagrilar, isEmpty, reason: 'the list comes from the phone');
  });

  testWidgets('a picked project is saved as the capture\'s Hedef (projects/<kimlik>)', (tester) async {
    await cevrimdisiHazirla(tester);
    await goster(tester);

    await tester.tap(find.text('Proje (isteğe bağlı)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitap Kulübü Sitesi'));
    await tester.pumpAndSettle();
    expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget, reason: 'shown on the button now');

    await tester.enterText(find.byType(TextFormField), 'takvim için renk sor');
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await gercekZaman(tester);

    final govde = await kuyrukGovdesi(tester);
    expect(govde['hedef'], 'projects/kitap-kulubu');
    expect(govde['metin'], 'takvim için renk sor');
  });

  testWidgets('the picked project is cleared after each save: the next capture starts without one', (tester) async {
    await cevrimdisiHazirla(tester);
    await goster(tester);
    await tester.tap(find.text('Proje (isteğe bağlı)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitap Kulübü Sitesi'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'birinci');
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await gercekZaman(tester);

    expect(find.text('Proje (isteğe bağlı)'), findsOneWidget, reason: 'the button is back to "no project"');
    expect(find.byTooltip('Projeyi kaldır'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'ikinci');
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await gercekZaman(tester);

    final satirlar = (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;
    final govdeler = [for (final s in satirlar) jsonDecode(s.govde) as Map<String, dynamic>];
    expect(govdeler.firstWhere((g) => g['metin'] == 'birinci')['hedef'], 'projects/kitap-kulubu');
    expect(govdeler.firstWhere((g) => g['metin'] == 'ikinci').containsKey('hedef'), isFalse);
  });

  testWidgets('no project is the default: the capture carries no Hedef', (tester) async {
    await cevrimdisiHazirla(tester);
    await goster(tester);

    await tester.enterText(find.byType(TextFormField), 'projesiz düşünce');
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await gercekZaman(tester);

    expect((await kuyrukGovdesi(tester)).containsKey('hedef'), isFalse);
  });

  testWidgets('the x clears the pick', (tester) async {
    await cevrimdisiHazirla(tester);
    await goster(tester);
    await tester.tap(find.text('Proje (isteğe bağlı)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balkon Bahçesi Sulama'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Projeyi kaldır'));
    await tester.pump();

    expect(find.text('Proje (isteğe bağlı)'), findsOneWidget);
    expect(find.byTooltip('Projeyi kaldır'), findsNothing);
  });

  testWidgets('edit mode starts on the capture\'s project; it can be changed and removed', (tester) async {
    await cevrimdisiHazirla(tester);
    await tester.runAsync(() => ortam.yakalamalar.yakala(metin: 'ilk hali', hedef: 'projects/balkon-bahcesi'));
    final satir = (await tester.runAsync(ortam.yakalamalar.yerelListe))!.single;
    expect(satir.hedef, 'projects/balkon-bahcesi');
    final vm = await goster(tester, duzenlenenId: satir.id);

    expect(find.text('Balkon Bahçesi Sulama'), findsOneWidget, reason: 'the title of the capture\'s project');

    // Change it to another project.
    await tester.tap(find.text('Balkon Bahçesi Sulama'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitap Kulübü Sitesi'));
    await tester.pumpAndSettle();
    // (The screen's Save closes the page through the router; the test saves through the view model, as the other edit tests do.)
    expect(await tester.runAsync(() => vm.kaydet(metin: 'ilk hali')), isTrue);
    final guncel = (await tester.runAsync(ortam.yakalamalar.yerelListe))!.single;
    expect(guncel.hedef, 'projects/kitap-kulubu');
    expect(guncel.metin, 'ilk hali', reason: 'the rest of the capture is untouched');
  });

  testWidgets('edit mode: the x removes the project from the capture', (tester) async {
    await cevrimdisiHazirla(tester);
    await tester.runAsync(() => ortam.yakalamalar.yakala(metin: 'ilk hali', hedef: 'projects/balkon-bahcesi'));
    final satir = (await tester.runAsync(ortam.yakalamalar.yerelListe))!.single;
    final vm = await goster(tester, duzenlenenId: satir.id);

    await tester.tap(find.byTooltip('Projeyi kaldır'));
    await tester.pump();
    expect(await tester.runAsync(() => vm.kaydet(metin: 'ilk hali')), isTrue);

    final guncel = (await tester.runAsync(ortam.yakalamalar.yerelListe))!.single;
    expect(guncel.hedef, isNull);
  });

  testWidgets('a capture saved without touching the picker keeps the project it came with', (tester) async {
    // A capture made elsewhere (the web page) with a Hedef, edited on the phone: the Hedef must survive.
    ortam.api.yakalamalar = [
      Yakalama(
        id: 'w1',
        metin: 'web\'den',
        hedef: 'projects/kitap-kulubu',
        durum: YakalamaDurumu.bekliyor,
        yakalandiAt: sabitAn,
        olusturulma: sabitAn,
      ),
    ];
    await tester.runAsync(ortam.yakalamalar.listele);
    ortam.api.cevrimdisi = true;
    final vm = await goster(tester, duzenlenenId: 'w1');

    expect(await tester.runAsync(() => vm.kaydet(metin: 'web\'den, düzeltildi')), isTrue);
    await gercekZaman(tester, 200); // the background send (offline) finishes before the database closes

    expect((await kuyrukGovdesi(tester))['hedef'], 'projects/kitap-kulubu');
  });

  testWidgets('an empty phone list says how to fill it; "Listeyi yenile" fetches it when online', (tester) async {
    ortam.api.projeler = projeler;
    await goster(tester);

    await tester.tap(find.text('Proje (isteğe bağlı)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Telefonda proje listesi yok'), findsOneWidget);
    expect(ortam.api.cagrilar, isEmpty);

    await tester.tap(find.text('Listeyi yenile'));
    await gercekZaman(tester);
    await tester.pumpAndSettle();

    expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);
    expect(find.textContaining('Telefonda proje listesi yok'), findsNothing);
  });

  testWidgets('"Listeyi yenile" offline keeps the phone list and says so', (tester) async {
    await cevrimdisiHazirla(tester);
    await goster(tester);
    await tester.tap(find.text('Proje (isteğe bağlı)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listeyi yenile'));
    await gercekZaman(tester);
    await tester.pump();

    expect(find.textContaining('telefondaki liste gösteriliyor'), findsOneWidget);
    expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);
  });

  testWidgets('a project that is no longer in the list still shows by its id', (tester) async {
    await cevrimdisiHazirla(tester);
    await tester.runAsync(() => ortam.yakalamalar.yakala(metin: 'x', hedef: 'projects/eski-proje'));
    final satir = (await tester.runAsync(ortam.yakalamalar.yerelListe))!.single;

    await goster(tester, duzenlenenId: satir.id);

    expect(find.text('eski-proje'), findsOneWidget);
  });
}
