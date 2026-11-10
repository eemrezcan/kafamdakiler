import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/models/asistan.dart';
import 'package:kafamdakiler/data/models/gun_gorunum.dart';
import 'package:kafamdakiler/data/repositories/aliskanlik_repository.dart';
import 'package:kafamdakiler/data/repositories/asistan_repository.dart';
import 'package:kafamdakiler/data/repositories/auth_repository.dart';
import 'package:kafamdakiler/data/repositories/beyin_repository.dart';
import 'package:kafamdakiler/data/repositories/bildirim_izni.dart';
import 'package:kafamdakiler/data/repositories/bildirim_repository.dart';
import 'package:kafamdakiler/data/repositories/brifing_repository.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/gun_plani_repository.dart';
import 'package:kafamdakiler/data/repositories/gun_repository.dart';
import 'package:kafamdakiler/data/repositories/eylem_repository.dart';
import 'package:kafamdakiler/data/repositories/gelen_repository.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_repository.dart';
import 'package:kafamdakiler/data/repositories/is_repository.dart';
import 'package:kafamdakiler/data/models/is_karti.dart';
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

/// The real router and the real shell with in-memory data (K-0024): the five tabs, the bell and the profile sheet in their top
/// bar, the doors of the Asistan and Beyin tabs and the pages above them.
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
          ChangeNotifierProvider<BildirimIzni>.value(value: BildirimIzni(servis: SahteBildirimServisi())),
          ChangeNotifierProvider.value(value: kullanici),
          Provider<ApiService>.value(value: ortam.api),
          ChangeNotifierProvider<Esitleyici>.value(value: ortam.esitleyici),
          ChangeNotifierProvider<AliskanlikRepository>.value(value: ortam.repo),
          ChangeNotifierProvider<YakalamaRepository>.value(value: ortam.yakalamalar),
          ChangeNotifierProvider<HatirlaticiRepository>.value(value: ortam.hatirlaticilar),
          ChangeNotifierProvider<EylemRepository>.value(value: ortam.eylemler),
          ChangeNotifierProvider<GelenRepository>.value(value: ortam.gelen),
          ChangeNotifierProvider<IsRepository>.value(value: ortam.isler),
          Provider<HatirlaticiBildirimYoneticisi>.value(
            value: HatirlaticiBildirimYoneticisi(
              repo: ortam.hatirlaticilar,
              esitleyici: ortam.esitleyici,
              servis: SahteBildirimServisi(),
              yazabilir: () => true,
            ),
          ),
          Provider<BrifingRepository>.value(value: ortam.brifing),
          Provider<BeyinRepository>.value(value: ortam.beyin),
          ChangeNotifierProvider<GunPlaniRepository>.value(value: ortam.gunPlani),
          ChangeNotifierProvider<GunRepository>.value(value: ortam.gun),
          ChangeNotifierProvider<BildirimRepository>.value(value: ortam.bildirimMerkezi),
          ChangeNotifierProvider<AsistanRepository>.value(value: ortam.asistan),
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

  const sekmeAdlari = ['Bugün', 'Takvim', 'Asistan', 'Alışkanlıklar', 'Beyin'];

  testWidgets('five tabs in the agreed order; the Asistan is the round button in the middle', (tester) async {
    await uygulamayiAc(tester);

    final etiketler = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label).toList();
    expect(etiketler, sekmeAdlari);
    final orta = tester.widget<NavigationDestination>(find.byType(NavigationDestination).at(2));
    expect(orta.icon, isNot(isA<Icon>()), reason: 'a round button, not a plain icon');
    expect(tester.getSize(find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(LucideIcons.sparkles)).first).width, lessThan(48));
  });

  testWidgets('at 360 dp the five labels fit and no tab overflows', (tester) async {
    await uygulamayiAc(tester);
    tester.view.physicalSize = const Size(360, 800);
    await bekle(tester);

    for (final ad in sekmeAdlari) {
      await sekme(tester, ad);
      expect(tester.takeException(), isNull, reason: ad);
    }
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
    await sekme(tester, 'Beyin');
    expect(secili(tester), 4);

    await tester.binding.handlePopRoute();
    await bekle(tester);

    expect(secili(tester), 0);
    expect(find.text('BUGÜN'), findsNothing);
    expect(find.byKey(const ValueKey('gun-bos')), findsOneWidget);
  });

  testWidgets('the addresses of the tabs open the tab; the old tabs\' addresses lead to where their content went', (tester) async {
    await uygulamayiAc(tester);

    for (final (yol, sira) in [('/takvim', 1), ('/asistan', 2), ('/beyin', 4), ('/aliskanliklar', 1 + 2), ('/', 0)]) {
      router.go(yol);
      await bekle(tester);
      expect(secili(tester), sira, reason: yol);
    }
    router.go('/hatirlaticilar');
    await bekle(tester);
    expect(router.state.matchedLocation, '/takvim', reason: 'reminders live on the calendar now');
    router.go('/daha-fazla');
    await bekle(tester);
    expect(router.state.matchedLocation, '/', reason: 'the profile is a sheet, so the address leads to Bugün');
  });

  testWidgets('Bugün shows the summary, the load and the rows of the day view', (tester) async {
    ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(
      ozet: 'Bugün 2 iş var; ilki 14:00\'te.',
      ogeler: [
        ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'E-kampüsü kontrol et', saat: '14:00', tahminDk: 15),
        ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Vize slaytlarını oku', tahminDk: 120),
      ],
    );
    await uygulamayiAc(tester);

    expect(find.text('Bugün 2 iş var; ilki 14:00\'te.'), findsOneWidget);
    expect(find.byKey(const ValueKey('gun-yuku')), findsOneWidget);
    expect(find.text('E-kampüsü kontrol et'), findsOneWidget);
    expect(find.text('Vize slaytlarını oku'), findsOneWidget);
    expect(find.text('Su iç'), findsOneWidget, reason: 'today\'s habit on the strip');
  });

  testWidgets('Takvim opens on today and shows its list', (tester) async {
    ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Takvimdeki iş', saat: '10:00')]);
    await uygulamayiAc(tester);

    await sekme(tester, 'Takvim');

    expect(find.text('Takvimdeki iş'), findsOneWidget);
    expect(find.byKey(const ValueKey('takvim-gorunum')), findsOneWidget);
  });

  testWidgets('a bottom sheet covers the bottom bar: the sheets open on the root navigator', (tester) async {
    await uygulamayiAc(tester);
    await sekme(tester, 'Takvim');
    expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('takvim-yeni')));
    await tester.pumpAndSettle();

    expect(find.text('Yeni yapılacak'), findsWidgets);
    expect(find.byType(NavigationBar).hitTestable(), findsNothing, reason: 'the sheet and its barrier are over the bar');
  });

  group('a day\'s address (E8)', () {
    testWidgets('/gun/{tarih} opens Takvim on that day and shows that day\'s list', (tester) async {
      ortam.api.gunGorunumleri['2026-11-11'] = ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Yarının işi', saat: '09:00')]);
      await uygulamayiAc(tester);

      router.go('/gun/2026-11-11');
      await bekle(tester);

      expect(secili(tester), 1);
      expect(router.state.uri.path, '/takvim');
      expect(find.text('Yarının işi'), findsOneWidget);
    });

    testWidgets('from the Asistan tab: a tap on a result lands on that day, and a second day moves it again', (tester) async {
      ortam.api.gunGorunumleri['2026-11-11'] = ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Yarının işi')]);
      ortam.api.gunGorunumleri['2026-11-12'] = ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Öbür günün işi')]);
      await uygulamayiAc(tester);
      await sekme(tester, 'Asistan');

      router.go('/gun/2026-11-11');
      await bekle(tester);
      expect(find.text('Yarının işi'), findsOneWidget);

      await sekme(tester, 'Asistan');
      router.go('/gun/2026-11-12');
      await bekle(tester);
      expect(secili(tester), 1);
      expect(find.text('Öbür günün işi'), findsOneWidget);
      expect(find.text('Yarının işi'), findsNothing);
    });

    testWidgets('a date that is not a day opens Takvim on today', (tester) async {
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: [ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'Bugünün işi')]);
      await uygulamayiAc(tester);

      router.go('/gun/2026-02-30');
      await bekle(tester);

      expect(secili(tester), 1);
      expect(router.state.uri.path, '/takvim');
      expect(find.text('Bugünün işi'), findsOneWidget);
    });
  });

  group('the top bar', () {
    testWidgets('every tab has the bell and the profile button; search is in the top bar of none (it is on the Beyin tab itself)', (tester) async {
      await uygulamayiAc(tester);

      for (final ad in sekmeAdlari) {
        await sekme(tester, ad);
        expect(find.byTooltip('Bildirimler'), findsOneWidget, reason: ad);
        expect(find.byTooltip('Profil'), findsOneWidget, reason: ad);
        expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Ara')), findsNothing, reason: ad);
      }
    });

    testWidgets('the bell shows how many notifications are unread and opens the notification page', (tester) async {
      ortam.api.okunmamisBildirim = 3;
      await uygulamayiAc(tester);

      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('Bildirimler, 3 okunmamış'), findsOneWidget);

      await tester.tap(find.byTooltip('Bildirimler, 3 okunmamış'));
      await bekle(tester);
      expect(router.state.matchedLocation, '/bildirimler');
      expect(find.byType(NavigationBar), findsNothing, reason: 'a page above the tabs');
    });

    testWidgets('no unread: no badge', (tester) async {
      await uygulamayiAc(tester);
      expect(find.byTooltip('Bildirimler'), findsOneWidget);
      final zil = find.descendant(of: find.byTooltip('Bildirimler'), matching: find.byType(Badge));
      expect(zil, findsOneWidget);
      expect(tester.widget<Badge>(zil).isLabelVisible, isFalse);
    });

    testWidgets('a big number is shown as 99+', (tester) async {
      ortam.api.okunmamisBildirim = 120;
      await uygulamayiAc(tester);

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('the profile sheet', () {
    /// Real time for drift, a frame, and the sheet's slide-in.
    Future<void> yerles(WidgetTester tester, [int ms = 150]) async {
      await bekle(tester, ms);
      await tester.pumpAndSettle();
    }

    Future<void> profilAc(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Profil'));
      await yerles(tester);
    }

    testWidgets('the account and the rows, in the order of the mock-up', (tester) async {
      await uygulamayiAc(tester);
      await profilAc(tester);

      expect(find.text('x@y.z'), findsOneWidget);
      final siralar = [for (final k in ['profil-yonetim', 'profil-kapasite', 'profil-bildirim', 'profil-sifre', 'profil-kuyruk', 'profil-cikis']) tester.getTopLeft(find.byKey(ValueKey(k))).dy];
      expect(siralar, orderedEquals([...siralar]..sort()));
      expect(find.text('0 bekleyen'), findsOneWidget);
    });

    testWidgets('the Asistan account has no management and no capacity row, but the password, the queue and sign-out', (tester) async {
      await uygulamayiAc(tester, rol: 'Asistan');
      await profilAc(tester);

      expect(find.byKey(const ValueKey('profil-yonetim')), findsNothing);
      expect(find.byKey(const ValueKey('profil-kapasite')), findsNothing);
      expect(find.byKey(const ValueKey('profil-sifre')), findsOneWidget);
      expect(find.byKey(const ValueKey('profil-kuyruk')), findsOneWidget);
      expect(find.byKey(const ValueKey('profil-cikis')), findsOneWidget);
      expect(find.text('Asistan hesabı'), findsOneWidget);
    });

    testWidgets('"Asistan izinleri ve yönetim" closes the sheet and opens the management page; back returns to the tab', (tester) async {
      await uygulamayiAc(tester);
      await sekme(tester, 'Takvim');
      await profilAc(tester);

      await tester.tap(find.byKey(const ValueKey('profil-yonetim')));
      await yerles(tester);

      expect(router.state.matchedLocation, '/yonetim');
      router.pop();
      await yerles(tester);
      expect(secili(tester), 1);
      expect(find.byKey(const ValueKey('profil-yonetim')), findsNothing, reason: 'the sheet closed');
    });

    testWidgets('the password row opens the password page', (tester) async {
      await uygulamayiAc(tester, rol: 'Asistan');
      await profilAc(tester);

      await tester.tap(find.byKey(const ValueKey('profil-sifre')));
      await yerles(tester);

      expect(router.state.matchedLocation, '/sifre');
    });

    testWidgets('the capacity row sets the weekday and weekend hours; the change is queued and sent', (tester) async {
      ortam.api.gunAyariYaniti = const GunAyari(haftaIciDk: 360, haftaSonuDk: 180);
      await uygulamayiAc(tester);
      await profilAc(tester);

      await tester.tap(find.byKey(const ValueKey('profil-kapasite')));
      await yerles(tester);
      expect(find.text('6 sa'), findsOneWidget);
      expect(find.text('3 sa'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('hafta-ici-arttir')));
      await tester.tap(find.byKey(const ValueKey('hafta-sonu-azalt')));
      await tester.pump();
      expect(find.text('6 sa 30 dk'), findsOneWidget);
      expect(find.text('2 sa 30 dk'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kapasite-kaydet')));
      await yerles(tester, 300);

      expect(ortam.api.gunAyariYaniti.haftaIciDk, 390);
      expect(ortam.api.gunAyariYaniti.haftaSonuDk, 150);
    });

    testWidgets('the notification settings: the permission, and the morning notification can be turned off with its hour kept', (tester) async {
      await uygulamayiAc(tester);
      await profilAc(tester);

      await tester.tap(find.byKey(const ValueKey('profil-bildirim')));
      await yerles(tester);

      expect(find.byKey(const ValueKey('bildirim-izni-acik')), findsOneWidget);
      expect(find.text('Brifing hazır olunca haber verir'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('brifing-saat')), matching: find.text('06:30')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('brifing-bildirim')));
      await yerles(tester);
      expect(find.text('Kapalı'), findsOneWidget);
      expect(find.byKey(const ValueKey('brifing-saat')), findsNothing);
      expect((await tester.runAsync(ortam.brifing.ayar))!.acik, isFalse);
    });

    testWidgets('the sending queue lists what waits and what the server refused', (tester) async {
      ortam.api.cevrimdisi = true;
      await uygulamayiAc(tester);
      await tester.runAsync(() => ortam.esitleyici.gunYaptimKuyrugaAl(DateTime.utc(2026, 10, 31), 'm:aa11bb'));
      await tester.runAsync(() => ortam.esitleyici.dundenBirakKuyrugaAl(DateTime.utc(2026, 10, 31), 'ab12cd'));
      await profilAc(tester);

      expect(find.text('2 bekleyen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profil-kuyruk')));
      await yerles(tester);
      expect(find.text('2 kayıt gönderilmeyi bekliyor'), findsOneWidget);
    });

    testWidgets('a write the server took without a clear answer (202) waits in the queue as "Dikkat" until it is read and dismissed', (tester) async {
      await tester.runAsync(() async {
        await ortam.gunPlani.gorevEkle(baslik: 'Belirsiz görev', proje: 'kitap-kulubu');
        ortam.api.beyinYazmaKodlari = [202];
        ortam.api.beyinYazmaGovdesi = {'belirsiz': true, 'ayrinti': 'Beyin zamanında cevap vermedi; yazılmış olabilir.'};
        await ortam.esitleyici.gonder();
      });
      await uygulamayiAc(tester);
      await profilAc(tester);

      expect(find.text('0 bekleyen, 1 uyarı'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profil-kuyruk')));
      await yerles(tester);
      expect(find.text('Dikkat: 1 kayıt'), findsOneWidget);
      expect(find.textContaining('yazılmış olabilir'), findsOneWidget);

      await tester.tap(find.textContaining('Tamam'));
      await yerles(tester);
      expect(find.text('Dikkat: 1 kayıt'), findsNothing);
      expect(await tester.runAsync(ortam.esitleyici.uyarilar), isEmpty);
    });

    testWidgets('sign-out asks first and says how many unsent entries would be lost', (tester) async {
      ortam.api.cevrimdisi = true;
      await uygulamayiAc(tester);
      await tester.runAsync(() => ortam.esitleyici.gunYaptimKuyrugaAl(DateTime.utc(2026, 10, 31), 'm:aa11bb'));
      await profilAc(tester);

      await tester.tap(find.byKey(const ValueKey('profil-cikis')));
      await yerles(tester);

      expect(find.text('Çıkış yapılsın mı?'), findsOneWidget);
      expect(find.textContaining('1 kayıt henüz gönderilmedi'), findsOneWidget);
      expect(auth.girisYapildi, isTrue, reason: 'nothing happens until the person confirms');
    });
  });

  group('the Asistan tab', () {
    IsKarti kart(String kimlik, {String asama = 'karar', String sahip = 'kullanici'}) => IsKarti(
          kimlik: kimlik,
          baslik: 'Kart $kimlik',
          tip: 'kod',
          asama: asama,
          sahip: sahip,
          proje: 'kitap-kulubu',
          gecisler: const ['plan', 'iptal'],
        );

    Future<void> menuAc(WidgetTester tester, String ad) async {
      await tester.tap(find.byKey(const ValueKey('asistan-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ad));
      await bekle(tester);
    }

    testWidgets('the tab is the feed with its input; the Sahip has the menu with the inbox, the queue, the cards and "Projeye yakala"', (tester) async {
      ortam.api.akisOgeleri = [
        AkisOgesi(id: 'k1', zaman: DateTime.utc(2026, 10, 31, 8), tur: AkisTuru.kullanici, metin: 'yarın e-kampüse bak'),
      ];
      await uygulamayiAc(tester);
      await sekme(tester, 'Asistan');

      expect(find.text('yarın e-kampüse bak'), findsOneWidget);
      expect(find.byKey(const ValueKey('asistan-metin')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('asistan-menu')));
      await tester.pumpAndSettle();
      for (final ad in ['Gelen kutusu', 'Onay kuyruğu', 'İş kartları', 'Projeye yakala']) {
        expect(find.text(ad), findsOneWidget, reason: ad);
      }
    });

    testWidgets('the badge on the tab is the number that waits on the person', (tester) async {
      ortam.api.asistanBekleyenSayisi = 2;
      await uygulamayiAc(tester);

      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('2')), findsOneWidget);
    });

    testWidgets('"Projeye yakala" opens the capture screen with its project picker above the tabs', (tester) async {
      await uygulamayiAc(tester);
      await sekme(tester, 'Asistan');

      await menuAc(tester, 'Projeye yakala');

      expect(find.text('Aklında ne var?'), findsOneWidget);
      expect(find.text('Proje (isteğe bağlı)'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the Asistan account (no assistant permission): the feed to read, no input, no capture entry', (tester) async {
      await uygulamayiAc(tester, rol: 'Asistan');
      await sekme(tester, 'Asistan');

      expect(find.byKey(const ValueKey('asistan-metin')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('asistan-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Projeye yakala'), findsNothing);
      expect(find.text('Gelen kutusu'), findsOneWidget);
    });

    testWidgets('the inbox entry shows the waiting captures and has a back button', (tester) async {
      // Offline, so the capture stays on the phone instead of being sent at once.
      ortam.api.cevrimdisi = true;
      await tester.runAsync(() => ortam.yakalamalar.yakala(metin: 'yoldaki yakalama'));
      await uygulamayiAc(tester);
      await sekme(tester, 'Asistan');

      await menuAc(tester, 'Gelen kutusu');

      expect(router.state.matchedLocation, '/gelen');
      expect(find.text('GÖNDERİLİYOR  1'), findsOneWidget);
      expect(find.text('yoldaki yakalama'), findsOneWidget);
      router.pop();
      await bekle(tester);
      expect(secili(tester), 2);
    });

    testWidgets('the approval queue opens, and a tap on an action opens its detail', (tester) async {
      ortam.api.eylemler = [ornekEylem(id: 'e1', ozet: 'Ali\'yi ara'), ornekEylem(id: 'e2', ozet: 'Faturayı öde')];
      await uygulamayiAc(tester);
      await sekme(tester, 'Asistan');

      await menuAc(tester, 'Onay kuyruğu');
      expect(router.state.matchedLocation, '/eylemler');

      await tester.tap(find.text('Faturayı öde'));
      await bekle(tester);
      expect(router.state.matchedLocation, '/eylem/e2');
      expect(find.text('Yük'), findsOneWidget);
    });

    testWidgets('the work cards entry opens the board, and a card opens its detail at the address notifications carry', (tester) async {
      ortam.api.isKartlari = [kart('takvim'), kart('liste', asama: 'plan', sahip: 'vps')];
      ortam.api.isAyrintilari = {
        'takvim': IsAyrinti(kart: kart('takvim'), talep: 'Buluşma takvimi', plan: '## Adımlar\n- Ay görünümü'),
      };
      await uygulamayiAc(tester);
      await sekme(tester, 'Asistan');

      await menuAc(tester, 'İş kartları');
      expect(router.state.matchedLocation, '/isler');
      expect(find.text('Sende bekleyen · 1'), findsOneWidget);

      await tester.tap(find.text('Kart takvim'));
      await bekle(tester);
      expect(router.state.matchedLocation, '/asistan/takvim');
      expect(find.text('Buluşma takvimi'), findsOneWidget);
    });

    testWidgets('a deep link to a work card still opens the card (the tab is /asistan, the card /asistan/:kimlik)', (tester) async {
      ortam.api.isAyrintilari = {
        'takvim': IsAyrinti(kart: kart('takvim'), talep: 'Buluşma takvimi', plan: '## Adımlar'),
      };
      await uygulamayiAc(tester);

      router.push('/asistan/takvim');
      await bekle(tester);

      expect(find.text('Buluşma takvimi'), findsOneWidget);
    });

    testWidgets('the card is also at the board\'s address, /isler/:kimlik', (tester) async {
      ortam.api.isAyrintilari = {
        'takvim': IsAyrinti(kart: kart('takvim'), talep: 'Buluşma takvimi', plan: '## Adımlar'),
      };
      await uygulamayiAc(tester);

      router.push('/isler/takvim');
      await bekle(tester);

      expect(find.text('Buluşma takvimi'), findsOneWidget);
    });

    testWidgets('someone without the cards permission has no "İş kartları" in the menu', (tester) async {
      ortam.api.isKartlari = [kart('takvim')];
      await uygulamayiAc(tester, rol: 'Asistan');
      await sekme(tester, 'Asistan');

      await tester.tap(find.byKey(const ValueKey('asistan-menu')));
      await tester.pumpAndSettle();
      expect(find.text('İş kartları'), findsNothing);
    });

    testWidgets('the Sahip can open the new card form from its address', (tester) async {
      await uygulamayiAc(tester);

      router.go('/asistan/yeni');
      await bekle(tester);

      expect(router.state.matchedLocation, '/asistan/yeni');
      expect(find.text('Kartı aç'), findsOneWidget);
    });

    testWidgets('the Asistan account is sent away from the form\'s address', (tester) async {
      await uygulamayiAc(tester, rol: 'Asistan');

      router.go('/asistan/yeni');
      await bekle(tester);

      expect(router.state.matchedLocation, '/aliskanliklar');
    });
  });

  group('the Beyin tab', () {
    testWidgets('the projects are listed on the tab itself: a row opens the project, back returns to the tab', (tester) async {
      await uygulamayiAc(tester);
      await sekme(tester, 'Beyin');
      expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);
      expect(find.text('Balkon Bahçesi Sulama'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('beyin-proje-kitap-kulubu')));
      await bekle(tester);
      expect(router.state.matchedLocation, '/projeler/kitap-kulubu');
      expect(find.text('Okuma listesi bitti.'), findsOneWidget);
      expect(find.text('Takvim sayfası.'), findsOneWidget);

      router.pop();
      await bekle(tester);
      expect(secili(tester), 4);
      expect(find.text('Balkon Bahçesi Sulama'), findsOneWidget);
    });

    testWidgets('search is here only: words typed -> the results page already searched -> a hit opens the note -> back keeps the results', (tester) async {
      await uygulamayiAc(tester);
      await sekme(tester, 'Beyin');

      await tester.enterText(find.byKey(const ValueKey('beyin-ara')), 'takvim');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await bekle(tester);
      expect(router.state.uri.toString(), '/ara?q=takvim');
      expect(find.byType(NavigationBar), findsNothing, reason: 'search is a page above the tabs, not a tab');
      expect(find.text('Takvim için kütüphane'), findsOneWidget, reason: 'the words typed on the tab are searched at once');

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
      expect(secili(tester), 4, reason: 'Beyin');
    });

    testWidgets('an empty box opens the results page empty, ready to type', (tester) async {
      await uygulamayiAc(tester);
      await sekme(tester, 'Beyin');

      await tester.tap(find.byKey(const ValueKey('beyin-ara-git')));
      await bekle(tester);

      expect(router.state.matchedLocation, '/ara');
    });

    testWidgets('offline with no kept list: the tab says so instead of an empty list', (tester) async {
      ortam.api.beyinCevrimdisi = true;
      await uygulamayiAc(tester);
      await sekme(tester, 'Beyin');

      expect(find.byKey(const ValueKey('beyin-proje-kitap-kulubu')), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });
  });

  testWidgets('the Yakalamalar page is gone: its address matches no route; the edit route of a waiting capture stays', (tester) async {
    await uygulamayiAc(tester);

    final yollar = router.configuration.routes.whereType<GoRoute>().map((r) => r.path);
    expect(yollar, isNot(contains('/yakalamalar')));
    expect(yollar, contains('/yakalama/:id/duzenle'));
  });

  testWidgets('Alışkanlıklar is a tab of its own: the list shows there with the top bar', (tester) async {
    await uygulamayiAc(tester);

    await sekme(tester, 'Alışkanlıklar');

    expect(find.text('Su iç'), findsOneWidget);
    expect(find.byTooltip('Profil'), findsOneWidget);
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
