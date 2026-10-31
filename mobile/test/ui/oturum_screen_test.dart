import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/repositories/kronometre_repository.dart';
import 'package:kafamdakiler/ui/oturum/kronometre_view_model.dart';
import 'package:kafamdakiler/ui/oturum/oturum_screen.dart';
import 'package:kafamdakiler/ui/oturum/oturum_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  tearDown(() async => ortam.kapat());

  Future<OturumViewModel> hazirla(WidgetTester tester, {double? toplam = 160}) async {
    ortam = TestOrtami(api: SahteApi(ogeler: [ornekOge(konum: 12, toplam: toplam)]));
    final vm = OturumViewModel(
      repo: ortam.repo,
      esitleyici: ortam.esitleyici,
      kronometre: KronometreViewModel(repo: KronometreRepository(db: ortam.db), hedefId: 'o1'),
      ogeId: 'o1',
    );
    await tester.runAsync(vm.yukle);
    return vm;
  }

  Future<void> elleGirisAc(WidgetTester tester, OturumViewModel vm) async {
    await tester.pumpWidget(MaterialApp(home: OturumScreen(viewModel: vm)));
    await tester.pump();
    await tester.tap(find.text('Kronometresiz, elle gir'));
    await tester.pump();
  }

  testWidgets('"Nereye kadar geldin?" shows the start position and the total', (tester) async {
    final vm = await hazirla(tester);
    await elleGirisAc(tester, vm);

    expect(find.text('Nereye kadar geldin?'), findsOneWidget);
    expect(find.textContaining('Başlangıç: 12'), findsOneWidget);
    expect(find.textContaining('Toplam: 160'), findsOneWidget);
  });

  testWidgets('rejects empty, not above the start, and above the total', (tester) async {
    final vm = await hazirla(tester);
    await elleGirisAc(tester, vm);
    final alan = find.widgetWithText(TextFormField, 'Bitiş konumu');

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('Nereye kadar geldiğini sayı olarak yaz.'), findsOneWidget);

    await tester.enterText(alan, '12');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('12 değerinden büyük olmalı.'), findsOneWidget);

    await tester.enterText(alan, '161');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('Toplamdan (160) büyük olamaz.'), findsOneWidget);

    expect(await tester.runAsync(ortam.esitleyici.bekleyenler), isEmpty, reason: 'nothing queued while invalid');
  });

  testWidgets('without a total, no upper limit is shown or enforced', (tester) async {
    final vm = await hazirla(tester, toplam: null);
    await elleGirisAc(tester, vm);

    expect(find.textContaining('Toplam:'), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Bitiş konumu'), '9999');
    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
    await tester.pump();
    expect(find.textContaining('değerinden büyük olmalı'), findsNothing);
    expect(find.textContaining('Toplamdan'), findsNothing);
  });
}
