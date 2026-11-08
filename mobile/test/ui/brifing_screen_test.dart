import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/data/models/ses.dart';
import 'package:kafamdakiler/routing/router.dart';
import 'package:kafamdakiler/ui/brifing/brifing_screen.dart';
import 'package:kafamdakiler/ui/brifing/brifing_view_model.dart';
import 'package:kafamdakiler/ui/yakalama/ses_view_model.dart';

import '../test_destek.dart';
import 'ses_test.dart' show SahteBaglanti, SahteDikte;

// The briefing screen (K2.7): the cards, a thumb on each, the way into the screen a card is about, the last briefing shown
// offline, and the box that writes a correction through the "İşe çevir" preview with the briefing as its source.

Brifing ornek() => Brifing(
      gun: '2026-11-08',
      uretimAni: DateTime.utc(2026, 11, 8, 3, 30),
      yontem: Brifing.claudeYontemi,
      kartlar: const [
        BrifingKarti(sira: 0, tur: BrifingTuru.plan, baslik: 'Bugün 3 iş var', metin: 'Rapor ve iki küçük iş.', bagliKimlikler: ['m1']),
        BrifingKarti(sira: 1, tur: BrifingTuru.hatirlatici, baslik: 'Cuma: diş randevusu', metin: 'Üç gün sonra saat 10:00.', bagliKimlikler: ['h1']),
        BrifingKarti(sira: 2, tur: BrifingTuru.onay, baslik: '2 eylem onay bekliyor', metin: 'Onay kuyruğuna bak.'),
        BrifingKarti(sira: 3, tur: BrifingTuru.kapasite, baslik: 'Gün dolu', metin: 'Açık işler güne sığmıyor.'),
      ],
    );

void main() {
  late TestOrtami ortam;
  late SahteBaglanti baglanti;
  late SesViewModel ses;
  late BrifingViewModel vm;
  var sahip = true;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() {
    ortam = TestOrtami();
    baglanti = SahteBaglanti();
    sahip = true;
  });
  tearDown(() async => ortam.kapat());

  Future<List<String>> goster(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    vm = BrifingViewModel(repo: ortam.brifing, yenileyebilir: () => sahip);
    ses = SesViewModel(api: ortam.api, dikte: SahteDikte(), baglanti: baglanti, kaynak: IsCikarKaynagi.brifing);
    addTearDown(ses.dispose);
    addTearDown(vm.dispose);
    final gidilen = <String>[];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => BrifingScreen(viewModel: vm, sesViewModel: ses)),
      for (final yol in [Rotalar.hatirlaticilar, Rotalar.eylemler, Rotalar.bugun])
        if (yol != '/')
          GoRoute(path: yol, builder: (_, _) {
            gidilen.add(yol);
            return Scaffold(body: Text('sayfa $yol'));
          }),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.runAsync(vm.yukle);
    await tester.pumpAndSettle();
    return gidilen;
  }

  testWidgets('the cards are shown in order with their title and sentence, and the source of the briefing', (tester) async {
    ortam.api.brifingYaniti = ornek();
    await goster(tester);
    expect(find.text('Bugün 3 iş var'), findsOneWidget);
    expect(find.text('Cuma: diş randevusu'), findsOneWidget);
    expect(find.text('Üç gün sonra saat 10:00.'), findsOneWidget);
    expect(find.text('Asistan hazırladı'), findsOneWidget);
    expect(find.text('8 Kasım Pazar'), findsOneWidget);
    expect(find.byKey(const ValueKey('brifing-eski')), findsNothing);
  });

  testWidgets('the box that turns a note into work is hidden while Claude is not connected', (tester) async {
    ortam.api.brifingYaniti = ornek();
    ortam.api.asistanBagli = false;
    await goster(tester);

    expect(find.text('Bugün 3 iş var'), findsOneWidget, reason: 'the briefing itself is still there');
    expect(find.byKey(const ValueKey('brifing-metin')), findsNothing);
    expect(find.byKey(const ValueKey('brifing-gonder')), findsNothing);
  });

  testWidgets('a briefing made by fixed rules says so', (tester) async {
    ortam.api.brifingYaniti = Brifing(gun: '2026-11-08', uretimAni: DateTime.utc(2026, 11, 8), yontem: Brifing.hesapYontemi, kartlar: ornek().kartlar);
    await goster(tester);
    expect(find.text('Sabit kurallarla hazırlandı'), findsOneWidget);
  });

  testWidgets('a thumb sends the vote and shows it; the same thumb again takes it back', (tester) async {
    ortam.api.brifingYaniti = ornek();
    await goster(tester);

    await tester.runAsync(() async => tester.tap(find.byKey(const ValueKey('brifing-oy-yukari-1'))));
    await tester.pumpAndSettle();
    expect(ortam.api.brifingOylari, [('2026-11-08', 1, 1)]);
    expect(vm.brifing!.kartlar[1].oy, 1);

    await tester.tap(find.byKey(const ValueKey('brifing-oy-yukari-1')));
    await tester.pumpAndSettle();
    expect(ortam.api.brifingOylari.last, ('2026-11-08', 1, 0), reason: 'the same thumb takes the vote back');

    await tester.tap(find.byKey(const ValueKey('brifing-oy-asagi-0')));
    await tester.pumpAndSettle();
    expect(ortam.api.brifingOylari.last, ('2026-11-08', 0, -1));
  });

  testWidgets('a card opens the screen it is about; a card with nowhere to go does nothing', (tester) async {
    ortam.api.brifingYaniti = ornek();
    final gidilen = await goster(tester);

    await tester.tap(find.text('Cuma: diş randevusu'));
    await tester.pumpAndSettle();
    expect(gidilen, [Rotalar.hatirlaticilar]);
    expect(find.text('sayfa ${Rotalar.hatirlaticilar}'), findsOneWidget);

    expect(brifingKartRotasi(BrifingTuru.onay), Rotalar.eylemler);
    expect(brifingKartRotasi(BrifingTuru.plan), Rotalar.bugun);
    expect(brifingKartRotasi(BrifingTuru.kalan), Rotalar.bugun);
    expect(brifingKartRotasi(BrifingTuru.kapasite), isNull);
    expect(brifingKartRotasi(BrifingTuru.takvim), isNull);
    expect(brifingKartRotasi(BrifingTuru.bos), isNull);
  });

  group('offline', () {
    testWidgets('the last briefing the phone kept is shown, with a note that it is not today\'s', (tester) async {
      ortam.api.brifingYaniti = ornek();
      await ortam.brifing.bugun();
      ortam.api.cevrimdisi = true;

      await goster(tester);
      expect(find.text('Bugün 3 iş var'), findsOneWidget);
      expect(find.byKey(const ValueKey('brifing-eski')), findsOneWidget);
    });

    testWidgets('a vote is not sent and the person is told', (tester) async {
      ortam.api.brifingYaniti = ornek();
      await ortam.brifing.bugun();
      ortam.api.cevrimdisi = true;
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('brifing-oy-yukari-0')));
      await tester.pump();
      await tester.pump();
      expect(ortam.api.brifingOylari, isEmpty);
      expect(find.textContaining('oy gönderilmedi'), findsOneWidget);
    });

    testWidgets('with nothing kept, a message and a retry that works once the connection is back', (tester) async {
      ortam.api.cevrimdisi = true;
      await goster(tester);
      expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);

      ortam.api.cevrimdisi = false;
      ortam.api.brifingYaniti = ornek();
      await tester.runAsync(() async => tester.tap(find.text('Tekrar dene')));
      await tester.pumpAndSettle();
      expect(find.text('Bugün 3 iş var'), findsOneWidget);
    });

    testWidgets('the writing box is off', (tester) async {
      ortam.api.brifingYaniti = ornek();
      await goster(tester);
      baglanti.ayarla(false);
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('brifing-metin')), 'cuma 10\'da diş randevusu');
      await tester.pump();
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('brifing-gonder'))).onPressed, isNull);
    });
  });

  testWidgets('not ready yet (404) and nothing kept: the person is told to try after the hour', (tester) async {
    await goster(tester);
    expect(find.textContaining('henüz hazır değil'), findsOneWidget);
  });

  group('new briefing', () {
    testWidgets('the Sahip has the button and it asks the server', (tester) async {
      ortam.api.brifingYaniti = ornek();
      await goster(tester);
      await tester.runAsync(() async => tester.tap(find.byTooltip('Yeniden hazırla')));
      await tester.pumpAndSettle();
      expect(ortam.api.brifingYenilemeleri, 1);
    });

    testWidgets('someone who is not the Sahip does not see it', (tester) async {
      sahip = false;
      ortam.api.brifingYaniti = ornek();
      await goster(tester);
      expect(find.byTooltip('Yeniden hazırla'), findsNothing);
    });

    testWidgets('a used-up limit (429) is explained', (tester) async {
      ortam.api.brifingYaniti = ornek();
      await goster(tester);
      ortam.api.brifingHatasi = 429;
      await tester.runAsync(() async => tester.tap(find.byTooltip('Yeniden hazırla')));
      await tester.pumpAndSettle();
      expect(find.text('Bugünlük yenileme sınırı doldu.'), findsOneWidget);
    });
  });

  group('the writing box', () {
    testWidgets('the text goes through the preview, and what is applied carries the briefing as its source', (tester) async {
      ortam.api.brifingYaniti = ornek();
      ortam.api.isCikarYaniti = const IsCikarYaniti(
        bugun: '2026-11-08',
        haftaninGunu: 'Pazar',
        oneriler: [IsOnerisi(tur: IsOnerisi.hatirlatici, baslik: 'Diş randevusu', gun: '2026-11-13', saat: '10:00', guven: 0.95)],
        atlananlar: [],
      );
      await goster(tester);

      await tester.enterText(find.byKey(const ValueKey('brifing-metin')), 'cuma 10\'da diş randevusu');
      await tester.pump();
      await tester.runAsync(() async => tester.tap(find.byKey(const ValueKey('brifing-gonder'))));
      await tester.pumpAndSettle();
      expect(ortam.api.isCikarMetinleri, ['cuma 10\'da diş randevusu']);
      expect(find.text('Diş randevusu'), findsOneWidget, reason: 'the preview is open');
      expect(ortam.api.uygulananIstekler, isEmpty, reason: 'nothing is saved before the person chooses');

      await tester.runAsync(() async => tester.tap(find.textContaining('Seçilenleri ekle')));
      await tester.pumpAndSettle();
      expect(ortam.api.uygulananIstekler.single.single.baslik, 'Diş randevusu');
      expect(ortam.api.uygulamaKaynaklari, [IsCikarKaynagi.brifing]);
    });

    testWidgets('the send button waits for some text; after a closed preview the text stays', (tester) async {
      ortam.api.brifingYaniti = ornek();
      ortam.api.isCikarYaniti = const IsCikarYaniti(
        bugun: '2026-11-08',
        haftaninGunu: 'Pazar',
        oneriler: [IsOnerisi(tur: IsOnerisi.plan, baslik: 'Raporu bitir', gun: '2026-11-13', guven: 0.9)],
        atlananlar: [],
      );
      await goster(tester);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('brifing-gonder'))).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('brifing-metin')), 'raporu bitir');
      await tester.pump();
      await tester.runAsync(() async => tester.tap(find.byKey(const ValueKey('brifing-gonder'))));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 20)); // outside the sheet: closes it
      await tester.pumpAndSettle();
      expect(find.text('raporu bitir'), findsOneWidget, reason: 'the text is still in the box');
      expect(ortam.api.uygulananIstekler, isEmpty);
    });
  });
}
