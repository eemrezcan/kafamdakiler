import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/models/yonetim.dart';
import 'package:kafamdakiler/data/repositories/kullanici_repository.dart';
import 'package:kafamdakiler/ui/profil/profil_screen.dart';
import 'package:kafamdakiler/ui/profil/profil_view_model.dart';
import 'package:kafamdakiler/ui/yonetim/yonetim_screen.dart';
import 'package:kafamdakiler/ui/yonetim/yonetim_view_model.dart';
import 'package:provider/provider.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUp(() {
    ortam = TestOrtami();
    ortam.api.izinler = const [
      Izin(izin: 'beyin.oku', aciklama: 'Beyni okur', acik: false),
      Izin(izin: 'yakalama.oku', aciklama: 'Yakalamaları okur', acik: true),
    ];
    ortam.api.gonderimler = [
      ornekGonderim(id: 'hatali', metin: 'hatalı olan', sonHata: 'beyin.py zaman aşımı'),
      ornekGonderim(id: 'takili', metin: 'takılı olan', gonderim: GonderimDurumu.takili, sonHata: null),
      ornekGonderim(id: 'tamam', metin: 'giden', gonderim: GonderimDurumu.tamam, durum: YakalamaDurumu.beyneGitti, deneme: 0, sonHata: null),
    ];
  });
  tearDown(() async => ortam.kapat());

  Future<YonetimViewModel> goster(WidgetTester tester) async {
    // Tall enough that the list builds every row: a ListView only builds what is on screen.
    tester.view.physicalSize = const Size(375, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = YonetimViewModel(api: ortam.api);
    await tester.runAsync(vm.yukle);
    await tester.pumpWidget(MaterialApp(home: YonetimScreen(viewModel: vm)));
    await tester.pump();
    return vm;
  }

  testWidgets('shows the permissions with their keys, the brain and the queue', (tester) async {
    await goster(tester);

    expect(find.text('beyin.oku'), findsOneWidget);
    expect(find.text('Beyni okur'), findsOneWidget);
    expect(find.text('yakalama.oku'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('izin-beyin.oku'))).value, isFalse);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('izin-yakalama.oku'))).value, isTrue);
    expect(find.text('Beyin bağlı'), findsOneWidget);
    expect(find.text('hatalı olan'), findsOneWidget);
    expect(find.text('takılı olan'), findsOneWidget);
    expect(find.text('beyin.py zaman aşımı'), findsOneWidget);
    // Only the failed and stuck ones can be sent again.
    expect(find.text('Yeniden gönder'), findsNWidgets(2));
  });

  testWidgets('flipping a switch asks the server and keeps the new state', (tester) async {
    await goster(tester);

    await tester.tap(find.byKey(const ValueKey('izin-beyin.oku')));
    await tester.pump();
    await tester.pump();

    expect(ortam.api.cagrilar, contains('izinAyarla:beyin.oku:true'));
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('izin-beyin.oku'))).value, isTrue);
  });

  testWidgets('a permission that could not be changed says so and stays as it was', (tester) async {
    await goster(tester);
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
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final kullanici = KullaniciRepository(api: ortam.api, db: ortam.db);
      ortam.api.ben_ = Ben(id: 'u', email: 'x@y.z', roller: [rol]);
      await tester.runAsync(kullanici.yukle);
      final vm = ProfilViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: kullanici,
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
