import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/eylem.dart';
import 'package:kafamdakiler/data/repositories/kullanici_repository.dart';
import 'package:kafamdakiler/ui/eylemler/eylem_detay_screen.dart';
import 'package:kafamdakiler/ui/eylemler/eylem_detay_view_model.dart';
import 'package:kafamdakiler/ui/eylemler/eylem_liste_screen.dart';
import 'package:kafamdakiler/ui/eylemler/eylem_liste_view_model.dart';
import 'package:kafamdakiler/ui/yonetim/yonetim_screen.dart';
import 'package:kafamdakiler/ui/yonetim/yonetim_view_model.dart';
import 'package:provider/provider.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async {
    // A decision starts a send in the background; let it end before the database is closed.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await ortam.kapat();
  });

  // Drift needs real time; the fake-async zone of a widget test would never finish its queries.
  Future<void> gercekZaman(WidgetTester tester, [int ms = 120]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  Future<KullaniciRepository> kullaniciOlustur(WidgetTester tester, String rol) async {
    final kullanici = KullaniciRepository(api: ortam.api, db: ortam.db);
    ortam.api.ben_ = Ben(id: 'u', email: 'x@y.z', roller: [rol]);
    await tester.runAsync(kullanici.yukle);
    return kullanici;
  }

  void ekran(WidgetTester tester, [Size boyut = const Size(375, 900)]) {
    tester.view.physicalSize = boyut;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<EylemListeViewModel> listeGoster(WidgetTester tester, {String rol = 'Sahip', bool cevrimdisiOl = false}) async {
    ekran(tester);
    final kullanici = await kullaniciOlustur(tester, rol);
    final vm = EylemListeViewModel(repo: ortam.eylemler, esitleyici: ortam.esitleyici);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.yukle);
    if (cevrimdisiOl) ortam.api.cevrimdisi = true;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: kullanici,
        child: MaterialApp(home: EylemListeScreen(viewModel: vm)),
      ),
    );
    await tester.pump();
    return vm;
  }

  group('queue list', () {
    setUp(() {
      ortam.api.eylemler = [
        ornekEylem(id: 'a', ozet: 'Ali\'yi ara', createdAt: DateTime.utc(2026, 11, 1, 8)),
        ornekEylem(id: 'b', ozet: 'Mailden gelen iş', disKaynak: true, guven: 0.4, createdAt: DateTime.utc(2026, 11, 2, 8)),
        ornekEylem(id: 'u', ozet: 'Faturayı öde', durum: EylemDurumu.uygulandi),
        ornekEylem(id: 'h', ozet: 'Patlayan iş', durum: EylemDurumu.hatali),
      ];
    });

    testWidgets('shows the waiting ones newest first with source, reason and the warnings, and the applied ones apart', (tester) async {
      await listeGoster(tester);

      expect(find.text('Bekleyenler  2'), findsNothing, reason: 'headings are upper-case');
      expect(find.text('BEKLEYENLER  2'), findsOneWidget);
      final yeniY = tester.getTopLeft(find.text('Mailden gelen iş')).dy;
      final eskiY = tester.getTopLeft(find.text('Ali\'yi ara')).dy;
      expect(yeniY, lessThan(eskiY), reason: 'newest first');
      expect(find.text('Hatırlatıcı kur'), findsNWidgets(2));
      expect(find.text('Gelen kutusu'), findsNWidgets(2));
      expect(find.text('Mailde yazıyor'), findsNWidgets(2));
      expect(find.text('Dış kaynak'), findsOneWidget);
      expect(find.text('Emin değil · %40'), findsOneWidget);
      expect(find.text('SON UYGULANANLAR'), findsOneWidget);
      expect(find.text('Faturayı öde'), findsOneWidget);
      expect(find.text('Geri al'), findsOneWidget);
      expect(find.text('UYGULANAMAYANLAR  1'), findsOneWidget);
      expect(find.text('Patlayan iş'), findsOneWidget);
    });

    testWidgets('the buttons approve and reject: shown at once, queued for the server', (tester) async {
      await listeGoster(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Uygula').first);
      await gercekZaman(tester);

      expect(find.text('BEKLEYENLER  1'), findsOneWidget);
      expect(find.text('SON UYGULANANLAR'), findsOneWidget);
      expect((await tester.runAsync(ortam.esitleyici.bekleyenler))!.length, anyOf(0, 1), reason: 'a send may already have run');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reddet').first);
      await gercekZaman(tester);

      expect(find.text('Onay bekleyen bir şey yok.'), findsOneWidget);
      expect(ortam.api.cagrilar.where((c) => c.startsWith('eylem') && !c.startsWith('eylemleri')).toList(),
          ['eylemUygula:b', 'eylemReddet:a:false'], reason: 'sent in the order they were made');
    });

    testWidgets('swipe right approves, swipe left rejects', (tester) async {
      await listeGoster(tester);

      await tester.fling(find.byKey(const ValueKey('eylem-b')), const Offset(400, 0), 1500);
      await gercekZaman(tester);
      expect(ortam.api.cagrilar, contains('eylemUygula:b'));
      expect(ortam.api.eylemler.firstWhere((e) => e.id == 'b').durum, EylemDurumu.uygulandi);

      await tester.fling(find.byKey(const ValueKey('eylem-a')), const Offset(-400, 0), 1500);
      await gercekZaman(tester);
      expect(ortam.api.cagrilar, contains('eylemReddet:a:false'));
      expect(find.text('Onay bekleyen bir şey yok.'), findsOneWidget);
    });

    testWidgets('Geri al on an applied action undoes it', (tester) async {
      await listeGoster(tester);

      await tester.tap(find.text('Geri al'));
      await gercekZaman(tester);

      expect(ortam.api.cagrilar, contains('eylemGeriAl:u'));
      expect(find.text('Henüz uygulanan bir şey yok.'), findsOneWidget);
    });

    testWidgets('an applied action that cannot be undone (a placed inbox card) offers no "Geri al"', (tester) async {
      ortam.api.eylemler = [ornekEylem(id: 'u', ozet: 'Kart yerleştirildi', durum: EylemDurumu.uygulandi, geriAlinabilir: false)];

      await listeGoster(tester);

      expect(find.text('Kart yerleştirildi'), findsOneWidget);
      expect(find.text('Geri al'), findsNothing);
    });

    testWidgets('offline, the decision is made on the phone and the screen says so', (tester) async {
      await listeGoster(tester, cevrimdisiOl: true);

      await tester.tap(find.widgetWithText(FilledButton, 'Uygula').first);
      await gercekZaman(tester);

      expect(find.text('BEKLEYENLER  1'), findsOneWidget);
      // The send was tried and failed (offline): the server copy is untouched and the entry stays queued.
      expect(ortam.api.eylemler.firstWhere((e) => e.id == 'b').durum, EylemDurumu.bekliyor);
      expect((await tester.runAsync(ortam.esitleyici.bekleyenler))!, hasLength(1));
    });

    testWidgets('a user who cannot decide only reads: no buttons, no swipe, no undo', (tester) async {
      await listeGoster(tester, rol: 'Asistan');

      expect(find.text('Ali\'yi ara'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Uygula'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Reddet'), findsNothing);
      expect(find.byType(Dismissible), findsNothing);
      expect(find.text('Geri al'), findsNothing);
    });

    testWidgets('a read the server refuses (403) says so, and shows nothing to decide', (tester) async {
      ortam.api.sunucuHatasi = 403;
      ekran(tester);
      final kullanici = await kullaniciOlustur(tester, 'Asistan');
      final vm = EylemListeViewModel(repo: ortam.eylemler, esitleyici: ortam.esitleyici);
      addTearDown(vm.dispose);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(ChangeNotifierProvider.value(value: kullanici, child: MaterialApp(home: EylemListeScreen(viewModel: vm))));
      await tester.pump();

      expect(find.text('Bu işlem için yetkin yok.'), findsOneWidget);
      expect(find.text('Ali\'yi ara'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Uygula'), findsNothing);
    });
  });

  group('action detail', () {
    setUp(() {
      ortam.api.eylemler = [
        ornekEylem(id: 'e1', ozet: 'Ali\'yi ara', guven: 0.5, yuk: {'baslik': 'Ali\'yi ara', 'gun': '2030-01-01'}),
        ornekEylem(id: 'e2', ozet: 'Bitmiş', durum: EylemDurumu.uygulandi),
      ];
    });

    Future<GoRouter> detayGoster(WidgetTester tester, String id, {String rol = 'Sahip'}) async {
      ekran(tester, const Size(375, 1100));
      final kullanici = await kullaniciOlustur(tester, rol);
      await tester.runAsync(ortam.eylemler.listele);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('kuyruk'))),
        GoRoute(
          path: '/eylem/:id',
          builder: (c, s) {
            final vm = EylemDetayViewModel(repo: ortam.eylemler, esitleyici: ortam.esitleyici, id: s.pathParameters['id']!)..yukle();
            return EylemDetayScreen(viewModel: vm);
          },
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: kullanici, child: MaterialApp.router(routerConfig: router)),
      );
      // On top of the first page, like a tap from the list would open it.
      unawaited(router.push('/eylem/$id'));
      await gercekZaman(tester);
      return router;
    }

    testWidgets('shows the facts and the payload as JSON in an editable box', (tester) async {
      await detayGoster(tester, 'e1');

      expect(find.text('Ali\'yi ara'), findsWidgets);
      expect(find.text('Gelen kutusu'), findsOneWidget);
      expect(find.text('%50 (emin değil)'), findsOneWidget);
      expect(find.text('Mailde yazıyor'), findsOneWidget);
      final kutu = tester.widget<TextField>(find.byType(TextField)).controller!.text;
      expect(kutu, contains('"gun": "2030-01-01"'), reason: 'indented JSON');
    });

    testWidgets('approving as it is sends no payload; the screen goes back', (tester) async {
      await detayGoster(tester, 'e1');

      await tester.tap(find.widgetWithText(FilledButton, 'Uygula'));
      await gercekZaman(tester);

      expect(ortam.api.cagrilar, contains('eylemUygula:e1'));
      expect(find.text('kuyruk'), findsOneWidget);
    });

    testWidgets('approving with a corrected payload sends the corrected one', (tester) async {
      await detayGoster(tester, 'e1');

      await tester.enterText(find.byType(TextField), '{"baslik": "Ali\'yi 10:00\'da ara", "gun": "2031-02-03"}');
      await tester.tap(find.widgetWithText(FilledButton, 'Uygula'));
      await gercekZaman(tester);

      expect(ortam.api.cagrilar, contains('eylemUygula:e1:yuk={"baslik":"Ali\'yi 10:00\'da ara","gun":"2031-02-03"}'));
    });

    testWidgets('a payload that is not a JSON object is refused on the spot and nothing is queued', (tester) async {
      await detayGoster(tester, 'e1');

      await tester.enterText(find.byType(TextField), '{ bozuk');
      await tester.tap(find.widgetWithText(FilledButton, 'Uygula'));
      await gercekZaman(tester);

      expect(find.text('Yük geçerli bir JSON nesnesi değil.'), findsOneWidget);
      expect(find.text('kuyruk'), findsNothing, reason: 'stays on the screen');
      expect(await tester.runAsync(ortam.esitleyici.bekleyenler), isEmpty);
    });

    testWidgets('Reddet with the switch on forbids the kind', (tester) async {
      await detayGoster(tester, 'e1');

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reddet'));
      await gercekZaman(tester);

      expect(ortam.api.cagrilar, contains('eylemReddet:e1:true'));
    });

    testWidgets('Reddet with the switch off is a plain rejection', (tester) async {
      await detayGoster(tester, 'e1');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reddet'));
      await gercekZaman(tester);

      expect(ortam.api.cagrilar, contains('eylemReddet:e1:false'));
    });

    testWidgets('a decided action shows its payload read-only', (tester) async {
      await detayGoster(tester, 'e2');

      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Uygula'), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('a user who cannot decide sees the payload but cannot change it', (tester) async {
      await detayGoster(tester, 'e1', rol: 'Asistan');

      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Uygula'), findsNothing);
    });

    testWidgets('an unknown id says so', (tester) async {
      await detayGoster(tester, 'yok');

      expect(find.textContaining('Eylem bulunamadı'), findsOneWidget);
    });
  });

  group('Yönetim: action modes', () {
    setUp(() {
      ortam.api.eylemKipleri = const [
        EylemKipDurumu(tur: 'hatirlatici-kur', turAdi: 'Hatırlatıcı kur', kip: EylemKipi.sor),
        EylemKipDurumu(tur: 'plan-ekle', turAdi: 'Plana ekle', kip: EylemKipi.yasak),
      ];
    });

    Future<YonetimViewModel> goster(WidgetTester tester) async {
      ekran(tester, const Size(375, 4000));
      final vm = YonetimViewModel(api: ortam.api);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(MaterialApp(home: YonetimScreen(viewModel: vm)));
      await tester.pump();
      // The modes are in the "Gelişmiş" section.
      await tester.tap(find.text('Gelişmiş'));
      await tester.pumpAndSettle();
      return vm;
    }

    testWidgets('each kind shows its mode and what it means', (tester) async {
      await goster(tester);

      expect(find.text('Asistan\'ın eylem kipleri'), findsOneWidget);
      expect(find.text('Hatırlatıcı kur'), findsOneWidget);
      expect(find.text('Plana ekle'), findsOneWidget);
      expect(find.text('Önce onayını bekler.'), findsOneWidget);
      expect(find.text('Bu türde öneri hiç kaydedilmez.'), findsOneWidget);
      final kart = find.byKey(const ValueKey('kip-hatirlatici-kur'));
      final secili = tester.widget<SegmentedButton<EylemKipi>>(find.descendant(of: kart, matching: find.byType(SegmentedButton<EylemKipi>))).selected;
      expect(secili, {EylemKipi.sor});
    });

    testWidgets('choosing a mode asks the server and keeps the new one', (tester) async {
      await goster(tester);
      final kart = find.byKey(const ValueKey('kip-hatirlatici-kur'));

      await tester.tap(find.descendant(of: kart, matching: find.text('Kendin yap')));
      await tester.pump();
      await tester.pump();

      expect(ortam.api.cagrilar, contains('eylemKipiAyarla:hatirlatici-kur:kendinYap'));
      expect(find.textContaining('Hemen uygular'), findsOneWidget);
      final secili = tester.widget<SegmentedButton<EylemKipi>>(find.descendant(of: kart, matching: find.byType(SegmentedButton<EylemKipi>))).selected;
      expect(secili, {EylemKipi.kendinYap});
    });

    testWidgets('a failed change keeps the old mode and says why', (tester) async {
      await goster(tester);
      ortam.api.sunucuHatasi = 500;
      final kart = find.byKey(const ValueKey('kip-hatirlatici-kur'));

      await tester.tap(find.descendant(of: kart, matching: find.text('Yasak')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      final secili = tester.widget<SegmentedButton<EylemKipi>>(find.descendant(of: kart, matching: find.byType(SegmentedButton<EylemKipi>))).selected;
      expect(secili, {EylemKipi.sor});
    });
  });
}
