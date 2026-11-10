import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/oturum/okuma_kaydi_sheet.dart';
import 'package:kafamdakiler/ui/oturum/okuma_kaydi_view_model.dart';

import '../test_destek.dart';

/// The reading entry sheet (K-0024): which book, how far, how long, "Kitabı bitirdim".
void main() {
  late TestOrtami ortam;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  const sapiens = OgeOzet(id: 'k1', ad: 'Sapiens', guncelKonum: 212, toplam: 412, ilerleme: 0.51);
  const atomic = OgeOzet(id: 'k2', ad: 'Atomic Habits', guncelKonum: 48, toplam: 320, ilerleme: 0.15);

  Aliskanlik kitapAliskanligi({List<OgeOzet> kitaplar = const [sapiens, atomic], double bugun = 12}) => ornekAliskanlik(
        id: 'r',
        ad: 'Kitap okuma',
        tur: AliskanlikTuru.raf,
        birim: 'sayfa',
        hedef: 30,
        miktar: bugun,
        devamEdenler: kitaplar,
      );

  Future<void> bekle(WidgetTester tester, [int ms = 150]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  /// A page with a button that opens the sheet, on a router (the sheet's "Kronometre" and "Raftan seç" push pages).
  Future<void> ac(WidgetTester tester, Aliskanlik a, {String? ogeId, bool cevrimdisi = true}) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kullanici = (await tester.runAsync(() => testKullanicisi(ortam)))!;
    ortam.api.ogeler = [
      Oge(
        id: 'k1',
        aliskanlikId: 'r',
        ad: 'Sapiens',
        toplam: 412,
        baslangicKonumu: 0,
        guncelKonum: 212,
        durum: OgeDurumu.devam,
        olusturulma: DateTime.utc(2026, 10, 1),
      ),
    ];
    router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => Scaffold(
          body: Builder(
            builder: (c) => TextButton(key: const ValueKey('ac'), onPressed: () => okumaKaydiAc(c, aliskanlik: a, ogeId: ogeId), child: const Text('Aç')),
          ),
        ),
      ),
      GoRoute(path: '/oge/:id/oturum', builder: (c, s) => Scaffold(body: Text('kronometre ${s.pathParameters['id']}'))),
      GoRoute(path: '/aliskanlik/:id/raf', builder: (c, s) => Scaffold(body: Text('raf ${s.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    if (cevrimdisi) ortam.api.cevrimdisi = true;
    await tester.pumpWidget(testSarmalayici(ortam, kullanici, MaterialApp.router(routerConfig: router)));
    await tester.tap(find.byKey(const ValueKey('ac')));
    await tester.pumpAndSettle();
  }

  Future<List<BekleyenIslemlerData>> kuyruk(WidgetTester tester) async =>
      (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;

  testWidgets('it opens on the first book with its position, the goal of the day and the books to pick from', (tester) async {
    await ac(tester, kitapAliskanligi());

    expect(find.text('Okuma kaydı'), findsOneWidget);
    expect(find.text('Kitap okuma · bugün 12 / 30 sayfa'), findsOneWidget);
    expect(find.text('Nereye kadar geldin? (212 / 412)'), findsOneWidget);
    expect(find.byKey(const ValueKey('okuma-kitap-k1')), findsOneWidget);
    expect(find.byKey(const ValueKey('okuma-kitap-k2')), findsOneWidget);
    expect(find.byKey(const ValueKey('okuma-raf')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('okuma-konum'))).controller!.text, '212');
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('okuma-kaydet'))).onPressed, isNull, reason: 'no progress yet');
  });

  testWidgets('a given book is selected when the sheet opens from that book\'s button', (tester) async {
    await ac(tester, kitapAliskanligi(), ogeId: 'k2');

    expect(find.text('Nereye kadar geldin? (48 / 320)'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('okuma-konum'))).controller!.text, '48');
  });

  testWidgets('the steps change the position and say what is left of the day\'s goal; at the goal it says so', (tester) async {
    await ac(tester, kitapAliskanligi());

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const ValueKey('okuma-arti')));
    }
    await tester.pump();
    expect(find.text('bu kayıtta +10 sayfa → hedefe 8 sayfa kaldı'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('okuma-konum'))).controller!.text, '222');

    await tester.enterText(find.byKey(const ValueKey('okuma-konum')), '230');
    await tester.pump();
    expect(find.text('bu kayıtta +18 sayfa → günün hedefine ulaştın'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('okuma-eksi')));
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('okuma-konum'))).controller!.text, '229');
  });

  testWidgets('a position that is not above the current one, or above the total, is refused and cannot be saved', (tester) async {
    await ac(tester, kitapAliskanligi());

    await tester.enterText(find.byKey(const ValueKey('okuma-konum')), '200');
    await tester.pump();
    expect(find.text('212 değerinden büyük olmalı.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('okuma-kaydet'))).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('okuma-konum')), '500');
    await tester.pump();
    expect(find.text('Toplamdan (412) büyük olamaz.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('okuma-kaydet'))).onPressed, isNull);
  });

  testWidgets('saving queues the session with the start position and the minutes, closes the sheet and says so', (tester) async {
    await ac(tester, kitapAliskanligi());

    await tester.enterText(find.byKey(const ValueKey('okuma-konum')), '230');
    await tester.tap(find.byKey(const ValueKey('okuma-sure-20')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('okuma-kaydet')));
    await tester.pumpAndSettle();
    await bekle(tester);

    final satir = (await kuyruk(tester)).single;
    expect(satir.tur, BekleyenTur.oturumEkle);
    expect(satir.hedefId, 'k1');
    expect(satir.govde, contains('"bitisKonum":230.0'));
    expect(satir.govde, contains('"baslangicKonum":212.0'));
    expect(satir.govde, contains('"dakika":20'));
    expect(find.text('Okuma kaydı'), findsNothing, reason: 'the sheet closed');
    expect(find.text('Okuma kaydedildi'), findsOneWidget);
  });

  testWidgets('minutes are optional: none chosen sends none; a chip is a toggle', (tester) async {
    await ac(tester, kitapAliskanligi());

    await tester.tap(find.byKey(const ValueKey('okuma-sure-30')));
    await tester.pump();
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('okuma-sure-30'))).selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('okuma-sure-30')));
    await tester.pump();
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('okuma-sure-30'))).selected, isFalse);

    await tester.tap(find.byKey(const ValueKey('okuma-arti')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('okuma-kaydet')));
    await tester.pumpAndSettle();
    await bekle(tester);

    expect((await kuyruk(tester)).single.govde, isNot(contains('dakika')));
  });

  testWidgets('"Elle…" takes minutes by hand and the chip shows them', (tester) async {
    await ac(tester, kitapAliskanligi());

    await tester.tap(find.byKey(const ValueKey('okuma-sure-elle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('okuma-sure-alan')), '55');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();

    expect(find.text('55 dk'), findsOneWidget);
  });

  testWidgets('picking another book moves the position to that book\'s and clears "bitirdim"', (tester) async {
    await ac(tester, kitapAliskanligi());

    await tester.tap(find.byKey(const ValueKey('okuma-bitti')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('okuma-kitap-k2')));
    await tester.pump();

    expect(find.text('Nereye kadar geldin? (48 / 320)'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('okuma-bitti'))).value, isFalse);
  });

  testWidgets('"Raftan seç" and "Kronometre" close the sheet and open their pages', (tester) async {
    await ac(tester, kitapAliskanligi());
    await tester.tap(find.byKey(const ValueKey('okuma-raf')));
    await tester.pumpAndSettle();
    expect(find.text('raf r'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ac')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('okuma-kronometre')));
    await tester.pumpAndSettle();
    expect(find.text('kronometre k1'), findsOneWidget);
  });

  testWidgets('no book in progress: it says so and offers the shelf; nothing can be saved', (tester) async {
    await ac(tester, kitapAliskanligi(kitaplar: const []));

    expect(find.textContaining('Devam eden kitap yok'), findsOneWidget);
    expect(find.byKey(const ValueKey('okuma-raf')), findsOneWidget);
    expect(find.byKey(const ValueKey('okuma-kronometre')), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('okuma-kaydet'))).onPressed, isNull);
  });

  testWidgets('"Kitabı bitirdim" online: the session is sent first, then the book is marked finished', (tester) async {
    await ac(tester, kitapAliskanligi(), cevrimdisi: false);

    await tester.enterText(find.byKey(const ValueKey('okuma-konum')), '412');
    await tester.tap(find.byKey(const ValueKey('okuma-bitti')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('okuma-kaydet')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();

    expect(ortam.api.cagrilar.indexOf('oturumEkle'), lessThan(ortam.api.cagrilar.indexOf('ogeGuncelle')));
    final (id, yaz) = ortam.api.ogeGuncellemeleri.single;
    expect(id, 'k1');
    expect(yaz.durum, OgeDurumu.bitti);
    expect(yaz.ad, 'Sapiens');
    expect(find.text('Okuma kaydedildi'), findsOneWidget);
  });

  testWidgets('"Kitabı bitirdim" offline: the session is kept, the finished mark cannot be made and the message says so', (tester) async {
    await ac(tester, kitapAliskanligi());

    await tester.enterText(find.byKey(const ValueKey('okuma-konum')), '412');
    await tester.tap(find.byKey(const ValueKey('okuma-bitti')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('okuma-kaydet')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect((await kuyruk(tester)).single.tur, BekleyenTur.oturumEkle);
    expect(ortam.api.ogeGuncellemeleri, isEmpty);
    expect(find.textContaining('bağlantı gerekli'), findsOneWidget);
  });

  testWidgets('360 dp: nothing overflows and the buttons are at least 48 dp', (tester) async {
    await ac(tester, kitapAliskanligi());

    expect(tester.takeException(), isNull);
    for (final k in ['okuma-arti', 'okuma-eksi', 'okuma-kaydet', 'okuma-kronometre', 'okuma-sure-elle']) {
      final boy = tester.getSize(find.byKey(ValueKey(k)));
      expect(boy.width, greaterThanOrEqualTo(48), reason: k);
      expect(boy.height, greaterThanOrEqualTo(48), reason: k);
    }
  });

  test('the view model: the goal figures', () {
    final vm = OkumaKaydiViewModel(
      repo: ortam.repo,
      esitleyici: ortam.esitleyici,
      aliskanlik: kitapAliskanligi(),
    );
    addTearDown(vm.dispose);

    expect(vm.fark, 0);
    expect(vm.hedefKalan, 18);
    vm.konumYaz(250);
    expect(vm.fark, 38);
    expect(vm.bugunToplam, 50);
    expect(vm.hedefKalan, 0, reason: 'past the goal is zero left, not a negative');
  });
}
