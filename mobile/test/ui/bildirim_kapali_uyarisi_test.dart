import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/repositories/bildirim_izni.dart';
import 'package:kafamdakiler/ui/bugun/bildirim_kapali_uyarisi.dart';

import '../test_destek.dart';

// The "Bildirimler kapalı" warning: only while the permission is known to be off, with a button to the system settings.
void main() {
  late SahteBildirimServisi servis;
  late BildirimIzni izin;

  setUp(() {
    servis = SahteBildirimServisi()
      ..izinli = false
      ..izinVerilir = false;
    izin = BildirimIzni(servis: servis);
  });

  Future<void> goster(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BildirimKapaliUyarisi(izin: izin))));
  }

  testWidgets('not shown while the permission is not known yet', (tester) async {
    await goster(tester);

    expect(find.text('Bildirimler kapalı'), findsNothing);
  });

  testWidgets('shown once the permission is known to be off, with a button to the settings', (tester) async {
    await goster(tester);

    await tester.runAsync(izin.denetle);
    await tester.pump();

    expect(find.text('Bildirimler kapalı'), findsOneWidget);
    await tester.tap(find.text('Ayarlara git'));
    expect(servis.ayarAcilislari, 1);
  });

  testWidgets('goes away when the permission is turned on', (tester) async {
    await goster(tester);
    await tester.runAsync(izin.denetle);
    await tester.pump();
    expect(find.text('Bildirimler kapalı'), findsOneWidget);

    servis.izinli = true;
    await tester.runAsync(izin.denetle);
    await tester.pump();

    expect(find.text('Bildirimler kapalı'), findsNothing);
  });
}
