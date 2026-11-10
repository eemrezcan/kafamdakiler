import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/asistan.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/data/models/is_karti.dart';
import 'package:kafamdakiler/data/models/yakala_girdisi.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/asistan/asistan_screen.dart';
import 'package:kafamdakiler/ui/asistan/asistan_view_model.dart';
import 'package:kafamdakiler/ui/yakalama/ses_view_model.dart';

import '../test_destek.dart';
import 'ses_test.dart' show SahteBaglanti, SahteDikte;

/// The Asistan tab (K-0024): the single feed and its input.
void main() {
  late TestOrtami ortam;
  late GoRouter router;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  final bugun = DateTime.utc(2026, 10, 31, 8);

  Future<void> bekle(WidgetTester tester, [int ms = 150]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  Future<List<BekleyenIslemlerData>> kuyruk(WidgetTester tester) async =>
      (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;

  /// [cevrimdisi] (the default) cuts the connection after the first load: the fake server never changes its answer, so a write
  /// that was sent would be undone by the next read.
  Future<AsistanViewModel> goster(
    WidgetTester tester, {
    String rol = 'Sahip',
    bool cevrimdisi = true,
    bool yuklemedenOnce = false,
    YakalaGirdisi? baslangic,
    SahteDikte? dikte,
    Future<String?> Function(ImageSource)? fotografSecici,
    Size boyut = const Size(360, 900),
    int? sunucuHatasi,
  }) async {
    tester.view.physicalSize = boyut;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kullanici = (await tester.runAsync(() => testKullanicisi(ortam, rol: rol)))!;
    final vm = AsistanViewModel(repo: ortam.asistan, brifing: ortam.brifing, esitleyici: ortam.esitleyici);
    addTearDown(vm.dispose);
    final ses = dikte == null ? null : SesViewModel(api: ortam.api, dikte: dikte, baglanti: SahteBaglanti());
    if (ses != null) addTearDown(ses.dispose);
    if (yuklemedenOnce) ortam.api.cevrimdisi = true;
    if (sunucuHatasi != null) ortam.api.sunucuHatasi = sunucuHatasi;
    await tester.runAsync(vm.yukle);
    if (cevrimdisi) ortam.api.cevrimdisi = true;
    router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => AsistanScreen(
          viewModel: vm,
          ses: ses,
          fotografSecici: fotografSecici,
          baslangic: baslangic,
          yazabilir: kullanici.asistanKullanabilir,
          islerOkuyabilir: kullanici.islerOkuyabilir,
          sahip: kullanici.sahip,
          simdi: () => DateTime.utc(2026, 10, 31, 10),
        ),
      ),
      GoRoute(path: '/eylem/:id', builder: (c, s) => Scaffold(body: Text('eylem ${s.pathParameters['id']}'))),
      GoRoute(path: '/asistan/:kimlik', builder: (c, s) => Scaffold(body: Text('iş ${s.pathParameters['kimlik']}'))),
      GoRoute(path: '/yakalama/:id/duzenle', builder: (c, s) => Scaffold(body: Text('yakalama ${s.pathParameters['id']}'))),
      GoRoute(path: '/hatirlatici/:id/duzenle', builder: (c, s) => Scaffold(body: Text('hatırlatıcı ${s.pathParameters['id']}'))),
      GoRoute(path: '/gelen', builder: (c, s) => const Scaffold(body: Text('gelen sayfası'))),
      GoRoute(path: '/gun/:tarih', builder: (c, s) => Scaffold(body: Text('gün ${s.pathParameters['tarih']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(testSarmalayici(ortam, kullanici, MaterialApp.router(routerConfig: router)));
    await bekle(tester);
    return vm;
  }

  final yakalama = Yakalama(
    id: 'y1',
    metin: 'Flutter state yönetimi',
    hedef: 'projects/kafamdakiler',
    durum: YakalamaDurumu.bekliyor,
    yakalandiAt: bugun,
    olusturulma: bugun,
  );

  group('the feed', () {
    testWidgets('oldest at the top, newest at the bottom next to the input; the day heading above the first item', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('c', AkisTuru.sonuc, zaman: bugun.add(const Duration(minutes: 2)), sonuclar: [ornekSonuc(baslik: 'En yeni sonuç')]),
        ornekAkis('b', AkisTuru.kullanici, zaman: bugun.add(const Duration(minutes: 1)), metin: 'ortadaki mesaj'),
        ornekAkis('a', AkisTuru.kullanici, zaman: bugun, metin: 'en eski mesaj'),
      ];
      await goster(tester);

      final y = [for (final t in ['en eski mesaj', 'ortadaki mesaj', 'En yeni sonuç']) tester.getTopLeft(find.text(t)).dy];
      expect(y, orderedEquals([...y]..sort()));
      expect(find.text('Bugün'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const ValueKey('asistan-metin'))).dy, greaterThan(y.last), reason: 'the input is under the feed');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a feed that is empty tells how to start', (tester) async {
      await goster(tester);
      expect(find.byKey(const ValueKey('akis-bos')), findsOneWidget);
    });

    testWidgets('a server error on the first load: the message and a retry; the input stays', (tester) async {
      await goster(tester, cevrimdisi: false, sunucuHatasi: 500);

      expect(find.textContaining('Asistan akışı alınamadı (sunucu hatası 500)'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.byKey(const ValueKey('asistan-metin')), findsOneWidget);
    });

    testWidgets('offline with a kept page: the feed shows and says so', (tester) async {
      ortam.api.akisOgeleri = [ornekAkis('a', AkisTuru.kullanici, metin: 'eski mesaj')];
      final ilk = AsistanViewModel(repo: ortam.asistan, brifing: ortam.brifing, esitleyici: ortam.esitleyici);
      await tester.runAsync(ilk.yukle);
      ilk.dispose();

      await goster(tester, yuklemedenOnce: true);

      expect(find.text('eski mesaj'), findsOneWidget);
      expect(find.byKey(const ValueKey('akis-cevrimdisi')), findsOneWidget);
    });

    testWidgets('a kind of item this version does not know is not shown and breaks nothing', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('x', 'gelecekteki-tur'),
        ornekAkis('a', AkisTuru.kullanici, metin: 'bilinen'),
      ];
      await goster(tester);

      expect(find.text('bilinen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a full page has "Daha eski kayıtlar", which adds the older page above', (tester) async {
      ortam.api.akisOgeleri = [
        for (var i = 0; i < 43; i++) ornekAkis('s$i', AkisTuru.kullanici, zaman: bugun.subtract(Duration(minutes: i)), metin: 'mesaj $i'),
      ];
      await goster(tester, cevrimdisi: false);

      await tester.scrollUntilVisible(find.byKey(const ValueKey('akis-daha')), 400, scrollable: find.descendant(of: find.byKey(const ValueKey('akis-liste')), matching: find.byType(Scrollable)));
      await tester.tap(find.byKey(const ValueKey('akis-daha')));
      await bekle(tester);

      await tester.scrollUntilVisible(find.text('mesaj 42'), 400, scrollable: find.descendant(of: find.byKey(const ValueKey('akis-liste')), matching: find.byType(Scrollable)));
      expect(find.text('mesaj 42'), findsOneWidget);
      expect(find.byKey(const ValueKey('akis-daha')), findsNothing, reason: 'the short page was the last');
    });
  });

  group('the kinds of item', () {
    testWidgets('a result: "✓ Yaptım", a row per thing done, and "Geri al" that queues the undo and marks the row', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [
          ornekSonuc(baslik: 'E-kampüsü kontrol et', ozet: 'yarın 09:00 · 🔔', eylemId: 'e1'),
          ornekSonuc(baslik: 'Ödev teslimi', ozet: 'Cuma, tüm gün 🔔', eylemId: 'e2'),
        ]),
      ];
      await goster(tester);

      expect(find.text('✓ YAPTIM'), findsOneWidget);
      expect(find.text('yarın 09:00 · 🔔'), findsOneWidget);
      expect(find.text('Cuma, tüm gün 🔔'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sonuc-geri-al-e1')));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.eylemGeriAl);
      expect(satir.hedefId, 'e1');
      expect(find.text('Geri alınıyor'), findsOneWidget);
      expect(find.byKey(const ValueKey('sonuc-geri-al-e1')), findsNothing, reason: 'it cannot be undone twice');
      expect(find.byKey(const ValueKey('sonuc-geri-al-e2')), findsOneWidget, reason: 'the other row is untouched');
    });

    testWidgets('a result that cannot be undone has no "Geri al"; one the person may not do says so', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [
          ornekSonuc(baslik: 'Silinemez iş', eylemId: 'e3', geriAlinabilir: false),
          ornekSonuc(baslik: 'Planı yazmak', eylemId: null, durum: SonucDurumu.izinYok, geriAlinabilir: false),
        ]),
      ];
      await goster(tester);

      expect(find.byKey(const ValueKey('sonuc-geri-al-e3')), findsNothing);
      expect(find.text('YAPAMADIM'), findsOneWidget);
      expect(find.text('Bu işe iznin yok.'), findsOneWidget);
    });

    testWidgets('"Düzelt" opens the place the result names', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [ornekSonuc(eylemId: 'e1', hedefRota: '/hatirlatici/h5/duzenle')]),
      ];
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('sonuc-duzelt-e1')));
      await tester.pumpAndSettle();

      expect(find.text('hatırlatıcı h5'), findsOneWidget);
    });

    testWidgets('"Düzelt" on a result whose route is a day (E8) goes to that day, replacing the feed (a tab switch, not a page on top)', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [ornekSonuc(eylemId: 'e1', hedefRota: '/gun/2026-11-11')]),
      ];
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('sonuc-duzelt-e1')));
      await tester.pumpAndSettle();

      expect(find.text('gün 2026-11-11'), findsOneWidget);
      expect(router.canPop(), isFalse, reason: 'go, not push: no page was put on top of the feed');
    });

    testWidgets('a result with a route that is an address, not an in-app path, offers no "Düzelt"', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [ornekSonuc(eylemId: 'e1', hedefRota: 'https://kotu.example/x')]),
      ];
      await goster(tester);

      expect(find.byKey(const ValueKey('sonuc-duzelt-e1')), findsNothing);
    });

    testWidgets('a result that went to approval (E7): "Onayını bekliyor", not red, no "Geri al"/"Düzelt"; "Ekle" queues the approval and shows it done', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [
          ornekSonuc(baslik: 'Dışarıdan gelen plan', ozet: 'onay bekliyor', eylemId: 'e7', durum: SonucDurumu.onayda, geriAlinabilir: false, hedefRota: '/asistan'),
        ]),
      ];
      await goster(tester);

      expect(find.text('ONAYINI BEKLİYOR'), findsOneWidget);
      expect(find.text('YAPAMADIM'), findsNothing);
      expect(find.byKey(const ValueKey('sonuc-geri-al-e7')), findsNothing);
      expect(find.byKey(const ValueKey('sonuc-duzelt-e7')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sonuc-onay-uygula-e7')));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect((satir.tur, satir.hedefId), (BekleyenTur.eylemUygula, 'e7'));
      expect(find.text('✓ YAPTIM'), findsOneWidget);
      expect(find.byKey(const ValueKey('sonuc-onay-uygula-e7')), findsNothing);
    });

    testWidgets('a result that went to approval: "Geç" queues the refusal and the row leaves the card', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [
          ornekSonuc(baslik: 'Dışarıdan gelen plan', eylemId: 'e7', durum: SonucDurumu.onayda, geriAlinabilir: false),
        ]),
      ];
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('sonuc-onay-gec-e7')));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect((satir.tur, satir.hedefId), (BekleyenTur.eylemReddet, 'e7'));
      expect(find.text('Dışarıdan gelen plan'), findsNothing);
    });

    testWidgets('a result row that waits for approval next to one that failed: the card says it could not do', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('r', AkisTuru.sonuc, sonuclar: [
          ornekSonuc(baslik: 'Bekleyen', eylemId: 'e7', durum: SonucDurumu.onayda, geriAlinabilir: false),
          ornekSonuc(baslik: 'Hatalı', eylemId: null, durum: SonucDurumu.hata, geriAlinabilir: false),
        ]),
      ];
      await goster(tester);

      expect(find.text('YAPAMADIM'), findsOneWidget);
      expect(find.byKey(const ValueKey('sonuc-onay-uygula-e7')), findsOneWidget);
    });

    testWidgets('a question: its answers are buttons; one is sent through the queue and the question leaves, the answer shows', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('q', AkisTuru.soru, soru: const AsistanSorusu(id: 'q1', metin: '"Mobil UI maketini bitir" yarına kalsın mı?', secenekler: ['Yarına al', 'Bugün yaparım'])),
      ];
      await goster(tester);

      expect(find.text('BİR SORU'), findsOneWidget);
      expect(find.textContaining('yarına kalsın mı?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('soru-cevap-0')));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.asistanCevap);
      expect(satir.hedefId, 'q1');
      expect(satir.govde, contains('Yarına al'));
      expect(find.byKey(const ValueKey('soru-cevap-0')), findsNothing);
      expect(find.text('Yarına al'), findsOneWidget, reason: 'as the person\'s own message');
      expect(find.byKey(const ValueKey('akis-gonderilecek')), findsOneWidget);
    });

    testWidgets('an approval: where it came from, what it would do, "Ekle" and "Geç"; a tap on the card opens its detail', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('o1', AkisTuru.onay, eylem: ornekEylem(id: 'e1', ozet: 'Cuma 15:00 proje toplantısı', disKaynak: true)),
        ornekAkis('o2', AkisTuru.onay, zaman: bugun.subtract(const Duration(minutes: 1)), eylem: ornekEylem(id: 'e2', ozet: 'Faturayı öde')),
      ];
      await goster(tester);

      expect(find.text('ONAYINI BEKLİYOR · DIŞ KAYNAK'), findsOneWidget);
      expect(find.text('ONAYINI BEKLİYOR'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onay-uygula-e1')));
      await bekle(tester);
      await tester.tap(find.byKey(const ValueKey('onay-reddet-e2')));
      await bekle(tester);

      final turler = (await kuyruk(tester)).map((b) => (b.tur, b.hedefId)).toList();
      expect(turler, [(BekleyenTur.eylemUygula, 'e1'), (BekleyenTur.eylemReddet, 'e2')]);
      expect(find.text('Cuma 15:00 proje toplantısı'), findsNothing, reason: 'a decided approval leaves the feed');
    });

    testWidgets('a tap on the body of an approval opens its detail', (tester) async {
      ortam.api.akisOgeleri = [ornekAkis('o1', AkisTuru.onay, eylem: ornekEylem(id: 'e1', ozet: 'Cuma 15:00 proje toplantısı'))];
      await goster(tester);

      await tester.tap(find.text('Cuma 15:00 proje toplantısı'));
      await tester.pumpAndSettle();

      expect(find.text('eylem e1'), findsOneWidget);
    });

    testWidgets('a work card: its stage and holder; a tap opens the card', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('i', AkisTuru.isKarti, isKarti: const IsKarti(kimlik: 'takvim', baslik: 'Habit detayına ısı haritası', tip: 'kod', asama: 'yapim', sahip: 'vps', proje: 'kafamdakiler')),
      ];
      await goster(tester);

      expect(find.text('İŞ · VPS\'TE'), findsOneWidget);
      expect(find.text('kafamdakiler · kod · Yapım'), findsOneWidget);
      await tester.tap(find.text('Habit detayına ısı haritası'));
      await tester.pumpAndSettle();

      expect(find.text('iş takvim'), findsOneWidget);
    });

    testWidgets('a work card with a question shows how many are open; a finished one says so', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('i1', AkisTuru.isKarti, isKarti: const IsKarti(kimlik: 'a', baslik: 'Karar bekleyen', tip: 'kod', asama: 'karar', sahip: 'kullanici', bekleyenSoru: 2)),
        ornekAkis('i2', AkisTuru.isKarti, zaman: bugun.subtract(const Duration(minutes: 1)), isKarti: const IsKarti(kimlik: 'b', baslik: 'Biten iş', tip: 'genel', asama: 'bitti', sahip: 'vps')),
      ];
      await goster(tester);

      expect(find.textContaining('2 cevapsız soru'), findsOneWidget);
      expect(find.text('İŞ · BİTTİ'), findsOneWidget);
    });

    testWidgets('a note: what it says and where it went; "Başka yere" opens the capture', (tester) async {
      ortam.api.akisOgeleri = [ornekAkis('n', AkisTuru.not, yakalama: yakalama)];
      await goster(tester);

      expect(find.text('✓ NOT OLARAK KAYDETTİM'), findsOneWidget);
      expect(find.text('Flutter state yönetimi'), findsOneWidget);
      expect(find.text('projects/kafamdakiler'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('not-baska-y1')));
      await tester.pumpAndSettle();
      expect(find.text('yakalama y1'), findsOneWidget);
    });

    testWidgets('a note: "Geri al" deletes the capture and the note leaves the feed at once', (tester) async {
      ortam.api.akisOgeleri = [ornekAkis('n', AkisTuru.not, yakalama: yakalama)];
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('not-geri-al-y1')));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.yakalamaSil);
      expect(satir.hedefId, 'y1');
      expect(find.text('Flutter state yönetimi'), findsNothing);
    });

    testWidgets('a note that already went to the brain has no "Geri al"', (tester) async {
      final gitmis = Yakalama(id: 'y2', metin: 'Gitmiş not', durum: YakalamaDurumu.beyneGitti, yakalandiAt: bugun, olusturulma: bugun);
      ortam.api.akisOgeleri = [ornekAkis('n', AkisTuru.not, yakalama: gitmis)];
      await goster(tester);

      expect(find.text('✓ BEYNE GİTTİ'), findsOneWidget);
      expect(find.byKey(const ValueKey('not-geri-al-y2')), findsNothing);
    });

    testWidgets('the briefing: its cards with a thumb each; a thumb is a vote to the server and the same thumb takes it back', (tester) async {
      final brifing = Brifing(
        gun: '2026-10-31',
        uretimAni: bugun,
        yontem: 'claude',
        kartlar: const [
          BrifingKarti(sira: 0, tur: BrifingTuru.plan, baslik: 'Bugün 7 iş var', metin: 'İlki 14:00\'te'),
          BrifingKarti(sira: 1, tur: BrifingTuru.kalan, baslik: 'Dünden kalanlar', metin: 'Market'),
          BrifingKarti(sira: 2, tur: BrifingTuru.kapasite, baslik: 'Gün taşıyor', metin: '1 sa 20 dk fazla'),
        ],
      );
      ortam.api.brifingYaniti = brifing;
      ortam.api.akisOgeleri = [ornekAkis('br', AkisTuru.brifing, metin: 'Günaydın.', brifing: brifing)];
      await goster(tester, cevrimdisi: false);

      expect(find.text('✦ SABAH ÖZETİ'), findsOneWidget);
      expect(find.text('Günaydın.'), findsOneWidget);
      expect(find.text('Bugün 7 iş var'), findsOneWidget);
      expect(find.text('Dünden kalanlar'), findsNothing, reason: 'Bugün lists what was left; the card is not repeated');

      await tester.tap(find.byKey(const ValueKey('brifing-oy-up-0')));
      await bekle(tester);
      expect(ortam.api.brifingOylari, [('2026-10-31', 0, 1)]);

      await tester.tap(find.byKey(const ValueKey('brifing-oy-up-0')));
      await bekle(tester);
      expect(ortam.api.brifingOylari.last, ('2026-10-31', 0, 0), reason: 'the same thumb again takes it back');
    });

    testWidgets('a vote without a connection says so and changes nothing', (tester) async {
      final brifing = Brifing(
        gun: '2026-10-31',
        uretimAni: bugun,
        yontem: 'hesap',
        kartlar: const [BrifingKarti(sira: 0, tur: BrifingTuru.plan, baslik: 'Plan', metin: 'x')],
      );
      ortam.api.brifingYaniti = brifing;
      ortam.api.akisOgeleri = [ornekAkis('br', AkisTuru.brifing, brifing: brifing)];
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('brifing-oy-up-0')));
      await bekle(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Çevrimdışısın: oy gönderilmedi'), findsOneWidget);
      expect(ortam.api.brifingOylari, isEmpty);
    });
  });

  group('the filters', () {
    final karisik = [
      ornekAkis('i', AkisTuru.isKarti, zaman: bugun.add(const Duration(minutes: 5)), isKarti: const IsKarti(kimlik: 'a', baslik: 'İş kartı', tip: 'kod', asama: 'yapim', sahip: 'vps')),
      ornekAkis('o', AkisTuru.onay, zaman: bugun.add(const Duration(minutes: 4)), eylem: ornekEylem(id: 'e1', ozet: 'Bekleyen onay')),
      ornekAkis('q', AkisTuru.soru, zaman: bugun.add(const Duration(minutes: 3)), soru: const AsistanSorusu(id: 'q1', metin: 'Bekleyen soru', secenekler: ['Evet'])),
      ornekAkis('n', AkisTuru.not, zaman: bugun.add(const Duration(minutes: 2)), yakalama: Yakalama(id: 'y1', metin: 'Bir not', durum: YakalamaDurumu.bekliyor, yakalandiAt: bugun, olusturulma: bugun)),
      ornekAkis('k', AkisTuru.kullanici, zaman: bugun, metin: 'düz mesaj'),
    ];

    testWidgets('chips with how many there are; a chip asks the server for that filter', (tester) async {
      ortam.api.akisOgeleri = karisik;
      await goster(tester, cevrimdisi: false, boyut: const Size(600, 900));

      expect(find.text('Hepsi'), findsOneWidget);
      expect(find.text('Bekleyen 2'), findsOneWidget);
      expect(find.text('İşler 1'), findsOneWidget);
      expect(find.text('Notlar'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('suzgec-bekleyen')));
      await bekle(tester);

      expect(ortam.api.akisIstekleri, contains('bekleyen|'));
      expect(find.text('Bekleyen onay'), findsOneWidget);
      expect(find.text('Bekleyen soru'), findsOneWidget);
      expect(find.text('düz mesaj'), findsNothing);
      expect(find.text('Bekleyen 2'), findsOneWidget, reason: 'the counts stay those of the whole feed');
    });

    testWidgets('"İşler" and "Notlar" show only their own; "Hepsi" brings everything back', (tester) async {
      ortam.api.akisOgeleri = karisik;
      await goster(tester, cevrimdisi: false, boyut: const Size(600, 900));

      await tester.tap(find.byKey(const ValueKey('suzgec-isler')));
      await bekle(tester);
      expect(find.text('İş kartı'), findsOneWidget);
      expect(find.text('Bir not'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('suzgec-notlar')));
      await bekle(tester);
      expect(find.text('Bir not'), findsOneWidget);
      expect(find.text('İş kartı'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('suzgec-hepsi')));
      await bekle(tester);
      expect(find.text('düz mesaj'), findsOneWidget);
    });

    testWidgets('a filter with nothing in it says so', (tester) async {
      ortam.api.akisOgeleri = [ornekAkis('k', AkisTuru.kullanici, metin: 'düz mesaj')];
      await goster(tester, cevrimdisi: false, boyut: const Size(600, 900));

      await tester.tap(find.byKey(const ValueKey('suzgec-notlar')));
      await bekle(tester);

      expect(find.text('Bu süzgeçte bir şey yok.'), findsOneWidget);
    });

    testWidgets('at 360 dp every chip is on screen, the last one too, with big counts; each can be tapped', (tester) async {
      ortam.api.akisOgeleri = [
        for (var i = 0; i < 12; i++) ornekAkis('o$i', AkisTuru.onay, zaman: bugun.add(Duration(minutes: i)), eylem: ornekEylem(id: 'e$i')),
        for (var i = 0; i < 11; i++)
          ornekAkis('i$i', AkisTuru.isKarti, zaman: bugun.subtract(Duration(minutes: i + 1)), isKarti: IsKarti(kimlik: 'k$i', baslik: 'İş $i', tip: 'kod', asama: 'yapim', sahip: 'vps')),
      ];
      await goster(tester, cevrimdisi: false);

      expect(tester.takeException(), isNull);
      for (final k in ['hepsi', 'bekleyen', 'isler', 'notlar']) {
        final r = tester.getRect(find.byKey(ValueKey('suzgec-$k')));
        expect(r.left, greaterThanOrEqualTo(0), reason: k);
        expect(r.right, lessThanOrEqualTo(360), reason: k);
        expect(r.height, greaterThanOrEqualTo(32), reason: k);
      }
      expect(find.text('Bekleyen 12'), findsOneWidget);
      expect(find.text('İşler 11'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('suzgec-notlar')));
      await bekle(tester);
      expect(ortam.api.akisIstekleri, contains('notlar|'));
    });

    testWidgets('offline the filters work on the kept page', (tester) async {
      ortam.api.akisOgeleri = karisik;
      final ilk = AsistanViewModel(repo: ortam.asistan, brifing: ortam.brifing, esitleyici: ortam.esitleyici);
      await tester.runAsync(ilk.yukle);
      ilk.dispose();
      await goster(tester, yuklemedenOnce: true, boyut: const Size(600, 900));

      await tester.tap(find.byKey(const ValueKey('suzgec-isler')));
      await bekle(tester);

      expect(find.text('İş kartı'), findsOneWidget);
      expect(find.text('Bekleyen onay'), findsNothing);
    });
  });

  group('the input', () {
    testWidgets('empty, it cannot be sent; with text it can; the text goes through the queue and shows as "gönderilecek"', (tester) async {
      await goster(tester);

      expect(tester.widget<IconButton>(find.byKey(const ValueKey('asistan-gonder'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('asistan-metin')), 'yarın sabah e-kampüse bakmayı hatırlat');
      await tester.pump();
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('asistan-gonder'))).onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('asistan-gonder')));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.asistanGirdi);
      expect(satir.govde, contains('yarın sabah e-kampüse bakmayı hatırlat'));
      expect(satir.govde, contains('"kaynak":"yazi"'));
      expect(find.text('yarın sabah e-kampüse bakmayı hatırlat'), findsOneWidget, reason: 'as the person\'s message');
      expect(find.byKey(const ValueKey('akis-gonderilecek')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('asistan-metin'))).controller!.text, isEmpty, reason: 'ready for the next one');
    });

    testWidgets('spaces alone are not an input', (tester) async {
      await goster(tester);

      await tester.enterText(find.byKey(const ValueKey('asistan-metin')), '   ');
      await tester.pump();

      expect(tester.widget<IconButton>(find.byKey(const ValueKey('asistan-gonder'))).onPressed, isNull);
    });

    testWidgets('a text over the limit is refused with the limit said', (tester) async {
      await goster(tester);

      await tester.enterText(find.byKey(const ValueKey('asistan-metin')), 'a' * 4001);
      await tester.pump();

      expect(find.text('En çok 4000 karakter.'), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('asistan-gonder'))).onPressed, isNull);
    });

    testWidgets('online the input is sent at once, and the answer the server made shows in the feed', (tester) async {
      await goster(tester, cevrimdisi: false);

      await tester.enterText(find.byKey(const ValueKey('asistan-metin')), 'merhaba');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('asistan-gonder')));
      await bekle(tester, 400);

      expect(ortam.api.asistanGirdileri.single.metin, 'merhaba');
      expect(find.byKey(const ValueKey('akis-gonderilecek')), findsNothing, reason: 'it reached the server');
    });

    testWidgets('a refused input stays with the reason and can be deleted', (tester) async {
      await goster(tester, cevrimdisi: false);
      ortam.api.gunYazmaHatasi = 400;

      await tester.enterText(find.byKey(const ValueKey('asistan-metin')), 'olmayacak iş');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('asistan-gonder')));
      await bekle(tester, 400);

      expect(find.textContaining('Gönderilemedi: Sunucu bu işi kabul etmedi.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('akis-girdi-sil')));
      await bekle(tester);
      expect(find.text('olmayacak iş'), findsNothing);
      expect(await kuyruk(tester), isEmpty);
    });

    testWidgets('a photo: the picker, a preview that can be taken off, and an input that carries the photo\'s copy', (tester) async {
      final dosya = File('${ortam.fotografKlasoru.path}${Platform.pathSeparator}foto.jpg')..writeAsBytesSync([1, 2, 3]);
      final istenen = <ImageSource>[];
      await goster(tester, fotografSecici: (k) async {
        istenen.add(k);
        return dosya.path;
      });

      await tester.tap(find.byKey(const ValueKey('asistan-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('foto-galeri')));
      await tester.pumpAndSettle();
      expect(istenen, [ImageSource.gallery]);
      expect(find.byKey(const ValueKey('asistan-foto-kaldir')), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('asistan-gonder'))).onPressed, isNotNull, reason: 'a photo alone is enough');

      await tester.tap(find.byKey(const ValueKey('asistan-foto-kaldir')));
      await tester.pump();
      expect(find.byKey(const ValueKey('asistan-foto-kaldir')), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('asistan-gonder'))).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('asistan-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('foto-kamera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('asistan-gonder')));
      // The photo is copied (file IO) and then queued (drift): two rounds of real time.
      await bekle(tester);
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.asistanGirdi);
      expect(satir.govde, contains('fotografYolu'));
      expect(istenen.last, ImageSource.camera);
      expect(find.byKey(const ValueKey('asistan-foto-kaldir')), findsNothing, reason: 'the preview is gone after sending');
    });

    testWidgets('a picker that fails says so and sends nothing', (tester) async {
      await goster(tester, fotografSecici: (_) async => throw Exception('kamera yok'));

      await tester.tap(find.byKey(const ValueKey('asistan-foto')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('foto-kamera')));
      await tester.pumpAndSettle();

      expect(find.text('Fotoğraf alınamadı.'), findsOneWidget);
      expect(await kuyruk(tester), isEmpty);
    });

    testWidgets('the microphone: the words come into the field as they are heard; the input is sent as voice', (tester) async {
      final dikte = SahteDikte();
      await goster(tester, dikte: dikte);

      await tester.tap(find.byKey(const ValueKey('asistan-dikte')));
      await bekle(tester);
      expect(dikte.dinlemeSayisi, 1);
      dikte.sonuc!('cuma 10\'da diş randevusu', true);
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('asistan-metin'))).controller!.text, 'cuma 10\'da diş randevusu');

      await tester.tap(find.byKey(const ValueKey('asistan-gonder')));
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.govde, contains('"kaynak":"ses"'));
      expect(dikte.durdurmaSayisi, greaterThan(0), reason: 'sending stops the listening');
    });

    testWidgets('no microphone service: the button is not there', (tester) async {
      await goster(tester);
      expect(find.byKey(const ValueKey('asistan-dikte')), findsNothing);
    });
  });

  group('coming from outside', () {
    testWidgets('a share: its text is in the input, ready to look at and send, and the input is focused', (tester) async {
      await goster(tester, baslangic: const YakalaGirdisi(metin: 'https://ornek.example/makale'));

      final alan = tester.widget<TextField>(find.byKey(const ValueKey('asistan-metin')));
      expect(alan.controller!.text, 'https://ornek.example/makale');
      expect(alan.focusNode!.hasFocus, isTrue);

      await tester.tap(find.byKey(const ValueKey('asistan-gonder')));
      await bekle(tester);
      expect((await kuyruk(tester)).single.govde, contains('"kaynak":"paylas"'));
    });

    testWidgets('a shared photo is shown as the photo to send', (tester) async {
      final dosya = File('${ortam.fotografKlasoru.path}${Platform.pathSeparator}paylasilan.jpg')..writeAsBytesSync([1, 2, 3]);
      await goster(tester, baslangic: YakalaGirdisi(fotografYolu: dosya.path));

      expect(find.byKey(const ValueKey('asistan-foto-kaldir')), findsOneWidget);
    });

    testWidgets('the widget or the shortcut (an empty request): the input is focused and the source is the widget\'s', (tester) async {
      await goster(tester, baslangic: const YakalaGirdisi());

      expect(tester.widget<TextField>(find.byKey(const ValueKey('asistan-metin'))).focusNode!.hasFocus, isTrue);
      await tester.enterText(find.byKey(const ValueKey('asistan-metin')), 'hızlı not');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('asistan-gonder')));
      await bekle(tester);

      expect((await kuyruk(tester)).single.govde, contains('"kaynak":"widget"'));
    });
  });

  group('roles and the menu', () {
    testWidgets('an account without the assistant permission reads the feed: no input, no buttons on questions or approvals', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('q', AkisTuru.soru, zaman: bugun.add(const Duration(minutes: 1)), soru: const AsistanSorusu(id: 'q1', metin: 'Bir soru', secenekler: ['Evet'])),
        ornekAkis('o', AkisTuru.onay, eylem: ornekEylem(id: 'e1', ozet: 'Bir onay')),
        ornekAkis('r', AkisTuru.sonuc, zaman: bugun.subtract(const Duration(minutes: 1)), sonuclar: [ornekSonuc(eylemId: 'e8', durum: SonucDurumu.onayda, geriAlinabilir: false)]),
      ];
      await goster(tester, rol: 'Asistan');

      expect(find.text('ONAYINI BEKLİYOR'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('sonuc-onay-uygula-e8')), findsNothing);

      expect(find.text('Bir soru'), findsOneWidget);
      expect(find.text('Bir onay'), findsOneWidget);
      expect(find.byKey(const ValueKey('asistan-metin')), findsNothing);
      expect(find.byKey(const ValueKey('soru-cevap-0')), findsNothing);
      expect(find.byKey(const ValueKey('onay-uygula-e1')), findsNothing);
    });

    testWidgets('the menu: the Sahip has the inbox, the queue, the cards and "Projeye yakala"; a reader less', (tester) async {
      await goster(tester);
      await tester.tap(find.byKey(const ValueKey('asistan-menu')));
      await tester.pumpAndSettle();
      for (final ad in ['Gelen kutusu', 'Onay kuyruğu', 'İş kartları', 'Projeye yakala']) {
        expect(find.text(ad), findsOneWidget, reason: ad);
      }
    });
  });

  group('layout', () {
    testWidgets('360 dp with every kind on screen: nothing overflows and the buttons are at least 48 dp', (tester) async {
      ortam.api.akisOgeleri = [
        ornekAkis('n', AkisTuru.not, zaman: bugun.add(const Duration(minutes: 6)), yakalama: yakalama),
        ornekAkis('i', AkisTuru.isKarti, zaman: bugun.add(const Duration(minutes: 5)), isKarti: const IsKarti(kimlik: 'a', baslik: 'Çok uzun bir iş kartı başlığı taşmamalı ekranda', tip: 'kod', asama: 'yapim', sahip: 'vps', proje: 'kafamdakiler')),
        ornekAkis('o', AkisTuru.onay, zaman: bugun.add(const Duration(minutes: 4)), eylem: ornekEylem(id: 'e1', ozet: 'Çok uzun bir onay özeti taşmamalı ekranda', disKaynak: true)),
        ornekAkis('q', AkisTuru.soru, zaman: bugun.add(const Duration(minutes: 3)), soru: const AsistanSorusu(id: 'q1', metin: 'Çok uzun bir soru metni satıra sarılmalı', secenekler: ['Birinci seçenek', 'İkinci seçenek', 'Üçüncü seçenek'])),
        ornekAkis('r', AkisTuru.sonuc, zaman: bugun.add(const Duration(minutes: 2)), sonuclar: [ornekSonuc(hedefRota: '/takvim')]),
        ornekAkis('w', AkisTuru.sonuc, zaman: bugun.add(const Duration(minutes: 1)), sonuclar: [ornekSonuc(eylemId: 'e9', durum: SonucDurumu.onayda, geriAlinabilir: false)]),
        ornekAkis('k', AkisTuru.kullanici, zaman: bugun, metin: 'uzun bir mesaj ' * 12),
      ];
      await goster(tester, boyut: const Size(360, 2000));

      expect(tester.takeException(), isNull);
      for (final k in ['onay-uygula-e1', 'onay-reddet-e1', 'soru-cevap-0', 'sonuc-geri-al-e1', 'sonuc-duzelt-e1', 'sonuc-onay-uygula-e9', 'sonuc-onay-gec-e9', 'asistan-gonder', 'asistan-foto']) {
        final boy = tester.getSize(find.byKey(ValueKey(k)));
        expect(boy.width, greaterThanOrEqualTo(48), reason: k);
        expect(boy.height, greaterThanOrEqualTo(48), reason: k);
      }
    });

    testWidgets('1200 dp: the feed is centred with a maximum width', (tester) async {
      ortam.api.akisOgeleri = [ornekAkis('k', AkisTuru.kullanici, metin: 'merhaba')];
      await goster(tester, boyut: const Size(1200, 900));

      final balon = tester.getRect(find.text('merhaba'));
      expect(balon.right, lessThanOrEqualTo(600 + 320 + 1), reason: 'inside the 640 dp column');
    });
  });
}
