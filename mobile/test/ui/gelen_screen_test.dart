import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/gelen.dart';
import 'package:kafamdakiler/data/repositories/kullanici_repository.dart';
import 'package:kafamdakiler/ui/gelen/gelen_liste_screen.dart';
import 'package:kafamdakiler/ui/gelen/gelen_liste_view_model.dart';
import 'package:provider/provider.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async {
    // A decision starts a send in the background; let it end before the database is closed.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await ortam.kapat();
  });

  // Drift needs real time; the fake-async zone of a widget test would never finish its queries.
  Future<void> gercekZaman(WidgetTester tester, [int ms = 120]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
    await tester.pump();
  }

  // After the first load the fake server is switched off by default, so a decision stays in the phone's queue where the
  // test can read it (online, the background send would empty it at once).
  Future<GelenListeViewModel> goster(WidgetTester tester, {String rol = 'Sahip', bool cevrimdisiOl = true}) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kullanici = KullaniciRepository(api: ortam.api, db: ortam.db);
    ortam.api.ben_ = Ben(id: 'u', email: 'x@y.z', roller: [rol]);
    await tester.runAsync(kullanici.yukle);
    final vm = GelenListeViewModel(repo: ortam.gelen, eylemler: ortam.eylemler, esitleyici: ortam.esitleyici, beyin: ortam.beyin);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.yukle);
    if (cevrimdisiOl) ortam.api.cevrimdisi = true;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: kullanici,
        child: MaterialApp(home: GelenListeScreen(viewModel: vm)),
      ),
    );
    await tester.pump();
    return vm;
  }

  setUp(() {
    ortam.api.gelenKartlari = [
      ornekGelenKarti(kimlik: 'b', ozet: 'Önerisiz kart'),
      ornekGelenKarti(kimlik: 'a', ozet: 'Önerili kart', eylemId: 'e-a'),
      ornekGelenKarti(kimlik: 'x', ozet: 'Şüpheli kart', eylemId: 'e-x', disKaynak: true, guven: 0.4),
      ornekGelenKarti(kimlik: 'l', ozet: 'Laptop kartı', laptoptaIslenecek: true, gorselVar: true),
    ];
    ortam.api.eylemler = [ornekEylem(id: 'e-a'), ornekEylem(id: 'e-x')];
  });

  testWidgets('shows the suggestion under its card with the warnings, the cards with a suggestion first', (tester) async {
    await goster(tester);

    expect(find.text('KARTLAR  4'), findsOneWidget);
    expect(find.text('Önerili kart'), findsOneWidget);
    expect(find.text('projects/kitap-kulubu/notlar/simyaci.md'), findsNWidgets(2));
    expect(find.text('Simyacı önerisi'), findsNWidgets(2));
    expect(find.text('#kaynak #okul'), findsNWidgets(2));
    expect(find.text('Kitap önerisi.'), findsNWidgets(2));
    expect(find.text('Güven %90'), findsOneWidget);
    expect(find.text('Emin değil · %40'), findsOneWidget);
    expect(find.text('Dış kaynak'), findsOneWidget);
    expect(find.text('Laptopta işlenecek'), findsOneWidget);
    expect(find.textContaining('mimari-karar'), findsOneWidget);
    expect(find.text('Görselli'), findsOneWidget);
    final onerili = tester.getTopLeft(find.text('Önerili kart')).dy;
    final onerisiz = tester.getTopLeft(find.text('Önerisiz kart')).dy;
    expect(onerili, lessThan(onerisiz), reason: 'the ones with a suggestion first');
  });

  testWidgets('an empty inbox says so', (tester) async {
    ortam.api.gelenKartlari = [];

    await goster(tester);

    expect(find.text('Gelen kutusu boş.'), findsOneWidget);
  });

  testWidgets('swipe right approves the suggestion: it is queued for the approval queue and the card leaves at once', (tester) async {
    await goster(tester);

    await tester.drag(find.text('Önerili kart'), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await gercekZaman(tester);

    expect(find.text('Önerili kart'), findsNothing);
    final bekleyen = await tester.runAsync(ortam.esitleyici.bekleyenler) ?? [];
    expect(bekleyen.map((b) => b.hedefId), contains('e-a'));
  });

  testWidgets('swipe left puts the card aside without deciding anything', (tester) async {
    await goster(tester);

    await tester.drag(find.text('Önerili kart'), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await gercekZaman(tester);

    expect(find.text('Önerili kart'), findsOneWidget);
    expect(find.text('Sonra'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Önerili kart')).dy, greaterThan(tester.getTopLeft(find.text('Önerisiz kart')).dy),
        reason: 'it moved below the cards that still wait for a look');
    expect(await tester.runAsync(ortam.esitleyici.bekleyenler), isEmpty);
  });

  testWidgets('the Asistan only reads: no swipe, no buttons in the preview', (tester) async {
    await goster(tester, rol: 'Asistan');

    expect(find.byType(Dismissible), findsNothing);
    await tester.tap(find.text('Önerili kart'));
    await tester.pumpAndSettle();

    expect(find.text('Uygula'), findsNothing);
    expect(find.text('Elle yerleştir'), findsNothing);
    expect(find.text('Sil'), findsNothing);
    expect(find.text('Yakalandı: 2026-11-03 18:40'), findsOneWidget);
  });

  testWidgets('the preview of a card with a suggestion: Uygula and Reddet queue the decision', (tester) async {
    await goster(tester);

    await tester.tap(find.text('Şüpheli kart'));
    await tester.pumpAndSettle();
    expect(find.text('Düzelt'), findsOneWidget);
    expect(find.text('Yeniden öner'), findsNothing, reason: 'there is a suggestion already');
    await tester.tap(find.text('Reddet'));
    await tester.pumpAndSettle();
    await gercekZaman(tester);

    expect(find.text('Şüpheli kart'), findsOneWidget, reason: 'the card stays, without its suggestion');
    expect(find.text('Emin değil · %40'), findsNothing);
    final bekleyen = await tester.runAsync(ortam.esitleyici.bekleyenler) ?? [];
    expect(bekleyen.map((b) => b.hedefId), ['e-x']);
  });

  testWidgets('placing by hand: folder, file name, title and tags are queued as one placement', (tester) async {
    await goster(tester);

    await tester.tap(find.text('Önerisiz kart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elle yerleştir'));
    await tester.pumpAndSettle();
    // Nothing typed yet: refused on the spot.
    await tester.tap(find.text('Yerleştir'));
    await tester.pump();
    expect(find.text('Başlık ve en az bir etiket gerekli.'), findsOneWidget);

    // The file name is not asked up front; "Gelişmiş" holds it for the rare case it is typed.
    expect(find.widgetWithText(TextField, 'Dosya adı'), findsNothing);
    await tester.ensureVisible(find.text('Gelişmiş'));
    await tester.tap(find.text('Gelişmiş'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Dosya adı'), 'simyaci');
    await tester.enterText(find.widgetWithText(TextField, 'Etiketler'), 'kaynak, #okul');
    await tester.tap(find.text('Yerleştir'));
    await tester.pumpAndSettle();
    await gercekZaman(tester);

    expect(find.text('Önerisiz kart'), findsNothing, reason: 'gone at once');
    final bekleyen = await tester.runAsync(ortam.esitleyici.bekleyenler) ?? [];
    expect(bekleyen, hasLength(1));
    expect(bekleyen.single.hedefId, 'b');
    expect(bekleyen.single.govde, contains('"yol":"ogrenme/simyaci.md"'));
    expect(bekleyen.single.govde, contains('"baslik":"Önerisiz kart"'));
    expect(bekleyen.single.govde, contains('"etiketler":["kaynak","okul"]'));
  });

  Future<void> elleYerlestirAc(WidgetTester tester) async {
    await tester.tap(find.text('Önerisiz kart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elle yerleştir'));
    await tester.pumpAndSettle();
  }

  testWidgets('placing by hand with the server lists: the folder and the tags are picked, not typed', (tester) async {
    ortam.api.gelenEtiketleri_ = const [GelenEtiket(ad: 'kaynak', esler: ['source']), GelenEtiket(ad: 'okul'), GelenEtiket(ad: 'fikir')];
    ortam.api.gelenKlasorleri_ = const [
      GelenKlasoru(yol: 'projects/kitap/notlar/', ad: 'Kitap Kulübü', tur: 'proje', proje: 'kitap'),
      GelenKlasoru(yol: 'ogrenme/', ad: 'ogrenme', tur: 'kok'),
    ];
    await goster(tester, cevrimdisiOl: false);
    await elleYerlestirAc(tester);

    expect(find.widgetWithText(TextField, 'Etiketler'), findsNothing, reason: 'tags are chips now');
    expect(find.widgetWithText(FilterChip, 'kaynak'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'okul'), findsOneWidget);
    expect(find.text('Kitap Kulübü (notlar)'), findsOneWidget, reason: 'the first folder is preselected');

    // No tag picked: refused on the spot.
    await tester.tap(find.text('Yerleştir'));
    await tester.pump();
    expect(find.text('Başlık ve en az bir etiket gerekli.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'kaynak'));
    await tester.tap(find.widgetWithText(FilterChip, 'okul'));
    // Picked and picked again: unselected.
    await tester.tap(find.widgetWithText(FilterChip, 'fikir'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'fikir'));
    await tester.pump();
    await tester.tap(find.text('Kitap Kulübü (notlar)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ogrenme').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yerleştir'));
    await tester.pumpAndSettle();
    await gercekZaman(tester);

    expect(ortam.api.cagrilar, contains('gelenEtiketleri'));
    expect(ortam.api.cagrilar, contains('gelenKlasorleri'));
    expect(ortam.api.cagrilar, contains('gelenIsle:b:ogrenme/onerisiz-kart.md:Önerisiz kart:kaynak,okul'),
        reason: 'the file name is made from the title');
  });

  testWidgets('placing by hand: the card\'s target project is the folder that comes selected', (tester) async {
    ortam.api.gelenKartlari = [ornekGelenKarti(kimlik: 'h', ozet: 'Takvim fikri', hedef: 'projects/balkon')];
    ortam.api.gelenEtiketleri_ = const [GelenEtiket(ad: 'fikir')];
    ortam.api.gelenKlasorleri_ = const [
      GelenKlasoru(yol: 'projects/kitap/notlar/', ad: 'Kitap Kulübü', tur: 'proje', proje: 'kitap'),
      GelenKlasoru(yol: 'projects/balkon/notlar/', ad: 'Balkon Bahçesi', tur: 'proje', proje: 'balkon'),
    ];
    await goster(tester, cevrimdisiOl: false);
    await tester.tap(find.text('Takvim fikri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elle yerleştir'));
    await tester.pumpAndSettle();

    expect(find.text('Balkon Bahçesi (notlar)'), findsOneWidget, reason: 'not the first folder of the list');
    expect(find.text('Kitap Kulübü (notlar)'), findsNothing);
  });

  testWidgets('"Yeniden öner" is hidden while the assistant is not connected', (tester) async {
    ortam.api.asistanBagli = false;
    await goster(tester);
    await tester.tap(find.text('Önerisiz kart'));
    await tester.pumpAndSettle();

    expect(find.text('Elle yerleştir'), findsOneWidget);
    expect(find.text('Yeniden öner'), findsNothing);
  });

  testWidgets('"Yeniden öner" shows while the assistant is connected', (tester) async {
    await goster(tester);
    await tester.tap(find.text('Önerisiz kart'));
    await tester.pumpAndSettle();

    expect(find.text('Yeniden öner'), findsOneWidget);
  });

  testWidgets('when the server lists cannot be read, the typed tag field and the cached projects stand in', (tester) async {
    ortam.api.gelenSecenekHatasi = 403;
    await goster(tester, cevrimdisiOl: false);
    await elleYerlestirAc(tester);

    expect(find.widgetWithText(TextField, 'Etiketler'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.text('ogrenme/'), findsOneWidget, reason: 'the fixed folder list');
  });

  testWidgets('deleting asks first, then queues the deletion', (tester) async {
    await goster(tester);

    await tester.tap(find.text('Önerisiz kart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(find.text('Kart silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Önerisiz kart'), findsOneWidget);
    expect(await tester.runAsync(ortam.esitleyici.bekleyenler), isEmpty);

    await tester.tap(find.text('Önerisiz kart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    await gercekZaman(tester);

    expect(find.text('Önerisiz kart'), findsNothing);
    final bekleyen = await tester.runAsync(ortam.esitleyici.bekleyenler) ?? [];
    expect(bekleyen.single.hedefId, 'b');
  });

  testWidgets('"Yeniden öner" asks the server and says what came of it', (tester) async {
    await goster(tester, cevrimdisiOl: false);

    await tester.tap(find.text('Önerisiz kart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden öner'));
    await tester.pump();
    await gercekZaman(tester);

    expect(ortam.api.cagrilar, contains('gelenOner:b'));
    expect(find.text('Öneri hazır.'), findsOneWidget);
  });

  testWidgets('"Yeniden öner" past the daily cap and offline tells the reason', (tester) async {
    final vm = await goster(tester, cevrimdisiOl: false);

    ortam.api.gelenOneriHatasi = 429;
    expect(await tester.runAsync(() => vm.oneriIste('b')), contains('bugünlük sınır'));
    ortam.api.gelenOneriHatasi = 422;
    expect(await tester.runAsync(() => vm.oneriIste('b')), 'Kart elle yerleştirilir.');
    ortam.api.gelenOneriHatasi = 503;
    expect(await tester.runAsync(() => vm.oneriIste('b')), contains('bağlı değil'));
    ortam.api.gelenOneriHatasi = null;
    ortam.api.cevrimdisi = true;
    expect(await tester.runAsync(() => vm.oneriIste('b')), contains('Çevrimdışısın'));
  });

  testWidgets('offline, the cached cards show with a note that decisions wait on the phone', (tester) async {
    final vm = await goster(tester);
    await tester.runAsync(vm.yukle);
    await tester.pump();

    expect(vm.cevrimdisi, isTrue);
    expect(find.text('Önerili kart'), findsOneWidget);
    expect(find.textContaining('Çevrimdışısın; kararların telefona yazılıyor'), findsOneWidget);
  });

  testWidgets('a refusal of the list (no permission) is shown with a retry, not as an empty inbox', (tester) async {
    ortam.api.sunucuHatasi = 403;

    await goster(tester, cevrimdisiOl: false);

    expect(find.text('Bu işlem için yetkin yok.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
}
