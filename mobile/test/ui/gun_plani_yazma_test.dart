import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/ui/bugun/gun_plani_karti.dart';
import 'package:kafamdakiler/ui/bugun/gun_plani_view_model.dart';

import '../test_destek.dart';

// The plan card with its writes (K2.3a): tick, add, carry over, the morning card, the "does not fit" warning, offline use and
// what the user is told when the server refuses a write or answers unclearly.

BeyinGunMaddesi _madde(String id, String baslik, {String durum = 'acik', int? tahminDk}) =>
    BeyinGunMaddesi(id: id, baslik: baslik, durum: durum, tahminDk: tahminDk);

BeyinGun _plan(DateTime tarih, List<BeyinGunMaddesi> maddeler, {GunKapasiteUyarisi? uyari, bool kapandi = false}) => BeyinGun(
      tarih: tarih,
      planVar: true,
      kapandi: kapandi,
      bolumler: [BeyinGunBolumu(ad: 'Yapılacaklar', maddeler: maddeler)],
      toplam: BeyinGunToplami(madde: maddeler.length),
      kapasiteUyarisi: uyari,
    );

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  /// Drift needs real time; the fake-async zone of a widget test would never finish its queries.
  Future<void> gercekZaman(WidgetTester tester, [int ms = 150]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }

  Future<GunPlaniViewModel> goster(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = GunPlaniViewModel(repo: ortam.gunPlani, esitleyici: ortam.esitleyici);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.yukle);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GunPlaniKarti(viewModel: vm)))));
    await gercekZaman(tester);
    return vm;
  }

  void bugunPlani(List<BeyinGunMaddesi> maddeler, {GunKapasiteUyarisi? uyari, bool kapandi = false}) {
    ortam.api.gunPlanlari = {'2026-10-31': _plan(sabitBugun, maddeler, uyari: uyari, kapandi: kapandi)};
  }

  group('offline use', () {
    testWidgets('a tick offline shows at once, stays queued, and goes out when the connection is back', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim ay görünümü')]);
      final vm = await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.byTooltip('Yaptım: Takvim ay görünümü'));
      await gercekZaman(tester);

      expect(find.byTooltip('İşareti kaldır: Takvim ay görünümü'), findsOneWidget);
      expect(find.bySemanticsLabel('Yapıldı'), findsOneWidget);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));

      ortam.api.cevrimdisi = false;
      await tester.runAsync(() => ortam.esitleyici.gonder());
      await gercekZaman(tester);
      expect(ortam.api.beyinYazimlari.single.yol, '/api/beyin/gunler/2026-10-31/isaretle');
      expect(ortam.api.beyinYazimlari.single.govde, {'madde': 'a3f09c', 'geri': false});
      expect(vm.bildirimler, isEmpty);
    });

    testWidgets('a new line offline appears as "gönderilecek", cannot be ticked, and tells the plan is the phone\'s copy', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim')]);
      await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.byKey(const Key('plan-ekle')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'one "Ekle" asks where it goes; the plan is the default');
      await tester.enterText(find.byType(TextField), 'Fatura kontrol ~45dk');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpAndSettle();
      await gercekZaman(tester);

      expect(find.text('Fatura kontrol'), findsOneWidget);
      expect(find.text('gönderilecek'), findsOneWidget);
      expect(find.text('45 dk'), findsOneWidget);
      expect(find.byTooltip('Yaptım: Fatura kontrol'), findsNothing, reason: 'it has no id of the brain\'s yet');
      expect(find.byTooltip('Yaptım: Takvim'), findsOneWidget);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
    });

    testWidgets('with no answer from the server the phone\'s copy of the day is shown and says so', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim')]);
      final vm = await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.runAsync(vm.yukle);
      await gercekZaman(tester);

      expect(find.text('Takvim'), findsOneWidget);
      expect(find.text('Çevrimdışısın; telefondaki plan gösteriliyor.'), findsOneWidget);
    });

    testWidgets('carry over from the menu: the line is marked and the queue holds the write', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim', tahminDk: 60)]);
      await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.byTooltip('Madde işlemleri: Takvim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ertesi güne devret'));
      await tester.pumpAndSettle();
      await gercekZaman(tester);

      expect(find.text('devredildi'), findsOneWidget);
      expect(find.byTooltip('Yaptım: Takvim'), findsNothing);
      final bekleyen = (await ortam.esitleyici.bekleyenler()).single;
      expect(bekleyen.hedefId, 'a3f09c');
      expect(bekleyen.tarih, '2026-10-31');
    });

    testWidgets('a note from the menu is queued', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim')]);
      await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.byTooltip('Madde işlemleri: Takvim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Önce kütüphaneye bak');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      await gercekZaman(tester);

      expect((await ortam.esitleyici.bekleyenler()).single.govde, contains('Önce kütüphaneye bak'));
    });

    testWidgets('a task finished from the overdue list leaves the list at once', (tester) async {
      ortam.api.gunPlanlari = {
        '2026-10-31': BeyinGun(tarih: sabitBugun, planVar: true, geciken: const [GecikenGorev(kimlik: 'diş', baslik: 'Diş randevusu al', gun: 3)]),
      };
      await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.byTooltip('Görev işlemleri: Diş randevusu al'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Görevi bitir'));
      await tester.pumpAndSettle();
      await gercekZaman(tester);

      expect(find.text('Diş randevusu al'), findsNothing);
      expect((await ortam.esitleyici.bekleyenler()).single.hedefId, 'diş');
    });

    testWidgets('a task is split over days from the overdue list', (tester) async {
      ortam.api.gunPlanlari = {
        '2026-10-31': BeyinGun(tarih: sabitBugun, planVar: true, geciken: const [GecikenGorev(kimlik: 'uye-girisi', baslik: 'Üye girişi', gun: 1)]),
      };
      await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.byTooltip('Görev işlemleri: Üye girişi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Günlere böl'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Artır'));
      await tester.pump();
      await tester.tap(find.text('Böl'));
      await tester.pumpAndSettle();
      await gercekZaman(tester);

      final bekleyen = (await ortam.esitleyici.bekleyenler()).single;
      expect(bekleyen.hedefId, 'uye-girisi');
      expect(bekleyen.govde, contains('"gunSayisi":3'));
      expect(bekleyen.govde, contains('"baslangic":"2026-10-31"'));
    });

    testWidgets('a new task needs a project; the phone\'s project list is offered', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim')]);
      ortam.api.projeler = const [ProjeOzet(kimlik: 'kitap-kulubu', baslik: 'Kitap Kulübü Sitesi')];
      await tester.runAsync(ortam.beyin.projeleriGetir);
      await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.byKey(const Key('plan-ekle')));
      await tester.pumpAndSettle();
      expect(find.text('Kitap Kulübü Sitesi'), findsNothing, reason: 'the project only matters for a task');
      await tester.tap(find.text('Görev').last);
      await tester.pumpAndSettle();
      expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Üye girişi testleri');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
      await tester.pumpAndSettle();
      await gercekZaman(tester);

      final bekleyen = (await ortam.esitleyici.bekleyenler()).single;
      expect(bekleyen.govde, contains('"baslik":"Üye girişi testleri"'));
      expect(bekleyen.govde, contains('"proje":"kitap-kulubu"'));
    });
  });

  group('what the user is told', () {
    testWidgets('a refused tick goes back to open on the screen and the reason is shown; "Kapat" removes the message', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim')]);
      await goster(tester);
      ortam.api.beyinYazmaKodlari = [409];
      ortam.api.beyinYazmaProblemi = {'title': 'Gün kapandı', 'detail': 'Kapanmış güne yazılmaz.'};

      await tester.tap(find.byTooltip('Yaptım: Takvim'));
      await gercekZaman(tester, 400);

      expect(find.textContaining('Kapanmış güne yazılmaz.'), findsOneWidget);
      expect(find.textContaining('geri alındı'), findsOneWidget);
      expect(find.byTooltip('Yaptım: Takvim'), findsOneWidget, reason: 'open again: the write was taken back');

      await tester.tap(find.byTooltip('Kapat'));
      await gercekZaman(tester);
      expect(find.textContaining('Kapanmış güne yazılmaz.'), findsNothing);
    });

    testWidgets('an unclear answer (202) is shown as a note, not as success and not as a refusal', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim')]);
      await goster(tester);
      ortam.api.beyinYazmaKodlari = [202];
      ortam.api.beyinYazmaGovdesi = {'ayrinti': 'Beyin zamanında cevap vermedi; yazılmış olabilir.'};

      await tester.tap(find.byTooltip('Yaptım: Takvim'));
      await gercekZaman(tester, 400);

      expect(find.textContaining('yazılmış olabilir'), findsOneWidget);
      expect(find.textContaining('geri alındı'), findsNothing);
      expect(ortam.api.beyinYazimlari, hasLength(1), reason: 'never sent again');
    });
  });

  group('"Bugün sığmıyor" and the closed day', () {
    testWidgets('the warning from the server is shown with its minutes', (tester) async {
      bugunPlani(
        [_madde('a3f09c', 'Büyük iş', tahminDk: 400)],
        uyari: const GunKapasiteUyarisi(acikTahminDk: 400, kapasiteDk: 360, asimDk: 40),
      );
      await goster(tester);

      expect(find.byKey(const Key('kapasite-uyarisi')), findsOneWidget);
      final kutu = find.byKey(const Key('kapasite-uyarisi'));
      expect(find.descendant(of: kutu, matching: find.textContaining('Bugün sığmıyor')), findsOneWidget);
      expect(find.descendant(of: kutu, matching: find.textContaining('açık işler 6 sa 40 dk')), findsOneWidget);
      expect(find.descendant(of: kutu, matching: find.textContaining('günlük kapasite 6 sa;')), findsOneWidget);
      expect(find.descendant(of: kutu, matching: find.textContaining('40 dk fazla')), findsOneWidget);
    });

    testWidgets('no warning when the server sent none', (tester) async {
      bugunPlani([_madde('a3f09c', 'Küçük iş', tahminDk: 30)]);
      await goster(tester);

      expect(find.byKey(const Key('kapasite-uyarisi')), findsNothing);
    });

    testWidgets('a day the brain closed offers no writes and says so', (tester) async {
      bugunPlani([_madde('a3f09c', 'Takvim')], kapandi: true);
      await goster(tester);

      expect(find.textContaining('Bu gün kapandı'), findsOneWidget);
      expect(find.text('Madde ekle'), findsNothing);
      expect(find.byTooltip('Yaptım: Takvim'), findsNothing);
    });

    testWidgets('an item whose id the brain did not write (not the permanent kind) cannot be written to', (tester) async {
      bugunPlani([_madde('a1', 'Eski kimlik')]);
      await goster(tester);

      expect(find.text('Eski kimlik'), findsOneWidget);
      expect(find.byTooltip('Yaptım: Eski kimlik'), findsNothing);
      expect(find.byTooltip('Madde işlemleri: Eski kimlik'), findsNothing);
    });
  });

  group('the morning card', () {
    void dunPlani() {
      ortam.api.gunPlanlari = {
        '2026-10-30': _plan(DateTime.utc(2026, 10, 30), [_madde('b4e1d2', 'Dünden kalan iş'), _madde('c5d2e3', 'Bitmiş', durum: 'yapildi')]),
        '2026-10-31': _plan(sabitBugun, [_madde('a3f09c', 'Bugünün işi')]),
      };
    }

    testWidgets('lists yesterday\'s open lines on today, and only on today', (tester) async {
      dunPlani();
      final vm = await goster(tester);

      expect(find.byKey(const Key('sabah-karti')), findsOneWidget);
      expect(find.text('Dünden kalanlar'), findsOneWidget);
      expect(find.text('Dünden kalan iş'), findsOneWidget);
      expect(find.text('Bitmiş'), findsNothing);

      await tester.runAsync(() => vm.gunDegistir(1));
      await gercekZaman(tester);
      expect(find.byKey(const Key('sabah-karti')), findsNothing);
    });

    testWidgets('"Taşı" queues a carry-over dated yesterday and the line leaves the card', (tester) async {
      dunPlani();
      await goster(tester);
      ortam.api.cevrimdisi = true;

      await tester.tap(find.text('Taşı'));
      await gercekZaman(tester);

      expect(find.text('Dünden kalanlar'), findsNothing);
      final bekleyen = (await ortam.esitleyici.bekleyenler()).single;
      expect(bekleyen.tarih, '2026-10-30');
      expect(bekleyen.hedefId, 'b4e1d2');
    });

    testWidgets('"Bırak" closes the entry and writes nothing to the brain, now and after a reload', (tester) async {
      dunPlani();
      final vm = await goster(tester);

      await tester.tap(find.text('Bırak'));
      await gercekZaman(tester);

      expect(find.text('Dünden kalanlar'), findsNothing);
      expect(await ortam.esitleyici.bekleyenler(reddedilenler: true), isEmpty);
      expect(ortam.api.beyinYazimlari, isEmpty);

      await tester.runAsync(vm.yukle);
      await gercekZaman(tester);
      expect(find.text('Dünden kalanlar'), findsNothing);
    });
  });
}
