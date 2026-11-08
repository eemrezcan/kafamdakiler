import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/data/repositories/aliskanlik_repository.dart';
import 'package:kafamdakiler/data/repositories/auth_repository.dart';
import 'package:kafamdakiler/data/repositories/beyin_repository.dart';
import 'package:kafamdakiler/data/repositories/brifing_repository.dart';
import 'package:kafamdakiler/data/repositories/zaman_cizelgesi_repository.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/gun_plani_repository.dart';
import 'package:kafamdakiler/data/repositories/eylem_repository.dart';
import 'package:kafamdakiler/data/repositories/gelen_repository.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_repository.dart';
import 'package:kafamdakiler/data/repositories/kronometre_repository.dart';
import 'package:kafamdakiler/data/repositories/kullanici_repository.dart';
import 'package:kafamdakiler/data/repositories/yakalama_repository.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/token_depo.dart';
import 'package:kafamdakiler/routing/router.dart';
import 'package:provider/provider.dart';

import '../test_destek.dart';
import '../ui/ses_test.dart' show SahteBaglanti;

class _SahteDepo implements TokenDepo {
  @override
  Future<String?> accessToken() async => 'a';
  @override
  Future<String?> refreshToken() async => 'r';
  @override
  Future<void> kaydet({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> temizle() async {}
}

/// The real router and the real shell with in-memory data: the five tabs, the Yakala button, the search page, the briefing
/// strip on Bugün, the Daha fazla screen and the pages above them.
void main() {
  late TestOrtami ortam;
  late AuthRepository auth;
  late KullaniciRepository kullanici;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('tr'));

  setUp(() {
    ortam = TestOrtami();
    ortam.api.aliskanliklar = [ornekAliskanlik()];
    ortam.api.projeler = const [
      ProjeOzet(kimlik: 'kitap-kulubu', baslik: 'Kitap Kulübü Sitesi'),
      ProjeOzet(kimlik: 'balkon-bahcesi', baslik: 'Balkon Bahçesi Sulama'),
    ];
    ortam.api.projeDetaylari = {
      'kitap-kulubu': const ProjeDetay(
        kimlik: 'kitap-kulubu',
        baslik: 'Kitap Kulübü Sitesi',
        durum: 'Okuma listesi bitti.',
        siradakiAdim: 'Takvim sayfası.',
      ),
    };
    ortam.api.aramaSonuclari = const [
      AramaSonucu(yol: 'projects/kitap-kulubu/notlar/takvim.md', baslik: 'Takvim için kütüphane', alinti: 'Hazır bileşen.'),
    ];
    ortam.api.notlar = {
      'projects/kitap-kulubu/notlar/takvim.md': const BeyinNotu(
        yol: 'projects/kitap-kulubu/notlar/takvim.md',
        baslik: 'Takvim için kütüphane',
        etiketler: ['mimari'],
        govde: '## Karar\n\nHazır bir **bileşen** kullanılacak.',
      ),
    };
  });

  tearDown(() async {
    router.dispose();
    await ortam.kapat();
  });

  /// Real time for drift, then a frame.
  Future<void> bekle(WidgetTester tester, [int ms = 150]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  Future<void> uygulamayiAc(WidgetTester tester, {String rol = 'Sahip'}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ortam.api.ben_ = Ben(id: 'u', email: 'x@y.z', roller: [rol]);
    auth = AuthRepository(api: ortam.api, depo: _SahteDepo());
    kullanici = KullaniciRepository(api: ortam.api, db: ortam.db);
    await tester.runAsync(() async {
      await auth.baslat();
      await kullanici.yukle();
    });
    router = routerOlustur(auth, kullanici, baglantiServisi: SahteBaglanti.new);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: kullanici),
          Provider<ApiService>.value(value: ortam.api),
          ChangeNotifierProvider<Esitleyici>.value(value: ortam.esitleyici),
          ChangeNotifierProvider<AliskanlikRepository>.value(value: ortam.repo),
          ChangeNotifierProvider<YakalamaRepository>.value(value: ortam.yakalamalar),
          ChangeNotifierProvider<HatirlaticiRepository>.value(value: ortam.hatirlaticilar),
          ChangeNotifierProvider<EylemRepository>.value(value: ortam.eylemler),
          ChangeNotifierProvider<GelenRepository>.value(value: ortam.gelen),
          Provider<HatirlaticiBildirimYoneticisi>.value(
            value: HatirlaticiBildirimYoneticisi(
              repo: ortam.hatirlaticilar,
              esitleyici: ortam.esitleyici,
              servis: SahteBildirimServisi(),
              yazabilir: () => true,
            ),
          ),
          Provider<BrifingRepository>.value(value: ortam.brifing),
          Provider<ZamanCizelgesiRepository>.value(value: ortam.zamanCizelgesi),
          Provider<BeyinRepository>.value(value: ortam.beyin),
          ChangeNotifierProvider<GunPlaniRepository>.value(value: ortam.gunPlani),
          Provider<KronometreRepository>.value(value: KronometreRepository(db: ortam.db)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await bekle(tester);
  }

  Future<void> sekme(WidgetTester tester, String ad) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(ad)));
    await bekle(tester);
  }

  int secili(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  const sekmeAdlari = ['Bugün', 'Gelen', 'Projeler', 'Hatırlatıcılar', 'Daha fazla'];

  testWidgets('five tabs in the agreed order; search and the habit list are not among them', (tester) async {
    await uygulamayiAc(tester);

    final etiketler = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label).toList();
    expect(etiketler, sekmeAdlari);
  });

  testWidgets('tabs are switched in the order of the bar', (tester) async {
    await uygulamayiAc(tester);
    for (var i = 0; i < sekmeAdlari.length; i++) {
      await sekme(tester, sekmeAdlari[i]);
      expect(secili(tester), i);
      expect(router.state.matchedLocation, Rotalar.sekmeler[i]);
    }
  });

  testWidgets('back on another tab goes to Bugün first', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Daha fazla');
    expect(secili(tester), 4);

    await tester.binding.handlePopRoute();
    await bekle(tester);

    expect(secili(tester), 0);
    expect(find.text('Gün planı'), findsOneWidget);
  });

  testWidgets('the addresses of the tabs open the tab', (tester) async {
    await uygulamayiAc(tester);

    for (final (yol, sira) in [('/gelen', 1), ('/hatirlaticilar', 3), ('/daha-fazla', 4), ('/projeler', 2), ('/', 0)]) {
      router.go(yol);
      await bekle(tester);
      expect(secili(tester), sira, reason: yol);
    }
  });

  testWidgets('Bugün shows the brain plan and today\'s habit cards together', (tester) async {
    await uygulamayiAc(tester);

    expect(find.text('Gün planı'), findsOneWidget);
    expect(find.text('Su iç'), findsOneWidget);
  });

  testWidgets('the Yakala button stays on every tab and opens the capture screen', (tester) async {
    await uygulamayiAc(tester);

    for (final ad in sekmeAdlari) {
      await sekme(tester, ad);
      expect(find.text('Yakala'), findsOneWidget, reason: 'on the $ad tab');
    }

    await tester.tap(find.text('Yakala'));
    await bekle(tester);
    expect(find.text('Aklında ne var?'), findsOneWidget);
    expect(find.text('Proje (isteğe bağlı)'), findsOneWidget);
  });

  testWidgets('the Asistan role has no Yakala button on the tabs', (tester) async {
    await uygulamayiAc(tester, rol: 'Asistan');

    for (final ad in sekmeAdlari) {
      await sekme(tester, ad);
      expect(find.text('Yakala'), findsNothing, reason: 'on the $ad tab');
    }
  });

  testWidgets('Projeler: list -> detail -> back to the list', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Projeler');
    expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);

    await tester.tap(find.text('Kitap Kulübü Sitesi'));
    await bekle(tester);
    expect(find.text('Okuma listesi bitti.'), findsOneWidget);
    expect(find.text('Takvim sayfası.'), findsOneWidget);

    router.pop();
    await bekle(tester);
    expect(find.text('Balkon Bahçesi Sulama'), findsOneWidget);
  });

  group('search', () {
    testWidgets('the magnifier is in the top bar of the four tabs and not on Daha fazla', (tester) async {
      await uygulamayiAc(tester);

      for (final ad in ['Bugün', 'Gelen', 'Projeler', 'Hatırlatıcılar']) {
        await sekme(tester, ad);
        expect(find.byTooltip('Ara'), findsOneWidget, reason: 'on the $ad tab');
      }
      await sekme(tester, 'Daha fazla');
      expect(find.byTooltip('Ara'), findsNothing);
    });

    testWidgets('the magnifier opens a full-screen page: query -> hit -> the note rendered -> back keeps the results', (tester) async {
      await uygulamayiAc(tester);
      await sekme(tester, 'Projeler');

      await tester.tap(find.byTooltip('Ara'));
      await bekle(tester);
      expect(router.state.matchedLocation, '/ara');
      expect(find.byType(NavigationBar), findsNothing, reason: 'search is a page above the tabs, not a tab');

      await tester.enterText(find.byType(TextField), 'takvim');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await bekle(tester);
      expect(find.text('Takvim için kütüphane'), findsOneWidget);

      await tester.tap(find.text('Takvim için kütüphane'));
      await bekle(tester);
      expect(find.textContaining('Hazır bir', findRichText: true), findsOneWidget);
      expect(find.textContaining('**', findRichText: true), findsNothing);

      router.pop();
      await bekle(tester);
      expect(find.text('Takvim için kütüphane'), findsOneWidget);
      expect(find.text('Hazır bileşen.'), findsOneWidget);

      // Back from the search page returns to the tab it was opened from.
      router.pop();
      await bekle(tester);
      expect(secili(tester), 2);
    });
  });

  testWidgets('the Yakalamalar page is gone: its address matches no route, and the Gelen tab shows the waiting captures', (tester) async {
    // Offline, so the capture stays on the phone instead of being sent at once.
    ortam.api.cevrimdisi = true;
    await tester.runAsync(() => ortam.yakalamalar.yakala(metin: 'yoldaki yakalama'));
    await uygulamayiAc(tester);

    final yollar = router.configuration.routes.whereType<GoRoute>().map((r) => r.path);
    expect(yollar, isNot(contains('/yakalamalar')));
    // The edit route stays: a row of "Gönderiliyor" opens it.
    expect(router.configuration.routes.whereType<GoRoute>().map((r) => r.path), contains('/yakalama/:id/duzenle'));

    await sekme(tester, 'Gelen');
    expect(find.text('GÖNDERİLİYOR  1'), findsOneWidget);
    expect(find.text('yoldaki yakalama'), findsOneWidget);
  });

  testWidgets('Daha fazla opens the habit list, and the old habit routes still work', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Daha fazla');

    await tester.tap(find.text('Alışkanlıklar'));
    await bekle(tester);
    expect(find.text('Su iç'), findsOneWidget, reason: 'the habit list page');

    // The address works on its own too (an old link, a redirect), not only through Daha fazla.
    router.go('/');
    await bekle(tester);
    router.go('/aliskanliklar');
    await bekle(tester);
    expect(router.state.matchedLocation, '/aliskanliklar');
    expect(find.text('Su iç'), findsOneWidget);
  });

  testWidgets('Daha fazla has the account, Yönetim, the password and sign-out, and no tab entries', (tester) async {
    await uygulamayiAc(tester);
    tester.view.physicalSize = const Size(400, 1600);
    await sekme(tester, 'Daha fazla');

    for (final metin in ['x@y.z', 'Alışkanlıklar', 'Yönetim', 'Şifremi değiştir', 'Çıkış yap', 'Sabah bildirimi']) {
      expect(find.text(metin), findsOneWidget, reason: metin);
    }
    for (final metin in ['Onay kuyruğu', 'Gelen kutusu', 'Sabah brifingi', 'Yakalamalar']) {
      expect(find.text(metin), findsNothing, reason: '$metin is not a row here');
    }
    // "Hatırlatıcılar" is the tab label only, not a row.
    expect(find.text('Hatırlatıcılar'), findsOneWidget);

    await tester.tap(find.text('Yönetim'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/yonetim');
    expect(find.byType(NavigationBar), findsNothing, reason: 'a page above the tabs');
  });

  testWidgets('the Yaklaşanlar card on Bugün switches to the Hatırlatıcılar tab', (tester) async {
    ortam.api.hatirlaticilar = [
      ornekHatirlatici(id: 'h', baslik: 'Yaklaşan iş', sonrakiAn: DateTime.now().toUtc().add(const Duration(days: 2))),
    ];
    await uygulamayiAc(tester);

    expect(find.text('Yaklaşanlar'), findsOneWidget);
    await tester.tap(find.text('Yaklaşanlar'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/hatirlaticilar');
    expect(secili(tester), 3);
    expect(find.text('Yaklaşan iş'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await bekle(tester);
    expect(secili(tester), 0, reason: 'back goes to Bugün, it does not leave the app');
  });

  testWidgets('the "Onay bekleyen" card on Bugün and on Gelen both open the approval queue; a tap on a card opens its detail', (tester) async {
    ortam.api.eylemler = [ornekEylem(id: 'e1', ozet: 'Ali\'yi ara'), ornekEylem(id: 'e2', ozet: 'Faturayı öde')];
    await uygulamayiAc(tester);

    expect(find.text('Onay bekleyen 2'), findsOneWidget);
    await tester.tap(find.text('Onay bekleyen 2'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/eylemler');
    expect(find.text('Faturayı öde'), findsOneWidget);

    await tester.tap(find.text('Faturayı öde'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/eylem/e2');
    expect(find.text('Yük'), findsOneWidget);

    router.go('/');
    await bekle(tester);
    await sekme(tester, 'Gelen');
    expect(find.text('Onay bekleyen 2'), findsOneWidget);
    await tester.tap(find.text('Onay bekleyen 2'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/eylemler');
  });

  testWidgets('with nothing waiting neither Bugün nor Gelen has the "Onay bekleyen" card', (tester) async {
    await uygulamayiAc(tester);
    expect(find.textContaining('Onay bekleyen'), findsNothing);

    await sekme(tester, 'Gelen');
    expect(find.textContaining('Onay bekleyen'), findsNothing);
  });

  group('the briefing strip on Bugün', () {
    final brifing = Brifing(
      gun: '2026-11-08',
      uretimAni: DateTime.utc(2026, 11, 8, 3, 30),
      yontem: Brifing.claudeYontemi,
      kartlar: const [
        BrifingKarti(sira: 0, tur: BrifingTuru.kalan, baslik: 'Dünden 2 iş kaldı', metin: 'Rapor ve fatura.'),
        BrifingKarti(sira: 1, tur: BrifingTuru.hatirlatici, baslik: 'Cuma: diş randevusu', metin: 'Üç gün sonra saat 10:00.'),
      ],
    );

    testWidgets('the Sahip sees it above the plan, without the leftovers card; the writing box waits for the assistant', (tester) async {
      ortam.api.brifingYaniti = brifing;
      ortam.api.asistanBagli = false;
      await uygulamayiAc(tester);

      expect(find.text('Sabah brifingi'), findsOneWidget);
      expect(find.text('Cuma: diş randevusu'), findsOneWidget);
      expect(find.text('Dünden 2 iş kaldı'), findsNothing);
      expect(find.byKey(const ValueKey('brifing-metin')), findsNothing, reason: 'the assistant is not connected');
      expect(tester.getTopLeft(find.text('Sabah brifingi')).dy, lessThan(tester.getTopLeft(find.text('Gün planı')).dy));
    });

    testWidgets('with the assistant connected the writing box is in the strip', (tester) async {
      ortam.api.brifingYaniti = brifing;
      ortam.api.asistanBagli = true;
      await uygulamayiAc(tester);

      expect(find.byKey(const ValueKey('brifing-metin')), findsOneWidget);
    });

    testWidgets('a card opens the reminders tab; there is no separate briefing page', (tester) async {
      ortam.api.brifingYaniti = brifing;
      await uygulamayiAc(tester);

      await tester.tap(find.text('Cuma: diş randevusu'));
      await bekle(tester);
      expect(secili(tester), 3);
    });

    testWidgets('someone without the briefing permission has no strip and Bugün never asks for the briefing', (tester) async {
      ortam.api.brifingYaniti = brifing;
      await uygulamayiAc(tester, rol: 'Asistan');

      expect(find.text('Sabah brifingi'), findsNothing);
      expect(ortam.api.cagrilar, isNot(contains('brifingBugun')));
    });
  });

  testWidgets('Daha fazla: the morning notification can be turned off and its hour is kept', (tester) async {
    await uygulamayiAc(tester);
    tester.view.physicalSize = const Size(400, 1600);
    await sekme(tester, 'Daha fazla');

    expect(find.text('Her gün 06:30'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('brifing-bildirim')));
    await bekle(tester);
    expect(find.text('Kapalı'), findsOneWidget);
    expect(find.byKey(const ValueKey('brifing-saat')), findsNothing);
    expect((await tester.runAsync(ortam.brifing.ayar))!.acik, isFalse);
  });

  testWidgets('Daha fazla has no briefing rows and no Yönetim for a user without the permission', (tester) async {
    await uygulamayiAc(tester, rol: 'Asistan');
    await sekme(tester, 'Daha fazla');

    expect(find.text('Sabah bildirimi'), findsNothing);
    expect(find.text('Yönetim'), findsNothing);
    expect(find.text('Şifremi değiştir'), findsOneWidget);
  });

  testWidgets('a note path with slashes and spaces survives the route', (tester) async {
    ortam.api.notlar = {
      'projects/a b/ç.md': const BeyinNotu(yol: 'projects/a b/ç.md', baslik: 'Boşluklu', govde: 'içerik'),
    };
    await uygulamayiAc(tester);

    router.go(Uri(path: '/not', queryParameters: {'yol': 'projects/a b/ç.md'}).toString());
    await bekle(tester);

    expect(find.text('Boşluklu'), findsOneWidget);
    expect(ortam.api.cagrilar, contains('beyinNot'));
  });
}
