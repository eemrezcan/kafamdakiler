import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/is_karti.dart';
import 'package:kafamdakiler/data/models/sunucu_bildirimi.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/repositories/is_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/repositories/push_mesaj_isleyici.dart';
import 'package:kafamdakiler/data/services/bildirim_servisi.dart';
import 'package:kafamdakiler/data/services/sunucu_bildirim_gosterici.dart';
import 'package:kafamdakiler/utils/is_bildirimi.dart';
import 'package:kafamdakiler/utils/is_gorunum.dart';

import '../test_destek.dart';

// The work cards on the phone: the shapes the server sends, the groups of the board, the offline board, the writes (path, body,
// key), and the buttons of a card's notification, in particular that a push or a deploy cannot be approved from the tray.

IsKarti kart(
  String kimlik, {
  String asama = 'plan',
  String sahip = 'vps',
  bool acik = true,
  int bekleyen = 0,
  String? proje = 'kitap-kulubu',
  String? alan,
  List<String> gecisler = const ['plan', 'iptal'],
}) =>
    IsKarti(
      kimlik: kimlik,
      baslik: 'Kart $kimlik',
      tip: 'kod',
      asama: asama,
      sahip: sahip,
      proje: proje,
      alan: alan,
      bekleyenSoru: bekleyen,
      gecisler: gecisler,
      acik: acik,
    );

Map<String, dynamic> kartJson(String kimlik, {String asama = 'karar', String sahip = 'kullanici'}) => kart(kimlik, asama: asama, sahip: sahip).toJson();

class IsGosterici implements SunucuBildirimGosterici {
  final kartlar = <({int id, String baslik, String govde, String yuk, List<IsBildirimDugmesi> dugmeler})>[];
  final duzler = <String>[];

  @override
  Future<void> goster({required int id, required String baslik, required String govde, required String yuk}) async => duzler.add(baslik);

  @override
  Future<void> hatirlaticiGoster({required int id, required String baslik, required String govde, required String hatirlaticiId}) async {}

  @override
  Future<void> isKartiGoster({
    required int id,
    required String baslik,
    required String govde,
    required String yuk,
    required List<IsBildirimDugmesi> dugmeler,
  }) async =>
      kartlar.add((id: id, baslik: baslik, govde: govde, yuk: yuk, dugmeler: dugmeler));
}

void main() {
  group('models parse what /api/isler answers', () {
    test('a card, with null fields and a missing list', () {
      final k = IsKarti.fromJson({
        'kimlik': 'takvim-sayfasi',
        'baslik': 'Takvim sayfası',
        'tip': 'kod',
        'asama': 'karar',
        'sahip': 'kullanici',
        'kilit': null,
        'proje': 'kitap-kulubu',
        'alan': null,
        'kaynak': 'telefon',
        'olusma': '2026-11-09T08:00',
        'guncelleme': '2026-11-10T09:00',
        'bekleyenSoru': 2,
        'gecisler': ['plan', 'iptal'],
        'acik': true,
      });

      expect((k.kimlik, k.asama, k.sahip, k.yer, k.bekleyenSoru, k.acik), ('takvim-sayfasi', 'karar', 'kullanici', 'kitap-kulubu', 2, true));
      expect(k.gecisler, ['plan', 'iptal']);
      expect(IsKarti.fromJson({'kimlik': 'x', 'baslik': 'X', 'asama': 'talep', 'sahip': 'vps'}).gecisler, isEmpty);
    });

    test('a detail: request, plan, questions with an answer or none, history', () {
      final a = IsAyrinti.fromJson({
        ...kartJson('k'),
        'talep': 'Satır bir\nSatır iki',
        'plan': '## Plan\n- adım',
        'sorular': [
          {'no': 1, 'soru': 'Hangi?', 'secenekler': ['a', 'b'], 'onerilen': 'a', 'neden': 'Daha hafif', 'cevap': null},
          {'no': 2, 'soru': 'Ne zaman?', 'secenekler': [], 'onerilen': null, 'neden': null, 'cevap': 'Bu hafta'},
        ],
        'gecmis': [
          {'zaman': '2026-11-10 09:00', 'olay': 'plan yazıldı', 'kim': 'vps'},
        ],
      });

      expect(a.kart.kimlik, 'k');
      expect(a.sorular.map((s) => s.cevaplandi), [false, true]);
      expect(a.sorular.first.secenekler, ['a', 'b']);
      expect((a.sorular.first.onerilen, a.sorular.first.neden), ('a', 'Daha hafif'));
      expect(a.gecmis.single.olay, 'plan yazıldı');
    });

    test('a notification with buttons, and one without', () {
      final b = SunucuBildirimi.fromJson({
        'id': 'n1',
        'baslik': 'Kart',
        'metin': 'Karar bekliyor',
        'rota': '/asistan/{id}',
        'hedefKimligi': 'k',
        'kaynakTuru': 'is',
        'secenekler': [
          {'etiket': 'a', 'eylem': 'cevap', 'soruNo': 1, 'cevap': 'a', 'asama': null},
          {'etiket': 'Onayla', 'eylem': 'asama', 'soruNo': null, 'cevap': null, 'asama': 'yapim'},
        ],
      });
      expect(b.isKartiMi, isTrue);
      expect(b.secenekler.map((s) => (s.eylem, s.soruNo, s.cevap, s.asama)), [('cevap', 1, 'a', null), ('asama', null, null, 'yapim')]);

      final duz = SunucuBildirimi.fromJson({'id': 'n2', 'baslik': 'B', 'metin': 'M', 'kaynakTuru': 'gorev'});
      expect(duz.isKartiMi, isFalse);
      expect(duz.secenekler, isEmpty);
    });

    test('a new card is sent without the empty parts', () {
      expect(const IsAcGirdi(baslik: 'B', proje: 'p').toJson(), {'baslik': 'B', 'proje': 'p', 'tip': 'kod'});
      expect(const IsAcGirdi(baslik: 'B', talep: 'T', alan: 'ogrenme', tip: 'genel').toJson(), {'baslik': 'B', 'talep': 'T', 'alan': 'ogrenme', 'tip': 'genel'});
    });
  });

  group('the board', () {
    final kartlar = [
      kart('karar-bir', asama: 'karar', sahip: 'kullanici', bekleyen: 1),
      kart('kod', asama: 'kod-onayi', sahip: 'kullanici'),
      kart('push', asama: 'push-onayi', sahip: 'vps'),
      kart('vps-plan', asama: 'plan', sahip: 'vps'),
      kart('vps-yapim', asama: 'yapim', sahip: 'vps'),
      kart('kullanici-yapim', asama: 'yapim', sahip: 'kullanici'),
      kart('laptop', asama: 'plan', sahip: 'laptop'),
      kart('bitti', asama: 'bitti', sahip: 'vps', acik: false),
      kart('iptal', asama: 'iptal', sahip: 'vps', acik: false),
    ];

    test('every open card is in exactly one group; a gate is a gate whoever holds it; a cancelled card is not on the board', () {
      final p = IsPanosu.grupla(kartlar);

      expect(p.sende.map((k) => k.kimlik), ['karar-bir']);
      expect(p.kapilar.map((k) => k.kimlik), ['kod', 'push']);
      expect(p.vps.map((k) => k.kimlik), ['vps-plan']);
      expect(p.yapim.map((k) => k.kimlik), ['vps-yapim', 'kullanici-yapim']);
      expect(p.laptop.map((k) => k.kimlik), ['laptop']);
      expect(p.biten.map((k) => k.kimlik), ['bitti']);
      expect([p.sende, p.kapilar, p.vps, p.yapim, p.laptop, p.biten].expand((g) => g).length, kartlar.length - 1);
    });

    test('the numbers of the Bugün card: what waits on the person (gates included), what the VPS has (its builds included)', () {
      final p = IsPanosu.grupla(kartlar);

      expect(p.sendeBekleyen.map((k) => k.kimlik), ['kod', 'push', 'karar-bir'], reason: 'gates first');
      expect(p.vpstekiSayi, 2);
      expect(IsPanosu.grupla(const []).bos, isTrue);
    });

    test('stage words and where a gate leads', () {
      expect(asamaEtiketi('kod-onayi'), 'Kod onayı');
      expect(sahipEtiketi('vps'), "VPS'te");
      expect([kapidanSonraki('kod-onayi'), kapidanSonraki('push-onayi'), kapidanSonraki('deploy-onayi'), kapidanSonraki('plan')], ['yapim', 'deploy-onayi', 'bitti', null]);
    });
  });

  group('the buttons of a notification', () {
    test('an answer and a stage survive the Android action id, even with | and non-ASCII in the answer', () {
      const cevap = IsBildirimEylemi.cevap(kimlik: 'kart-bir', soruNo: 2, cevap: 'a|b ç ğ/ö');
      const asama = IsBildirimEylemi.asama(kimlik: 'kart-bir', asama: 'yapim');

      final c = IsBildirimEylemi.coz(cevap.kod)!;
      final a = IsBildirimEylemi.coz(asama.kod)!;

      expect((c.kimlik, c.soruNo, c.cevap, c.asama), ('kart-bir', 2, 'a|b ç ğ/ö', null));
      expect((a.kimlik, a.asama, a.soruNo), ('kart-bir', 'yapim', null));
    });

    test('an id that is not a card button is not read as one', () {
      for (final kod in [null, '', 'yaptim', 'eylemOnayla', 'is|x|a|b', 'is|c|k|bir|cevap', 'is|a|k']) {
        expect(IsBildirimEylemi.coz(kod), isNull, reason: '$kod');
      }
    });

    test('only an answer, the code gate and back to the plan may come from a notification', () {
      expect(const IsBildirimEylemi.cevap(kimlik: 'k', soruNo: 1, cevap: 'a').guvenli, isTrue);
      expect(const IsBildirimEylemi.asama(kimlik: 'k', asama: 'yapim').guvenli, isTrue);
      expect(const IsBildirimEylemi.asama(kimlik: 'k', asama: 'plan').guvenli, isTrue);
      for (final yasak in ['deploy-onayi', 'bitti', 'iptal', 'push-onayi', 'karar']) {
        expect(IsBildirimEylemi.asama(kimlik: 'k', asama: yasak).guvenli, isFalse, reason: yasak);
      }
      const sahteOnay = BildirimSecenegi(etiket: 'Onayla', eylem: 'asama', asama: 'deploy-onayi');
      expect(IsBildirimEylemi.secenekten('k', sahteOnay), isNull, reason: 'a forged option is dropped');
    });

    test('a pressed button reaches the phone as a response with the request in it', () {
      const eylem = IsBildirimEylemi.asama(kimlik: 'kart-bir', asama: 'yapim');

      final y = YerelBildirimServisi.yanittan(NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        id: 7,
        actionId: eylem.kod,
        payload: 'rota:/asistan/kart-bir',
      ))!;

      expect((y.isEylemi?.asama, y.isEylemi?.kimlik, y.bildirimNo, y.rota), ('yapim', 'kart-bir', 7, '/asistan/kart-bir'));
      // A tap (no action) is still just the route.
      final dokunma = YerelBildirimServisi.yanittan(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 7,
        payload: 'rota:/asistan/kart-bir',
      ))!;
      expect((dokunma.isEylemi, dokunma.rota), (null, '/asistan/kart-bir'));
    });
  });

  group('PushMesajIsleyici and a work card', () {
    late IsGosterici gosterici;

    PushMesajIsleyici isleyici(SunucuBildirimi b) => PushMesajIsleyici(getir: (_) async => b, gosterici: gosterici);

    setUp(() => gosterici = IsGosterici());

    SunucuBildirimi bildirim({String kaynak = 'is', List<BildirimSecenegi> secenekler = const []}) => SunucuBildirimi(
          id: 'n1',
          baslik: 'Takvim sayfası',
          metin: 'Karar bekliyor: Hangi?',
          rota: '/asistan/{id}',
          hedefKimligi: 'takvim-sayfasi',
          kaynakTuru: kaynak,
          secenekler: secenekler,
        );

    test('the decision comes with one button per option; a tap opens the card', () async {
      await isleyici(bildirim(secenekler: const [
        BildirimSecenegi(etiket: 'a', eylem: 'cevap', soruNo: 1, cevap: 'a'),
        BildirimSecenegi(etiket: 'b', eylem: 'cevap', soruNo: 1, cevap: 'b'),
      ])).isle({'bildirimId': 'n1'});

      final g = gosterici.kartlar.single;
      expect((g.baslik, g.govde, g.yuk), ('Takvim sayfası', 'Karar bekliyor: Hangi?', 'rota:/asistan/takvim-sayfasi'));
      expect(g.dugmeler.map((d) => d.etiket), ['a', 'b']);
      expect(IsBildirimEylemi.coz(g.dugmeler.first.kod)!.cevap, 'a');
      expect(gosterici.duzler, isEmpty, reason: 'not the plain notification');
    });

    test('the code gate comes with "Onayla" and "Plana dön"', () async {
      await isleyici(bildirim(secenekler: const [
        BildirimSecenegi(etiket: 'Onayla', eylem: 'asama', asama: 'yapim'),
        BildirimSecenegi(etiket: 'Plana dön', eylem: 'asama', asama: 'plan'),
      ])).isle({'bildirimId': 'n1'});

      final g = gosterici.kartlar.single;
      expect(g.dugmeler.map((d) => d.etiket), ['Onayla', 'Plana dön']);
      expect(g.dugmeler.map((d) => IsBildirimEylemi.coz(d.kod)!.asama), ['yapim', 'plan']);
    });

    test('a push or deploy approval has no button: the server offers none, and one forged into the answer is dropped', () async {
      await isleyici(bildirim()).isle({'bildirimId': 'n1'});
      expect(gosterici.kartlar.single.dugmeler, isEmpty);

      gosterici.kartlar.clear();
      await isleyici(bildirim(secenekler: const [
        BildirimSecenegi(etiket: 'Onayla', eylem: 'asama', asama: 'deploy-onayi'),
        BildirimSecenegi(etiket: 'Bitir', eylem: 'asama', asama: 'bitti'),
        BildirimSecenegi(etiket: 'Plana dön', eylem: 'asama', asama: 'plan'),
      ])).isle({'bildirimId': 'n1'});
      expect(gosterici.kartlar.single.dugmeler.map((d) => d.etiket), ['Plana dön']);
    });

    test('any other notification stays a plain one', () async {
      await isleyici(bildirim(kaynak: 'gorev')).isle({'bildirimId': 'n1'});

      expect(gosterici.kartlar, isEmpty);
      expect(gosterici.duzler, ['Takvim sayfası']);
    });
  });

  group('IsRepository', () {
    late TestOrtami ortam;

    setUp(() => ortam = TestOrtami());
    tearDown(() async => ortam.kapat());

    test('the board is kept on the phone and shown when there is no connection', () async {
      ortam.api.isKartlari = [kart('a', asama: 'karar', sahip: 'kullanici'), kart('b', asama: 'bitti', acik: false)];

      final canli = await ortam.isler.panoyuGetir();
      ortam.api.beyinCevrimdisi = true;
      final yerel = await ortam.isler.panoyuGetir();

      expect(canli.cevrimdisi, isFalse);
      expect(yerel.cevrimdisi, isTrue);
      expect(yerel.liste.map((k) => (k.kimlik, k.acik)), [('a', true), ('b', false)]);
    });

    test('offline with nothing kept is an error; without the permission the phone forgets the board', () async {
      ortam.api.beyinCevrimdisi = true;
      await expectLater(ortam.isler.panoyuGetir(), throwsA(isA<DioException>()));

      ortam.api.beyinCevrimdisi = false;
      ortam.api.isKartlari = [kart('a')];
      await ortam.isler.panoyuGetir();
      ortam.api.beyinHatasi = 403;
      await expectLater(ortam.isler.panoyuGetir(), throwsA(isA<DioException>()));
      expect(await ortam.isler.yerelPano(), isEmpty);
    });

    test('the writes: path, body and a key; the answer is the card', () async {
      ortam.api.beyinYazmaGovdesi = kartJson('k', asama: 'yapim');

      final cevap = await ortam.isler.cevapla('k', 2, 'a');
      final asama = await ortam.isler.asamaDegistir('k', 'iptal', gerekce: 'Vazgeçtim');
      final acilan = await ortam.isler.ac(const IsAcGirdi(baslik: 'Yeni', proje: 'p'), anahtar: 'anahtar-1');
      final not = await ortam.isler.notYaz('k', 'Not');

      final yazimlar = ortam.api.beyinYazimlari;
      expect(yazimlar.map((y) => y.yol), ['/api/isler/k/cevap', '/api/isler/k/asama', '/api/isler', '/api/isler/k/not']);
      expect(yazimlar[0].govde, {'soruNo': 2, 'cevap': 'a'});
      expect(yazimlar[1].govde, {'asama': 'iptal', 'gerekce': 'Vazgeçtim'});
      expect(yazimlar[2].govde, {'baslik': 'Yeni', 'proje': 'p', 'tip': 'kod'});
      expect(yazimlar[2].anahtar, 'anahtar-1', reason: 'the form keeps one key for the card it makes');
      expect(yazimlar.map((y) => y.anahtar).toSet(), hasLength(4));
      expect([cevap, asama, acilan, not].map((s) => s.kart?.asama), ['yapim', 'yapim', 'yapim', 'yapim']);
    });

    test('an unclear answer (202) is a sentence and no card; a refusal is thrown with the server\'s words; listeners hear only a write', () async {
      var duyulan = 0;
      ortam.isler.addListener(() => duyulan++);

      ortam.api.beyinYazmaKodlari = [202];
      ortam.api.beyinYazmaGovdesi = {'ayrinti': 'Beyin yazdı ama cevabı anlaşılamadı.'};
      final belirsiz = await ortam.isler.notYaz('k', 'x');
      expect((belirsiz.kart, belirsiz.uyari), (null, 'Beyin yazdı ama cevabı anlaşılamadı.'));
      expect(duyulan, 1);

      ortam.api.beyinYazmaKodlari = [409];
      ortam.api.beyinYazmaProblemi = {'title': 'Cevapsız soru var', 'detail': 'Önce soruları cevapla.'};
      await expectLater(
        ortam.isler.asamaDegistir('k', 'kod-onayi'),
        throwsA(isA<DioException>().having((e) => e.response?.data['detail'], 'detail', 'Önce soruları cevapla.')),
      );
      expect(duyulan, 1, reason: 'a refused write changed nothing');
    });
  });

  group('IsBildirimYoneticisi', () {
    late TestOrtami ortam;
    late SahteBildirimServisi servis;
    late IsBildirimYoneticisi yonetici;
    var sahip = true;

    BildirimYaniti dugme(IsBildirimEylemi e, {int no = 7}) => BildirimYaniti(isEylemi: e, bildirimNo: no, rota: '/asistan/k');

    setUp(() {
      ortam = TestOrtami();
      servis = SahteBildirimServisi();
      sahip = true;
      yonetici = IsBildirimYoneticisi(repo: ortam.isler, servis: servis, yazabilir: () => sahip);
      ortam.api.beyinYazmaGovdesi = kartJson('k');
    });
    tearDown(() async => ortam.kapat());

    test('an answer button writes the answer and takes the notification down', () async {
      final ac = await yonetici.yanitla(dugme(const IsBildirimEylemi.cevap(kimlik: 'k', soruNo: 1, cevap: 'a')));

      expect(ac, isFalse);
      expect(ortam.api.beyinYazimlari.single.yol, '/api/isler/k/cevap');
      expect(ortam.api.beyinYazimlari.single.govde, {'soruNo': 1, 'cevap': 'a'});
      expect(servis.kapatilanlar, [7]);
      expect(servis.isHatalari, isEmpty);
    });

    test('"Onayla" at the code gate moves the card to the build; "Plana dön" sends it back', () async {
      await yonetici.yanitla(dugme(const IsBildirimEylemi.asama(kimlik: 'k', asama: 'yapim')));
      await yonetici.yanitla(dugme(const IsBildirimEylemi.asama(kimlik: 'k', asama: 'plan'), no: 8));

      expect(ortam.api.beyinYazimlari.map((y) => y.govde['asama']), ['yapim', 'plan']);
      expect(servis.kapatilanlar, [7, 8]);
    });

    test('a push or deploy approval is never written from a notification, even with a forged id', () async {
      for (final asama in ['push-onayi', 'deploy-onayi', 'bitti', 'iptal']) {
        final ac = await yonetici.yanitla(dugme(IsBildirimEylemi.asama(kimlik: 'k', asama: asama)));
        expect(ac, isTrue, reason: '$asama opens the card instead');
      }

      expect(ortam.api.beyinYazimlari, isEmpty);
      expect(servis.kapatilanlar, isEmpty);
    });

    test('when the write fails the notification says so (offline, or the server refused)', () async {
      ortam.api.beyinCevrimdisi = true;
      await yonetici.yanitla(dugme(const IsBildirimEylemi.asama(kimlik: 'k', asama: 'yapim')));
      ortam.api.beyinCevrimdisi = false;
      ortam.api.beyinYazmaKodlari = [409];
      await yonetici.yanitla(dugme(const IsBildirimEylemi.cevap(kimlik: 'k', soruNo: 1, cevap: 'a'), no: 9));

      expect(servis.isHatalari, [(7, 'k'), (9, 'k')]);
      expect(servis.kapatilanlar, isEmpty, reason: 'nothing worked, nothing is taken down');
    });

    test('an unclear answer is not "done": the person is asked to look', () async {
      ortam.api.beyinYazmaKodlari = [202];
      ortam.api.beyinYazmaGovdesi = {'ayrinti': 'Belirsiz.'};

      await yonetici.yanitla(dugme(const IsBildirimEylemi.asama(kimlik: 'k', asama: 'yapim')));

      expect(servis.isHatalari, [(7, 'k')]);
      expect(servis.kapatilanlar, isEmpty);
    });

    test('someone who may not write opens the card instead; the call reaches the right manager through the reminders\' one', () async {
      sahip = false;
      expect(await yonetici.yanitla(dugme(const IsBildirimEylemi.asama(kimlik: 'k', asama: 'yapim'))), isTrue);
      expect(ortam.api.beyinYazimlari, isEmpty);

      sahip = true;
      final acilan = <String>[];
      final bildirimler = HatirlaticiBildirimYoneticisi(
        repo: ortam.hatirlaticilar,
        esitleyici: ortam.esitleyici,
        servis: servis,
        yazabilir: () => true,
        isler: yonetici,
      );
      await bildirimler.baslat(listeyiAc: () => acilan.add('liste'), rotayiAc: acilan.add);
      servis.yanitla!(dugme(const IsBildirimEylemi.cevap(kimlik: 'k', soruNo: 1, cevap: 'a')));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ortam.api.beyinYazimlari.single.yol, '/api/isler/k/cevap');
      expect(acilan, isEmpty, reason: 'a button that worked opens nothing');
      bildirimler.durdur();
    });
  });
}
