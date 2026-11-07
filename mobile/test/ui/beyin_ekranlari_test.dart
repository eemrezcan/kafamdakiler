import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/ui/ara/ara_screen.dart';
import 'package:kafamdakiler/ui/ara/ara_view_model.dart';
import 'package:kafamdakiler/ui/ara/not_screen.dart';
import 'package:kafamdakiler/ui/bugun/bugun_screen.dart';
import 'package:kafamdakiler/ui/bugun/bugun_view_model.dart';
import 'package:kafamdakiler/ui/bugun/gun_plani_view_model.dart';
import 'package:kafamdakiler/data/models/proje_repo.dart';
import 'package:kafamdakiler/ui/projeler/proje_detay_screen.dart';
import 'package:kafamdakiler/ui/projeler/proje_liste_screen.dart';
import 'package:kafamdakiler/ui/projeler/proje_view_model.dart';

import '../test_destek.dart';

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  /// Drift needs real time; the fake-async zone of a widget test would never finish its queries.
  Future<void> gercekZaman(WidgetTester tester, [int ms = 100]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }

  void telefonBoyu(WidgetTester tester, {double boy = 900}) {
    tester.view.physicalSize = Size(375, boy);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('Projeler', () {
    setUp(() {
      ortam.api.projeler = const [
        ProjeOzet(kimlik: 'balkon-bahcesi', baslik: 'Balkon Bahçesi Sulama'),
        ProjeOzet(kimlik: 'kitap-kulubu', baslik: 'Kitap Kulübü Sitesi'),
      ];
    });

    Future<ProjeListeViewModel> goster(WidgetTester tester) async {
      telefonBoyu(tester);
      final vm = ProjeListeViewModel(repo: ortam.beyin);
      await tester.runAsync(vm.yukle);
      await tester.pumpWidget(MaterialApp(home: ProjeListeScreen(viewModel: vm)));
      await tester.pump();
      return vm;
    }

    testWidgets('lists the projects with their ids', (tester) async {
      await goster(tester);

      expect(find.text('Balkon Bahçesi Sulama'), findsOneWidget);
      expect(find.text('kitap-kulubu'), findsOneWidget);
    });

    testWidgets('503: says the brain is not connected, and Tekrar dene loads the list once it is', (tester) async {
      ortam.api.beyinHatasi = 503;
      await goster(tester);

      expect(find.textContaining('Beyin bağlı değil'), findsOneWidget);
      expect(find.text('Balkon Bahçesi Sulama'), findsNothing);

      ortam.api.beyinHatasi = null;
      await tester.tap(find.text('Tekrar dene'));
      await gercekZaman(tester);

      expect(find.text('Balkon Bahçesi Sulama'), findsOneWidget);
    });

    testWidgets('403: says there is no permission, still with a retry button', (tester) async {
      ortam.api.beyinHatasi = 403;
      await goster(tester);

      expect(find.textContaining('iznin yok'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('offline with a kept list: shows it with a note, no error', (tester) async {
      await tester.runAsync(ortam.beyin.projeleriGetir);
      ortam.api.beyinCevrimdisi = true;
      await goster(tester);

      expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);
      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsNothing);
    });

    testWidgets('offline with nothing kept: explains, with a retry button', (tester) async {
      ortam.api.beyinCevrimdisi = true;
      await goster(tester);

      expect(find.textContaining('internet ister'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });
  });

  group('Proje ayrıntısı', () {
    const proje = ProjeDetay(
      kimlik: 'kitap-kulubu',
      baslik: 'Kitap Kulübü Sitesi',
      durum: 'Okuma listesi sayfası bitti.',
      siradakiAdim: 'Buluşma takvimi sayfası: ay görünümü.',
      acikGorevler: [
        ProjeGorev(kimlik: 'takvim', baslik: 'Buluşma takvimi sayfası', durum: 'aktif', oncelik: 'yuksek', sonrakiAdim: 'Ay görünümünü çiz'),
        ProjeGorev(kimlik: 'mobil', baslik: 'Mobil görünüm düzeltmeleri', durum: 'bekliyor'),
      ],
      sonGunluk: [GunlukSatiri(zaman: '2026-11-03 18:42', baslik: 'Okuma listesi', metin: 'Liste sayfası bitti.')],
    );

    // [boy] taller than a phone when the test looks at the lower cards (a list only builds what is on screen).
    Future<ProjeDetayViewModel> goster(WidgetTester tester, {double boy = 900}) async {
      telefonBoyu(tester, boy: boy);
      final vm = ProjeDetayViewModel(repo: ortam.beyin, kimlik: 'kitap-kulubu');
      await vm.yukle();
      await tester.pumpWidget(MaterialApp(home: ProjeDetayScreen(viewModel: vm)));
      await tester.pump();
      return vm;
    }

    testWidgets('shows status, next step, open tasks and the last journal lines', (tester) async {
      ortam.api.projeDetaylari = {'kitap-kulubu': proje};
      await goster(tester);

      expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget, reason: 'app bar title');
      expect(find.text('Okuma listesi sayfası bitti.'), findsOneWidget);
      expect(find.text('Buluşma takvimi sayfası: ay görünümü.'), findsOneWidget);
      expect(find.text('Buluşma takvimi sayfası'), findsOneWidget);
      expect(find.text('Aktif · Yüksek öncelik'), findsOneWidget);
      expect(find.text('Ay görünümünü çiz'), findsOneWidget);
      expect(find.text('Bekliyor'), findsOneWidget);
      expect(find.text('2026-11-03 18:42'), findsOneWidget);
      expect(find.text('Liste sayfası bitti.'), findsOneWidget);
    });

    testWidgets('journal rows line up on the left, a short one too (seen drifting to the middle on a phone)', (tester) async {
      ortam.api.projeDetaylari = {
        'kitap-kulubu': const ProjeDetay(
          kimlik: 'kitap-kulubu',
          baslik: 'Kitap Kulübü Sitesi',
          sonGunluk: [
            GunlukSatiri(zaman: '2026-11-03 18:42', baslik: 'Uzun satır', metin: 'Bu satırın metni epeyce uzun, kartın tüm genişliğini dolduracak kadar uzun yazıldı.'),
            GunlukSatiri(zaman: '2026-11-03 18:43', baslik: 'Kısa', metin: 'ok'),
          ],
        ),
      };
      await goster(tester);

      expect(
        tester.getTopLeft(find.text('2026-11-03 18:43')).dx,
        tester.getTopLeft(find.text('2026-11-03 18:42')).dx,
      );
    });

    testWidgets('repo card: link, open PR count and the last commits', (tester) async {
      ortam.api.projeDetaylari = {'kitap-kulubu': proje};
      ortam.api.projeRepolari = {
        'kitap-kulubu': ProjeRepoOzeti(
          proje: 'kitap-kulubu',
          depo: 'emre/kitap-kulubu',
          baglanti: 'https://github.com/emre/kitap-kulubu',
          durum: 'tamam',
          acikPrSayisi: 2,
          commitler: [
            RepoCommit(hash: 'a1b2c3d', mesaj: 'feat: add the calendar', yazar: 'Emre', tarih: DateTime.utc(2026, 11, 3, 18)),
            const RepoCommit(hash: 'e4f5a6b', mesaj: 'fix: typo'),
          ],
        ),
      };
      await goster(tester, boy: 2400);

      expect(find.text('DEPO'), findsOneWidget, reason: 'section titles are drawn in capitals');
      expect(find.text('emre/kitap-kulubu'), findsOneWidget);
      expect(find.text('https://github.com/emre/kitap-kulubu'), findsOneWidget);
      expect(find.text('2 açık PR'), findsOneWidget);
      expect(find.text('feat: add the calendar'), findsOneWidget);
      expect(find.textContaining('a1b2c3d · Emre'), findsOneWidget);
      expect(find.text('e4f5a6b'), findsOneWidget, reason: 'a commit without author and date shows just its hash');
    });

    testWidgets('repo card without a GitHub token: the link and the reason, no counts', (tester) async {
      ortam.api.projeDetaylari = {'kitap-kulubu': proje};
      ortam.api.projeRepolari = {
        'kitap-kulubu': const ProjeRepoOzeti(
          proje: 'kitap-kulubu',
          depo: 'emre/kitap-kulubu',
          baglanti: 'https://github.com/emre/kitap-kulubu',
          durum: 'tokenYok',
          mesaj: 'GitHub token yok; yalnız bağlantı gösteriliyor.',
        ),
      };
      await goster(tester, boy: 2400);

      expect(find.text('https://github.com/emre/kitap-kulubu'), findsOneWidget);
      expect(find.text('GitHub token yok; yalnız bağlantı gösteriliyor.'), findsOneWidget);
      expect(find.textContaining('açık PR'), findsNothing);
    });

    testWidgets('a project with no repository linked has no card', (tester) async {
      ortam.api.projeDetaylari = {'kitap-kulubu': proje};
      await goster(tester, boy: 2400);

      expect(find.text('DEPO'), findsNothing);
      expect(find.text('Kitap Kulübü Sitesi'), findsOneWidget);
      expect(find.text('SON GÜNLÜK'), findsOneWidget);
    });

    testWidgets('a repo card that cannot be read leaves the project page as it is', (tester) async {
      ortam.api.projeDetaylari = {'kitap-kulubu': proje};
      ortam.api.projeRepoHatasi = 500;
      final vm = await goster(tester, boy: 2400);

      expect(vm.repoHatasi, isTrue);
      expect(vm.repoOzeti, isNull);
      expect(find.text('DEPO'), findsNothing);
      expect(find.text('Okuma listesi sayfası bitti.'), findsOneWidget, reason: 'the project itself is still shown');
      expect(find.text('Tekrar dene'), findsNothing);
    });

    testWidgets('a project that is not there (or is hidden): a 404 message', (tester) async {
      await goster(tester);

      expect(find.textContaining('Bulunamadı'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('503 and offline each say what is wrong', (tester) async {
      ortam.api.beyinHatasi = 503;
      final vm = await goster(tester);
      expect(find.textContaining('Beyin bağlı değil'), findsOneWidget);

      ortam.api.beyinHatasi = null;
      ortam.api.beyinCevrimdisi = true;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);
      expect(vm.hata, isNotNull);
    });
  });

  group('Ara', () {
    const sonuclar = [
      AramaSonucu(yol: 'gelen/kitap-onerisi.md', baslik: 'Kitap önerisi', alan: 'gelen', alinti: 'Ayşe "Simyacı"yı önerdi.'),
      AramaSonucu(yol: 'projects/kitap-kulubu/gunluk/2026-11.md', baslik: 'kitap-kulubu günlüğü', proje: 'kitap-kulubu', alinti: 'Liste sayfası bitti.'),
    ];

    Future<AraViewModel> goster(WidgetTester tester) async {
      telefonBoyu(tester);
      final vm = AraViewModel(repo: ortam.beyin);
      await tester.pumpWidget(MaterialApp(home: AraScreen(viewModel: vm)));
      await tester.pump();
      return vm;
    }

    Future<void> ara(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField), q);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('starts with a hint and makes no call', (tester) async {
      await goster(tester);

      expect(find.textContaining('Notlarda, görevlerde'), findsOneWidget);
      expect(ortam.api.cagrilar, isEmpty);
    });

    testWidgets('searches the trimmed query and lists the hits with where they are from', (tester) async {
      ortam.api.aramaSonuclari = sonuclar;
      await goster(tester);

      await ara(tester, '  kitap  ');

      expect(ortam.api.cagrilar, ['beyinAra:kitap']);
      expect(find.text('Kitap önerisi'), findsOneWidget);
      expect(find.text('Liste sayfası bitti.'), findsOneWidget);
      expect(find.text('kitap-kulubu'), findsOneWidget);
      expect(find.text('gelen'), findsOneWidget);
    });

    testWidgets('an empty query does nothing; no hits says so', (tester) async {
      await goster(tester);

      await ara(tester, '   ');
      expect(ortam.api.cagrilar, isEmpty);

      await ara(tester, 'zebra');
      expect(find.textContaining('için sonuç yok'), findsOneWidget);
    });

    testWidgets('503 and 403: a message with a retry that searches again', (tester) async {
      ortam.api.beyinHatasi = 503;
      await goster(tester);
      await ara(tester, 'kitap');
      expect(find.textContaining('Beyin bağlı değil'), findsOneWidget);

      ortam.api.beyinHatasi = 403;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('iznin yok'), findsOneWidget);

      ortam.api.beyinHatasi = null;
      ortam.api.aramaSonuclari = sonuclar;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Kitap önerisi'), findsOneWidget);
      expect(ortam.api.cagrilar, ['beyinAra:kitap', 'beyinAra:kitap', 'beyinAra:kitap']);
    });

    testWidgets('offline: says the screen needs the internet', (tester) async {
      ortam.api.beyinCevrimdisi = true;
      await goster(tester);

      await ara(tester, 'kitap');

      expect(find.textContaining('internet ister'), findsOneWidget);
    });

    test('a hit opens the note by its path, escaped', () {
      expect(notRotasi('projects/a b/ç.md'), '/not?yol=projects%2Fa+b%2F%C3%A7.md');
      expect(Uri.parse(notRotasi('projects/a b/ç.md')).queryParameters['yol'], 'projects/a b/ç.md');
    });
  });

  group('Not', () {
    const not = BeyinNotu(
      yol: 'projects/kitap-kulubu/notlar/takvim-kutuphanesi.md',
      baslik: 'Takvim için kütüphane seçimi',
      etiketler: ['mimari', 'yazılım'],
      govde: '# Karar\n\nHazır bir **takvim bileşeni** kullanılacak.\n\n- ay görünümü\n- tıklanabilir gün\n\n![şema](https://example.com/x.png)\n',
    );

    Future<NotViewModel> goster(WidgetTester tester) async {
      telefonBoyu(tester);
      final vm = NotViewModel(repo: ortam.beyin, yol: not.yol);
      await vm.yukle();
      await tester.pumpWidget(MaterialApp(home: NotScreen(viewModel: vm)));
      await tester.pump();
      return vm;
    }

    testWidgets('renders the Markdown: headings, bold, lists, tags; images become their alt text', (tester) async {
      ortam.api.notlar = {not.yol: not};
      await goster(tester);

      expect(find.text('Takvim için kütüphane seçimi'), findsOneWidget, reason: 'app bar title');
      expect(find.text(not.yol), findsOneWidget);
      expect(find.text('mimari'), findsOneWidget);
      expect(find.textContaining('Karar', findRichText: true), findsOneWidget);
      expect(find.textContaining('takvim bileşeni', findRichText: true), findsOneWidget);
      expect(find.textContaining('ay görünümü', findRichText: true), findsOneWidget);
      expect(find.textContaining('# Karar', findRichText: true), findsNothing, reason: 'the # is syntax, not text');
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.text('şema'), findsOneWidget, reason: 'the image is not fetched; its alt text stands in');
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a note that is not there (or hidden): 404 message; 503: not connected', (tester) async {
      await goster(tester);
      expect(find.textContaining('Bulunamadı'), findsOneWidget);

      ortam.api.beyinHatasi = 503;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Beyin bağlı değil'), findsOneWidget);
    });
  });

  group('Gün planı on the Bugün tab', () {
    // 2026-10-31 12:00 Istanbul is habit day 2026-10-31 (sabitAn).
    final plan31 = BeyinGun(
      tarih: DateTime.utc(2026, 10, 31),
      planVar: true,
      bolumler: const [
        BeyinGunBolumu(ad: 'Yapılacaklar', maddeler: [
          BeyinGunMaddesi(id: 'a1', baslik: 'Takvim ay görünümü', durum: 'acik', tahminDk: 90),
          BeyinGunMaddesi(id: 'a2', baslik: '20 sayfa kitap', durum: 'yapildi'),
        ]),
      ],
      geciken: const [GecikenGorev(kimlik: 'dis', baslik: 'Diş randevusu al', gun: 3, proje: 'kisisel')],
      toplam: const BeyinGunToplami(madde: 2, yapildi: 1, acik: 1),
    );
    final plan1 = BeyinGun(
      tarih: DateTime.utc(2026, 11, 1),
      planVar: true,
      bolumler: const [
        BeyinGunBolumu(ad: 'Yapılacaklar', maddeler: [BeyinGunMaddesi(id: 'b1', baslik: 'Yarının işi', durum: 'acik')]),
      ],
    );

    Future<(BugunViewModel, GunPlaniViewModel)> goster(WidgetTester tester) async {
      telefonBoyu(tester);
      ortam.api.aliskanliklar = [ornekAliskanlik()];
      final bugun = BugunViewModel(repo: ortam.repo, esitleyici: ortam.esitleyici);
      await tester.runAsync(bugun.yukle);
      final plan = GunPlaniViewModel(repo: ortam.gunPlani, esitleyici: ortam.esitleyici);
      await plan.yukle();
      await tester.pumpWidget(MaterialApp(home: BugunScreen(viewModel: bugun, gunPlani: plan)));
      await tester.pump();
      return (bugun, plan);
    }

    testWidgets("shows today's plan, the overdue tasks and the tally above the habit cards", (tester) async {
      ortam.api.gunPlanlari = {'2026-10-31': plan31};
      await goster(tester);

      expect(find.text('Gün planı'), findsOneWidget);
      expect(find.text('Bugün'), findsWidgets);
      expect(find.text('Takvim ay görünümü'), findsOneWidget);
      expect(find.text('1 sa 30 dk'), findsOneWidget);
      expect(find.text('20 sayfa kitap'), findsOneWidget);
      expect(find.text('Diş randevusu al'), findsOneWidget);
      expect(find.text('3 gün'), findsOneWidget);
      expect(find.text('1 / 2 tamam'), findsOneWidget);
      expect(find.text('Su iç'), findsOneWidget, reason: 'the habit card is on the same screen');
    });

    testWidgets('day forward and back; "Bugüne dön" comes back', (tester) async {
      ortam.api.gunPlanlari = {'2026-10-31': plan31, '2026-11-01': plan1};
      await goster(tester);
      expect(find.text('Bugüne dön'), findsNothing);

      await tester.tap(find.byTooltip('Sonraki gün'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Yarın'), findsOneWidget);
      expect(find.text('Yarının işi'), findsOneWidget);
      expect(find.text('Takvim ay görünümü'), findsNothing, reason: "today's lines are gone");
      expect(find.text('Su iç'), findsOneWidget, reason: 'the habits stay on today');

      await tester.tap(find.byTooltip('Önceki gün'));
      await tester.tap(find.byTooltip('Önceki gün'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Dün'), findsOneWidget);
      expect(find.text('Bu gün için plan yok.'), findsOneWidget);

      await tester.tap(find.text('Bugüne dön'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Takvim ay görünümü'), findsOneWidget);
      // opening, tomorrow, two taps back (tomorrow -> today -> yesterday), then "Bugüne dön" = 5 reads of the day on screen;
      // every time the plan is on today the morning card also reads yesterday (opening, back on today, "Bugüne dön") = 3 more.
      expect(ortam.api.cagrilar.where((c) => c == 'beyinGun'), hasLength(8));
    });

    testWidgets('a day without a plan says so', (tester) async {
      await goster(tester);

      expect(find.text('Bu gün için plan yok.'), findsOneWidget);
    });

    testWidgets('503: the card explains, the habits are untouched; Tekrar dene works', (tester) async {
      ortam.api.beyinHatasi = 503;
      await goster(tester);

      expect(find.textContaining('Beyin bağlı değil'), findsOneWidget);
      expect(find.text('Su iç'), findsOneWidget);

      ortam.api.beyinHatasi = null;
      ortam.api.gunPlanlari = {'2026-10-31': plan31};
      await tester.tap(find.text('Tekrar dene'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Takvim ay görünümü'), findsOneWidget);
    });

    testWidgets('403 and offline each have their message in the card', (tester) async {
      ortam.api.beyinHatasi = 403;
      final (_, plan) = await goster(tester);
      expect(find.textContaining('iznin yok'), findsOneWidget);

      ortam.api.beyinHatasi = null;
      ortam.api.beyinCevrimdisi = true;
      await plan.yukle();
      await tester.pump();
      expect(find.textContaining('internet ister'), findsOneWidget);
      expect(find.text('Su iç'), findsOneWidget);
    });

    testWidgets('a quick tap on two days: the last answer wins', (tester) async {
      ortam.api.gunPlanlari = {'2026-10-31': plan31, '2026-11-01': plan1};
      final (_, plan) = await goster(tester);

      final ilk = plan.gunDegistir(1);
      final ikinci = plan.gunDegistir(-1);
      await Future.wait([ilk, ikinci]);
      await tester.pump();

      expect(plan.tarih, DateTime.utc(2026, 10, 31));
      expect(plan.veri?.tarih, DateTime.utc(2026, 10, 31));
    });
  });
}
