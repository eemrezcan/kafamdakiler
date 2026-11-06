import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/yakala_girdisi.dart';
import 'package:kafamdakiler/data/repositories/yakala_yonlendirici.dart';

void main() {
  group('paylasimdanGirdi', () {
    test('text becomes the text field', () {
      final g = paylasimdanGirdi([const PaylasimOgesi(PaylasimTuru.metin, ' bir fikir ')]);
      expect(g!.metin, 'bir fikir');
      expect(g.fotografYolu, isNull);
      expect(g.cokluGorsel, isFalse);
    });

    test('a link is kept as it is', () {
      final g = paylasimdanGirdi([const PaylasimOgesi(PaylasimTuru.metin, 'https://example.com/a?b=1')]);
      expect(g!.metin, 'https://example.com/a?b=1');
    });

    test('one image becomes the photo', () {
      final g = paylasimdanGirdi([const PaylasimOgesi(PaylasimTuru.gorsel, '/cache/a.jpg')]);
      expect(g!.fotografYolu, '/cache/a.jpg');
      expect(g.metin, isNull);
      expect(g.cokluGorsel, isFalse);
    });

    test('several images: the first is taken and the flag is set', () {
      final g = paylasimdanGirdi([
        const PaylasimOgesi(PaylasimTuru.gorsel, '/cache/a.jpg'),
        const PaylasimOgesi(PaylasimTuru.gorsel, '/cache/b.jpg'),
      ]);
      expect(g!.fotografYolu, '/cache/a.jpg');
      expect(g.cokluGorsel, isTrue);
    });

    test('text and image together fill both', () {
      final g = paylasimdanGirdi([
        const PaylasimOgesi(PaylasimTuru.metin, 'başlık'),
        const PaylasimOgesi(PaylasimTuru.gorsel, '/cache/a.jpg'),
      ]);
      expect(g!.metin, 'başlık');
      expect(g.fotografYolu, '/cache/a.jpg');
    });

    test('nothing usable gives null', () {
      expect(paylasimdanGirdi([]), isNull);
      expect(paylasimdanGirdi([const PaylasimOgesi(PaylasimTuru.diger, '/cache/v.mp4')]), isNull);
      expect(paylasimdanGirdi([const PaylasimOgesi(PaylasimTuru.metin, '  ')]), isNull);
    });
  });

  group('kisayolGirdisi', () {
    test('the Yakala shortcut opens an empty capture', () {
      final g = kisayolGirdisi(yakalaKisayoluTuru);
      expect(g, isNotNull);
      expect(g!.metin, isNull);
      expect(g.fotografYolu, isNull);
    });

    test('an unknown shortcut is ignored', () {
      expect(kisayolGirdisi('baska'), isNull);
    });
  });

  group('YakalaYonlendirici', () {
    late BekleyenYakala bekleyen;
    late ValueNotifier<int> degisim;
    late bool girisYapildi, rolBilinir, sahip, hazir, yakalaAcik;
    late List<YakalaGirdisi> acilan;
    late List<String> mesajlar;
    late YakalaYonlendirici yonlendirici;

    setUp(() {
      bekleyen = BekleyenYakala();
      degisim = ValueNotifier(0);
      girisYapildi = true;
      rolBilinir = true;
      sahip = true;
      hazir = true;
      yakalaAcik = false;
      acilan = [];
      mesajlar = [];
      yonlendirici = YakalaYonlendirici(
        bekleyen: bekleyen,
        degisim: Listenable.merge([degisim, bekleyen]),
        girisYapildi: () => girisYapildi,
        rolBilinir: () => rolBilinir,
        sahip: () => sahip,
        hazir: () => hazir,
        yakalaAcik: () => yakalaAcik,
        ac: acilan.add,
        mesaj: mesajlar.add,
      );
    });

    tearDown(() => yonlendirici.durdur());

    test('Sahip signed in: Yakala opens with the content', () {
      bekleyen.bekle(const YakalaGirdisi(metin: 'x'));
      expect(acilan.single.metin, 'x');
      expect(bekleyen.bekleyen, isNull);
      expect(mesajlar, isEmpty);
    });

    test('signed out: it waits, and is consumed after sign-in', () {
      girisYapildi = false;
      hazir = false;
      bekleyen.bekle(const YakalaGirdisi(metin: 'x'));
      expect(acilan, isEmpty);
      expect(bekleyen.bekleyen, isNotNull);

      girisYapildi = true;
      degisim.value++; // signed in, the router still on the login screen
      expect(acilan, isEmpty);

      rolBilinir = false;
      hazir = true;
      degisim.value++; // role not asked yet
      expect(acilan, isEmpty);

      rolBilinir = true;
      degisim.value++;
      expect(acilan.single.metin, 'x');
      expect(bekleyen.bekleyen, isNull);
    });

    test('Asistan: the content is dropped with a message', () {
      sahip = false;
      bekleyen.bekle(const YakalaGirdisi(metin: 'x'));
      expect(acilan, isEmpty);
      expect(bekleyen.bekleyen, isNull);
      expect(mesajlar, hasLength(1));
    });

    test('a newer share replaces the waiting one', () {
      girisYapildi = false;
      bekleyen.bekle(const YakalaGirdisi(metin: 'eski'));
      bekleyen.bekle(const YakalaGirdisi(metin: 'yeni'));
      girisYapildi = true;
      degisim.value++;
      expect(acilan.single.metin, 'yeni');
    });

    test('a plain request is ignored when Yakala is already on top, shared content is not', () {
      yakalaAcik = true;
      bekleyen.bekle(kisayolGirdisi(yakalaKisayoluTuru)!);
      expect(acilan, isEmpty);
      expect(bekleyen.bekleyen, isNull);

      bekleyen.bekle(const YakalaGirdisi(metin: 'x'));
      expect(acilan.single.metin, 'x');
    });

    test('a plain request opens Yakala when it is not on top', () {
      bekleyen.bekle(kisayolGirdisi(yakalaKisayoluTuru)!);
      expect(acilan.single.bos, isTrue);
    });

    test('nothing waiting: nothing happens', () {
      degisim.value++;
      expect(acilan, isEmpty);
      expect(mesajlar, isEmpty);
    });
  });
}
