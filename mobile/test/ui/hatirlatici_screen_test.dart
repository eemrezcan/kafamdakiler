import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/repositories/kullanici_repository.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/bugun/bugun_screen.dart';
import 'package:kafamdakiler/ui/bugun/bugun_view_model.dart';
import 'package:kafamdakiler/ui/bugun/yaklasanlar_view_model.dart';
import 'package:kafamdakiler/ui/hatirlaticilar/hatirlatici_form_screen.dart';
import 'package:kafamdakiler/ui/hatirlaticilar/hatirlatici_form_view_model.dart';
import 'package:kafamdakiler/ui/hatirlaticilar/hatirlatici_liste_screen.dart';
import 'package:kafamdakiler/ui/hatirlaticilar/hatirlatici_liste_view_model.dart';
import 'package:provider/provider.dart';

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

  Future<KullaniciRepository> kullaniciOlustur(WidgetTester tester, String rol) async {
    final kullanici = KullaniciRepository(api: ortam.api, db: ortam.db);
    ortam.api.ben_ = Ben(id: 'u', email: 'x@y.z', roller: [rol]);
    await tester.runAsync(kullanici.yukle);
    return kullanici;
  }

  /// [cevrimdisiOl]: the list is read once while online (it fills the phone's cache), then the connection is lost.
  Future<void> listeGoster(WidgetTester tester, {String rol = 'Sahip', bool cevrimdisiOl = false}) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kullanici = await kullaniciOlustur(tester, rol);
    final vm = HatirlaticiListeViewModel(repo: ortam.hatirlaticilar, esitleyici: ortam.esitleyici, simdi: simdi);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.yukle);
    if (cevrimdisiOl) ortam.api.cevrimdisi = true;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: kullanici,
        child: MaterialApp(home: HatirlaticiListeScreen(viewModel: vm)),
      ),
    );
    await tester.pump();
  }

  group('reminders list', () {
    setUp(() {
      ortam.api.hatirlaticilar = [
        // Yesterday 09:00 Istanbul: overdue.
        ornekHatirlatici(id: 'g', baslik: 'Gecikmiş fatura', sonrakiAn: DateTime.utc(2026, 11, 5, 6)),
        // In 3 days, yearly, with a heads-up.
        ornekHatirlatici(
          id: 'd',
          baslik: 'Annemin doğum günü',
          tur: HatirlaticiTuru.ozelTarih,
          gun: DateTime.utc(2024, 11, 9),
          tekrar: Tekrar.yillik,
          onceGun: 2,
          sonrakiAn: DateTime.utc(2026, 11, 9, 6),
        ),
        ornekHatirlatici(
          id: 's',
          baslik: 'Kitabı geri ver',
          tur: HatirlaticiTuru.soz,
          kime: 'Ali',
          sonrakiAn: DateTime.utc(2026, 11, 7, 6),
        ),
        ornekHatirlatici(id: 't', baslik: 'Bitmiş iş', durum: HatirlaticiDurumu.tamam),
      ];
    });

    testWidgets('open reminders by effective moment, overdue first, with the day left and the repeat rule', (tester) async {
      await listeGoster(tester);

      final baslikSirasi = ['Gecikmiş fatura', 'Kitabı geri ver', 'Annemin doğum günü'];
      final yler = [for (final b in baslikSirasi) tester.getTopLeft(find.text(b)).dy];
      expect(yler, [...yler]..sort(), reason: 'soonest first');
      expect(find.text('Bitmiş iş'), findsNothing, reason: 'closed ones are on another tab');

      expect(find.text('1 gün gecikti'), findsOneWidget);
      expect(find.text('yarın'), findsOneWidget);
      expect(find.text('3 gün sonra'), findsOneWidget);
      expect(find.text('her yıl 9 Kasım'), findsOneWidget);
      expect(find.text('2 gün önce de haber verilir'), findsOneWidget);
      expect(find.text('Kime: Ali'), findsOneWidget);
      expect(find.text('Söz'), findsOneWidget);
      expect(find.text('Özel tarih'), findsOneWidget);
      expect(find.text('Açık 3'), findsOneWidget);
      expect(find.text('Tamam 1'), findsOneWidget);
    });

    testWidgets('the overdue card has a red edge, the others do not', (tester) async {
      await listeGoster(tester);

      Card kart(String baslik) =>
          tester.widget<Card>(find.ancestor(of: find.text(baslik), matching: find.byType(Card)).first);
      expect(kart('Gecikmiş fatura').shape, isA<RoundedRectangleBorder>());
      expect(kart('Annemin doğum günü').shape, isNull);
    });

    testWidgets('the Tamam tab shows the closed ones, without Yaptım and Ertele', (tester) async {
      await listeGoster(tester);

      await tester.tap(find.text('Tamam 1'));
      await tester.pump();

      expect(find.text('Bitmiş iş'), findsOneWidget);
      expect(find.text('Gecikmiş fatura'), findsNothing);
      expect(find.text('Yaptım'), findsNothing);
    });

    testWidgets('Yaptım on a one-off moves it to the Tamam tab at once, offline', (tester) async {
      await listeGoster(tester, cevrimdisiOl: true);

      await tester.tap(find.text('Yaptım').first);
      await gercekZaman(tester);

      expect(find.text('Gecikmiş fatura'), findsNothing);
      expect(find.text('Açık 2'), findsOneWidget);
      expect(find.text('Tamam 2'), findsOneWidget);
      final satirlar = await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get());
      expect(satirlar!.single.tur, BekleyenTur.hatirlaticiYaptim);
      expect(satirlar.single.hedefId, 'g');
    });

    testWidgets('the two Ertele buttons queue 1 saat and yarın and mark the row snoozed', (tester) async {
      await listeGoster(tester, cevrimdisiOl: true);

      await tester.tap(find.text('1 saat ertele').first);
      await gercekZaman(tester);
      expect(find.text('ertelendi'), findsOneWidget);

      await tester.tap(find.text('Yarın').first);
      await gercekZaman(tester);
      final satirlar = await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get());
      expect(satirlar!.map((s) => s.govde), ['{"sure":"1s"}', '{"sure":"yarin"}']);
    });

    testWidgets('the Asistan reads: no add button, no Yaptım or Ertele', (tester) async {
      await listeGoster(tester, rol: 'Asistan');

      expect(find.text('Gecikmiş fatura'), findsOneWidget);
      expect(find.text('Yeni'), findsNothing);
      expect(find.text('Yaptım'), findsNothing);
      expect(find.text('1 saat ertele'), findsNothing);
    });

    testWidgets('the Sahip sees the add button', (tester) async {
      await listeGoster(tester);
      expect(find.text('Yeni'), findsOneWidget);
    });

    testWidgets('an empty list guides the user', (tester) async {
      ortam.api.hatirlaticilar = [];
      await listeGoster(tester);
      expect(find.textContaining('Henüz hatırlatıcı yok'), findsOneWidget);
    });
  });

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

  group('Yaklaşanlar card on the Today tab', () {
    Future<void> bugunGoster(WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ortam.api.aliskanliklar = [ornekAliskanlik()];
      final bugun = BugunViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
      final yaklasan = YaklasanlarViewModel(repo: ortam.hatirlaticilar, esitleyici: ortam.esitleyici, simdi: simdi);
      addTearDown(yaklasan.dispose);
      await tester.runAsync(bugun.yukle);
      await tester.runAsync(yaklasan.yukle);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => BugunScreen(viewModel: bugun, yaklasanlar: yaklasan)),
        GoRoute(path: '/hatirlaticilar', builder: (c, s) => const Scaffold(body: Text('hatırlatıcı listesi'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
    }

    testWidgets('overdue and the next 7 days are listed with the days left; later ones and closed ones are not', (tester) async {
      ortam.api.hatirlaticilar = [
        ornekHatirlatici(id: 'g', baslik: 'Gecikmiş', sonrakiAn: DateTime.utc(2026, 11, 5, 6)),
        ornekHatirlatici(id: 'b', baslik: 'Yarın olan', sonrakiAn: DateTime.utc(2026, 11, 7, 6)),
        ornekHatirlatici(id: 'y', baslik: 'Yedi gün sonra', sonrakiAn: DateTime.utc(2026, 11, 13, 6)),
        ornekHatirlatici(id: 'u', baslik: 'Çok uzak', sonrakiAn: DateTime.utc(2026, 12, 20, 6)),
        ornekHatirlatici(id: 't', baslik: 'Bitmiş', durum: HatirlaticiDurumu.tamam, sonrakiAn: DateTime.utc(2026, 11, 7, 6)),
      ];
      await bugunGoster(tester);

      expect(find.text('Yaklaşanlar'), findsOneWidget);
      expect(find.text('Gecikmiş'), findsOneWidget);
      expect(find.text('1 gün gecikti'), findsOneWidget);
      expect(find.text('Yarın olan'), findsOneWidget);
      expect(find.text('yarın'), findsOneWidget);
      expect(find.text('Yedi gün sonra'), findsOneWidget);
      expect(find.text('7 gün sonra'), findsOneWidget);
      expect(find.text('Çok uzak'), findsNothing);
      expect(find.text('Bitmiş'), findsNothing);
    });

    testWidgets('tapping the card opens the reminders list', (tester) async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'b', baslik: 'Yarın olan', sonrakiAn: DateTime.utc(2026, 11, 7, 6))];
      await bugunGoster(tester);

      await tester.tap(find.text('Yaklaşanlar'));
      await tester.pumpAndSettle();

      expect(find.text('hatırlatıcı listesi'), findsOneWidget);
    });

    testWidgets('nothing in the next 7 days: the card says so', (tester) async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'u', sonrakiAn: DateTime.utc(2026, 12, 20, 6))];
      await bugunGoster(tester);

      expect(find.text('Önümüzdeki 7 günde hatırlatıcı yok.'), findsOneWidget);
    });

    testWidgets('a failing read (no permission) hides the card; the habits still show', (tester) async {
      ortam.api.sunucuHatasi = 403;
      await bugunGoster(tester);

      expect(find.text('Yaklaşanlar'), findsNothing);
    });

    testWidgets('more than five: the card shows five and counts the rest', (tester) async {
      ortam.api.hatirlaticilar = [
        for (var i = 0; i < 7; i++)
          ornekHatirlatici(id: 'r$i', baslik: 'Hatırlatıcı $i', sonrakiAn: DateTime.utc(2026, 11, 7, 6, i)),
      ];
      await bugunGoster(tester);

      expect(find.text('+ 2 tane daha'), findsOneWidget);
    });
  });
}
