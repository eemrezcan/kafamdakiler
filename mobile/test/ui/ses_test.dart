import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/ses.dart';
import 'package:kafamdakiler/data/services/baglanti_servisi.dart';
import 'package:kafamdakiler/data/services/dikte_servisi.dart';
import 'package:kafamdakiler/ui/yakalama/ses_view_model.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_screen.dart';
import 'package:kafamdakiler/ui/yakalama/yakala_view_model.dart';

import '../test_destek.dart';

/// Stands in for the microphone: the test plays the recognizer by calling the callbacks it was given.
class SahteDikte implements DikteServisi {
  DikteHazirlik hazirlik = DikteHazirlik.hazir;
  int dinlemeSayisi = 0;
  int durdurmaSayisi = 0;
  void Function(String metin, bool son)? sonuc;
  void Function()? durdu;
  void Function(String kod)? hata;

  @override
  Future<DikteHazirlik> hazirla() async => hazirlik;

  @override
  Future<void> dinle({
    required void Function(String metin, bool son) onSonuc,
    required void Function() onDurdu,
    required void Function(String kod) onHata,
  }) async {
    dinlemeSayisi++;
    sonuc = onSonuc;
    durdu = onDurdu;
    hata = onHata;
  }

  @override
  Future<void> durdur() async => durdurmaSayisi++;
}

class SahteBaglanti implements BaglantiServisi {
  bool var_ = true;
  final _akis = StreamController<bool>.broadcast();

  void ayarla(bool deger) {
    var_ = deger;
    _akis.add(deger);
  }

  @override
  Future<bool> varMi() async => var_;

  @override
  Stream<bool> get degisim => _akis.stream;
}

void main() {
  late TestOrtami ortam;
  late SahteDikte dikte;
  late SahteBaglanti baglanti;
  late SesViewModel ses;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() {
    ortam = TestOrtami();
    dikte = SahteDikte();
    baglanti = SahteBaglanti();
  });
  tearDown(() async => ortam.kapat());

  const oneriler = [
    IsOnerisi(tur: IsOnerisi.hatirlatici, baslik: 'Ali\'yi ara', gun: '2026-11-08', saat: '09:00', guven: 0.95),
    IsOnerisi(tur: IsOnerisi.plan, baslik: 'Raporu bitir', gun: '2026-11-13', tahminDk: 60, guven: 0.9),
    IsOnerisi(tur: IsOnerisi.gorev, baslik: 'Üye girişi ekranı', proje: 'kitap-kulubu', guven: 0.4),
  ];

  Future<void> goster(WidgetTester tester, {String? metin}) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = YakalaViewModel(repo: ortam.yakalamalar, esitleyici: ortam.esitleyici);
    ses = SesViewModel(api: ortam.api, dikte: dikte, baglanti: baglanti);
    addTearDown(ses.dispose);
    await tester.pumpWidget(MaterialApp(home: YakalaScreen(viewModel: vm, sesViewModel: ses)));
    await tester.pump();
    if (metin != null) await tester.enterText(find.byType(TextFormField), metin);
    await tester.pump();
  }

  String alan(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  bool acik(WidgetTester tester, String yazi) {
    final dugme = find.ancestor(of: find.text(yazi), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    return tester.widget<ButtonStyleButton>(dugme.first).onPressed != null;
  }

  group('assistant status', () {
    testWidgets('with Claude off on the server, İşe çevir, Özetle and Maddele are not offered; dictation still is', (tester) async {
      ortam.api.asistanBagli = false;
      await goster(tester, metin: 'yarın Ali\'yi ara');

      expect(find.text('İşe çevir'), findsNothing);
      expect(find.text('Özetle'), findsNothing);
      expect(find.text('Maddele'), findsNothing);
      expect(find.text('Dikte'), findsOneWidget);
    });

    testWidgets('with Claude connected they are offered', (tester) async {
      await goster(tester, metin: 'yarın Ali\'yi ara');

      expect(find.text('İşe çevir'), findsOneWidget);
      expect(find.text('Özetle'), findsOneWidget);
      expect(find.text('Maddele'), findsOneWidget);
    });

    testWidgets('a connection that comes back asks the server again', (tester) async {
      baglanti.var_ = false;
      ortam.api.asistanBagli = false;
      await goster(tester, metin: 'x');
      expect(find.text('İşe çevir'), findsNothing);

      ortam.api.asistanBagli = true;
      baglanti.ayarla(true);
      await tester.pump();
      await tester.pump();

      expect(find.text('İşe çevir'), findsOneWidget);
    });
  });

  group('dictation', () {
    testWidgets('the words stream into the field, a pause stops it, the button starts it again after the text', (tester) async {
      await goster(tester);
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      expect(dikte.dinlemeSayisi, 1);
      expect(find.text('Durdur'), findsOneWidget);

      dikte.sonuc!('merhaba', false);
      await tester.pump();
      expect(alan(tester), 'merhaba');
      dikte.sonuc!('merhaba dünya', true);
      await tester.pump();
      expect(alan(tester), 'merhaba dünya');

      dikte.durdu!(); // the recognizer ended on a pause
      await tester.pump();
      expect(find.text('Dikte'), findsOneWidget);

      await tester.tap(find.text('Dikte'));
      await tester.pump();
      dikte.sonuc!('ikinci cümle', false);
      await tester.pump();
      expect(alan(tester), 'merhaba dünya ikinci cümle');
    });

    testWidgets('dictation goes after the text already in the field', (tester) async {
      await goster(tester, metin: 'önce yazdım');
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      dikte.sonuc!('sonra söyledim', false);
      await tester.pump();
      expect(alan(tester), 'önce yazdım sonra söyledim');
    });

    testWidgets('the field is read only while listening, typing works again after', (tester) async {
      await goster(tester);
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isTrue);
      await tester.tap(find.text('Durdur'));
      await tester.pump();
      expect(dikte.durdurmaSayisi, 1);
      expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isFalse);
    });

    testWidgets('a refused microphone permission says so and does not listen', (tester) async {
      dikte.hazirlik = DikteHazirlik.izinYok;
      await goster(tester);
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      expect(find.textContaining('Mikrofon izni verilmedi'), findsOneWidget);
      expect(dikte.dinlemeSayisi, 0);
      expect(find.text('Dikte'), findsOneWidget);
      expect(ses.izinReddedildi, isTrue);
    });

    testWidgets('a permission error while listening stops it and says so', (tester) async {
      await goster(tester);
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      dikte.hata!('error_permission');
      await tester.pump();
      expect(find.textContaining('Mikrofon izni verilmedi'), findsOneWidget);
      expect(find.text('Dikte'), findsOneWidget);
    });

    testWidgets('no Turkish on the phone and no recognizer have their own messages', (tester) async {
      dikte.hazirlik = DikteHazirlik.turkceYok;
      await goster(tester);
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      expect(find.textContaining('Türkçe bilmiyor'), findsOneWidget);

      dikte.hazirlik = DikteHazirlik.kullanilamaz;
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      expect(find.textContaining('kullanılamıyor'), findsOneWidget);
    });

    testWidgets('"nothing was said" ends the listening quietly', (tester) async {
      await goster(tester);
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      dikte.hata!('error_no_match');
      dikte.durdu!();
      await tester.pump();
      expect(find.text('Dikte'), findsOneWidget);
      expect(find.textContaining('Ses tanıma durdu'), findsNothing);
    });
  });

  group('offline', () {
    testWidgets('the server tools are off with a note, dictation and Kaydet stay', (tester) async {
      await goster(tester, metin: 'yarın Ali\'yi ara');
      expect(acik(tester, 'İşe çevir'), isTrue);

      baglanti.ayarla(false);
      await tester.pump();
      await tester.pump();
      expect(acik(tester, 'İşe çevir'), isFalse);
      expect(acik(tester, 'Özetle'), isFalse);
      expect(acik(tester, 'Maddele'), isFalse);
      expect(acik(tester, 'Dikte'), isTrue);
      expect(acik(tester, 'Kaydet'), isTrue);
      expect(find.textContaining('Çevrimdışısın'), findsOneWidget);

      baglanti.ayarla(true);
      await tester.pump();
      await tester.pump();
      expect(acik(tester, 'İşe çevir'), isTrue);
      expect(find.textContaining('Çevrimdışısın'), findsNothing);
    });

    testWidgets('the server tools need some text', (tester) async {
      await goster(tester);
      expect(acik(tester, 'İşe çevir'), isFalse);
      expect(acik(tester, 'Özetle'), isFalse);
    });
  });

  group('turn into work', () {
    setUp(() {
      ortam.api.isCikarYaniti = const IsCikarYaniti(
        bugun: '2026-11-07',
        haftaninGunu: 'Cumartesi',
        oneriler: oneriler,
        atlananlar: [AtlananOneri(baslik: 'Geçmiş iş', neden: 'Tarih geçmişte')],
      );
    });

    testWidgets('the preview lists the suggestions, ticks the sure ones and saves nothing', (tester) async {
      await goster(tester, metin: 'Yarın Ali\'yi ara. Cuma raporu bitir.');
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();

      expect(ortam.api.isCikarMetinleri, ['Yarın Ali\'yi ara. Cuma raporu bitir.']);
      expect(find.text('Ali\'yi ara'), findsOneWidget);
      expect(find.text('Raporu bitir'), findsOneWidget);
      expect(find.text('Üye girişi ekranı'), findsOneWidget);
      expect(find.textContaining('Hatırlatıcı · 8 Kasım Pazar · 09:00'), findsOneWidget);
      expect(find.textContaining('Gün planı · 13 Kasım Cuma · 60 dk'), findsOneWidget);
      expect(find.textContaining('Emin değil · %40'), findsOneWidget);
      expect(find.text('Tarih geçmişte'), findsOneWidget);
      expect(find.text('Seçilenleri ekle (2)'), findsOneWidget);

      // Closing the sheet without adding: nothing was sent.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(ortam.api.uygulananIstekler, isEmpty);
      expect(ses.akis, IsAkisi.yok);
    });

    testWidgets('ticking and correcting change what is sent; each result is shown', (tester) async {
      await goster(tester, metin: 'metin');
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onizleme-2'))); // the unsure one is added by hand
      await tester.tap(find.byKey(const ValueKey('onizleme-1'))); // and the plan item is left out
      await tester.pump();
      expect(find.text('Seçilenleri ekle (2)'), findsOneWidget);

      await tester.tap(find.byTooltip('Düzelt').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Ali\'yi akşam ara');
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.text('Ali\'yi akşam ara'), findsOneWidget);

      await tester.tap(find.text('Seçilenleri ekle (2)'));
      await tester.pumpAndSettle();

      final gonderilen = ortam.api.uygulananIstekler.single;
      expect(gonderilen.map((o) => o.baslik), ['Ali\'yi akşam ara', 'Üye girişi ekranı']);
      // The correction keeps what was not touched.
      expect(gonderilen.first.gun, '2026-11-08');
      expect(gonderilen.first.saat, '09:00');
      expect(gonderilen.last.proje, 'kitap-kulubu');

      expect(find.text('2 / 2 eklendi'), findsOneWidget);
      expect(find.text('Eklendi'), findsNWidgets(2));
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(ses.akis, IsAkisi.yok);
    });

    testWidgets('a half success shows which one failed and why; the others stay applied', (tester) async {
      ortam.api.uygulaYaniti = const IsCikarUygulaYaniti(
        uygulanan: 1,
        basarisiz: 1,
        sonuclar: [
          IsUygulaSonucu(sira: 0, durum: 'uygulandi'),
          IsUygulaSonucu(sira: 1, durum: 'hata', mesaj: 'Beyin yazmayı reddetti.'),
        ],
      );
      await goster(tester, metin: 'metin');
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seçilenleri ekle (2)'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2 eklendi'), findsOneWidget);
      expect(find.text('Eklendi'), findsOneWidget);
      expect(find.text('Eklenemedi · Beyin yazmayı reddetti.'), findsOneWidget);
    });

    testWidgets('a kind the person may not apply is told apart', (tester) async {
      ortam.api.uygulaYaniti = const IsCikarUygulaYaniti(
        uygulanan: 0,
        basarisiz: 2,
        sonuclar: [IsUygulaSonucu(sira: 0, durum: 'izinYok'), IsUygulaSonucu(sira: 1, durum: 'gecersiz', mesaj: 'Gün geçmişte.')],
      );
      await goster(tester, metin: 'metin');
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seçilenleri ekle (2)'));
      await tester.pumpAndSettle();

      expect(find.text('0 / 2 eklendi'), findsOneWidget);
      expect(find.text('Bunu yapma iznin yok'), findsOneWidget);
      expect(find.text('Geçersiz, eklenmedi · Gün geçmişte.'), findsOneWidget);
    });

    testWidgets('no answer while applying says it is not known whether they went through', (tester) async {
      await goster(tester, metin: 'metin');
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();
      ortam.api.cevrimdisi = true;
      await tester.tap(find.text('Seçilenleri ekle (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Sunucudan yanıt gelmedi'), findsOneWidget);
      expect(find.textContaining('Son uygulananlar'), findsOneWidget);
      expect(find.text('Sonuç bilinmiyor'), findsNWidgets(2));
    });

    testWidgets('a refusal of the whole apply keeps the preview with the reason', (tester) async {
      await goster(tester, metin: 'metin');
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();
      ortam.api.sesHatasi = 403;
      await tester.tap(find.text('Seçilenleri ekle (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Asistanı kullanma iznin yok.'), findsOneWidget);
      expect(find.text('Seçilenleri ekle (2)'), findsOneWidget);
    });

    testWidgets('an empty answer says nothing came out', (tester) async {
      ortam.api.isCikarYaniti = const IsCikarYaniti(bugun: '2026-11-07', haftaninGunu: 'Cumartesi', oneriler: [], atlananlar: []);
      await goster(tester, metin: 'günaydın');
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();
      expect(find.text('Bu metinden eklenecek bir iş çıkmadı.'), findsOneWidget);
      expect(acik(tester, 'Seçilenleri ekle'), isFalse);
    });

    testWidgets('dictation is stopped before the text is sent', (tester) async {
      await goster(tester, metin: 'metin');
      await tester.tap(find.text('Dikte'));
      await tester.pump();
      dikte.sonuc!('dahası', false);
      await tester.pump();
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();
      expect(dikte.durdurmaSayisi, 1);
      expect(ortam.api.isCikarMetinleri, ['metin dahası']);
    });

    for (final (kod, parca) in [
      (503, 'Asistan şu an kullanılamıyor.'),
      (429, 'çağrı sınırı doldu'),
      (502, 'Asistan yanıt veremedi'),
      (403, 'Asistanı kullanma iznin yok.'),
    ]) {
      testWidgets('a $kod answer shows its message and opens no preview', (tester) async {
        ortam.api.sesHatasi = kod;
        await goster(tester, metin: 'metin');
        await tester.tap(find.text('İşe çevir'));
        await tester.pumpAndSettle();
        expect(find.textContaining(parca), findsOneWidget);
        expect(find.textContaining('Metinden çıkanlar'), findsNothing);
        expect(ses.akis, IsAkisi.yok);
      });
    }

    testWidgets('a text over the server limit is not sent', (tester) async {
      await goster(tester, metin: 'a' * 4001);
      await tester.tap(find.text('İşe çevir'));
      await tester.pumpAndSettle();
      expect(ortam.api.isCikarMetinleri, isEmpty);
      expect(find.textContaining('en çok 4000 karakter'), findsOneWidget);
    });
  });

  group('rewrite', () {
    testWidgets('Özetle shows the result and replaces the text only when accepted', (tester) async {
      await goster(tester, metin: 'uzun bir metin');
      await tester.tap(find.text('Özetle'));
      await tester.pumpAndSettle();
      expect(ortam.api.yenidenYazIstekleri.single, ('uzun bir metin', YenidenYazKipi.ozet));
      expect(find.text('Kısa özet.'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(alan(tester), 'uzun bir metin');

      await tester.tap(find.text('Özetle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metnin yerine koy'));
      await tester.pumpAndSettle();
      expect(alan(tester), 'Kısa özet.');
    });

    testWidgets('Maddele asks for the bullet kind', (tester) async {
      ortam.api.yenidenYazSonucu = '- bir\n- iki';
      await goster(tester, metin: 'bir ve iki');
      await tester.tap(find.text('Maddele'));
      await tester.pumpAndSettle();
      expect(ortam.api.yenidenYazIstekleri.single.$2, YenidenYazKipi.madde);
      await tester.tap(find.text('Metnin yerine koy'));
      await tester.pumpAndSettle();
      expect(alan(tester), '- bir\n- iki');
    });

    testWidgets('a failure leaves the text alone and says why', (tester) async {
      ortam.api.sesHatasi = 503;
      await goster(tester, metin: 'metin');
      await tester.tap(find.text('Özetle'));
      await tester.pumpAndSettle();
      expect(alan(tester), 'metin');
      expect(find.text('Asistan şu an kullanılamıyor.'), findsOneWidget);
    });
  });
}
