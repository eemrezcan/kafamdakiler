import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/models/oturum.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_detay_screen.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_detay_view_model.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_liste_screen.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_liste_view_model.dart';

import '../test_destek.dart';

/// The Alışkanlıklar tab (K-0024): a card per habit with its quick write, the shelf habit with its book and the reading entry,
/// the archive as a plain list, and the habit's page with its latest sessions.
void main() {
  late TestOrtami ortam;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  Future<void> bekle(WidgetTester tester, [int ms = 150]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  Aliskanlik tamamlanmis(Aliskanlik a) => a.copyWith(
        bugun: BugunDurumu(tarih: sabitBugun, miktar: a.gunlukHedef ?? 1, deger: 1, planli: true),
      );

  Future<AliskanlikListeViewModel> goster(WidgetTester tester, {String rol = 'Sahip', bool cevrimdisi = true}) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kullanici = (await tester.runAsync(() => testKullanicisi(ortam, rol: rol)))!;
    final vm = AliskanlikListeViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.yukle);
    if (cevrimdisi) ortam.api.cevrimdisi = true;
    router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => AliskanlikListeScreen(viewModel: vm)),
      GoRoute(path: '/aliskanlik/:id', builder: (c, s) => Scaffold(body: Text('detay ${s.pathParameters['id']}'))),
      GoRoute(path: '/oge/:id/oturum', builder: (c, s) => Scaffold(body: Text('kronometre ${s.pathParameters['id']}'))),
      GoRoute(path: '/aliskanlik/:id/raf', builder: (c, s) => Scaffold(body: Text('raf ${s.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(testSarmalayici(ortam, kullanici, MaterialApp.router(routerConfig: router)));
    await bekle(tester);
    return vm;
  }

  Future<List<BekleyenIslemlerData>> kuyruk(WidgetTester tester) async =>
      (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;

  group('the list', () {
    testWidgets('a card per habit; the title says how many are done today', (tester) async {
      ortam.api.aliskanliklar = [
        tamamlanmis(ornekAliskanlik(id: 'a', ad: 'Spor', olcu: Olcu.evetHayir)),
        ornekAliskanlik(id: 'b', ad: 'Su', miktar: 5, sira: 1),
        ornekAliskanlik(id: 'c', ad: 'Yoga', olcu: Olcu.evetHayir, sira: 2),
        ornekAliskanlik(id: 'd', ad: 'Pazartesi koşusu', planli: false, sira: 3),
      ];
      await goster(tester);

      expect(find.text('Spor'), findsOneWidget);
      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('aliskanlik-ozet'))).data, '1 / 3 bugün', reason: 'the habit not planned today is not counted');
      expect(find.byTooltip('Bir artır'), findsNWidgets(2), reason: 'the two counters, planned today or not');
      expect(find.byTooltip('Yapıldı olarak işaretle'), findsOneWidget, reason: 'Yoga; Spor is done already');
    });

    testWidgets('a counter\'s plus writes the day through the queue and shows at once', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Su', miktar: 5)];
      await goster(tester);

      await tester.tap(find.byTooltip('Bir artır'));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.gunYaz);
      expect(satir.hedefId, 'b');
      expect(satir.govde, contains('"miktar":6.0'));
      expect(find.textContaining('6 / 8'), findsWidgets);
    });

    testWidgets('a yes/no habit is ticked, and "Geri al" takes it back', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'a', ad: 'Yoga', olcu: Olcu.evetHayir)];
      await goster(tester);

      await tester.tap(find.byTooltip('Yapıldı olarak işaretle'));
      await bekle(tester);
      expect((await kuyruk(tester)).single.tur, BekleyenTur.gunYaz);
      expect(find.text('Yoga: yapıldı'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Geri al'));
      await bekle(tester);
      expect((await kuyruk(tester)).map((s) => s.tur), [BekleyenTur.gunYaz, BekleyenTur.gunSil]);
    });

    testWidgets('the name opens the habit\'s page', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Su')];
      await goster(tester);

      await tester.tap(find.text('Su'));
      await tester.pumpAndSettle();

      expect(find.text('detay b'), findsOneWidget);
    });

    testWidgets('empty list: the Sahip is told where the plus is; a server error shows a retry', (tester) async {
      await goster(tester);
      expect(find.textContaining('Henüz alışkanlık yok'), findsOneWidget);
    });

    testWidgets('a server error on the first load: the message and a retry button', (tester) async {
      ortam.api.sunucuHatasi = 500;
      await goster(tester, cevrimdisi: false);

      expect(find.textContaining('Liste alınamadı (sunucu hatası 500)'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('360 dp: no overflow with a long name; the top bar has the bell and the profile', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Çok uzun bir alışkanlık adı taşmamalı ekranda', miktar: 5)];
      await goster(tester);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Profil'), findsOneWidget);
      expect(find.byTooltip('Bildirimler'), findsOneWidget);
    });
  });

  group('a shelf habit', () {
    const sapiens = OgeOzet(id: 'k1', ad: 'Sapiens', guncelKonum: 212, toplam: 412, ilerleme: 0.51);
    const atomic = OgeOzet(id: 'k2', ad: 'Atomic Habits', guncelKonum: 48, toplam: 320, ilerleme: 0.15);

    Aliskanlik kitap(List<OgeOzet> kitaplar) => ornekAliskanlik(
          id: 'r',
          ad: 'Kitap okuma',
          tur: AliskanlikTuru.raf,
          birim: 'sayfa',
          hedef: 30,
          devamEdenler: kitaplar,
        );

    testWidgets('the book in progress with "Okudum" and "Kronometre"; "Okudum" opens the reading entry on that book', (tester) async {
      ortam.api.aliskanliklar = [kitap(const [sapiens])];
      await goster(tester);

      expect(find.text('Sapiens'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('okudum-k1')));
      await tester.pumpAndSettle();

      expect(find.text('Okuma kaydı'), findsOneWidget);
      expect(find.text('Nereye kadar geldin? (212 / 412)'), findsOneWidget);
    });

    testWidgets('with several books the chosen cover\'s book is the one the entry opens on', (tester) async {
      ortam.api.aliskanliklar = [kitap(const [sapiens, atomic])];
      await goster(tester);

      await tester.tap(find.byTooltip('Atomic Habits'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('okudum-k2')));
      await tester.pumpAndSettle();

      expect(find.text('Nereye kadar geldin? (48 / 320)'), findsOneWidget);
    });

    testWidgets('"Kronometre" opens the stopwatch page of the book', (tester) async {
      ortam.api.aliskanliklar = [kitap(const [sapiens])];
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('kronometre-k1')));
      await tester.pumpAndSettle();

      expect(find.text('kronometre k1'), findsOneWidget);
    });

    testWidgets('no book in progress: "Rafa git"', (tester) async {
      ortam.api.aliskanliklar = [kitap(const [])];
      await goster(tester);

      await tester.tap(find.text('Rafa git'));
      await tester.pumpAndSettle();

      expect(find.text('raf r'), findsOneWidget);
    });

    testWidgets('the Asistan account sees the book but not the reading buttons', (tester) async {
      ortam.api.aliskanliklar = [kitap(const [sapiens])];
      await goster(tester, rol: 'Asistan');

      expect(find.text('Sapiens'), findsOneWidget);
      expect(find.byKey(const ValueKey('okudum-k1')), findsNothing);
      expect(find.byKey(const ValueKey('kronometre-k1')), findsNothing);
    });
  });

  group('the archive', () {
    testWidgets('a plain list of the archived habits, with no quick writes and no summary', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Eski alışkanlık')];
      final vm = await goster(tester, cevrimdisi: false);

      await tester.tap(find.byTooltip('Arşivdekileri göster'));
      await bekle(tester);

      expect(vm.arsiv, isTrue);
      expect(find.text('Eski alışkanlık'), findsOneWidget);
      expect(find.byTooltip('Bir artır'), findsNothing);
      expect(find.byKey(const ValueKey('aliskanlik-ozet')), findsNothing);
    });
  });

  group('the habit page', () {
    Future<AliskanlikDetayViewModel> detay(WidgetTester tester, String id, {String rol = 'Sahip'}) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final kullanici = (await tester.runAsync(() => testKullanicisi(ortam, rol: rol)))!;
      final vm = AliskanlikDetayViewModel(repo: ortam.repo, id: id);
      addTearDown(vm.dispose);
      await tester.runAsync(vm.yukle);
      // The page is on top of another one: deleting the habit pops it.
      router = GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('liste'))),
        GoRoute(path: '/detay', builder: (c, s) => AliskanlikDetayScreen(viewModel: vm)),
        GoRoute(path: '/aliskanlik/:id/duzenle', builder: (c, s) => Scaffold(body: Text('düzenle ${s.pathParameters['id']}'))),
        GoRoute(path: '/aliskanlik/:id/raf', builder: (c, s) => Scaffold(body: Text('raf ${s.pathParameters['id']}'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(testSarmalayici(ortam, kullanici, MaterialApp.router(routerConfig: router)));
      router.push('/detay');
      await bekle(tester);
      return vm;
    }

    Oturum oturum(String id, String ogeId, double bas, double bit, DateTime an, {int? dakika}) => Oturum(
          id: id,
          ogeId: ogeId,
          tarih: DateTime.utc(an.year, an.month, an.day),
          baslangicKonum: bas,
          bitisKonum: bit,
          miktar: bit - bas,
          dakika: dakika,
          olusturulma: an,
          son: false,
        );

    testWidgets('the streak, the 30 days and the latest sessions of the books in progress, newest first', (tester) async {
      const sapiens = OgeOzet(id: 'k1', ad: 'Sapiens', guncelKonum: 212, toplam: 412, ilerleme: 0.51);
      const atomic = OgeOzet(id: 'k2', ad: 'Atomic Habits', guncelKonum: 48, toplam: 320, ilerleme: 0.15);
      ortam.api.aliskanliklar = [
        ornekAliskanlik(id: 'r', ad: 'Kitap okuma', tur: AliskanlikTuru.raf, birim: 'sayfa', devamEdenler: const [sapiens, atomic]),
      ];
      ortam.api.oturumlar = {
        'k1': [oturum('o1', 'k1', 168, 200, DateTime.utc(2026, 10, 29, 9), dakika: 41), oturum('o2', 'k1', 200, 212, DateTime.utc(2026, 10, 31, 5), dakika: 18)],
        'k2': [oturum('o3', 'k2', 30, 48, DateTime.utc(2026, 10, 30, 8))],
      };
      await detay(tester, 'r');

      expect(find.text('SERİ'), findsOneWidget);
      expect(find.text('3'), findsWidgets, reason: 'the streak');
      expect(find.text('Son 30 gün'), findsOneWidget);
      expect(find.text('Son oturumlar'), findsOneWidget);
      final satirlar = tester.widgetList<Text>(find.descendant(of: find.byKey(const ValueKey('detay-oturumlar')), matching: find.byType(Text))).map((t) => t.data).toList();
      expect(satirlar.first, 'Sapiens · 200 → 212');
      expect(satirlar, contains('31 Ekim · 18 dk'));
      expect(satirlar, contains('Atomic Habits · 30 → 48'));
      expect(satirlar, contains('Sapiens · 168 → 200'));
      expect(satirlar.indexOf('Atomic Habits · 30 → 48'), lessThan(satirlar.indexOf('Sapiens · 168 → 200')), reason: 'newest first');
    });

    testWidgets('a counter has no session list', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Su')];
      await detay(tester, 'b');

      expect(find.byKey(const ValueKey('detay-oturumlar')), findsNothing);
    });

    testWidgets('offline the sessions are left out and the rest of the page shows', (tester) async {
      const sapiens = OgeOzet(id: 'k1', ad: 'Sapiens', guncelKonum: 212, toplam: 412, ilerleme: 0.51);
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'r', ad: 'Kitap okuma', tur: AliskanlikTuru.raf, devamEdenler: const [sapiens])];
      ortam.api.oturumlar = {'k1': [oturum('o1', 'k1', 200, 212, DateTime.utc(2026, 10, 31, 5))]};
      ortam.api.cevrimdisi = true;
      await detay(tester, 'r');

      expect(find.byKey(const ValueKey('detay-oturumlar')), findsNothing);
      expect(find.text('Son oturumlar'), findsNothing);
    });

    testWidgets('the menu: edit, archive and delete (the Sahip only)', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Su')];
      await detay(tester, 'b');

      await tester.tap(find.byTooltip('Seçenekler'));
      await tester.pumpAndSettle();
      expect(find.text('Düzenle'), findsOneWidget);
      expect(find.text('Arşivle'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);

      await tester.tap(find.text('Arşivle'));
      await bekle(tester);
      expect(ortam.api.aliskanlikYazimlari, ['guncelle:b:true']);
    });

    testWidgets('delete asks first', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Su')];
      await detay(tester, 'b');

      await tester.tap(find.byTooltip('Seçenekler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bu geri alınamaz'), findsOneWidget);
      expect(ortam.api.aliskanlikYazimlari, isEmpty, reason: 'nothing is deleted before the person confirms');

      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Sil')));
      await bekle(tester);
      await tester.pumpAndSettle();
      expect(ortam.api.aliskanlikYazimlari, ['sil:b']);
      expect(find.text('liste'), findsOneWidget, reason: 'the page closed after the delete');
    });

    testWidgets('the Asistan account has no menu', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'b', ad: 'Su')];
      await detay(tester, 'b', rol: 'Asistan');

      expect(find.byTooltip('Seçenekler'), findsNothing);
    });
  });
}
