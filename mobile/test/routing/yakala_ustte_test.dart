import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kafamdakiler/routing/router.dart';

void main() {
  testWidgets('yakalaUstte is true after push(/yakala) and false again after pop', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: Rotalar.bugun, builder: (_, _) => const Text('bugun')),
        GoRoute(path: Rotalar.yakala, builder: (_, _) => const Text('yakala')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(yakalaUstte(router), isFalse);

    router.push(Rotalar.yakala);
    await tester.pumpAndSettle();
    expect(find.text('yakala'), findsOneWidget);
    expect(yakalaUstte(router), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(yakalaUstte(router), isFalse);
  });
}
