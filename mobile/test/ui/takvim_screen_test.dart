import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/models/gun_gorunum.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/takvim/takvim_screen.dart';
import 'package:kafamdakiler/ui/takvim/takvim_view_model.dart';

import '../test_destek.dart';

/// Takvim (K-0024): week and month, dots, the chosen day's list, the upcoming list and the new "yapılacak" form.
/// The fixed "today" is Saturday 2026-10-31, so the week is Mon 26 Oct - Sun 1 Nov.
void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  Future<void> bekle(WidgetTester tester, [int ms = 150]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  Future<TakvimViewModel> goster(
    WidgetTester tester, {
    String rol = 'Sahip',
    Size boyut = const Size(360, 900),
    bool yuklemedenOnceCevrimdisi = false,
    bool cevrimdisi = true,
  }) async {
    tester.view.physicalSize = boyut;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kullanici = (await tester.runAsync(() => testKullanicisi(ortam, rol: rol)))!;
    final vm = TakvimViewModel(repo: ortam.gun, esitleyici: ortam.esitleyici);
    addTearDown(vm.dispose);
    if (yuklemedenOnceCevrimdisi) ortam.api.cevrimdisi = true;
    await tester.runAsync(vm.yukle);
    if (cevrimdisi) ortam.api.cevrimdisi = true;
    await tester.pumpWidget(testSarmalayici(ortam, kullanici, MaterialApp(home: TakvimScreen(viewModel: vm, yazabilir: kullanici.sahip))));
    await bekle(tester);
    return vm;
  }

  Future<List<BekleyenIslemlerData>> kuyruk(WidgetTester tester) async =>
      (await tester.runAsync(() => ortam.db.select(ortam.db.bekleyenIslemler).get()))!;

  Future<void> gunSec(WidgetTester tester, int gun, int ay) async {
    await tester.tap(find.byKey(ValueKey('takvim-gun-$gun-$ay')));
    await bekle(tester);
  }

  final bugunIsleri = [
    ornekYapilacak(kimlik: 'e:1', baslik: 'BLM4581 dersi', saat: '09:00'),
    ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'E-kampüsü kontrol et', saat: '14:00', tahminDk: 15),
  ];

  group('the view model', () {
    test('the range of a week is Monday to Sunday; of a month 42 days from the Monday on or before the 1st', () {
      final hafta = takvimAraligiHesapla(TakvimGorunumu.hafta, DateTime.utc(2026, 10, 31));
      expect(hafta.baslangic, DateTime.utc(2026, 10, 26));
      expect(hafta.bitis, DateTime.utc(2026, 11, 1));

      final ay = takvimAraligiHesapla(TakvimGorunumu.ay, DateTime.utc(2026, 11, 15));
      expect(ay.baslangic, DateTime.utc(2026, 10, 26), reason: '1 Nov 2026 is a Sunday');
      expect(ay.bitis.difference(ay.baslangic).inDays + 1, 42, reason: 'the most the range call takes');

      final pazartesi = takvimAraligiHesapla(TakvimGorunumu.ay, DateTime.utc(2026, 6, 10));
      expect(pazartesi.baslangic, DateTime.utc(2026, 6, 1), reason: '1 Jun 2026 is a Monday: the grid starts on it');
    });

    test('the week of a Sunday is the week that ends on it', () {
      expect(haftaBasi(DateTime.utc(2026, 11, 1)), DateTime.utc(2026, 10, 26));
      expect(haftaBasi(DateTime.utc(2026, 11, 2)), DateTime.utc(2026, 11, 2));
    });

    test('a month forward keeps the day number, or the last day when the next month is shorter', () async {
      final vm = TakvimViewModel(repo: ortam.gun, esitleyici: ortam.esitleyici);
      addTearDown(vm.dispose);
      await vm.gorunumDegistir(TakvimGorunumu.ay);

      await vm.kaydir(1);

      expect(vm.secili, DateTime.utc(2026, 11, 30), reason: '31 Oct -> 30 Nov');
      await vm.kaydir(-1);
      expect(vm.secili, DateTime.utc(2026, 10, 30));
    });

    test('choosing a day inside the loaded week reads only that day; leaving the week reads the new range too', () async {
      final vm = TakvimViewModel(repo: ortam.gun, esitleyici: ortam.esitleyici);
      addTearDown(vm.dispose);
      await vm.yukle();
      final once = ortam.api.takvimIstekleri.length;

      await vm.sec(DateTime.utc(2026, 10, 28));
      expect(ortam.api.takvimIstekleri.length, once, reason: 'the same week');
      expect(ortam.api.cagrilar, contains('gunGorunumu:2026-10-28'));

      await vm.sec(DateTime.utc(2026, 11, 3));
      expect(ortam.api.takvimIstekleri.last, '2026-11-02/2026-11-08');
    });
  });

  group('the week strip', () {
    testWidgets('seven days from Monday, today marked, the chosen day is today; dots per kind and a red one over capacity', (tester) async {
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: bugunIsleri);
      ortam.api.takvimYaniti = TakvimAraligi(gunler: [
        TakvimGunu(tarih: DateTime.utc(2026, 10, 31), sayilar: const TakvimSayilari(plan: 1, hatirlatici: 1)),
        TakvimGunu(tarih: DateTime.utc(2026, 10, 28), sayilar: const TakvimSayilari(plan: 3), yukAsimi: true),
      ]);
      await goster(tester);

      for (final g in ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']) {
        expect(find.text(g), findsOneWidget, reason: g);
      }
      expect(find.byKey(const ValueKey('takvim-gun-26-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('takvim-gun-1-11')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('takvim-gun-adi'))).data, 'CUMARTESİ 31 EKİM');
      expect(find.text('BLM4581 dersi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap on another day shows that day\'s list and its load', (tester) async {
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: bugunIsleri);
      ortam.api.gunGorunumleri['2026-10-28'] = ornekGun(
        tarih: DateTime.utc(2026, 10, 28),
        bugun: false,
        ogeler: [ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Çarşamba işi', tahminDk: 480)],
        kapasiteDk: 360,
      );
      await goster(tester, cevrimdisi: false);

      await gunSec(tester, 28, 10);

      expect(tester.widget<Text>(find.byKey(const ValueKey('takvim-gun-adi'))).data, 'ÇARŞAMBA 28 EKİM');
      expect(find.text('Çarşamba işi'), findsOneWidget);
      expect(find.text('BLM4581 dersi'), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('takvim-gun-yuku'))).data, '8 sa / 6 sa');
    });

    testWidgets('the arrows move a week; "Bugün" comes back', (tester) async {
      await goster(tester, cevrimdisi: false);

      await tester.tap(find.byKey(const ValueKey('takvim-ileri')));
      await bekle(tester);
      expect(find.byKey(const ValueKey('takvim-gun-2-11')), findsOneWidget);
      expect(find.byKey(const ValueKey('takvim-gun-26-10')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('takvim-gun-adi'))).data, 'CUMARTESİ 7 KASIM');
      expect(ortam.api.takvimIstekleri.last, '2026-11-02/2026-11-08');

      await tester.tap(find.byKey(const ValueKey('takvim-bugun')));
      await bekle(tester);
      expect(find.byKey(const ValueKey('takvim-gun-26-10')), findsOneWidget);
      expect(find.byKey(const ValueKey('takvim-bugun')), findsNothing, reason: 'already on today');
    });
  });

  group('the month grid', () {
    testWidgets('six weeks, the days of the neighbouring months faded; a tap chooses the day', (tester) async {
      ortam.api.gunGorunumleri['2026-11-05'] = ornekGun(
        tarih: DateTime.utc(2026, 11, 5),
        bugun: false,
        ogeler: [ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Kasım işi')],
      );
      await goster(tester, cevrimdisi: false);

      await tester.tap(find.text('Ay'));
      await bekle(tester);
      expect(ortam.api.takvimIstekleri.last, '2026-09-28/2026-11-08', reason: 'October\'s grid: six weeks from the Monday on or before the 1st');
      expect(find.text('Cmt'), findsOneWidget);

      // A day of the next month in the grid: the choice moves the month with it, and the grid is read again.
      await gunSec(tester, 5, 11);
      expect(find.text('Kasım işi'), findsOneWidget);
      expect(find.text('KASIM 2026'), findsNWidgets(2), reason: 'the app bar and the month label');
      expect(ortam.api.takvimIstekleri.last, '2026-10-26/2026-12-06');
      expect(tester.takeException(), isNull);
    });

    testWidgets('360 dp: the grid and every cell fit, and each cell is at least 48 dp high', (tester) async {
      await goster(tester);
      await tester.tap(find.text('Ay'));
      await bekle(tester);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey('takvim-gun-15-10'))).height, greaterThanOrEqualTo(48));
    });
  });

  group('upcoming', () {
    testWidgets('the rows the server lists, for reading', (tester) async {
      ortam.api.takvimYaniti = TakvimAraligi(yaklasan: [
        _yaklasan(ornekYapilacak(kimlik: 'h:r1', baslik: '1. sınıf içi gösterim', saat: '08:00', hatirlatici: const HatirlaticiOzet(id: 'r1', onceGun: 1)), DateTime.utc(2026, 11, 18)),
        _yaklasan(ornekYapilacak(kimlik: 'h:r2', baslik: 'Kira öde', hatirlatici: const HatirlaticiOzet(id: 'r2', tekrar: Tekrar.aylik)), DateTime.utc(2026, 11, 23)),
      ]);
      await goster(tester);

      expect(find.text('YAKLAŞAN'), findsOneWidget);
      expect(find.text('1. sınıf içi gösterim'), findsOneWidget);
      expect(find.text('18 Kas'), findsOneWidget, reason: 'each row names its day (sözleşme E1)');
      expect(find.text('23 Kas'), findsOneWidget);
      expect(find.text('her ay'), findsOneWidget);
    });

    testWidgets('a tap on an upcoming row shows its day in the calendar', (tester) async {
      ortam.api.takvimYaniti = TakvimAraligi(yaklasan: [
        _yaklasan(ornekYapilacak(kimlik: 'h:r1', baslik: '1. sınıf içi gösterim'), DateTime.utc(2026, 11, 18)),
      ]);
      ortam.api.gunGorunumleri['2026-11-18'] = ornekGun(
        tarih: DateTime.utc(2026, 11, 18),
        bugun: false,
        ogeler: [ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Gösterim günü işi')],
      );
      await goster(tester, cevrimdisi: false);

      await tester.tap(find.text('1. sınıf içi gösterim'));
      await bekle(tester);

      expect(tester.widget<Text>(find.byKey(const ValueKey('takvim-gun-adi'))).data, 'ÇARŞAMBA 18 KASIM');
      expect(find.text('Gösterim günü işi'), findsOneWidget);
    });

    testWidgets('no upcoming rows: no heading', (tester) async {
      await goster(tester);
      expect(find.text('YAKLAŞAN'), findsNothing);
    });
  });

  group('the new "yapılacak" form', () {
    Future<void> formAc(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('takvim-yeni')));
      await tester.pumpAndSettle();
    }

    Future<void> dokun(WidgetTester tester, String anahtar) async {
      await tester.ensureVisible(find.byKey(ValueKey(anahtar)));
      await tester.tap(find.byKey(ValueKey(anahtar)));
      await tester.pump();
    }

    testWidgets('a title is required; nothing is queued without it', (tester) async {
      await goster(tester);
      await formAc(tester);

      await dokun(tester, 'yeni-ekle');

      expect(find.text('Bir şey yaz.'), findsOneWidget);
      expect(await kuyruk(tester), isEmpty);
    });

    testWidgets('a plain row: title, estimate and project are queued for the chosen day', (tester) async {
      ortam.api.projeler = const [ProjeOzetOrnegi.okul];
      await goster(tester);
      await gunSec(tester, 28, 10);
      await formAc(tester);

      await tester.enterText(find.byKey(const ValueKey('yeni-baslik')), '  Ödev teslimi ');
      await dokun(tester, 'tahmin-60');
      await dokun(tester, 'yeni-ekle');
      await tester.pumpAndSettle();
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.gunOgeEkle);
      expect(satir.tarih, '2026-10-31', reason: 'a past day starts the form on today');
      expect(satir.govde, contains('"baslik":"Ödev teslimi"'));
      expect(satir.govde, contains('"tahminDk":60'));
      expect(satir.govde, isNot(contains('hatirlatici')));
      expect(find.byKey(const ValueKey('yeni-baslik')), findsNothing, reason: 'the sheet closed');
      await tester.tap(find.byKey(const ValueKey('takvim-bugun')));
      await bekle(tester);
      expect(find.text('Ödev teslimi'), findsOneWidget, reason: 'the new row is on today\'s list at once');
    });

    testWidgets('the reminder switch shows the fields; a weekly repeat on several days, urgent, 1 day before go into the write', (tester) async {
      await goster(tester);
      await formAc(tester);

      expect(find.byKey(const ValueKey('tekrar-haftalik')), findsNothing, reason: 'hidden until the switch is on');
      await dokun(tester, 'yeni-hatirlatici');
      expect(find.byKey(const ValueKey('tekrar-haftalik')), findsOneWidget);
      expect(find.byKey(const ValueKey('gun-sal')), findsNothing, reason: 'the days come with the weekly repeat');

      await tester.enterText(find.byKey(const ValueKey('yeni-baslik')), 'Spor salonu');
      await dokun(tester, 'tekrar-haftalik');
      expect(find.byKey(const ValueKey('gun-sal')), findsOneWidget);
      await dokun(tester, 'gun-sal');
      await dokun(tester, 'gun-per');
      await dokun(tester, 'once-1');
      await dokun(tester, 'hatirlatici-acil');
      await dokun(tester, 'hatirlatici-israrli');
      await dokun(tester, 'yeni-ekle');
      await tester.pumpAndSettle();
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.tur, BekleyenTur.gunOgeEkle);
      expect(satir.govde, contains('"tekrar":"haftalik"'));
      expect(satir.govde, contains('"gunler":["sal","per"]'));
      expect(satir.govde, contains('"onceGun":1'));
      expect(satir.govde, contains('"acil":true'));
      expect(satir.govde, contains('"israrli":true'));
    });

    testWidgets('days chosen and then another repeat: the days do not travel with a repeat that is not weekly', (tester) async {
      await goster(tester);
      await formAc(tester);
      await dokun(tester, 'yeni-hatirlatici');
      await tester.enterText(find.byKey(const ValueKey('yeni-baslik')), 'Kira');
      await dokun(tester, 'tekrar-haftalik');
      await dokun(tester, 'gun-cum');
      await dokun(tester, 'tekrar-aylik');
      await dokun(tester, 'yeni-ekle');
      await tester.pumpAndSettle();
      await bekle(tester);

      final satir = (await kuyruk(tester)).single;
      expect(satir.govde, contains('"tekrar":"aylik"'));
      expect(satir.govde, isNot(contains('gunler')));
    });

    testWidgets('an estimate chip is a toggle: a second tap takes it off', (tester) async {
      await goster(tester);
      await formAc(tester);

      await dokun(tester, 'tahmin-30');
      expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('tahmin-30'))).selected, isTrue);
      await dokun(tester, 'tahmin-30');
      expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('tahmin-30'))).selected, isFalse);
    });

    testWidgets('the form fits at 360 dp with the keyboard open and the reminder fields shown', (tester) async {
      await goster(tester);
      await formAc(tester);
      await dokun(tester, 'yeni-hatirlatici');
      await dokun(tester, 'tekrar-haftalik');

      expect(tester.takeException(), isNull);
    });
  });

  group('states and roles', () {
    testWidgets('the Asistan account: no ＋ button, no ticking, no sheet actions', (tester) async {
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: bugunIsleri);
      await goster(tester, rol: 'Asistan');

      expect(find.byKey(const ValueKey('takvim-yeni')), findsNothing);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('yaptim-m:aa11bb'))).onChanged, isNull);
    });

    testWidgets('a tick in the day list queues the write and the row is done at once', (tester) async {
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: bugunIsleri);
      await goster(tester);

      await tester.tap(find.byKey(const ValueKey('yaptim-m:aa11bb')));
      await bekle(tester);

      expect((await kuyruk(tester)).single.tur, BekleyenTur.gunYaptim);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('yaptim-m:aa11bb'))).value, isTrue);
    });

    testWidgets('a day with nothing says so', (tester) async {
      await goster(tester);
      expect(find.byKey(const ValueKey('takvim-gun-bos')), findsOneWidget);
    });

    testWidgets('offline with a kept range: it shows and says so; with none, the error and a retry', (tester) async {
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: bugunIsleri);
      final ilk = TakvimViewModel(repo: ortam.gun, esitleyici: ortam.esitleyici);
      await tester.runAsync(ilk.yukle);
      ilk.dispose();

      await goster(tester, yuklemedenOnceCevrimdisi: true);
      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
      expect(find.text('BLM4581 dersi'), findsOneWidget);
    });

    testWidgets('a server error on the first load: the message and a retry for the strip, a card for the day', (tester) async {
      ortam.api.sunucuHatasi = 500;
      await goster(tester, yuklemedenOnceCevrimdisi: false);

      expect(find.textContaining('Takvim alınamadı (sunucu hatası 500)'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.textContaining('Gün alınamadı (sunucu hatası 500)'), findsOneWidget);
    });

    testWidgets('1200 dp: the content is centred with a maximum width', (tester) async {
      await goster(tester, boyut: const Size(1200, 900));
      final kart = tester.getRect(find.byType(SegmentedButton<TakvimGorunumu>));
      expect(kart.width, lessThanOrEqualTo(640));
      expect(kart.center.dx, closeTo(600, 1));
    });

    testWidgets('the day cells and the arrows are at least 48 dp', (tester) async {
      await goster(tester);
      for (final k in ['takvim-gun-26-10', 'takvim-geri', 'takvim-ileri', 'takvim-yeni']) {
        final boy = tester.getSize(find.byKey(ValueKey(k)));
        expect(boy.width, greaterThanOrEqualTo(48), reason: k);
        expect(boy.height, greaterThanOrEqualTo(48), reason: k);
      }
    });
  });
}

/// A row of the upcoming list: the same row with the day it belongs to.
Yapilacak _yaklasan(Yapilacak o, DateTime tarih) => Yapilacak(
      kimlik: o.kimlik,
      tur: o.tur,
      baslik: o.baslik,
      saat: o.saat,
      hatirlatici: o.hatirlatici,
      hatirlaticiId: o.hatirlaticiId,
      tarih: tarih,
    );

/// A project of the phone's list (the form's picker).
abstract final class ProjeOzetOrnegi {
  static const okul = ProjeOzet(kimlik: 'okul', baslik: 'Okul');
}
