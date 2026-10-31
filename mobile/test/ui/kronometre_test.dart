import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/repositories/kronometre_repository.dart';
import 'package:kafamdakiler/ui/oturum/kronometre_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;
  late KronometreRepository repo;
  late DateTime simdi;

  setUp(() {
    ortam = TestOrtami();
    repo = KronometreRepository(db: ortam.db);
    simdi = sabitAn;
  });
  tearDown(() async => ortam.kapat());

  KronometreViewModel olustur() => KronometreViewModel(repo: repo, hedefId: 'o1', simdi: () => simdi);

  test('not running: zero elapsed', () {
    final vm = olustur();
    expect(vm.calisiyor, isFalse);
    expect(vm.gecen, Duration.zero);
    expect(vm.dakika, 0);
  });

  test('elapsed time comes from the start instant, not from ticks', () async {
    final vm = olustur();
    await vm.baslat();

    // The app sits in the background for 25 minutes: no timer fires, but the
    // next read is still right.
    simdi = sabitAn.add(const Duration(minutes: 25, seconds: 10));

    expect(vm.gecen, const Duration(minutes: 25, seconds: 10));
    expect(vm.dakika, 25);
    expect(sureMetni(vm.gecen), '25:10');
  });

  test('a stopwatch survives the app being killed', () async {
    await olustur().baslat();
    simdi = sabitAn.add(const Duration(hours: 1, minutes: 5, seconds: 9));

    final yeniOturum = olustur();
    expect(yeniOturum.calisiyor, isFalse);
    await yeniOturum.yukle();

    expect(yeniOturum.calisiyor, isTrue);
    expect(yeniOturum.baslangic, sabitAn);
    expect(yeniOturum.gecen, const Duration(hours: 1, minutes: 5, seconds: 9));
    expect(sureMetni(yeniOturum.gecen), '01:05:09');
  });

  test('minutes are rounded, at least 1 once started', () async {
    final vm = olustur();
    await vm.baslat();
    simdi = sabitAn.add(const Duration(seconds: 5));
    expect(vm.dakika, 1);
    simdi = sabitAn.add(const Duration(minutes: 2, seconds: 40));
    expect(vm.dakika, 3);
  });

  test('a clock that went backwards never gives a negative time', () async {
    final vm = olustur();
    await vm.baslat();
    simdi = sabitAn.subtract(const Duration(minutes: 3));
    expect(vm.gecen, Duration.zero);
  });

  test('sifirla forgets the start, also in storage', () async {
    final vm = olustur();
    await vm.baslat();
    await vm.sifirla();
    expect(vm.calisiyor, isFalse);

    final yeni = olustur();
    await yeni.yukle();
    expect(yeni.calisiyor, isFalse);
  });
}
