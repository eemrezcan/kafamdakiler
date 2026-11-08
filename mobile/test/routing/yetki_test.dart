import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/repositories/kullanici_repository.dart';
import 'package:kafamdakiler/routing/router.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_liste_screen.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_liste_view_model.dart';
import 'package:provider/provider.dart';

import '../test_destek.dart';

const _yonetimRotalari = [
  '/aliskanlik/yeni',
  '/aliskanlik/a1/duzenle',
  '/raf/r1/oge-yeni',
  '/oge/o1/duzenle',
  '/yakala',
  '/yakalama/y1/duzenle',
  '/hatirlatici/yeni',
  '/hatirlatici/h1/duzenle',
  '/yonetim',
];

const _herkesinRotalari = [
  '/',
  '/aliskanliklar',
  '/projeler',
  '/projeler/kitap-kulubu',
  '/ara',
  '/not?yol=projects/a/notlar/b.md',
  '/hatirlaticilar',
  '/gelen',
  '/daha-fazla',
  '/eylemler',
  '/sifre',
  '/aliskanlik/a1/raf',
  '/aliskanlik/a1',
  '/aliskanlik/a1/kronometre',
  '/oge/o1',
  '/oge/o1/oturum',
];

void main() {
  group('route gate (M07)', () {
    test('Asistan cannot open the management forms', () {
      for (final rota in _yonetimRotalari) {
        final hedef = yetkiYonlendirme(rota, girisYapildi: true, sahip: false);
        expect(hedef, isNotNull, reason: rota);
        expect(hedef, '/aliskanliklar', reason: rota);
      }
      expect(yetkiYonlendirme('/aliskanlik/yeni', girisYapildi: true, sahip: false), '/aliskanliklar');
      expect(yetkiYonlendirme('/oge/o1/duzenle', girisYapildi: true, sahip: false), '/aliskanliklar');
    });

    test('Sahip can open them', () {
      for (final rota in _yonetimRotalari) {
        expect(yetkiYonlendirme(rota, girisYapildi: true, sahip: true), isNull, reason: rota);
      }
    });

    test('read-only and daily-use screens are open to both roles', () {
      for (final rota in _herkesinRotalari) {
        expect(yetkiYonlendirme(rota, girisYapildi: true, sahip: false), isNull, reason: rota);
      }
    });

    test('signed-out users only get the login screen', () {
      expect(yetkiYonlendirme('/', girisYapildi: false, sahip: false), '/giris');
      expect(yetkiYonlendirme('/aliskanlik/yeni', girisYapildi: false, sahip: true), '/giris');
      expect(yetkiYonlendirme('/giris', girisYapildi: false, sahip: false), isNull);
      expect(yetkiYonlendirme('/giris', girisYapildi: true, sahip: true), '/');
    });
  });

  group('habit list screen', () {
    late TestOrtami ortam;

    setUp(() => ortam = TestOrtami(api: SahteApi(aliskanliklar: [ornekAliskanlik()])));
    tearDown(() async => ortam.kapat());

    Future<void> goster(WidgetTester tester, {required String rol}) async {
      final kullanici = KullaniciRepository(api: ortam.api, db: ortam.db);
      ortam.api.ben_ = Ben(id: 'u', email: 'x@y.z', roller: [rol]);
      await tester.runAsync(kullanici.yukle);
      final vm = AliskanlikListeViewModel(repo: ortam.repo);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: kullanici,
          child: MaterialApp(home: AliskanlikListeScreen(viewModel: vm)),
        ),
      );
      await tester.pump();
    }

    testWidgets('Asistan sees the list but no "+"', (tester) async {
      await goster(tester, rol: 'Asistan');
      expect(find.text('Su iç'), findsOneWidget);
      expect(find.byTooltip('Yeni alışkanlık'), findsNothing);
    });

    testWidgets('Sahip sees "+"', (tester) async {
      await goster(tester, rol: 'Sahip');
      expect(find.text('Su iç'), findsOneWidget);
      expect(find.byTooltip('Yeni alışkanlık'), findsOneWidget);
    });
  });
}
