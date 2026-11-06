import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/yakala_girdisi.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_screen.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  Future<void> goster(WidgetTester tester, YakalaGirdisi? girdi) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = YakalaViewModel(repo: ortam.yakalamalar, esitleyici: ortam.esitleyici);
    await tester.pumpWidget(MaterialApp(home: YakalaScreen(viewModel: vm, baslangic: girdi)));
    await tester.pump();
  }

  String metin(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('shared text fills the text field', (tester) async {
    await goster(tester, const YakalaGirdisi(metin: 'https://example.com'));
    expect(metin(tester), 'https://example.com');
    expect(find.textContaining('Birden çok görsel'), findsNothing);
  });

  testWidgets('several shared images show the note', (tester) async {
    await goster(tester, const YakalaGirdisi(cokluGorsel: true));
    expect(find.textContaining('Birden çok görsel paylaşıldı'), findsOneWidget);
  });

  testWidgets('a shared image counts as content, so Save is possible with an empty text', (tester) async {
    await goster(tester, YakalaGirdisi(fotografYolu: '${Directory.systemTemp.path}/yok.jpg'));
    expect(metin(tester), '');
    expect(find.byTooltip('Fotoğrafı kaldır'), findsOneWidget);
  });

  testWidgets('without a starting state the form is empty', (tester) async {
    await goster(tester, null);
    expect(metin(tester), '');
  });
}
