import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/bildirim_ogesi.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/bildirimler/bildirimler_screen.dart';
import 'package:kafamdakiler/ui/bildirimler/bildirimler_view_model.dart';

import '../test_destek.dart';

/// The notification page (K-0024, sözleşme §6).
void main() {
  late TestOrtami ortam;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  // 2026-11-10 13:00 Istanbul.
  final simdi = DateTime.utc(2026, 11, 10, 10);

  BildirimOgesi b(String id, String baslik, DateTime zaman, {bool okundu = false, String? kaynak, String? hedef, String? rota, String metin = ''}) =>
      BildirimOgesi(id: id, baslik: baslik, metin: metin, zaman: zaman, okundu: okundu, kaynakTuru: kaynak, hedefKimligi: hedef, rota: rota);

  Future<void> bekle(WidgetTester tester, [int ms = 150]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  Future<BildirimlerViewModel> goster(WidgetTester tester, {String rol = 'Sahip', bool cevrimdisi = false, bool yuklemedenOnce = false}) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kullanici = (await tester.runAsync(() => testKullanicisi(ortam, rol: rol)))!;
    final vm = BildirimlerViewModel(
      repo: ortam.bildirimMerkezi,
      hatirlaticilar: ortam.hatirlaticilar,
      esitleyici: ortam.esitleyici,
      simdi: () => simdi,
    );
    addTearDown(vm.dispose);
    if (yuklemedenOnce) ortam.api.cevrimdisi = true;
    await tester.runAsync(vm.yukle);
    if (cevrimdisi) ortam.api.cevrimdisi = true;
    router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => BildirimlerScreen(viewModel: vm, yazabilir: kullanici.sahip)),
      GoRoute(path: '/asistan', builder: (c, s) => const Scaffold(body: Text('asistan sekmesi'))),
      GoRoute(path: '/takvim', builder: (c, s) => const Scaffold(body: Text('takvim sekmesi'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(testSarmalayici(ortam, kullanici, MaterialApp.router(routerConfig: router)));
    await bekle(tester);
    return vm;
  }

  Future<List<BekleyenIslemlerData>> kuyruk(WidgetTester tester) async =>
      (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;

  final karisik = [
    b('1', 'E-kampüsü kontrol et', DateTime.utc(2026, 11, 10, 11), kaynak: 'hatirlatici', hedef: 'h1', metin: '14:00 · hatırlatıcı'),
    b('2', 'Onayını bekliyor: Cuma 15:00 toplantı', DateTime.utc(2026, 11, 10, 5, 55), kaynak: 'eylem', hedef: 'e1', rota: '/asistan', metin: 'mailden'),
    b('3', 'Ödev teslimi cumaya kuruldu', DateTime.utc(2026, 11, 10, 5, 12), okundu: true, kaynak: 'asistan'),
    b('4', 'Kitapta 3 gündür okuma yok', DateTime.utc(2026, 11, 9, 18), kaynak: 'hatirlatici', okundu: true),
    b('5', 'Eski bir şey', DateTime.utc(2026, 11, 3, 9), okundu: true),
  ];

  group('the list', () {
    testWidgets('under "Bugün", "Dün" and "Daha önce"; each with its time and text; unread ones have a dot', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester);

      expect(find.byKey(const ValueKey('bildirim-baslik-bugun')), findsOneWidget);
      expect(find.byKey(const ValueKey('bildirim-baslik-dun')), findsOneWidget);
      expect(find.byKey(const ValueKey('bildirim-baslik-once')), findsOneWidget);
      expect(find.text('BUGÜN'), findsOneWidget);
      expect(find.text('DÜN'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget, reason: 'the Istanbul time of 11:00Z');
      expect(find.text('dün 21:00'), findsOneWidget);
      expect(find.text('10 Kas 12:00'), findsNothing);
      expect(find.text('3 Kas 12:00'), findsOneWidget);
      expect(find.text('mailden'), findsOneWidget);
      expect(find.byKey(const ValueKey('bildirim-nokta-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('bildirim-nokta-3')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a notification without a time sits with the old ones', (tester) async {
      ortam.api.bildirimler = [BildirimOgesi(id: 'x', baslik: 'Zamansız', metin: '')];
      await goster(tester);

      expect(find.byKey(const ValueKey('bildirim-baslik-once')), findsOneWidget);
      expect(find.text('Zamansız'), findsOneWidget);
    });

    testWidgets('empty: it says so', (tester) async {
      await goster(tester);
      expect(find.text('Henüz bildirim yok.'), findsOneWidget);
    });

    testWidgets('a server error on the first load: the message and a retry', (tester) async {
      ortam.api.sunucuHatasi = 500;
      await goster(tester);

      expect(find.textContaining('Bildirimler alınamadı (sunucu hatası 500)'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('offline with a kept page: it shows and says so', (tester) async {
      ortam.api.bildirimler = karisik;
      final ilk = BildirimlerViewModel(repo: ortam.bildirimMerkezi, hatirlaticilar: ortam.hatirlaticilar, esitleyici: ortam.esitleyici);
      await tester.runAsync(ilk.yukle);
      ilk.dispose();

      await goster(tester, yuklemedenOnce: true);

      expect(find.text('Ödev teslimi cumaya kuruldu'), findsOneWidget);
      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
    });
  });

  group('read marks', () {
    testWidgets('a tap reads the notification (one queued mark) and opens the place it names', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester, cevrimdisi: true);

      await tester.tap(find.byKey(const ValueKey('bildirim-2')));
      await tester.pumpAndSettle();
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.bildirimOkundu);
      expect(satir.hedefId, '2');
      expect(find.text('asistan sekmesi'), findsOneWidget);
    });

    testWidgets('a tap on a read one marks nothing again; one without a route stays on the page', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester, cevrimdisi: true);

      await tester.tap(find.byKey(const ValueKey('bildirim-3')));
      await bekle(tester);

      expect(await kuyruk(tester), isEmpty);
      expect(find.text('Ödev teslimi cumaya kuruldu'), findsOneWidget);
    });

    testWidgets('"Tümü okundu" reads them all with one queued mark; the button is off when nothing is unread', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester, cevrimdisi: true);

      await tester.tap(find.byKey(const ValueKey('bildirim-hepsi-okundu')));
      await bekle(tester);

      expect((await kuyruk(tester)).single.tur, BekleyenTur.bildirimHepsiOkundu);
      expect(find.byKey(const ValueKey('bildirim-nokta-1')), findsNothing);
      expect(tester.widget<TextButton>(find.byKey(const ValueKey('bildirim-hepsi-okundu'))).onPressed, isNull);
    });
  });

  group('actions on a row', () {
    testWidgets('a reminder\'s notification has "Yaptım": the reminder is done and the notification read', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester, cevrimdisi: true);

      await tester.tap(find.byKey(const ValueKey('bildirim-yaptim-1')));
      await bekle(tester);

      final turler = (await kuyruk(tester)).map((s) => (s.tur, s.hedefId)).toList();
      expect(turler, contains((BekleyenTur.hatirlaticiYaptim, 'h1')));
      expect(turler, contains((BekleyenTur.bildirimOkundu, '1')));
      expect(find.byKey(const ValueKey('bildirim-yaptim-1')), findsNothing, reason: 'read: the buttons go');
    });

    testWidgets('"1 saat ertele" snoozes the reminder for an hour and reads the notification', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester, cevrimdisi: true);

      await tester.tap(find.byKey(const ValueKey('bildirim-ertele-1')));
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      final ertele = satirlar.firstWhere((s) => s.tur == BekleyenTur.hatirlaticiErtele);
      expect(ertele.hedefId, 'h1');
      expect(ertele.govde, contains('"sure":"1s"'));
    });

    testWidgets('a read reminder has no buttons; neither does a notification that is not a reminder', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester);

      expect(find.byKey(const ValueKey('bildirim-yaptim-4')), findsNothing);
      expect(find.byKey(const ValueKey('bildirim-yaptim-2')), findsNothing);
    });

    testWidgets('an unread approval has "Asistan\'da aç", which reads it and opens the Asistan tab', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester, cevrimdisi: true);

      await tester.tap(find.byKey(const ValueKey('bildirim-asistan-2')));
      await tester.pumpAndSettle();

      expect(find.text('asistan sekmesi'), findsOneWidget);
      expect((await kuyruk(tester)).single.hedefId, '2');
    });

    testWidgets('the Asistan account may read and mark, but has no "Yaptım" or "Ertele"', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester, rol: 'Asistan');

      expect(find.byKey(const ValueKey('bildirim-yaptim-1')), findsNothing);
      expect(find.byKey(const ValueKey('bildirim-ertele-1')), findsNothing);
      expect(find.byKey(const ValueKey('bildirim-hepsi-okundu')), findsOneWidget);
    });
  });

  group('older pages', () {
    testWidgets('a full page has "Daha eski bildirimler", which adds the next page below', (tester) async {
      ortam.api.bildirimler = [
        for (var i = 0; i < 33; i++) b('n$i', 'Bildirim $i', DateTime.utc(2026, 11, 10, 9).subtract(Duration(hours: i)), okundu: true),
      ];
      await goster(tester);

      await tester.scrollUntilVisible(find.byKey(const ValueKey('bildirim-daha')), 400, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('bildirim-daha')));
      await bekle(tester);

      await tester.scrollUntilVisible(find.text('Bildirim 32'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('Bildirim 32'), findsOneWidget);
      expect(find.byKey(const ValueKey('bildirim-daha')), findsNothing, reason: 'the short page was the last');
    });

    testWidgets('a short first page has no such button', (tester) async {
      ortam.api.bildirimler = karisik;
      await goster(tester);
      expect(find.byKey(const ValueKey('bildirim-daha')), findsNothing);
    });
  });

  testWidgets('every button and row is at least 48 dp; nothing overflows at 360 dp', (tester) async {
    ortam.api.bildirimler = karisik;
    await goster(tester);

    expect(tester.takeException(), isNull);
    for (final k in ['bildirim-yaptim-1', 'bildirim-ertele-1', 'bildirim-asistan-2', 'bildirim-hepsi-okundu']) {
      final boy = tester.getSize(find.byKey(ValueKey(k)));
      expect(boy.width, greaterThanOrEqualTo(48), reason: k);
      expect(boy.height, greaterThanOrEqualTo(48), reason: k);
    }
  });
}
