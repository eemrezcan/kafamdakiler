import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_form_screen.dart';
import 'package:kafamdakiler/ui/aliskanliklar/aliskanlik_form_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  testWidgets('Kaydet ends above the system navigation bar, not under it', (tester) async {
    const ekranYuksekligi = 800.0;
    const sistemCubugu = 48.0;
    tester.view.physicalSize = const Size(375, ekranYuksekligi);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = AliskanlikFormViewModel(repo: ortam.repo);
    addTearDown(vm.dispose);
    // The padding an edge-to-edge Android window reports for its navigation bar.
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(bottom: sistemCubugu),
            viewPadding: const EdgeInsets.only(bottom: sistemCubugu),
          ),
          child: child!,
        ),
        home: AliskanlikFormScreen(viewModel: vm),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Kaydet'), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pump();

    expect(tester.getBottomLeft(find.widgetWithText(FilledButton, 'Kaydet')).dy, lessThanOrEqualTo(ekranYuksekligi - sistemCubugu));
  });
}
