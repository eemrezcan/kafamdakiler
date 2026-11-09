import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/repositories/bildirim_izni.dart';

import '../test_destek.dart';

// The notification permission: asked after sign-in when it is off, remembered as off when the answer is no (so Bugün can say so),
// and looked at again when the app comes back.
void main() {
  late SahteBildirimServisi servis;
  late BildirimIzni izin;
  var degisim = 0;

  setUp(() {
    servis = SahteBildirimServisi();
    izin = BildirimIzni(servis: servis);
    degisim = 0;
    izin.addListener(() => degisim++);
  });

  test('before anything is known there is no warning', () {
    expect(izin.durum, BildirimIzniDurumu.bilinmiyor);
    expect(izin.kapali, isFalse);
  });

  test('allowed already: no question is asked and there is no warning', () async {
    await izin.denetle();

    expect(servis.izinIstekleri, 0);
    expect(izin.durum, BildirimIzniDurumu.acik);
    expect(izin.kapali, isFalse);
  });

  test('off: the question is asked once, and an answer "yes" clears it', () async {
    servis.izinli = false;

    await izin.denetle();

    expect(servis.izinIstekleri, 1);
    expect(izin.durum, BildirimIzniDurumu.acik);
  });

  test('off and the answer is "no": the warning shows, and the question is not asked again in the same run', () async {
    servis
      ..izinli = false
      ..izinVerilir = false;

    await izin.denetle();
    await izin.denetle();

    expect(servis.izinIstekleri, 1);
    expect(izin.durum, BildirimIzniDurumu.kapali);
    expect(izin.kapali, isTrue);
  });

  test('turning it on in the settings clears the warning the next time the app is looked at', () async {
    servis
      ..izinli = false
      ..izinVerilir = false;
    await izin.denetle();
    expect(izin.kapali, isTrue);

    servis.izinli = true;
    await izin.denetle();

    expect(izin.kapali, isFalse);
    expect(servis.izinIstekleri, 1);
  });

  test('listeners hear a change only when the state really changes', () async {
    servis
      ..izinli = false
      ..izinVerilir = false;

    await izin.denetle();
    await izin.denetle();
    await izin.denetle();

    expect(degisim, 1);
  });

  test('after a sign-out nothing is claimed, and the next person is asked again', () async {
    servis
      ..izinli = false
      ..izinVerilir = false;
    await izin.denetle();

    izin.sifirla();
    expect(izin.durum, BildirimIzniDurumu.bilinmiyor);
    await izin.denetle();

    expect(servis.izinIstekleri, 2);
  });

  test('the settings button goes to the system settings', () async {
    await izin.ayarlariAc();

    expect(servis.ayarAcilislari, 1);
  });
}
