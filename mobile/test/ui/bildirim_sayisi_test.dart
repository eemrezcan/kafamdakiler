import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/ui/shell/bildirim_sayisi_view_model.dart';

import '../test_destek.dart';

/// The number on the bell: read from the server, kept when it cannot be read, read again when a queued write got through.
void main() {
  late TestOrtami ortam;

  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  BildirimSayisiViewModel olustur() {
    final vm = BildirimSayisiViewModel(repo: ortam.bildirimMerkezi, esitleyici: ortam.esitleyici);
    addTearDown(vm.dispose);
    return vm;
  }

  test('no badge until the first answer; then the server\'s number', () async {
    ortam.api.okunmamisBildirim = 4;
    final vm = olustur();
    expect(vm.okunmamis, 0);

    await vm.yukle();

    expect(vm.okunmamis, 4);
  });

  test('offline, or a server that does not know the call: the last number stays', () async {
    ortam.api.okunmamisBildirim = 4;
    final vm = olustur();
    await vm.yukle();

    ortam.api.cevrimdisi = true;
    ortam.api.okunmamisBildirim = 9;
    await vm.yukle();
    expect(vm.okunmamis, 4);

    ortam.api.cevrimdisi = false;
    ortam.api.sunucuHatasi = 404;
    await vm.yukle();
    expect(vm.okunmamis, 4);
  });

  test('listeners are told only when the number changes', () async {
    ortam.api.okunmamisBildirim = 2;
    final vm = olustur();
    var bildirim = 0;
    vm.addListener(() => bildirim++);

    await vm.yukle();
    await vm.yukle();
    ortam.api.okunmamisBildirim = 3;
    await vm.yukle();

    expect(bildirim, 2);
  });

  test('a send that reached the server reads the number again', () async {
    final vm = olustur();
    await vm.yukle();
    expect(vm.okunmamis, 0);
    ortam.api.okunmamisBildirim = 5;

    await ortam.esitleyici.gunYaptimKuyrugaAl(DateTime.utc(2026, 10, 31), 'm:aa11bb');
    await ortam.esitleyici.gonder();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.okunmamis, 5);
  });

  test('the count and the badge text: 99+ for a big number is the screen\'s job, the model keeps the real one', () async {
    ortam.api.okunmamisBildirim = 120;
    final vm = olustur();
    await vm.yukle();
    expect(vm.okunmamis, 120);
  });
}
