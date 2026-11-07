import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/repositories/auth_repository.dart';
import 'package:kafamdakiler/data/services/token_depo.dart';
import 'package:kafamdakiler/ui/profil/sifre_screen.dart';
import 'package:kafamdakiler/ui/profil/sifre_view_model.dart';

import '../test_destek.dart';

class _BellekDepo implements TokenDepo {
  String? access;
  String? refresh;

  @override
  Future<String?> accessToken() async => access;
  @override
  Future<String?> refreshToken() async => refresh;
  @override
  Future<void> kaydet({required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> temizle() async {
    access = null;
    refresh = null;
  }
}

void main() {
  late TestOrtami ortam;
  late _BellekDepo depo;
  late AuthRepository auth;

  setUp(() {
    ortam = TestOrtami();
    depo = _BellekDepo()
      ..access = 'eski-a'
      ..refresh = 'eski-r';
    auth = AuthRepository(api: ortam.api, depo: depo);
  });
  tearDown(() async => ortam.kapat());

  // The form opens on top of a first page, so a successful change has a page to go back to.
  Future<void> ac(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = SifreViewModel(api: ortam.api, auth: auth, email: () => 'sahip@test.local');
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SifreScreen(viewModel: vm))),
            child: const Text('ac'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
  }

  Future<void> doldur(WidgetTester tester, {String mevcut = 'Eski-Parola-1!', String yeni = 'Yeni-Parola-2!', String? tekrar}) async {
    final alanlar = find.byType(TextFormField);
    await tester.enterText(alanlar.at(0), mevcut);
    await tester.enterText(alanlar.at(1), yeni);
    await tester.enterText(alanlar.at(2), tekrar ?? yeni);
  }

  Future<void> gonder(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Şifreyi değiştir'));
    await tester.pump();
    await tester.pump();
  }

  bool sifreCagrisiVar() => ortam.api.cagrilar.any((c) => c.startsWith('sifreDegistir'));

  testWidgets('an empty form shows what is missing and sends nothing', (tester) async {
    await ac(tester);

    await gonder(tester);

    expect(find.text('Mevcut şifre gerekli.'), findsOneWidget);
    expect(find.text('Yeni şifre gerekli.'), findsOneWidget);
    expect(find.text('Şifreyi tekrar yaz.'), findsOneWidget);
    expect(sifreCagrisiVar(), isFalse);
  });

  testWidgets('a password that breaks the rules, or a repeat that differs, is stopped before any request', (tester) async {
    await ac(tester);

    await doldur(tester, yeni: 'kisa');
    await gonder(tester);
    expect(find.text('Şifre en az 6 karakter olmalı.'), findsOneWidget);

    await doldur(tester, tekrar: 'Baska-Parola-3!');
    await gonder(tester);
    expect(find.text('Şifreler aynı değil.'), findsOneWidget);

    expect(sifreCagrisiVar(), isFalse);
  });

  testWidgets('a good form calls the API, signs in again with the new password and goes back', (tester) async {
    await ac(tester);

    await doldur(tester);
    await gonder(tester);
    await tester.pumpAndSettle();

    expect(ortam.api.cagrilar, contains('sifreDegistir:Eski-Parola-1!:Yeni-Parola-2!'));
    // The old refresh token died with the change; fresh ones were stored.
    expect(ortam.api.cagrilar, contains('girisYap:sahip@test.local:Yeni-Parola-2!'));
    expect(depo.refresh, 'yeni-r');
    expect(auth.girisYapildi, isTrue);
    expect(find.byType(SifreScreen), findsNothing);
    expect(find.text('Şifren değişti.'), findsOneWidget);
  });

  testWidgets('a refused password (wrong current one) shows the server\'s message and stays on the form', (tester) async {
    await ac(tester);
    ortam.api.sifreHatasi = 400;

    await doldur(tester);
    await gonder(tester);

    expect(find.text('Mevcut şifre yanlış.'), findsOneWidget);
    expect(find.byType(SifreScreen), findsOneWidget);
    expect(ortam.api.cagrilar.where((c) => c.startsWith('girisYap')), isEmpty);
    expect(depo.refresh, 'eski-r');
  });

  testWidgets('without a connection nothing is sent and the message says so', (tester) async {
    await ac(tester);
    ortam.api.cevrimdisi = true;

    await doldur(tester);
    await gonder(tester);

    expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
    expect(find.byType(SifreScreen), findsOneWidget);
    expect(ortam.api.cagrilar.where((c) => c.startsWith('girisYap')), isEmpty);
  });
}
