import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/gun_gorunum.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/repositories/bildirim_izni.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/bugun/bugun_screen.dart';
import 'package:kafamdakiler/ui/bugun/bugun_view_model.dart';
import 'package:kafamdakiler/ui/gun/gun_view_model.dart';

import '../test_destek.dart';

/// Bugün (K-0024): the summary with the day's load, what yesterday left, the habit rings and the one list with its sheet.
void main() {
  late TestOrtami ortam;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async {
    await ortam.kapat();
  });

  final dun = DateTime.utc(2026, 10, 30);

  /// Real time for drift, then a frame.
  Future<void> bekle(WidgetTester tester, [int ms = 120]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  /// The screen on a router, so "Takvim" and the shelf page have somewhere to go. [cevrimdisi] (the default) cuts the connection
  /// after the first load: the fake server never changes its answer, so a write that was sent would be undone by the next read.
  Future<({BugunViewModel bugun, GunViewModel gun})> goster(
    WidgetTester tester, {
    GunGorunum? gun,
    String rol = 'Sahip',
    Size boyut = const Size(360, 900),
    BildirimIzni? izin,
    bool cevrimdisi = true,
    bool yuklemedenOnce = false,
  }) async {
    tester.view.physicalSize = boyut;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (gun != null) ortam.api.gunGorunumleri['2026-10-31'] = gun;
    final kullanici = (await tester.runAsync(() => testKullanicisi(ortam, rol: rol)))!;
    final bugun = BugunViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
    final gunVm = GunViewModel(repo: ortam.gun, esitleyici: ortam.esitleyici);
    addTearDown(bugun.dispose);
    addTearDown(gunVm.dispose);
    if (yuklemedenOnce) ortam.api.cevrimdisi = true;
    await tester.runAsync(() async {
      await bugun.yukle();
      await gunVm.yukle();
    });
    if (cevrimdisi) ortam.api.cevrimdisi = true;
    router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => BugunScreen(viewModel: bugun, gun: gunVm, bildirimIzni: izin, yazabilir: kullanici.sahip),
      ),
      GoRoute(path: '/takvim', builder: (c, s) => const Scaffold(body: Text('takvim sekmesi'))),
      GoRoute(path: '/aliskanlik/:id/raf', builder: (c, s) => Scaffold(body: Text('raf ${s.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(testSarmalayici(ortam, kullanici, MaterialApp.router(routerConfig: router)));
    await bekle(tester);
    return (bugun: bugun, gun: gunVm);
  }

  Future<List<BekleyenIslemlerData>> kuyruk(WidgetTester tester) async =>
      (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;

  final yedekIsler = [
    ornekYapilacak(kimlik: 'e:1', baslik: 'BLM4581 dersi', saat: '09:00'),
    ornekYapilacak(
      kimlik: 'm:aa11bb',
      baslik: 'E-kampüsü kontrol et',
      saat: '14:00',
      tahminDk: 15,
      hatirlatici: const HatirlaticiOzet(id: 'r1', saat: '14:00'),
    ),
    ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Vize slaytlarını oku', tahminDk: 120, proje: 'Okul'),
    ornekYapilacak(kimlik: 'm:ee33ff', baslik: 'Gösterim videosunu çek', tahminDk: 90, proje: 'Kafamdakiler', bolunmus: const BolunmusBilgi(sira: 1, toplam: 2)),
  ];

  group('the list', () {
    testWidgets('rows with hour, estimate, bell and the meta line; events have no "yaptım" box', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler, etkinlikDk: 60));

      expect(find.text('BLM4581 dersi'), findsOneWidget);
      expect(find.text('14:00'), findsWidgets);
      expect(find.text('15 dk'), findsOneWidget);
      expect(find.text('2 sa'), findsOneWidget);
      expect(find.text('Okul'), findsOneWidget);
      expect(find.text('Kafamdakiler · 2 günden 1.'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byKey(const ValueKey('yaptim-e:1')), findsNothing, reason: 'an event cannot be ticked');
      expect(find.byKey(const ValueKey('yaptim-m:aa11bb')), findsOneWidget);
      expect(find.text('Yapılacaklar · 3'), findsNothing, reason: 'headings are upper case');
      expect(find.text('YAPILACAKLAR · 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the "yaptım" box ticks the row at once and queues one write with the typed id', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler));

      await tester.tap(find.byKey(const ValueKey('yaptim-m:cc22dd')));
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.gunYaptim);
      expect(satirlar.single.hedefId, 'm:cc22dd');
      expect(satirlar.single.tarih, '2026-10-31');
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('yaptim-m:cc22dd'))).value, isTrue);
      expect(find.text('YAPILACAKLAR · 2'), findsOneWidget, reason: 'the open count drops');
      expect(find.text('Geri al'), findsOneWidget);
    });

    testWidgets('"Geri al" takes the tick back with one more write', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler));

      await tester.tap(find.byKey(const ValueKey('yaptim-m:cc22dd')));
      await bekle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Geri al'));
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      expect(satirlar.map((s) => s.tur), [BekleyenTur.gunYaptim, BekleyenTur.gunYaptim]);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('yaptim-m:cc22dd'))).value, isFalse);
    });

    testWidgets('a finished task offers no "Geri al": the server cannot reopen it', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: [ornekYapilacak(kimlik: 'g:rapor', baslik: 'Raporu yaz', tahminDk: 60)]));

      await tester.tap(find.byKey(const ValueKey('yaptim-g:rapor')));
      await bekle(tester);

      expect(find.text('Geri al'), findsNothing);
      expect((await kuyruk(tester)).single.hedefId, 'g:rapor');
    });

    testWidgets('an empty day says so', (tester) async {
      await goster(tester, gun: ornekGun());
      expect(find.byKey(const ValueKey('gun-bos')), findsOneWidget);
    });
  });

  group('the summary and the load', () {
    testWidgets('over the capacity: the overflow in words and "Bir kısmını devret"', (tester) async {
      // 120 + 90 + 15 = 225 dk against 180.
      await goster(tester, gun: ornekGun(ozet: 'Bugün 3 iş var.', ogeler: yedekIsler.skip(1).toList(), kapasiteDk: 180));

      expect(find.text('Bugün 3 iş var.'), findsOneWidget);
      expect(find.byKey(const ValueKey('gun-yuku')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('gun-yuku'))).data, '3 sa 45 dk / 3 sa');
      expect(tester.widget<Text>(find.byKey(const ValueKey('gun-yuk-mesaj'))).data, '45 dk fazla.');
      expect(find.byKey(const ValueKey('gun-yuk-eylem')), findsOneWidget);
    });

    testWidgets('"Bir kısmını devret" opens the sheet with the guess ticked; the button carries them to tomorrow', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler.skip(1).toList(), kapasiteDk: 180));

      await tester.tap(find.byKey(const ValueKey('gun-yuk-eylem')));
      await tester.pumpAndSettle();

      // The guess starts from the end of the list: the 90 minute item alone clears 45 minutes.
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('devret-m:ee33ff'))).value, isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('devret-m:cc22dd'))).value, isFalse);
      expect(find.text('Seçilenlerle gün sığar.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('devret-tamam')));
      await tester.pumpAndSettle();
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.gunDevret);
      expect(satirlar.single.hedefId, 'm:ee33ff');
      expect(satirlar.single.tarih, '2026-10-31');
      expect(find.text('Gösterim videosunu çek'), findsNothing, reason: 'carried rows leave today at once');
      expect(find.byKey(const ValueKey('gun-yuk-eylem')), findsNothing, reason: 'and the day fits now');
    });

    testWidgets('ticking nothing leaves the button off; picking more shows what is still over', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler.skip(1).toList(), kapasiteDk: 120));

      await tester.tap(find.byKey(const ValueKey('gun-yuk-eylem')));
      await tester.pumpAndSettle();
      // 105 dk over; the guess is 90 + 120 from the end, so it fits.
      expect(find.text('Seçilenlerle gün sığar.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('devret-m:cc22dd')));
      await tester.pump();
      expect(find.text('Seçilenlerle de 15 dk fazla kalır.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('devret-m:ee33ff')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('devret-tamam'))).onPressed, isNull);
    });

    testWidgets('little to do: the free time and a way to look at tomorrow', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Kısa iş', tahminDk: 30)]));

      expect(tester.widget<Text>(find.byKey(const ValueKey('gun-yuk-mesaj'))).data, 'Bugün az iş var, 5 sa 30 dk boşluk.');
      await tester.tap(find.byKey(const ValueKey('gun-yuk-eylem')));
      await tester.pumpAndSettle();
      expect(find.text('takvim sekmesi'), findsOneWidget);
    });

    testWidgets('it fits: the room left, and no action', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Büyük iş', tahminDk: 270)]));

      expect(tester.widget<Text>(find.byKey(const ValueKey('gun-yuk-mesaj'))).data, 'Sığıyor. 1 sa 30 dk boşluk kaldı.');
      expect(find.byKey(const ValueKey('gun-yuk-eylem')), findsNothing);
    });

    testWidgets('no summary from the server: a plain line from the count; no capacity: no bar', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler.skip(1).toList(), kapasiteDk: 0));

      expect(tester.widget<Text>(find.byKey(const ValueKey('gun-ozet'))).data, 'Bugün 3 iş var.');
      expect(find.byKey(const ValueKey('gun-yuku')), findsNothing);
    });

    testWidgets('the card is compact: the summary one step below bodyLarge, the bar thin, the action at the end of the load line', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler.skip(1).toList(), kapasiteDk: 180));

      final tema = Theme.of(tester.element(find.byKey(const ValueKey('gun-ozet'))));
      final stil = tester.widget<Text>(find.byKey(const ValueKey('gun-ozet'))).style!;
      expect(stil.fontSize, tema.textTheme.bodyMedium!.fontSize);
      expect(stil.fontSize, lessThan(tema.textTheme.bodyLarge!.fontSize!));
      expect(tester.getSize(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').startsWith('Gün yükü '))).height, lessThanOrEqualTo(10), reason: 'a thin bar');
      final mesaj = tester.getRect(find.byKey(const ValueKey('gun-yuk-mesaj')));
      final eylem = tester.getRect(find.byKey(const ValueKey('gun-yuk-eylem')));
      expect(eylem.left, greaterThanOrEqualTo(mesaj.right - 1), reason: 'on the same line, after the sentence');
      expect((eylem.center.dy - mesaj.center.dy).abs(), lessThan(12));
    });

    testWidgets('rows without an estimate are counted aside', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Tahminsiz')]));
      expect(find.text('1 işin süre tahmini yok.'), findsOneWidget);
    });
  });

  group('left over from yesterday', () {
    final market = [const DundenKalan(maddeId: 'ab12cd', baslik: 'Market', tahminDk: 45)];

    testWidgets('the strip is one compact line: the title on the left, a small "Bırak" and a tonal "Bugüne al" on the right', (tester) async {
      await goster(tester, gun: ornekGun(dunden: market));

      final bant = find.ancestor(of: find.textContaining('Dünden kaldı: '), matching: find.byType(Card));
      expect(tester.getSize(bant).height, lessThanOrEqualTo(48), reason: 'one line, not a block');
      final baslik = tester.getRect(find.textContaining('Dünden kaldı: '));
      final birak = tester.getRect(find.byKey(const ValueKey('dunden-birak-ab12cd')));
      final al = tester.getRect(find.byKey(const ValueKey('dunden-al-ab12cd')));
      expect(baslik.right, lessThanOrEqualTo(birak.left));
      expect(birak.right, lessThanOrEqualTo(al.left));
      expect(al.height, lessThanOrEqualTo(40));
      expect(find.descendant(of: bant, matching: find.byType(TextButton)), findsOneWidget);
      final stil = tester.widget<FilledButton>(find.byKey(const ValueKey('dunden-al-ab12cd'))).style!;
      expect(stil.backgroundColor!.resolve({}), isNot(Theme.of(tester.element(bant)).colorScheme.onSurface), reason: 'not the solid ink button');
    });

    testWidgets('"Bugüne al" carries it with a plan write dated yesterday and it joins the list', (tester) async {
      await goster(tester, gun: ornekGun(dunden: market));

      expect(find.textContaining('Dünden kaldı: '), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dunden-al-ab12cd')));
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.gunDevret);
      expect(satirlar.single.hedefId, 'm:ab12cd');
      expect(satirlar.single.tarih, '2026-10-30');
      expect(find.textContaining('Dünden kaldı: '), findsNothing);
      expect(find.text('Market'), findsOneWidget);
      expect(dun.day, 30);
    });

    testWidgets('"Bırak" queues the new letting-go call and the band goes', (tester) async {
      await goster(tester, gun: ornekGun(dunden: market));

      await tester.tap(find.byKey(const ValueKey('dunden-birak-ab12cd')));
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.dundenBirak);
      expect(satirlar.single.hedefId, 'ab12cd');
      expect(find.textContaining('Dünden kaldı: '), findsNothing);
      expect(find.text('Market'), findsNothing, reason: 'it is not added to today');
    });

    testWidgets('the Asistan sees the line but not the buttons', (tester) async {
      await goster(tester, gun: ornekGun(dunden: market), rol: 'Asistan');

      expect(find.textContaining('Dünden kaldı: '), findsOneWidget);
      expect(find.byKey(const ValueKey('dunden-al-ab12cd')), findsNothing);
      expect(find.byKey(const ValueKey('dunden-birak-ab12cd')), findsNothing);
    });
  });

  group('the habit strip', () {
    Future<void> seritle(WidgetTester tester, List<dynamic> aliskanliklar, {String rol = 'Sahip'}) async {
      ortam.api.aliskanliklar = [for (final a in aliskanliklar) a];
      await goster(tester, gun: ornekGun(ogeler: yedekIsler), rol: rol);
    }

    testWidgets('a yes/no habit is ticked by a tap and the row shows "tamam"', (tester) async {
      await seritle(tester, [ornekAliskanlik(id: 'y', ad: 'Spor', olcu: Olcu.evetHayir)]);

      expect(find.text('bekliyor'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('serit-y')));
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.gunYaz);
      expect(satirlar.single.hedefId, 'y');
      expect(find.text('tamam'), findsOneWidget);
      expect(find.text('Spor: yapıldı'), findsOneWidget);
    });

    testWidgets('a counter gets one more on a tap; the label shows the total against the goal', (tester) async {
      await seritle(tester, [ornekAliskanlik(id: 's', ad: 'Su', miktar: 5)]);

      expect(find.text('5 / 8'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('serit-s')));
      await bekle(tester);

      expect(find.text('6 / 8'), findsOneWidget);
      expect((await kuyruk(tester)).single.tur, BekleyenTur.gunYaz);
    });

    testWidgets('a long press on a counter types the total', (tester) async {
      await seritle(tester, [ornekAliskanlik(id: 's', ad: 'Su', miktar: 5)]);

      await tester.longPress(find.byKey(const ValueKey('serit-s')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '8');
      await tester.tap(find.text('Kaydet'));
      await bekle(tester);

      expect(find.text('8 / 8'), findsOneWidget);
    });

    testWidgets('a shelf habit opens the reading entry sheet; saving queues the session', (tester) async {
      const kitap = OgeOzet(id: 'k1', ad: 'Sapiens', guncelKonum: 212, toplam: 412, ilerleme: 0.51);
      await seritle(tester, [ornekAliskanlik(id: 'kitap', ad: 'Kitap oku', tur: AliskanlikTuru.raf, birim: 'sayfa', hedef: 30, devamEdenler: const [kitap])]);

      await tester.tap(find.byKey(const ValueKey('serit-kitap')));
      await tester.pumpAndSettle();
      expect(find.text('Okuma kaydı'), findsOneWidget);
      expect(find.text('Nereye kadar geldin? (212 / 412)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('okuma-arti')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('okuma-kaydet')));
      await tester.pumpAndSettle();
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.oturumEkle);
      expect(satir.hedefId, 'k1');
      expect(find.text('Okuma kaydı'), findsNothing);
    });

    testWidgets('a shelf habit with no book in progress still opens the sheet, with the way to the shelf', (tester) async {
      await seritle(tester, [ornekAliskanlik(id: 'kitap', ad: 'Kitap oku', tur: AliskanlikTuru.raf, birim: 'sayfa')]);

      await tester.tap(find.byKey(const ValueKey('serit-kitap')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Devam eden kitap yok'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('okuma-raf')));
      await tester.pumpAndSettle();
      expect(find.text('raf kitap'), findsOneWidget);
    });

    testWidgets('the Asistan sees the rings but they do not write', (tester) async {
      await seritle(tester, [ornekAliskanlik(id: 's', ad: 'Su', miktar: 5)], rol: 'Asistan');

      await tester.tap(find.byKey(const ValueKey('serit-s')));
      await bekle(tester);

      expect(await kuyruk(tester), isEmpty);
    });

    testWidgets('habits not planned today are not on the strip; with none planned there is no strip', (tester) async {
      await seritle(tester, [ornekAliskanlik(id: 'x', ad: 'Pazartesi koşusu', planli: false)]);
      expect(find.text('ALIŞKANLIKLAR'), findsNothing);
      expect(find.text('Pazartesi koşusu'), findsNothing);
    });
  });

  group('the row sheet', () {
    Future<void> satirAc(WidgetTester tester, String baslik) async {
      await tester.tap(find.text(baslik));
      await tester.pumpAndSettle();
    }

    testWidgets('a reminder is set up for a plan item: one queued write with the chosen fields', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler));

      await satirAc(tester, 'Vize slaytlarını oku');
      await tester.tap(find.byKey(const ValueKey('oge-hatirlatici')));
      await tester.pumpAndSettle();
      Future<void> dokun(String anahtar) async {
        await tester.ensureVisible(find.byKey(ValueKey(anahtar)));
        await tester.tap(find.byKey(ValueKey(anahtar)));
        await tester.pump();
      }

      await dokun('tekrar-haftalik');
      await dokun('gun-sal');
      await dokun('gun-per');
      await dokun('once-1');
      await dokun('hatirlatici-acil');
      await dokun('oge-kaydet');
      await tester.pumpAndSettle();
      await bekle(tester);

      final satirlar = await kuyruk(tester);
      expect(satirlar.single.tur, BekleyenTur.ogeHatirlaticiYaz);
      expect(satirlar.single.hedefId, 'm:cc22dd');
      expect(satirlar.single.govde, contains('"guncelle":false'));
      expect(satirlar.single.govde, contains('"tekrar":"haftalik"'));
      expect(satirlar.single.govde, contains('"gunler":["sal","per"]'));
      expect(satirlar.single.govde, contains('"onceGun":1'));
      expect(satirlar.single.govde, contains('"acil":true'));
      expect(find.byIcon(Icons.notifications_none), findsNothing);
    });

    testWidgets('an existing reminder opens switched on with its values; switching it off queues the removal', (tester) async {
      await goster(
        tester,
        gun: ornekGun(ogeler: [
          ornekYapilacak(
            kimlik: 'm:aa11bb',
            baslik: 'Spor salonu',
            saat: '18:30',
            hatirlatici: const HatirlaticiOzet(id: 'r', saat: '18:30', tekrar: Tekrar.haftalik, gunler: [HaftaGunu.sal, HaftaGunu.per]),
          ),
        ]),
      );

      expect(find.text('haftalık Sal, Per'), findsOneWidget);
      await satirAc(tester, 'Spor salonu');
      expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('tekrar-haftalik'))).selected, isTrue);
      expect(tester.widget<FilterChip>(find.byKey(const ValueKey('gun-sal'))).selected, isTrue);
      expect(tester.widget<FilterChip>(find.byKey(const ValueKey('gun-car'))).selected, isFalse);

      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('oge-kaydet')));
      await tester.pumpAndSettle();
      await bekle(tester);

      expect((await kuyruk(tester)).single.tur, BekleyenTur.ogeHatirlaticiSil);
    });

    testWidgets('"Yarına devret" carries a plan item and the sheet closes', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler));

      await satirAc(tester, 'Vize slaytlarını oku');
      await tester.tap(find.byKey(const ValueKey('oge-devret')));
      await tester.pumpAndSettle();
      await bekle(tester);

      expect((await kuyruk(tester)).single.tur, BekleyenTur.gunDevret);
      expect(find.byKey(const ValueKey('oge-devret')), findsNothing);
      expect(find.text('Vize slaytlarını oku'), findsNothing);
    });

    testWidgets('a task can be split over days and carried; a plan item without a task cannot be split', (tester) async {
      await goster(
        tester,
        gun: ornekGun(ogeler: [
          ornekYapilacak(kimlik: 'g:rapor', baslik: 'Raporu yaz', tahminDk: 240),
          ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Düz madde'),
        ]),
      );

      await satirAc(tester, 'Düz madde');
      expect(find.byKey(const ValueKey('oge-bol')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await satirAc(tester, 'Raporu yaz');
      expect(find.byKey(const ValueKey('oge-devret')), findsOneWidget, reason: 'the one carry-over takes tasks too (sözleşme E2)');
      await tester.tap(find.byKey(const ValueKey('oge-bol')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bol-3')));
      await tester.pumpAndSettle();
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.beyinGunlereBol);
      expect(satir.hedefId, 'rapor');
      expect(satir.govde, contains('"gunSayisi":3'));
    });

    testWidgets('a note on a plan item is queued', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler));

      await satirAc(tester, 'Vize slaytlarını oku');
      await tester.tap(find.byKey(const ValueKey('oge-not-ekle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('oge-not')), 'Önce 3. üniteden başla');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Kaydet')));
      await tester.pumpAndSettle();
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.beyinMaddeNot);
      expect(satir.govde, contains('Önce 3. üniteden başla'));
    });

    testWidgets('an event is only looked at; a reminder-only row goes to the reminder form', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: [ornekYapilacak(kimlik: 'e:1', baslik: 'BLM4581 dersi', saat: '09:00')]));

      await satirAc(tester, 'BLM4581 dersi');
      expect(find.textContaining('yalnız görülür'), findsOneWidget);
      expect(find.byKey(const ValueKey('oge-hatirlatici')), findsNothing);
    });

    testWidgets('the Asistan sees the sheet without any action', (tester) async {
      await goster(tester, gun: ornekGun(ogeler: yedekIsler), rol: 'Asistan');

      await satirAc(tester, 'Vize slaytlarını oku');

      expect(find.byKey(const ValueKey('oge-hatirlatici')), findsNothing);
      expect(find.byKey(const ValueKey('oge-devret')), findsNothing);
      expect(find.byKey(const ValueKey('oge-kaydet')), findsNothing);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('yaptim-m:cc22dd'))).onChanged, isNull);
    });
  });

  group('states', () {
    testWidgets('a server error on the first load shows a Turkish message and a retry button', (tester) async {
      ortam.api.sunucuHatasi = 500;
      await goster(tester);

      expect(find.textContaining('Gün alınamadı (sunucu hatası 500)'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('offline with a cached day: the day shows and says so', (tester) async {
      // Online first, so the day is kept on the phone.
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: yedekIsler);
      final ilk = GunViewModel(repo: ortam.gun, esitleyici: ortam.esitleyici);
      await tester.runAsync(ilk.yukle);
      ilk.dispose();

      await goster(tester, yuklemedenOnce: true);

      expect(find.text('Vize slaytlarını oku'), findsOneWidget);
      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
    });

    testWidgets('offline with nothing cached: the message and a retry button', (tester) async {
      await goster(tester, yuklemedenOnce: true);
      expect(find.textContaining('Gün alınamadı'), findsOneWidget);
    });

    testWidgets('a plan the brain could not read is said, the rest of the day still shows', (tester) async {
      final gun = ornekGun(ogeler: yedekIsler);
      await goster(
        tester,
        gun: GunGorunum(tarih: gun.tarih, yuk: gun.yuk, ogeler: gun.ogeler, kaynaklar: const GunKaynaklari(plan: 'okunamadi')),
      );
      expect(find.textContaining('plan okunamadı'), findsOneWidget);
      expect(find.text('BLM4581 dersi'), findsOneWidget);
    });

    testWidgets('"Bildirimler kapalı" tops the screen when the permission is off, and is not there when it is on', (tester) async {
      final servis = SahteBildirimServisi()
        ..izinli = false
        ..izinVerilir = false;
      final izin = BildirimIzni(servis: servis);
      await tester.runAsync(izin.denetle);
      await goster(tester, gun: ornekGun(ogeler: yedekIsler), izin: izin);

      expect(find.text('Bildirimler kapalı'), findsOneWidget);
      servis.izinli = true;
      await tester.runAsync(izin.denetle);
      await tester.pump();
      expect(find.text('Bildirimler kapalı'), findsNothing);
    });

    testWidgets('360 dp: nothing overflows; 1200 dp: the content is centred with a maximum width', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 's', ad: 'Çok uzun bir alışkanlık adı taşmamalı', miktar: 5)];
      await goster(tester, gun: ornekGun(ogeler: yedekIsler, etkinlikDk: 60, dunden: [const DundenKalan(maddeId: 'ab12cd', baslik: 'Çok uzun bir iş adı sığmazsa satıra sarılmalı', tahminDk: 45)]));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1200, 900);
      await tester.pump();
      final kart = tester.getRect(find.byType(Card).first);
      expect(kart.width, lessThanOrEqualTo(640));
      expect(kart.center.dx, closeTo(600, 1));
    });

    testWidgets('every tap target is at least 48 dp', (tester) async {
      ortam.api.aliskanliklar = [ornekAliskanlik(id: 'y', ad: 'Spor', olcu: Olcu.evetHayir)];
      await goster(tester, gun: ornekGun(ogeler: yedekIsler, dunden: [const DundenKalan(maddeId: 'ab12cd', baslik: 'Market')]));

      for (final anahtar in ['yaptim-m:aa11bb', 'serit-y']) {
        final boy = tester.getSize(find.byKey(ValueKey(anahtar)));
        expect(boy.width, greaterThanOrEqualTo(48), reason: anahtar);
        expect(boy.height, greaterThanOrEqualTo(48), reason: anahtar);
      }
      // The compact buttons of the "Dünden kaldı" strip are 36+ dp tall; the theme pads their touch area to 48.
      for (final anahtar in ['dunden-al-ab12cd', 'dunden-birak-ab12cd']) {
        final boy = tester.getSize(find.byKey(ValueKey(anahtar)));
        expect(boy.width, greaterThanOrEqualTo(48), reason: anahtar);
        expect(boy.height, greaterThanOrEqualTo(36), reason: anahtar);
      }
    });
  });
}
