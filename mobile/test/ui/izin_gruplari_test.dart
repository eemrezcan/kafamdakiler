import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/ui/yonetim/izin_gruplari.dart';

void main() {
  // The permissions of backend/Yonetim/Izinler.cs. If a permission is added there, it must land in a group or be the
  // Claude switch, and this list (and the web's IzinGruplari) must follow.
  const sunucuIzinleri = {
    'aliskanlik.oku', 'aliskanlik.yaz', 'yakalama.oku', 'yakalama.yaz', 'hatirlatici.oku', 'hatirlatici.yaz',
    'beyin.oku', 'plan.yaz', 'gorev.yaz', 'eylem.oku', 'eylem.onayla', 'gelen.oku', 'gelen.yaz',
    'asistan.kullan', 'brifing.oku', 'takvim.oku', 'takvim.yaz', //
  };

  test('every permission is in exactly one group or is the Claude switch', () {
    final hepsi = [...izinGruplari.expand((g) => g.tumu), asistanKullanIzni];

    expect(hepsi.toSet(), sunucuIzinleri);
    expect(hepsi, hasLength(sunucuIzinleri.length), reason: 'no permission in two places');
  });

  test('levels follow the open permissions', () {
    const grup = IzinGrubu(id: 'x', ad: 'X', aciklama: '', okur: ['a.oku', 'b.oku'], yazar: ['a.yaz']);

    expect(grup.seviye({}), IzinSeviyesi.kapali);
    expect(grup.seviye({'a.oku', 'b.oku'}), IzinSeviyesi.okur);
    expect(grup.seviye({'a.oku', 'b.oku', 'a.yaz'}), IzinSeviyesi.okurYazar);
    expect(grup.seviye({'a.oku'}), IzinSeviyesi.ozel);
    expect(grup.seviye({'a.yaz'}), IzinSeviyesi.ozel, reason: 'writing without reading');
    expect(grup.seviye({'a.oku', 'b.oku', 'baska'}), IzinSeviyesi.okur, reason: 'other permissions do not count');
  });

  test('the target of a level, read back, gives the same level', () {
    for (final grup in izinGruplari) {
      for (final seviye in [IzinSeviyesi.kapali, IzinSeviyesi.okur, IzinSeviyesi.okurYazar]) {
        final acik = {for (final e in grup.hedef(seviye).entries) if (e.value) e.key};
        expect(grup.seviye(acik), seviye, reason: '${grup.id} $seviye');
      }
    }
  });
}
