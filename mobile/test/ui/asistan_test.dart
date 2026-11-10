import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/models/is_karti.dart';
import 'package:kafamdakiler/routing/router.dart';
import 'package:kafamdakiler/ui/asistan/asistan_pano_screen.dart';
import 'package:kafamdakiler/ui/asistan/asistan_pano_view_model.dart';
import 'package:kafamdakiler/ui/asistan/is_detay_screen.dart';
import 'package:kafamdakiler/ui/asistan/is_detay_view_model.dart';
import 'package:kafamdakiler/ui/asistan/is_form_screen.dart';
import 'package:kafamdakiler/ui/asistan/is_form_view_model.dart';
import 'package:kafamdakiler/utils/is_gorunum.dart';

import '../test_destek.dart';

// The work cards on the phone: the Bugün card's numbers, the board's groups, answering a question with one tap, the gate
// buttons (a push or deploy asks once more), the form's checks and the offline board.

IsKarti kart(
  String kimlik, {
  String asama = 'plan',
  String sahip = 'vps',
  bool acik = true,
  int bekleyen = 0,
  List<String>? gecisler,
  String tip = 'kod',
}) =>
    IsKarti(
      kimlik: kimlik,
      baslik: 'Kart $kimlik',
      tip: tip,
      asama: asama,
      sahip: sahip,
      proje: 'kitap-kulubu',
      bekleyenSoru: bekleyen,
      // As the brain reports them: the next stage of a gate (if it is at one), back to the plan, and cancelling.
      gecisler: gecisler ?? (acik ? [?kapidanSonraki(asama), 'plan', 'iptal'] : const []),
      acik: acik,
    );

IsAyrinti ayrinti(
  String kimlik, {
  String asama = 'karar',
  String sahip = 'kullanici',
  List<IsSorusu> sorular = const [],
  bool acik = true,
  String plan = '## Adımlar\n- Ay görünümü',
}) =>
    IsAyrinti(
      kart: kart(kimlik, asama: asama, sahip: sahip, acik: acik, bekleyen: sorular.where((s) => !s.cevaplandi).length),
      talep: 'Buluşma takvimi',
      plan: plan,
      sorular: sorular,
      gecmis: const [IsGecmisi(zaman: '2026-11-10 09:00', olay: 'plan yazıldı', kim: 'vps')],
    );

const hangisi = IsSorusu(no: 1, soru: 'Hangi kütüphane?', secenekler: ['a', 'b'], onerilen: 'a', neden: 'Daha hafif');

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  void telefonBoyu(WidgetTester tester, {double boy = 900}) {
    tester.view.physicalSize = Size(375, boy);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // The board (and the Bugün card) keeps the last download in the database, which needs real time.
  Future<void> gercekZaman(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  final panoKartlari = [
    kart('kod', asama: 'kod-onayi', sahip: 'kullanici'),
    kart('push', asama: 'push-onayi', sahip: 'vps'),
    kart('karar-bir', asama: 'karar', sahip: 'kullanici', bekleyen: 1),
    kart('vps-plan', asama: 'plan', sahip: 'vps'),
    kart('vps-yapim', asama: 'yapim', sahip: 'vps'),
    kart('bitti', asama: 'bitti', sahip: 'vps', acik: false),
  ];

  group('the board', () {
    Future<AsistanPanoViewModel> goster(WidgetTester tester, {bool yazabilir = true}) async {
      telefonBoyu(tester, boy: 1200);
      final vm = AsistanPanoViewModel(repo: ortam.isler);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(MaterialApp(home: AsistanPanoScreen(viewModel: vm, yazabilir: yazabilir)));
      await tester.pump();
      return vm;
    }

    testWidgets('the groups, each with its cards and a count, in the order the person looks for them', (tester) async {
      ortam.api.isKartlari = panoKartlari;

      await goster(tester);

      final basliklar = ['Sende bekleyen · 1', 'Onay bekleyen kapılar · 2', "VPS'te · 1", 'Yapımda · 1', 'Bu hafta biten · 1'];
      for (final b in basliklar) {
        expect(find.text(b), findsOneWidget, reason: b);
      }
      final yler = [for (final b in basliklar) tester.getTopLeft(find.text(b)).dy];
      expect(yler, orderedEquals([...yler]..sort()));
      expect(find.text('Karar · Sende · kitap-kulubu · 1 cevapsız soru'), findsOneWidget);
      expect(find.text("Laptop'ta · 0"), findsNothing, reason: 'an empty group is not shown');
    });

    testWidgets('no card at all says so', (tester) async {
      await goster(tester);

      expect(find.textContaining('Henüz iş kartı yok'), findsOneWidget);
    });

    testWidgets('offline: the last board with a note, and the new-card button is shut', (tester) async {
      ortam.api.isKartlari = panoKartlari;
      await tester.runAsync(ortam.isler.panoyuGetir);
      ortam.api.beyinCevrimdisi = true;

      await goster(tester);

      expect(find.textContaining('Çevrimdışısın; son indirilen pano gösteriliyor'), findsOneWidget);
      expect(find.text('Kart kod'), findsOneWidget);
      expect(tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed, isNull);
    });

    testWidgets('online the new-card button is there and works', (tester) async {
      ortam.api.isKartlari = panoKartlari;

      await goster(tester);

      expect(tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed, isNotNull);
    });

    testWidgets('someone who may not write has no new-card button', (tester) async {
      ortam.api.isKartlari = panoKartlari;

      await goster(tester, yazabilir: false);

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('offline with nothing on the phone: the reason and a retry', (tester) async {
      ortam.api.beyinCevrimdisi = true;

      await goster(tester);

      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });
  });

  group('a card', () {
    Future<IsDetayViewModel> goster(WidgetTester tester, IsAyrinti a, {bool yazabilir = true}) async {
      telefonBoyu(tester, boy: 1400);
      ortam.api.isAyrintilari[a.kart.kimlik] = a;
      final vm = IsDetayViewModel(repo: ortam.isler, kimlik: a.kart.kimlik, yazabilir: yazabilir);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(MaterialApp(home: IsDetayScreen(viewModel: vm)));
      await tester.pump();
      return vm;
    }

    Future<void> bekle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    // `FilledButton.icon` and friends are subclasses, which `find.byType` does not match: look for the button around its text.
    Finder dugme(String metin) => find.ancestor(
          of: find.text(metin),
          matching: find.byWidgetPredicate((w) => w is ActionChip || w is FilledButton || w is OutlinedButton || w is TextButton),
        );

    bool dugmeAcik(WidgetTester tester, String metin) => switch (tester.widget(dugme(metin).first)) {
          final ActionChip c => c.onPressed != null,
          final FilledButton b => b.onPressed != null,
          final OutlinedButton b => b.onPressed != null,
          final TextButton b => b.onPressed != null,
          _ => throw StateError('not a button'),
        };

    testWidgets('the request, the Markdown plan, the questions and the history', (tester) async {
      await goster(tester, ayrinti('k', sorular: [hangisi]));

      expect(find.text('Buluşma takvimi'), findsOneWidget);
      expect(find.text('Adımlar'), findsOneWidget, reason: 'the plan is rendered as Markdown');
      expect(find.text('Ay görünümü'), findsOneWidget);
      expect(find.text('S1 · Hangi kütüphane?'), findsOneWidget);
      expect(find.textContaining('plan yazıldı'), findsOneWidget);
      expect(find.text('Karar'), findsOneWidget);
    });

    testWidgets('the options are chips, the recommended one is marked, "neden" opens', (tester) async {
      await goster(tester, ayrinti('k', sorular: [hangisi]));

      expect(find.text('a (önerilen)'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('Daha hafif'), findsNothing);

      await tester.tap(find.text('Neden?'));
      await tester.pumpAndSettle();
      expect(find.text('Daha hafif'), findsOneWidget);
    });

    testWidgets('one tap on an option answers; the question is then locked and shows the answer', (tester) async {
      await goster(tester, ayrinti('k', sorular: [hangisi]));
      ortam.api.beyinYazmaGovdesi = kart('k').toJson();
      // The server, after the write, holds the answered card.
      ortam.api.isAyrintilari['k'] = ayrinti('k', sorular: [const IsSorusu(no: 1, soru: 'Hangi kütüphane?', secenekler: ['a', 'b'], onerilen: 'a', cevap: 'b')]);

      await tester.tap(find.text('b'));
      await bekle(tester);

      final yazim = ortam.api.beyinYazimlari.single;
      expect(yazim.yol, '/api/isler/k/cevap');
      expect(yazim.govde, {'soruNo': 1, 'cevap': 'b'});
      expect(find.text('Cevap: b'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing, reason: 'an answered question is locked');
    });

    testWidgets('a question with no options takes free text; an empty answer is not sent', (tester) async {
      await goster(tester, ayrinti('k', sorular: [const IsSorusu(no: 1, soru: 'Ne zaman?')]));
      ortam.api.beyinYazmaGovdesi = kart('k').toJson();

      await tester.tap(find.text('Gönder'));
      await bekle(tester);
      expect(find.text('Cevap boş olamaz.'), findsOneWidget);
      expect(ortam.api.beyinYazimlari, isEmpty);

      await tester.enterText(find.byType(TextField), 'Bu hafta');
      await tester.tap(find.text('Gönder'));
      await bekle(tester);
      expect(ortam.api.beyinYazimlari.single.govde, {'soruNo': 1, 'cevap': 'Bu hafta'});
    });

    testWidgets('the code gate: "Kodu onayla", "Plana geri gönder" and "İptal et"; one tap on the first moves the card to the build', (tester) async {
      await goster(tester, ayrinti('k', asama: 'kod-onayi'));
      ortam.api.beyinYazmaGovdesi = kart('k', asama: 'yapim').toJson();

      expect(find.text('Kodu onayla'), findsOneWidget);
      expect(find.text('Plana geri gönder'), findsOneWidget);
      expect(find.text('İptal et'), findsOneWidget);

      await tester.tap(find.text('Kodu onayla'));
      await bekle(tester);

      expect(ortam.api.beyinYazimlari.single.govde, {'asama': 'yapim'}, reason: 'the approval itself is added by the server');
    });

    testWidgets('the push gate asks once more; "Vazgeç" writes nothing, "Onayla" moves the card to the deploy gate', (tester) async {
      await goster(tester, ayrinti('k', asama: 'push-onayi'));
      ortam.api.beyinYazmaGovdesi = kart('k', asama: 'deploy-onayi').toJson();

      await tester.tap(find.text("Push'u onayla"));
      await tester.pumpAndSettle();
      expect(find.text('Push onayı verilsin mi?'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(ortam.api.beyinYazimlari, isEmpty);

      await tester.tap(find.text("Push'u onayla"));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Onayla')));
      await bekle(tester);
      expect(ortam.api.beyinYazimlari.single.govde, {'asama': 'deploy-onayi'});
    });

    testWidgets('the deploy gate also asks once more, and leads to done', (tester) async {
      await goster(tester, ayrinti('k', asama: 'deploy-onayi'));
      ortam.api.beyinYazmaGovdesi = kart('k', asama: 'bitti', acik: false).toJson();

      await tester.tap(find.text("Deploy'u onayla"));
      await tester.pumpAndSettle();
      expect(find.text('Deploy onayı verilsin mi?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Onayla')));
      await bekle(tester);

      expect(ortam.api.beyinYazimlari.single.govde, {'asama': 'bitti'});
    });

    testWidgets('a card that is not at a gate has no approve button, but can be sent back to the plan with a note', (tester) async {
      await goster(tester, ayrinti('k', asama: 'karar'));
      ortam.api.beyinYazmaGovdesi = kart('k').toJson();

      expect(find.textContaining('onayla'), findsNothing);
      await tester.tap(find.text('Plana geri gönder'));
      await tester.pumpAndSettle();
      expect(find.text('Plana geri gönderilsin mi?'), findsOneWidget);
      expect(ortam.api.beyinYazimlari, isEmpty, reason: 'the window asks first');

      await tester.enterText(find.byKey(const ValueKey('revizyon-not')), '  Ay görünümünü de ekle  ');
      await tester.tap(find.byKey(const ValueKey('revizyon-gonder')));
      await tester.pumpAndSettle();
      await bekle(tester);

      expect(ortam.api.beyinYazimlari.single.yol, '/api/isler/k/asama');
      expect(ortam.api.beyinYazimlari.single.govde, {'asama': 'plan', 'not': 'Ay görünümünü de ekle'});
    });

    testWidgets('a revision with an empty note is not sent: the window stays open and says what to write', (tester) async {
      await goster(tester, ayrinti('k', asama: 'karar'));

      await tester.tap(find.text('Plana geri gönder'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('revizyon-gonder')));
      await tester.pump();
      expect(find.text('Revizyon için kısa bir not yaz.'), findsOneWidget);
      expect(find.text('Plana geri gönderilsin mi?'), findsOneWidget, reason: 'still open');

      await tester.enterText(find.byKey(const ValueKey('revizyon-not')), '    ');
      await tester.tap(find.byKey(const ValueKey('revizyon-gonder')));
      await tester.pump();
      expect(find.text('Plana geri gönderilsin mi?'), findsOneWidget, reason: 'spaces are no note either');
      expect(ortam.api.beyinYazimlari, isEmpty);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(ortam.api.beyinYazimlari, isEmpty);
    });

    testWidgets('the server\'s "not-gerekli" (errors keyed by the rule) is shown as its sentence, not as a generic failure', (tester) async {
      await goster(tester, ayrinti('k', asama: 'karar'));
      ortam.api.beyinYazmaKodlari = [400];
      ortam.api.beyinYazmaProblemi = {
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'not-gerekli': ['Revizyon için kısa bir not yaz.'],
        },
      };

      await tester.tap(find.text('Plana geri gönder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('revizyon-not')), 'bir not');
      await tester.tap(find.byKey(const ValueKey('revizyon-gonder')));
      await tester.pumpAndSettle();
      await bekle(tester);

      expect(find.text('Revizyon için kısa bir not yaz.'), findsOneWidget);
      expect(find.textContaining('gönderilen bilgiler geçersiz'), findsNothing);
    });

    testWidgets('at the request stage the plan is the next step, not a revision: "Plana al" needs no note', (tester) async {
      await goster(tester, ayrinti('k', asama: 'talep'));
      ortam.api.beyinYazmaGovdesi = kart('k', asama: 'plan').toJson();

      expect(find.text('Plana geri gönder'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('is-plana-al')));
      await bekle(tester);

      expect(ortam.api.beyinYazimlari.single.govde, {'asama': 'plan'});
    });

    testWidgets('"Kendi cevabım" is always under the options; its text is sent as the answer as it is', (tester) async {
      await goster(tester, ayrinti('k', sorular: [hangisi]));
      ortam.api.beyinYazmaGovdesi = kart('k').toJson();

      expect(find.text('a (önerilen)'), findsOneWidget);
      expect(find.byKey(const ValueKey('soru-kendi-1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('soru-kendi-gonder-1')));
      await bekle(tester);
      expect(find.text('Cevap boş olamaz.'), findsOneWidget);
      expect(ortam.api.beyinYazimlari, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('soru-kendi-1')), '  ikisi de değil, c olsun ');
      await tester.tap(find.byKey(const ValueKey('soru-kendi-gonder-1')));
      await bekle(tester);

      expect(ortam.api.beyinYazimlari.single.govde, {'soruNo': 1, 'cevap': 'ikisi de değil, c olsun'});
    });

    testWidgets('an answered question has no "Kendi cevabım"; a question with no options has only it', (tester) async {
      await goster(
        tester,
        ayrinti('k', sorular: [
          const IsSorusu(no: 1, soru: 'Cevaplanmış?', secenekler: ['a', 'b'], cevap: 'a'),
          const IsSorusu(no: 2, soru: 'Seçeneksiz?'),
        ]),
      );

      expect(find.byKey(const ValueKey('soru-kendi-1')), findsNothing);
      expect(find.byKey(const ValueKey('soru-kendi-2')), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('someone who may not write sees "Kendi cevabım" shut', (tester) async {
      await goster(tester, ayrinti('k', sorular: [hangisi]), yazabilir: false);

      expect(tester.widget<TextField>(find.byKey(const ValueKey('soru-kendi-1'))).enabled, isFalse);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('soru-kendi-gonder-1'))).onPressed, isNull);
    });

    testWidgets('cancelling asks for a reason: empty is refused, a reason is sent with it', (tester) async {
      await goster(tester, ayrinti('k', asama: 'yapim'));
      ortam.api.beyinYazmaGovdesi = kart('k', asama: 'iptal', acik: false).toJson();

      await tester.tap(find.text('İptal et'));
      await tester.pumpAndSettle();
      final dialogDugmesi = find.descendant(of: find.byType(AlertDialog), matching: find.text('İptal et'));
      await tester.tap(dialogDugmesi);
      await tester.pumpAndSettle();
      expect(find.text('İptal için gerekçe yaz.'), findsOneWidget);
      expect(ortam.api.beyinYazimlari, isEmpty);

      await tester.enterText(find.byType(TextField), 'Vazgeçtim');
      await tester.tap(dialogDugmesi);
      await bekle(tester);
      await tester.pumpAndSettle();

      expect(ortam.api.beyinYazimlari.single.govde, {'asama': 'iptal', 'gerekce': 'Vazgeçtim'});
    });

    testWidgets('the server\'s refusal is shown as it is, and the card is read again', (tester) async {
      await goster(tester, ayrinti('k', asama: 'karar', sorular: [hangisi]));
      ortam.api.beyinYazmaKodlari = [409];
      ortam.api.beyinYazmaProblemi = {'title': 'Soru zaten cevaplanmış', 'detail': 'Bu soruya başka bir cevap yazılmış; cevap değiştirilmez.'};
      final okumaOnce = ortam.api.cagrilar.where((c) => c == 'isGetir').length;

      await tester.tap(find.text('b'));
      await bekle(tester);

      expect(find.text('Bu soruya başka bir cevap yazılmış; cevap değiştirilmez.'), findsOneWidget);
      expect(ortam.api.cagrilar.where((c) => c == 'isGetir').length, okumaOnce + 1, reason: 'the card changed under us: read again');
    });

    testWidgets('no connection: the write is not made, the screen says so and the buttons shut', (tester) async {
      await goster(tester, ayrinti('k', asama: 'kod-onayi', sorular: [hangisi]));
      ortam.api.beyinCevrimdisi = true;

      await tester.tap(find.text('b'));
      await bekle(tester);

      expect(find.textContaining('Çevrimdışısın'), findsWidgets);
      expect(dugmeAcik(tester, 'b'), isFalse);
      expect(dugmeAcik(tester, 'Kodu onayla'), isFalse);
      expect(dugmeAcik(tester, 'Plana geri gönder'), isFalse);
    });

    testWidgets('someone who may not write sees the card with every write shut', (tester) async {
      await goster(tester, ayrinti('k', asama: 'kod-onayi', sorular: [hangisi]), yazabilir: false);

      expect(dugmeAcik(tester, 'b'), isFalse);
      expect(dugmeAcik(tester, 'Kodu onayla'), isFalse);
      expect(dugmeAcik(tester, 'İptal et'), isFalse);
    });

    testWidgets('a finished card has no stage buttons', (tester) async {
      await goster(tester, ayrinti('k', asama: 'bitti', acik: false));

      expect(find.text('Plana geri gönder'), findsNothing);
      expect(find.text('İptal et'), findsNothing);
    });

    testWidgets('a card that cannot be read says why', (tester) async {
      telefonBoyu(tester);
      ortam.api.beyinHatasi = 404;
      final vm = IsDetayViewModel(repo: ortam.isler, kimlik: 'yok');
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(MaterialApp(home: IsDetayScreen(viewModel: vm)));
      await tester.pump();

      expect(find.textContaining('Bulunamadı'), findsOneWidget);
    });
  });

  group('the new card form', () {
    test('the checks repeat the server\'s', () {
      Map<String, String> dogrula({String baslik = 'B', String talep = '', bool projeModu = true, String? proje = 'p', String alan = ''}) =>
          IsFormViewModel.dogrula(baslik: baslik, talep: talep, projeModu: projeModu, proje: proje, alan: alan);

      expect(dogrula(), isEmpty);
      expect(dogrula(baslik: '  '), {'baslik': 'Başlık gerekli.'});
      expect(dogrula(baslik: 'a' * 201).keys, ['baslik']);
      expect(dogrula(baslik: 'iki\nsatır').keys, ['baslik']);
      expect(dogrula(talep: 'a' * 4001).keys, ['talep']);
      expect(dogrula(proje: null), {'proje': 'Bir proje seç.'});
      expect(dogrula(projeModu: false, alan: ''), {'alan': 'Alan gerekli.'});
      expect(dogrula(projeModu: false, alan: 'Ogrenme').keys, ['alan']);
      expect(dogrula(projeModu: false, alan: 'ogrenme'), isEmpty);
      for (final kapali in ['finans', 'kisisel', 'projects', 'sistem']) {
        expect(dogrula(projeModu: false, alan: kapali), {'alan': 'Bu alana kart açılamaz.'}, reason: kapali);
      }
      expect(dogrula(projeModu: false, alan: ''), isNot(contains('proje')), reason: 'the project is not asked in area mode');
    });

    Future<IsFormViewModel> goster(WidgetTester tester) async {
      telefonBoyu(tester, boy: 1400);
      ortam.api.projeler = const [ProjeOzet(kimlik: 'kitap-kulubu', baslik: 'Kitap Kulübü Sitesi')];
      final vm = IsFormViewModel(repo: ortam.isler, beyin: ortam.beyin);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => IsFormScreen(viewModel: vm)),
          GoRoute(path: '/asistan/:kimlik', builder: (context, state) => Scaffold(body: Text('Kart ${state.pathParameters['kimlik']} açıldı'))),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await gercekZaman(tester);
      return vm;
    }

    testWidgets('an empty form shows what is missing and sends nothing', (tester) async {
      await goster(tester);

      await tester.tap(find.text('Kartı aç'));
      await tester.pump();

      expect(find.text('Başlık gerekli.'), findsOneWidget);
      expect(find.text('Bir proje seç.'), findsOneWidget);
      expect(ortam.api.beyinYazimlari, isEmpty);
    });

    testWidgets('area mode: a closed area and a bad name are refused before any request', (tester) async {
      await goster(tester);
      await tester.enterText(find.byKey(const Key('is-baslik')), 'Kitap listesi');
      await tester.tap(find.text('Alan'));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('is-alan')), 'finans');
      await tester.tap(find.text('Kartı aç'));
      await tester.pump();
      expect(find.text('Bu alana kart açılamaz.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('is-alan')), 'Büyük Harf');
      await tester.tap(find.text('Kartı aç'));
      await tester.pump();
      expect(find.text('Alan küçük harf, rakam ve tire olmalı.'), findsOneWidget);
      expect(ortam.api.beyinYazimlari, isEmpty);
    });

    testWidgets('a valid form opens the card (the type as chosen, one key) and shows the new card', (tester) async {
      await goster(tester);
      ortam.api.beyinYazmaGovdesi = kart('takvim', asama: 'talep').toJson();
      await tester.enterText(find.byKey(const Key('is-baslik')), 'Takvim sayfası');
      await tester.enterText(find.byKey(const Key('is-talep')), 'Ay ve liste görünümü');
      await tester.tap(find.byKey(const Key('is-proje')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kitap Kulübü Sitesi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Genel'));
      await tester.pump();

      await tester.tap(find.text('Kartı aç'));
      await tester.pumpAndSettle();

      final yazim = ortam.api.beyinYazimlari.single;
      expect(yazim.yol, '/api/isler');
      expect(yazim.govde, {'baslik': 'Takvim sayfası', 'talep': 'Ay ve liste görünümü', 'proje': 'kitap-kulubu', 'tip': 'genel'});
      expect(yazim.anahtar, isNotEmpty);
      expect(find.text('Kart takvim açıldı'), findsOneWidget);
    });

    testWidgets('the server\'s refusal stays on the form, in its own words; the same key is used on the retry', (tester) async {
      await goster(tester);
      ortam.api.beyinYazmaKodlari = [409, 200];
      ortam.api.beyinYazmaProblemi = {'title': 'İşlem uygulanamadı', 'detail': 'Beyin işlemi uygulamadı: proje ya da alan bu işe uygun değil.'};
      ortam.api.beyinYazmaGovdesi = kart('takvim', asama: 'talep').toJson();
      await tester.enterText(find.byKey(const Key('is-baslik')), 'Takvim sayfası');
      await tester.tap(find.byKey(const Key('is-proje')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kitap Kulübü Sitesi').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kartı aç'));
      await tester.pumpAndSettle();
      expect(find.text('Beyin işlemi uygulamadı: proje ya da alan bu işe uygun değil.'), findsOneWidget);
      expect(find.text('Kartı aç'), findsOneWidget, reason: 'still on the form');

      await tester.tap(find.text('Kartı aç'));
      await tester.pumpAndSettle();
      expect(ortam.api.beyinYazimlari.map((y) => y.anahtar).toSet(), hasLength(1), reason: 'a repeat after a timeout must not open two cards');
    });

    testWidgets('offline: the form says nothing was sent', (tester) async {
      await goster(tester);
      ortam.api.beyinCevrimdisi = true;
      await tester.enterText(find.byKey(const Key('is-baslik')), 'Takvim sayfası');
      await tester.tap(find.byKey(const Key('is-proje')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kitap Kulübü Sitesi').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kartı aç'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Çevrimdışısın: işlem gönderilemedi'), findsOneWidget);
    });
  });

  group('who may open the new card form', () {
    test('the form is the Sahip\'s: the route is blocked for the others, not just the button hidden', () {
      expect(yetkiYonlendirme(Rotalar.asistanYeni, girisYapildi: true, sahip: false), Rotalar.aliskanliklar);
      expect(yetkiYonlendirme(Rotalar.asistanYeni, girisYapildi: true, sahip: true), isNull);
      expect(yetkiYonlendirme(Rotalar.isler, girisYapildi: true, sahip: false), isNull, reason: 'the board is for reading');
      expect(yetkiYonlendirme('/asistan/takvim', girisYapildi: true, sahip: false), isNull);
    });
  });
}
