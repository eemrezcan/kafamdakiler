import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/ui/bugun/bugun_screen.dart';
import 'package:kafamdakiler/ui/bugun/bugun_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  tearDown(() async => ortam.kapat());

  /// The view model is loaded outside the fake-async zone (drift needs real
  /// time); the widget then just renders its state.
  Future<BugunViewModel> yukle(WidgetTester tester, SahteApi api) async {
    ortam = TestOrtami(api: api);
    final vm = BugunViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
    await tester.runAsync(vm.yukle);
    return vm;
  }

  Future<void> goster(WidgetTester tester, BugunViewModel vm, {Size boyut = const Size(360, 800)}) async {
    tester.view.physicalSize = boyut;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: BugunScreen(viewModel: vm)));
    await tester.pump();
  }

  testWidgets('planned habits first, the others under a faded "Bugün planlı değil" heading', (tester) async {
    final vm = await yukle(
      tester,
      SahteApi(aliskanliklar: [
        ornekAliskanlik(id: 'a', ad: 'Planlı su', miktar: 2),
        ornekAliskanlik(id: 'b', ad: 'Pazartesi koşusu', planli: false, sira: 1),
        ornekAliskanlik(id: 'c', ad: 'Planlı yoga', olcu: Olcu.evetHayir, sira: 2),
      ]),
    );
    await goster(tester, vm);

    expect(find.text('Planlı su'), findsOneWidget);
    expect(find.text('Planlı yoga'), findsOneWidget);
    expect(find.text('Pazartesi koşusu'), findsOneWidget);
    expect(find.text('Bugün planlı değil'), findsOneWidget);

    final baslikY = tester.getTopLeft(find.text('Bugün planlı değil')).dy;
    expect(tester.getTopLeft(find.text('Planlı su')).dy, lessThan(baslikY));
    expect(tester.getTopLeft(find.text('Planlı yoga')).dy, lessThan(baslikY));
    expect(tester.getTopLeft(find.text('Pazartesi koşusu')).dy, greaterThan(baslikY));

    // The unplanned card is faded.
    final soluk = find.ancestor(of: find.text('Pazartesi koşusu'), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(soluk.first).opacity, lessThan(1));
    expect(find.ancestor(of: find.text('Planlı su'), matching: find.byType(Opacity)), findsNothing);
  });

  testWidgets('no "not planned" heading when every habit is planned', (tester) async {
    final vm = await yukle(tester, SahteApi(aliskanliklar: [ornekAliskanlik(ad: 'Su')]));
    await goster(tester, vm);
    expect(find.text('Bugün planlı değil'), findsNothing);
  });

  testWidgets('empty state guides the user', (tester) async {
    final vm = await yukle(tester, SahteApi());
    await goster(tester, vm);
    expect(find.textContaining('Henüz alışkanlık yok'), findsOneWidget);
  });

  testWidgets('a server error on the first load shows a Turkish message and a retry button', (tester) async {
    final vm = await yukle(tester, SahteApi()..sunucuHatasi = 500);
    await goster(tester, vm);
    expect(find.textContaining('Alışkanlıklar alınamadı (sunucu hatası 500)'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('offline with a cache: shows the cached habits and says so', (tester) async {
    final api = SahteApi(aliskanliklar: [ornekAliskanlik(ad: 'Su')]);
    final ilk = await yukle(tester, api); // online: fills the cache
    expect(ilk.liste, hasLength(1));
    api.cevrimdisi = true;
    final vm = BugunViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
    await tester.runAsync(vm.yukle);
    await goster(tester, vm);
    expect(find.text('Su'), findsOneWidget);
    expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
  });

  testWidgets('shows progress, strength and the yes/no tick; no overflow at 360 dp', (tester) async {
    final vm = await yukle(
      tester,
      SahteApi(aliskanliklar: [
        ornekAliskanlik(id: 'a', ad: 'Çok uzun bir alışkanlık adı taşmamalı ekranda', miktar: 6),
        ornekAliskanlik(id: 'b', ad: 'Yoga', olcu: Olcu.evetHayir, sira: 1),
      ]),
    );
    await goster(tester, vm);

    expect(find.textContaining('güç %50'), findsWidgets);
    expect(find.byTooltip('Bir artır'), findsOneWidget);
    expect(find.byTooltip('Yapıldı olarak işaretle'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide screens: content is centred with a maximum width', (tester) async {
    final vm = await yukle(tester, SahteApi(aliskanliklar: [ornekAliskanlik(ad: 'Su')]));
    await goster(tester, vm, boyut: const Size(1200, 800));

    final kart = tester.getRect(find.byType(Card).first);
    expect(kart.width, lessThanOrEqualTo(640));
    expect(kart.center.dx, closeTo(600, 1));
  });
}
