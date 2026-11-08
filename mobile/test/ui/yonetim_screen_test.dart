import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/eylem.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/models/yonetim.dart';
import 'package:kafamdakiler/data/models/zaman_cizelgesi.dart';
import 'package:kafamdakiler/data/repositories/brifing_repository.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/repositories/kullanici_repository.dart';
import 'package:kafamdakiler/ui/profil/profil_screen.dart';
import 'package:kafamdakiler/ui/profil/profil_view_model.dart';
import 'package:kafamdakiler/ui/yonetim/izin_gruplari.dart';
import 'package:kafamdakiler/ui/yonetim/yonetim_screen.dart';
import 'package:kafamdakiler/ui/yonetim/yonetim_view_model.dart';
import 'package:provider/provider.dart';

import '../test_destek.dart';

/// Every permission the server lists (the groups' ones and the Claude switch); only [acik] are open.
List<Izin> tumIzinler({Set<String> acik = const {}}) => [
      for (final k in [...izinGruplari.expand((g) => g.tumu), asistanKullanIzni]) Izin(izin: k, aciklama: '$k açıklaması', acik: acik.contains(k)),
    ];

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));

  setUp(() {
    ortam = TestOrtami();
    // The Asistan holds only "yakalama.oku": the "Gelen ve yakalamalar" group is half open ("Özel").
    ortam.api.izinler = tumIzinler(acik: {'yakalama.oku'});
    ortam.api.eylemKipleri = const [
      EylemKipDurumu(tur: 'hatirlatici-kur', turAdi: 'Hatırlatıcı kur', kip: EylemKipi.sor),
      EylemKipDurumu(tur: 'plan-ekle', turAdi: 'Plana ekle', kip: EylemKipi.sor),
      EylemKipDurumu(tur: 'takvim-ekle', turAdi: 'Takvime ekle', kip: EylemKipi.yasak),
    ];
    ortam.api.gonderimler = [
      ornekGonderim(id: 'hatali', metin: 'hatalı olan', sonHata: 'beyin.py zaman aşımı'),
      ornekGonderim(id: 'takili', metin: 'takılı olan', gonderim: GonderimDurumu.takili, sonHata: null),
      ornekGonderim(id: 'tamam', metin: 'giden', gonderim: GonderimDurumu.tamam, durum: YakalamaDurumu.beyneGitti, deneme: 0, sonHata: null),
    ];
  });
  tearDown(() async => ortam.kapat());

  Future<void> gelismisAc(WidgetTester tester) async {
    await tester.tap(find.text('Gelişmiş'));
    await tester.pumpAndSettle();
  }

  Set<String> acikOlanlar() => {for (final i in ortam.api.izinler) if (i.acik) i.izin};

  Future<YonetimViewModel> goster(WidgetTester tester) async {
    // Tall enough that the list builds every row: a ListView only builds what is on screen.
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = YonetimViewModel(api: ortam.api);
    await tester.runAsync(vm.yukle);
    await tester.pumpWidget(MaterialApp(home: YonetimScreen(viewModel: vm)));
    await tester.pump();
    return vm;
  }

  testWidgets('shows six cards, the Claude switch and a one-line summary; the raw keys wait in "Gelişmiş"', (tester) async {
    await goster(tester);

    for (final grup in izinGruplari) {
      expect(find.byKey(ValueKey('grup-${grup.id}')), findsOneWidget);
    }
    expect(find.text('Asistan Claude\'u çağırabilsin'), findsOneWidget);
    expect(find.text('3 eylem türü: 2 Sor, 1 Yasak'), findsOneWidget);
    // Collapsed: neither the keys nor the per-kind modes are built.
    expect(find.text('beyin.oku'), findsNothing);
    expect(find.byKey(const ValueKey('kip-plan-ekle')), findsNothing);
    // Words an ordinary person does not need.
    expect(find.textContaining('403'), findsNothing);
    expect(find.textContaining('refresh token'), findsNothing);

    await gelismisAc(tester);

    expect(find.text('beyin.oku'), findsOneWidget);
    expect(find.text('yakalama.oku'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('izin-beyin.oku'))).value, isFalse);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('izin-yakalama.oku'))).value, isTrue);
    expect(find.byKey(const ValueKey('kip-plan-ekle')), findsOneWidget);
  });

  testWidgets('shows the brain and the queue', (tester) async {
    await goster(tester);

    expect(find.text('Beyin bağlı'), findsOneWidget);
    expect(find.text('hatalı olan'), findsOneWidget);
    expect(find.text('takılı olan'), findsOneWidget);
    expect(find.text('beyin.py zaman aşımı'), findsOneWidget);
    // Only the failed and stuck ones can be sent again.
    expect(find.text('Yeniden gönder'), findsNWidgets(2));
  });

  testWidgets('flipping a switch asks the server and keeps the new state', (tester) async {
    await goster(tester);
    await gelismisAc(tester);

    await tester.tap(find.byKey(const ValueKey('izin-beyin.oku')));
    await tester.pump();
    await tester.pump();

    expect(ortam.api.cagrilar, contains('izinAyarla:beyin.oku:true'));
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('izin-beyin.oku'))).value, isTrue);
  });

  testWidgets('a permission that could not be changed says so and stays as it was', (tester) async {
    await goster(tester);
    await gelismisAc(tester);
    ortam.api.sunucuHatasi = 500;

    await tester.tap(find.byKey(const ValueKey('izin-beyin.oku')));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Sunucu hata verdi'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('izin-beyin.oku'))).value, isFalse);
  });

  testWidgets('"Yeniden gönder" on a failed capture asks the server and the capture leaves the problem list', (tester) async {
    await goster(tester);

    await tester.tap(find.text('Yeniden gönder').first);
    await tester.pump();
    await tester.pump();

    expect(ortam.api.cagrilar, contains('gonderimiYenidenDene:hatali'));
    expect(find.text('Yeniden gönderilecek.'), findsOneWidget);
    expect(find.text('Yeniden gönder'), findsOneWidget, reason: 'only the stuck one is left');
  });

  testWidgets('a stuck capture asks first: the card may already be in the brain', (tester) async {
    await goster(tester);

    // The stuck one is the second button.
    await tester.tap(find.text('Yeniden gönder').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('kart beyinde olabilir'), findsOneWidget);
    expect(ortam.api.cagrilar, isNot(contains('gonderimiYenidenDene:takili')));

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(ortam.api.cagrilar, isNot(contains('gonderimiYenidenDene:takili')));

    await tester.tap(find.text('Yeniden gönder').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yine de gönder'));
    await tester.pump();
    await tester.pump();
    expect(ortam.api.cagrilar, contains('gonderimiYenidenDene:takili'));
  });

  testWidgets('409 (being sent right now) is not shown as a failure: it says to look again soon', (tester) async {
    await goster(tester);
    ortam.api.yenidenDeneHatasi = 409;

    await tester.tap(find.text('Yeniden gönder').first);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('şu an gönderiliyor'), findsOneWidget);
    expect(find.textContaining('Sunucu hata verdi'), findsNothing);
  });

  testWidgets('403 shows the reason and a retry button instead of the lists', (tester) async {
    ortam.api.sunucuHatasi = 403;
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = YonetimViewModel(api: ortam.api);
    await tester.runAsync(vm.yukle);
    await tester.pumpWidget(MaterialApp(home: YonetimScreen(viewModel: vm)));
    await tester.pump();

    expect(find.text('Bu işlem için yetkin yok.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  group('permission cards', () {
    Finder dugme(String grup, String ad) =>
        find.descendant(of: find.byKey(ValueKey('grup-$grup')), matching: find.text(ad));

    Set<IzinSeviyesi> secili(WidgetTester tester, String grup) => tester
        .widget<SegmentedButton<IzinSeviyesi>>(find.descendant(of: find.byKey(ValueKey('grup-$grup')), matching: find.byType(SegmentedButton<IzinSeviyesi>)))
        .selected;

    List<String> izinCagrilari() => ortam.api.cagrilar.where((c) => c.startsWith('izinAyarla:')).toList();

    testWidgets('each card shows the level its permissions amount to', (tester) async {
      ortam.api.izinler = tumIzinler(acik: {'aliskanlik.oku', 'hatirlatici.oku', 'hatirlatici.yaz', 'yakalama.oku'});
      await goster(tester);

      expect(secili(tester, 'aliskanlik'), {IzinSeviyesi.okur});
      expect(secili(tester, 'hatirlatici'), {IzinSeviyesi.okurYazar});
      expect(secili(tester, 'beyin'), {IzinSeviyesi.kapali});
      // Only one of the two reading permissions of the group is open: set by hand.
      expect(secili(tester, 'gelen'), isEmpty);
      expect(find.descendant(of: find.byKey(const ValueKey('grup-gelen')), matching: find.text('Özel')), findsOneWidget);
      expect(find.text('Özel'), findsOneWidget);
    });

    testWidgets('"Okur ve yazar" opens every permission of the card, one call each', (tester) async {
      await goster(tester);

      await tester.tap(dugme('gelen', 'Okur ve yazar'));
      await tester.pump();
      await tester.pump();

      // yakalama.oku was open already: only the other three are sent.
      expect(izinCagrilari(), unorderedEquals(['izinAyarla:gelen.oku:true', 'izinAyarla:yakalama.yaz:true', 'izinAyarla:gelen.yaz:true']));
      expect(secili(tester, 'gelen'), {IzinSeviyesi.okurYazar});
      expect(acikOlanlar(), {'yakalama.oku', 'gelen.oku', 'yakalama.yaz', 'gelen.yaz'});
    });

    testWidgets('"Okur" closes only the writing permissions', (tester) async {
      ortam.api.izinler = tumIzinler(acik: {'beyin.oku', 'plan.yaz', 'gorev.yaz'});
      await goster(tester);

      await tester.tap(dugme('beyin', 'Okur'));
      await tester.pump();
      await tester.pump();

      expect(izinCagrilari(), ['izinAyarla:gorev.yaz:false', 'izinAyarla:plan.yaz:false']);
      expect(secili(tester, 'beyin'), {IzinSeviyesi.okur});
    });

    testWidgets('"Kapalı" closes the writing permissions first, then the reading ones', (tester) async {
      ortam.api.izinler = tumIzinler(acik: {'takvim.oku', 'brifing.oku', 'takvim.yaz', 'beyin.oku'});
      await goster(tester);

      await tester.tap(dugme('takvim', 'Kapalı'));
      await tester.pump();
      await tester.pump();

      expect(izinCagrilari(), ['izinAyarla:takvim.yaz:false', 'izinAyarla:brifing.oku:false', 'izinAyarla:takvim.oku:false']);
      expect(acikOlanlar(), {'beyin.oku'}, reason: 'other cards are not touched');
    });

    testWidgets('a level the card already has sends nothing', (tester) async {
      await goster(tester);

      await tester.tap(dugme('beyin', 'Kapalı'));
      await tester.pump();

      expect(izinCagrilari(), isEmpty);
    });

    testWidgets('a failure says so and the card shows what the server really holds', (tester) async {
      await goster(tester);
      ortam.api.sunucuHatasi = 500;

      await tester.tap(dugme('beyin', 'Okur ve yazar'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Sunucu hata verdi'), findsOneWidget);
      expect(izinCagrilari(), hasLength(1), reason: 'the rest are not sent after the first failure');
      expect(secili(tester, 'beyin'), {IzinSeviyesi.kapali});
    });

    testWidgets('the Claude switch is its own permission', (tester) async {
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('anahtar-asistan.kullan')));
      await tester.pump();
      await tester.pump();

      expect(ortam.api.cagrilar, contains('izinAyarla:asistan.kullan:true'));
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('anahtar-asistan.kullan'))).value, isTrue);
    });
  });

  group('Google Takvim', () {
    testWidgets('not connected: one line that points to the web', (tester) async {
      await goster(tester);

      expect(find.text('Google Takvim bağlı değil'), findsOneWidget);
      expect(find.textContaining('web\'deki Yönetim sayfasını aç'), findsOneWidget);
      expect(find.text('Şimdi eşitle'), findsNothing);
    });

    testWidgets('not set up on the server: says so, no button', (tester) async {
      ortam.api.googleDurum = const GoogleDurum(durum: GoogleDurumu.kapali);
      await goster(tester);

      expect(find.text('Google Takvim ayarlanmamış'), findsOneWidget);
      expect(find.text('Şimdi eşitle'), findsNothing);
    });

    testWidgets('a link that must be made again points to the web too', (tester) async {
      ortam.api.googleDurum = const GoogleDurum(durum: GoogleDurumu.yenidenBaglan);
      await goster(tester);

      expect(find.text('Google Takvim yeniden bağlanmalı'), findsOneWidget);
      expect(find.textContaining('web\'deki Yönetim sayfasını aç'), findsOneWidget);
    });

    testWidgets('connected: shows the last sync and "Şimdi eşitle" syncs and refreshes the time', (tester) async {
      ortam.api.googleDurum = const GoogleDurum(durum: GoogleDurumu.bagli);
      await goster(tester);
      expect(find.text('Henüz eşitlenmedi'), findsOneWidget);

      await tester.tap(find.text('Şimdi eşitle'));
      await tester.pump();
      await tester.pump();

      expect(ortam.api.cagrilar, contains('googleEsitle'));
      expect(find.text('Takvim eşitlendi: 2 yeni, 1 silinen.'), findsOneWidget);
      expect(find.textContaining('Son eşitleme: 8 Kasım'), findsOneWidget);
    });

    testWidgets('a sync Google refuses says to connect again on the web', (tester) async {
      ortam.api.googleDurum = const GoogleDurum(durum: GoogleDurumu.bagli);
      await goster(tester);
      ortam.api.esitleHatasi = 409;

      await tester.tap(find.text('Şimdi eşitle'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('yeniden bağlamayı dene'), findsOneWidget);
    });

    testWidgets('if the status cannot be read the rest of the screen still shows', (tester) async {
      ortam.api.googleDurumuHatali = true;
      await goster(tester);

      expect(find.text('Google Takvim durumu okunamadı'), findsOneWidget);
      expect(find.byKey(const ValueKey('grup-beyin')), findsOneWidget);
      expect(find.text('Beyin bağlı'), findsOneWidget);
    });
  });

  group('the Asistan\'s password', () {
    Future<void> diyalogAc(WidgetTester tester) async {
      await goster(tester);
      await tester.tap(find.text('Asistan\'ın şifresini yenile'));
      await tester.pumpAndSettle();
    }

    Future<void> doldur(WidgetTester tester, {String yeni = 'Yeni-Parola-2!', String? tekrar}) async {
      final alanlar = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
      await tester.enterText(alanlar.at(0), yeni);
      await tester.enterText(alanlar.at(1), tekrar ?? yeni);
    }

    Future<void> yenile(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Yenile'));
      await tester.pump();
      await tester.pump();
    }

    bool cagriVar() => ortam.api.cagrilar.any((c) => c.startsWith('asistaninSifresiniYenile'));

    testWidgets('the form stops a password that breaks the rules or does not match, before any request', (tester) async {
      await diyalogAc(tester);

      await doldur(tester, yeni: 'kisa');
      await yenile(tester);
      expect(find.text('Şifre en az 6 karakter olmalı.'), findsOneWidget);

      await doldur(tester, tekrar: 'Baska-Parola-3!');
      await yenile(tester);
      expect(find.text('Şifreler aynı değil.'), findsOneWidget);

      expect(cagriVar(), isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a good password goes to the server, the dialog closes and the message says the sessions are closed', (tester) async {
      await diyalogAc(tester);

      await doldur(tester);
      await yenile(tester);
      await tester.pumpAndSettle();

      expect(ortam.api.cagrilar, contains('asistaninSifresiniYenile:Yeni-Parola-2!'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Asistan\'ın şifresi değişti, oturumları kapatıldı.'), findsOneWidget);
    });

    testWidgets('a password the server refuses shows its message and the dialog stays open', (tester) async {
      await diyalogAc(tester);
      ortam.api.sifreHatasi = 400;

      await doldur(tester);
      await yenile(tester);

      expect(find.text('Mevcut şifre yanlış.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('without a connection nothing is sent and the dialog says so', (tester) async {
      await diyalogAc(tester);
      ortam.api.cevrimdisi = true;

      await doldur(tester);
      await yenile(tester);

      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('entry from Profil', () {
    Future<void> profil(WidgetTester tester, {required String rol}) async {
      // Tall: the list builds only what is on screen, and Profil has grown with the briefing rows.
      tester.view.physicalSize = const Size(375, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final kullanici = KullaniciRepository(api: ortam.api, db: ortam.db);
      ortam.api.ben_ = Ben(id: 'u', email: 'x@y.z', roller: [rol]);
      await tester.runAsync(kullanici.yukle);
      final vm = ProfilViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: kullanici),
            // The briefing rows of Profil (K2.7).
            Provider<BrifingRepository>.value(value: ortam.brifing),
            Provider<HatirlaticiBildirimYoneticisi>.value(
              value: HatirlaticiBildirimYoneticisi(
                repo: ortam.hatirlaticilar,
                esitleyici: ortam.esitleyici,
                servis: SahteBildirimServisi(),
                yazabilir: () => true,
              ),
            ),
          ],
          child: MaterialApp(home: ProfilScreen(viewModel: vm)),
        ),
      );
      await tester.pump();
    }

    testWidgets('the Sahip sees "Yönetim"', (tester) async {
      await profil(tester, rol: 'Sahip');
      expect(find.text('Yönetim'), findsOneWidget);
    });

    testWidgets('the Asistan does not', (tester) async {
      await profil(tester, rol: 'Asistan');
      expect(find.text('Yönetim'), findsNothing);
    });

    testWidgets('both roles can change their own password from here', (tester) async {
      await profil(tester, rol: 'Sahip');
      expect(find.text('Şifremi değiştir'), findsOneWidget);
      await profil(tester, rol: 'Asistan');
      expect(find.text('Şifremi değiştir'), findsOneWidget);
    });
  });
}
