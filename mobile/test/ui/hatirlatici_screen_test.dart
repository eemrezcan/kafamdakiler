import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/hatirlaticilar/hatirlatici_form_screen.dart';
import 'package:kafamdakiler/ui/hatirlaticilar/hatirlatici_form_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  // Drift needs real time; the fake-async zone of a widget test would never finish its queries.
  Future<void> gercekZaman(WidgetTester tester, [int ms = 100]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }

  /// 2026-11-06 12:00 Istanbul.
  DateTime simdi() => DateTime.utc(2026, 11, 6, 9);

  group('reminder form', () {
    HatirlaticiFormViewModel vmOlustur({String? id}) => HatirlaticiFormViewModel(
          repo: ortam.hatirlaticilar,
          esitleyici: ortam.esitleyici,
          duzenlenenId: id,
        );

    Future<HatirlaticiFormViewModel> formGoster(WidgetTester tester, {String? id}) async {
      ortam.api.cevrimdisi = true;
      // Tall enough that the whole form, Save button included, is on screen.
      tester.view.physicalSize = const Size(375, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = vmOlustur(id: id);
      addTearDown(vm.dispose);
      if (id != null) await tester.runAsync(vm.yukle);
      // The form pops itself after saving, so it sits on a second route.
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('liste'))),
        GoRoute(path: '/form', builder: (c, s) => HatirlaticiFormScreen(viewModel: vm, simdi: simdi)),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/form');
      await tester.pumpAndSettle();
      return vm;
    }

    Future<List<BekleyenIslemlerData>> kuyruk(WidgetTester tester) async =>
        (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;

    testWidgets('the new form starts on today; a title is required', (tester) async {
      await formGoster(tester);

      expect(find.text('6 Kasım 2026 Cuma'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pump();

      expect(find.text('Başlık gerekli.'), findsOneWidget);
      expect((await kuyruk(tester)), isEmpty);
    });

    testWidgets('"Kime" shows only while the type is Söz', (tester) async {
      await formGoster(tester);
      expect(find.text('Kime söz verdin?'), findsNothing);

      await tester.tap(find.text('Yapılacak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Söz').last);
      await tester.pumpAndSettle();

      expect(find.text('Kime söz verdin?'), findsOneWidget);
    });

    testWidgets('the month-end note shows only while the repeat is "Her ay"', (tester) async {
      await formGoster(tester);
      const not = "Ayın 31'inde başlayan aylık hatırlatıcı, kısa aylarda ayın son günü çalar.";
      expect(find.text(not), findsNothing);

      await tester.tap(find.text('Tekrarlanmaz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Her ay').last);
      await tester.pumpAndSettle();
      expect(find.text(not), findsOneWidget);

      await tester.tap(find.text('Her ay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Her gün').last);
      await tester.pumpAndSettle();
      expect(find.text(not), findsNothing);
    });

    testWidgets('the number of days before must be between 0 and 60', (tester) async {
      await formGoster(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Başlık'), 'Bir şey');
      await tester.enterText(find.widgetWithText(TextFormField, 'Kaç gün önce de haber verilsin?'), '99');
      await tester.tap(find.text('Kaydet'));
      await tester.pump();

      expect(find.text('Kaç gün önce uyarılacağı 0 ile 60 arasında olmalı.'), findsOneWidget);
      expect(await kuyruk(tester), isEmpty);
    });

    testWidgets('Save writes to the phone queue with the picked values and goes back', (tester) async {
      await formGoster(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Başlık'), '  Faturayı öde ');
      await tester.enterText(find.widgetWithText(TextFormField, 'Kaç gün önce de haber verilsin?'), '2');
      await tester.tap(find.text('Kaydet'));
      await gercekZaman(tester);
      await tester.pumpAndSettle();

      expect(find.text('liste'), findsOneWidget, reason: 'the form closed');
      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.hatirlaticiEkle);
      final govde = satirlar.single.govde;
      expect(govde, contains('"baslik":"Faturayı öde"'));
      expect(govde, contains('"gun":"2026-11-06"'));
      expect(govde, contains('"onceGun":2'));
    });

    testWidgets('Israrlı and Acil start off; the interval shows only while Israrlı is on', (tester) async {
      await formGoster(tester);

      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Israrlı')).value, isFalse);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Acil')).value, isFalse);
      expect(find.text('Israr aralığı'), findsNothing);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Israrlı'));
      await tester.pumpAndSettle();
      expect(find.text('Israr aralığı'), findsOneWidget);
      expect(find.text('15 dakikada bir'), findsOneWidget, reason: 'the server default');
    });

    testWidgets('the nag switches and the interval go into the queued write', (tester) async {
      await formGoster(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Başlık'), 'İlacı al');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Israrlı'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 dakikada bir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 dakikada bir').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Acil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await gercekZaman(tester);
      await tester.pumpAndSettle();

      final govde = (await kuyruk(tester)).single.govde;
      expect(govde, contains('"israrli":true'));
      expect(govde, contains('"israrAraligiDakika":5'));
      expect(govde, contains('"israrEnCok":3'));
      expect(govde, contains('"acil":true'));
    });

    testWidgets('a plain save sends the switches off', (tester) async {
      await formGoster(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Başlık'), 'Düz');
      await tester.tap(find.text('Kaydet'));
      await gercekZaman(tester);
      await tester.pumpAndSettle();

      final govde = (await kuyruk(tester)).single.govde;
      expect(govde, contains('"israrli":false'));
      expect(govde, contains('"acil":false'));
    });

    testWidgets('an edit opens with the saved nag settings', (tester) async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'h', israrli: true, israrAraligiDakika: 60, acil: true)];
      await tester.runAsync(ortam.hatirlaticilar.listele);
      await formGoster(tester, id: 'h');

      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Israrlı')).value, isTrue);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Acil')).value, isTrue);
      expect(find.text('1 saatte bir'), findsOneWidget);
    });

    testWidgets('an edit opens with the saved values and queues an update', (tester) async {
      ortam.api.hatirlaticilar = [
        ornekHatirlatici(id: 'h', baslik: 'Eski başlık', tur: HatirlaticiTuru.soz, kime: 'Ali', onceGun: 3, saat: const Saat(18, 30)),
      ];
      await tester.runAsync(ortam.hatirlaticilar.listele);
      await formGoster(tester, id: 'h');

      expect(find.text('Eski başlık'), findsOneWidget);
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('18:30'), findsOneWidget);
      expect(find.text('Durum'), findsOneWidget, reason: 'status can be changed when editing');

      await tester.enterText(find.widgetWithText(TextFormField, 'Başlık'), 'Yeni başlık');
      await tester.tap(find.text('Kaydet'));
      await gercekZaman(tester);
      await tester.pumpAndSettle();

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.hatirlaticiGuncelle);
      expect(satirlar.single.hedefId, 'h');
      expect(satirlar.single.govde, contains('"baslik":"Yeni başlık"'));
      expect(satirlar.single.govde, contains('"kime":"Ali"'));
      expect(satirlar.single.govde, contains('"saat":"18:30:00"'));
    });

    testWidgets('delete asks first and then queues the delete', (tester) async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'h')];
      await tester.runAsync(ortam.hatirlaticilar.listele);
      await formGoster(tester, id: 'h');

      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('Hatırlatıcı silinsin mi?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await gercekZaman(tester);
      await tester.pumpAndSettle();

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.hatirlaticiSil);
      expect(find.text('liste'), findsOneWidget);
    });
  });
}
