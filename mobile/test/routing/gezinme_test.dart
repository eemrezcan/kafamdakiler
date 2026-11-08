import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/repositories/aliskanlik_repository.dart';
import 'package:kafamdakiler/data/repositories/auth_repository.dart';
import 'package:kafamdakiler/data/repositories/beyin_repository.dart';
import 'package:kafamdakiler/data/repositories/brifing_repository.dart';
import 'package:kafamdakiler/data/repositories/zaman_cizelgesi_repository.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/gun_plani_repository.dart';
import 'package:kafamdakiler/data/repositories/eylem_repository.dart';
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

/// The real router and the real shell with in-memory data: the tabs, the Yakala button and the pages above them.
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
    router = routerOlustur(auth, kullanici);
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

  testWidgets('five tabs in the agreed order; the habit list is not one of them', (tester) async {
    await uygulamayiAc(tester);

    final etiketler = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label).toList();
    expect(etiketler, ['Bugün', 'Projeler', 'Yakalamalar', 'Ara', 'Profil']);
  });

  testWidgets('the label "Yakalamalar" fits on one line', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await uygulamayiAc(tester);

    final yakalamalar = tester.getSize(find.descendant(of: find.byType(NavigationBar), matching: find.text('Yakalamalar')));
    final projeler = tester.getSize(find.descendant(of: find.byType(NavigationBar), matching: find.text('Projeler')));
    expect(yakalamalar.height, projeler.height, reason: 'a wrapped label would be two lines high');
  });

  testWidgets('back on another tab goes to Bugün first', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Ara');
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);

    await tester.binding.handlePopRoute();
    await bekle(tester);

    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(find.text('Gün planı'), findsOneWidget);
  });

  testWidgets('Bugün shows the brain plan and today\'s habit cards together', (tester) async {
    await uygulamayiAc(tester);

    expect(find.text('Gün planı'), findsOneWidget);
    expect(find.text('Su iç'), findsOneWidget);
  });

  testWidgets('the Yakala button stays on every tab and opens the capture screen', (tester) async {
    await uygulamayiAc(tester);

    for (final ad in ['Bugün', 'Projeler', 'Yakalamalar', 'Ara', 'Profil']) {
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

    for (final ad in ['Bugün', 'Projeler', 'Ara']) {
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

  testWidgets('Ara: query -> hit -> the note rendered -> back keeps the results', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Ara');

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
  });

  testWidgets('Profil opens the habit list, and the old habit routes still work', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Profil');

    await tester.tap(find.text('Alışkanlıklar'));
    await bekle(tester);
    expect(find.text('Su iç'), findsOneWidget, reason: 'the habit list page');

    // The address works on its own too (an old link, a redirect), not only through Profil.
    router.go('/');
    await bekle(tester);
    router.go('/aliskanliklar');
    await bekle(tester);
    expect(router.state.matchedLocation, '/aliskanliklar');
    expect(find.text('Su iç'), findsOneWidget);
  });

  testWidgets('the Yaklaşanlar card on Bugün and the row on Profil both open the reminders list', (tester) async {
    ortam.api.hatirlaticilar = [
      ornekHatirlatici(id: 'h', baslik: 'Yaklaşan iş', sonrakiAn: DateTime.now().toUtc().add(const Duration(days: 2))),
    ];
    await uygulamayiAc(tester);

    expect(find.text('Yaklaşanlar'), findsOneWidget);
    await tester.tap(find.text('Yaklaşanlar'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/hatirlaticilar');
    expect(find.text('Yaklaşan iş'), findsOneWidget);

    router.go('/');
    await bekle(tester);
    await sekme(tester, 'Profil');
    await tester.tap(find.text('Hatırlatıcılar'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/hatirlaticilar');
  });

  testWidgets('the "Onay bekleyen" card on Bugün and the row on Profil both open the approval queue; a tap on a card opens its detail', (tester) async {
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
    await sekme(tester, 'Profil');
    await tester.tap(find.text('Onay kuyruğu'));
    await bekle(tester);
    expect(router.state.matchedLocation, '/eylemler');
  });

  testWidgets('Profil has the briefing rows for the Sahip: the notification can be turned off and its hour is kept', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Profil');

    expect(find.text('Sabah brifingi'), findsOneWidget);
    expect(find.text('Her gün 06:30'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('brifing-bildirim')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('brifing-bildirim')));
    await bekle(tester);
    expect(find.text('Kapalı'), findsOneWidget);
    expect(find.byKey(const ValueKey('brifing-saat')), findsNothing);
    expect((await tester.runAsync(ortam.brifing.ayar))!.acik, isFalse);
  });

  testWidgets('Profil has no briefing rows for a user without the permission', (tester) async {
    await uygulamayiAc(tester, rol: 'Asistan');
    await sekme(tester, 'Profil');

    expect(find.text('Sabah brifingi'), findsNothing);
  });

  testWidgets('with nothing waiting the Today tab has no "Onay bekleyen" card', (tester) async {
    await uygulamayiAc(tester);

    expect(find.textContaining('Onay bekleyen'), findsNothing);
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
