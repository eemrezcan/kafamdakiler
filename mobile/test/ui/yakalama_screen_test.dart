import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_screen.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  /// Drift needs real time; the fake-async zone of a widget test would never finish its queries.
  Future<void> gercekZaman(WidgetTester tester, [int ms = 100]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }

  /// Waits (real time) until the Save button is back, i.e. the save finished.
  Future<void> kayitBitsin(WidgetTester tester) async {
    for (var i = 0; i < 40 && find.text('Kaydet').evaluate().isEmpty; i++) {
      await gercekZaman(tester, 50);
    }
  }

  Future<void> yakalaGoster(WidgetTester tester, {Future<String?> Function(dynamic)? secici}) async {
    // Offline, so the saved capture stays in the queue where the test can look at it.
    ortam.api.cevrimdisi = true;
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = YakalaViewModel(repo: ortam.yakalamalar, esitleyici: ortam.esitleyici);
    await tester.pumpWidget(MaterialApp(home: YakalaScreen(viewModel: vm, fotografSecici: secici)));
    await tester.pump();
  }

  group('leaving the Yakala screen', () {
    /// A screen under Yakala, so a back press has somewhere to go.
    Future<void> altindaGoster(WidgetTester tester) async {
      ortam.api.cevrimdisi = true;
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = YakalaViewModel(repo: ortam.yakalamalar, esitleyici: ortam.esitleyici);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => YakalaScreen(viewModel: vm))),
              child: const Text('aç'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('typed text: back asks "Vazgeçilsin mi?"; staying keeps the text, leaving closes the screen', (tester) async {
      await altindaGoster(tester);
      await tester.enterText(find.byType(TextFormField), 'unutmamam gereken şey');
      await tester.pump();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Vazgeçilsin mi?'), findsOneWidget);

      await tester.tap(find.text('Yazmaya devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Vazgeçilsin mi?'), findsNothing);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'unutmamam gereken şey');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('Aklında ne var?'), findsNothing, reason: 'the screen closed');
      expect(find.text('aç'), findsOneWidget);
    });

    testWidgets('nothing typed: back closes at once, without asking', (tester) async {
      await altindaGoster(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Vazgeçilsin mi?'), findsNothing);
      expect(find.text('aç'), findsOneWidget);
    });
  });

  group('Yakala screen', () {
    testWidgets('opens with the keyboard ready and makes no API call', (tester) async {
      await yakalaGoster(tester);

      final alan = tester.widget<EditableText>(find.byType(EditableText));
      expect(alan.focusNode.hasFocus, isTrue);
      expect(ortam.api.cagrilar, isEmpty);
    });

    testWidgets('Save writes to the phone, clears the form, says "Kaydedildi" and stays', (tester) async {
      await yakalaGoster(tester);

      await tester.enterText(find.byType(TextFormField), 'kitap kulübü için öneri sor');
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await gercekZaman(tester);

      expect(find.text('Kaydedildi'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget, reason: 'the screen did not close');
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
      final satirlar = await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get());
      expect(satirlar!.single.tur, BekleyenTur.yakalamaEkle);
      expect(satirlar.single.govde, contains('kitap kulübü için öneri sor'));
    });

    testWidgets('nothing to save: Save stays disabled until there is text or a photo, and nothing is queued', (tester) async {
      await yakalaGoster(tester);

      FilledButton kaydet() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'));
      expect(kaydet().onPressed, isNull);
      await tester.tap(find.text('Kaydet'));
      await gercekZaman(tester);
      expect(find.text('Kaydedildi'), findsNothing);

      // Spaces alone are not a thought either.
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pump();
      expect(kaydet().onPressed, isNull);
      await tester.enterText(find.byType(TextFormField), 'bir fikir');
      await tester.pump();
      expect(kaydet().onPressed, isNotNull);
      expect(await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()), isEmpty);
    });

    testWidgets('a photo alone is enough; its copy goes to the app folder', (tester) async {
      final foto = File('${ortam.fotografKlasoru.path}/secilen.jpg')..writeAsBytesSync([1, 2, 3]);
      await yakalaGoster(tester, secici: (_) async => foto.path);

      await tester.tap(find.text('Galeri'));
      await tester.pump();
      expect(find.byTooltip('Fotoğrafı kaldır'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await gercekZaman(tester);
      await kayitBitsin(tester);

      expect(find.text('Kaydedildi'), findsOneWidget);
      expect(find.byTooltip('Fotoğrafı kaldır'), findsNothing, reason: 'cleared for the next one');
      final liste = await tester.runAsync(ortam.yakalamalar.yerelListe);
      final kopya = liste!.single.fotografYolu!;
      expect(kopya, isNot(foto.path));
      expect(File(kopya).existsSync(), isTrue);
    });

    testWidgets('a photo that cannot be taken shows a message and keeps the form', (tester) async {
      await yakalaGoster(tester, secici: (_) async => throw StateError('no camera'));

      await tester.tap(find.text('Kamera'));
      await tester.pump();

      expect(find.textContaining('Fotoğraf alınamadı'), findsOneWidget);
    });

    testWidgets('edit mode fills the form from the phone and saves the change to the queue', (tester) async {
      ortam.api.cevrimdisi = true; // the queue is looked at after saving
      await tester.runAsync(() => ortam.yakalamalar.yakala(metin: 'ilk hali'));
      final satir = (await tester.runAsync(ortam.yakalamalar.yerelListe))!.single;
      final vm = YakalaViewModel(repo: ortam.yakalamalar, esitleyici: ortam.esitleyici, duzenlenenId: satir.id);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(MaterialApp(home: YakalaScreen(viewModel: vm)));
      await tester.pump();

      expect(find.text('Yakalamayı düzenle'), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'ilk hali');
      expect(ortam.api.cagrilar, isEmpty, reason: 'edit reads the phone copy, no API call');

      await tester.enterText(find.byType(TextFormField), 'ikinci hali');
      expect(await tester.runAsync(() => vm.kaydet(metin: 'ikinci hali')), isTrue);

      expect((await tester.runAsync(ortam.yakalamalar.yerelListe))!.single.metin, 'ikinci hali');
      expect(await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()), hasLength(1));
    });

    testWidgets('a capture that already went to the brain cannot be edited', (tester) async {
      ortam.api.yakalamalar = [
        Yakalama(
          id: 'y1',
          metin: 'beyinde',
          durum: YakalamaDurumu.beyneGitti,
          yakalandiAt: DateTime.utc(2026, 11, 4, 9),
          olusturulma: DateTime.utc(2026, 11, 4, 9),
        ),
      ];
      await tester.runAsync(ortam.yakalamalar.listele);
      final vm = YakalaViewModel(repo: ortam.yakalamalar, esitleyici: ortam.esitleyici, duzenlenenId: 'y1');
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(MaterialApp(home: YakalaScreen(viewModel: vm)));
      await tester.pump();

      expect(find.textContaining('beyne gitti'), findsOneWidget);
      expect(find.text('Kaydet'), findsNothing);
    });
  });

}
