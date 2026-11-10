import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/ui/brifing/brifing_gorunum.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The words and icons of the briefing card in the assistant feed.
void main() {
  test('each kind of card has its icon; an unknown kind has the sun', () {
    expect(brifingTurIkonu(BrifingTuru.plan), LucideIcons.calendarCheck);
    expect(brifingTurIkonu(BrifingTuru.hatirlatici), LucideIcons.bell);
    expect(brifingTurIkonu(BrifingTuru.onay), LucideIcons.listChecks);
    expect(brifingTurIkonu(BrifingTuru.kapasite), LucideIcons.gauge);
    expect(brifingTurIkonu('bilinmeyen'), LucideIcons.sun);
  });

  test('the leftovers card is left out of the feed\'s cards: Bugün lists what was left itself', () {
    final b = Brifing(
      gun: '2026-11-10',
      uretimAni: DateTime.utc(2026, 11, 10, 4),
      yontem: 'hesap',
      kartlar: const [
        BrifingKarti(sira: 0, tur: BrifingTuru.plan, baslik: 'Plan', metin: 'a'),
        BrifingKarti(sira: 1, tur: BrifingTuru.kalan, baslik: 'Kalanlar', metin: 'b'),
        BrifingKarti(sira: 2, tur: BrifingTuru.kapasite, baslik: 'Kapasite', metin: 'c'),
      ],
    );
    expect(brifingKartlari(b).map((k) => k.sira), [0, 2]);
  });

  test('the messages of a failed briefing call', () {
    DioException durum(int kod) {
      final istek = RequestOptions(path: 'x');
      return DioException.badResponse(statusCode: kod, requestOptions: istek, response: Response(requestOptions: istek, statusCode: kod));
    }

    expect(brifingHataMetni(durum(404)), contains('henüz hazır değil'));
    expect(brifingHataMetni(durum(429)), contains('yenileme sınırı'));
    expect(brifingHataMetni(durum(503)), contains('hazırlanamıyor'));
    expect(brifingHataMetni(durum(403)), contains('iznin yok'));
  });

  test('a vote without a connection is told as that', () {
    final e = DioException.connectionError(requestOptions: RequestOptions(path: 'x'), reason: 'offline');
    expect(brifingHataMetni(e, islem: 'Oy verilemedi'), contains('Çevrimdışısın: oy gönderilmedi'));
  });
}
