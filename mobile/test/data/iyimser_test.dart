import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/models/oturum.dart';
import 'package:kafamdakiler/data/repositories/aliskanlik_repository.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/ui/bugun/bugun_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;
  late SahteApi api;

  Future<BugunViewModel> baslat() async {
    final vm = BugunViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
    await vm.yukle();
    return vm;
  }

  tearDown(() async {
    await pumpEventQueue(); // let background sends finish before the db closes
    await ortam.kapat();
  });

  group('optimistic update + queue (offline)', () {
    setUp(() {
      api = SahteApi(aliskanliklar: [
        ornekAliskanlik(id: 'su', ad: 'Su iç', miktar: 3),
        ornekAliskanlik(id: 'yoga', ad: 'Yoga', olcu: Olcu.evetHayir),
      ]);
      ortam = TestOrtami(api: api);
    });

    test('+1 shows at once and is queued, not lost, while the server is unreachable', () async {
      final vm = await baslat(); // online first load fills the cache
      api.cevrimdisi = true;
      final su = vm.liste!.firstWhere((a) => a.id == 'su');

      await vm.miktarYaz(su, 4);

      final yeni = vm.liste!.firstWhere((a) => a.id == 'su');
      expect(yeni.bugun!.miktar, 4);
      expect(yeni.bugun!.deger, 0.5); // 4 / 8
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk, hasLength(1));
      expect(kuyruk.single.hedefId, 'su');
      expect(kuyruk.single.tarih, '2026-10-31');
    });

    test('after reopening offline the list still shows the queued value', () async {
      final vm = await baslat();
      api.cevrimdisi = true;
      await vm.miktarYaz(vm.liste!.firstWhere((a) => a.id == 'su'), 5);

      final yeniVm = BugunViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
      await yeniVm.yukle();

      expect(yeniVm.cevrimdisi, isTrue);
      expect(yeniVm.liste!.firstWhere((a) => a.id == 'su').bugun!.miktar, 5);
    });

    test('tick toggles, returns the previous amount, and undo restores it', () async {
      final vm = await baslat();
      api.cevrimdisi = true;
      final yoga = vm.liste!.firstWhere((a) => a.id == 'yoga');

      final onceki = await vm.tikDegistir(yoga);
      expect(onceki, 0);
      var guncel = vm.liste!.firstWhere((a) => a.id == 'yoga');
      expect(guncel.bugun!.miktar, 1);
      expect(guncel.bugun!.deger, 1);

      await vm.miktarYaz(guncel, onceki); // "Geri al"
      guncel = vm.liste!.firstWhere((a) => a.id == 'yoga');
      expect(guncel.bugun!.miktar, 0);
      expect(guncel.bugun!.deger, 0);

      // Going back to zero is queued as a delete, not as "PUT 0".
      final turler = (await ortam.esitleyici.bekleyenler()).map((b) => b.tur).toList();
      expect(turler, [BekleyenTur.gunYaz, BekleyenTur.gunSil]);
    });

    test('the amount never goes below zero', () async {
      final vm = await baslat();
      api.cevrimdisi = true;
      await vm.miktarYaz(vm.liste!.firstWhere((a) => a.id == 'su'), -2);
      expect(vm.liste!.firstWhere((a) => a.id == 'su').bugun!.miktar, 0);
    });

    test('yesterday\'s cached amount is not shown as today\'s', () async {
      await baslat(); // cache: Su iç = 3 glasses for 2026-10-31
      // The phone is opened the next habit day, offline; the cache still says 10-31.
      final yarin = AliskanlikRepository(
        api: api,
        db: ortam.db,
        esitleyici: ortam.esitleyici,
        simdi: () => sabitAn.add(const Duration(days: 1)),
      );
      api.cevrimdisi = true;

      final sonuc = await yarin.listele();

      expect(sonuc.cevrimdisi, isTrue);
      expect(sonuc.liste.firstWhere((a) => a.id == 'su').bugun!.miktar, 0);
    });

    test('back online, the queue is sent and the list reloads from the server', () async {
      final vm = await baslat();
      api.cevrimdisi = true;
      await vm.miktarYaz(vm.liste!.firstWhere((a) => a.id == 'su'), 4);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));

      api.cevrimdisi = false;
      expect(await ortam.esitleyici.gonder(), 1);
      await pumpEventQueue(); // the view model reloads after the send
      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
      expect(api.cagrilar, contains('gunYaz'));
      expect(vm.liste!.firstWhere((a) => a.id == 'su').bugun!.miktar, 3,
          reason: 'queue is empty, so the server list (3 in this fake) is shown');
    });
  });

  group('session queued offline', () {
    setUp(() {
      final kitap = OgeOzet(id: 'o1', ad: 'Kürk Mantolu Madonna', guncelKonum: 12, toplam: 160, ilerleme: 12 / 160);
      api = SahteApi(
        aliskanliklar: [
          ornekAliskanlik(
            id: 'r1',
            ad: 'Kitap',
            tur: AliskanlikTuru.raf,
            hedef: 30,
            birim: 'sayfa',
            devamEdenler: [kitap],
          ),
        ],
        ogeler: [ornekOge()],
      );
      ortam = TestOrtami(api: api);
    });

    test('moves the item position and today\'s amount on the card', () async {
      final vm = await baslat();
      api.cevrimdisi = true;

      await ortam.esitleyici.oturumKuyrugaAl(
        'o1',
        OturumEkle(bitisKonum: 35, dakika: 40, baslangicKonum: 12, baslangicAni: sabitAn),
      );
      await vm.yukle();

      final kitap = vm.liste!.single;
      expect(kitap.devamEdenler.single.guncelKonum, 35);
      expect(kitap.devamEdenler.single.ilerleme, closeTo(35 / 160, 1e-9));
      expect(kitap.bugun!.miktar, 23);
      expect(kitap.bugun!.dakika, 40);
      expect(kitap.bugun!.deger, closeTo(23 / 30, 1e-9));
    });

    test('the item detail starts the next session from the queued end position', () async {
      await ortam.repo.ogeleriListele('r1'); // cache the item
      api.cevrimdisi = true;
      await ortam.esitleyici.oturumKuyrugaAl(
        'o1',
        OturumEkle(bitisKonum: 35, baslangicKonum: 12, baslangicAni: sabitAn),
      );

      final Oge oge = await ortam.repo.oge('o1');
      expect(oge.guncelKonum, 35);
    });
  });
}
