import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/ses.dart';
import 'package:kafamdakiler/data/services/api_service.dart';

import 'fake_adapter.dart';

void main() {
  group('IsOnerisi', () {
    test('toJson leaves out what is not set, so the server sees only the fields of the kind', () {
      const o = IsOnerisi(tur: IsOnerisi.hatirlatici, baslik: 'Ara', gun: '2026-11-08', saat: '09:00');
      expect(o.toJson(), {'tur': 'hatirlatici-kur', 'baslik': 'Ara', 'gun': '2026-11-08', 'saat': '09:00'});
    });

    test('duzelt changes the four fields and keeps the rest; a null clears an optional one', () {
      const o = IsOnerisi(
        tur: IsOnerisi.hatirlatici,
        baslik: 'Ara',
        gun: '2026-11-08',
        saat: '09:00',
        tekrar: 'haftalik',
        kaynakParca: 'yarın ara',
        guven: 0.8,
      );
      final d = o.duzelt(baslik: 'Ali\'yi ara', gun: '2026-11-09');
      expect(d.baslik, 'Ali\'yi ara');
      expect(d.gun, '2026-11-09');
      expect(d.saat, isNull);
      expect(d.tekrar, 'haftalik');
      expect(d.kaynakParca, 'yarın ara');
      expect(d.guven, 0.8);
    });

    test('a suggestion under the threshold is "not sure"', () {
      expect(const IsOnerisi(tur: IsOnerisi.gorev, baslik: 'x', guven: 0.69).eminDegil, isTrue);
      expect(const IsOnerisi(tur: IsOnerisi.gorev, baslik: 'x', guven: 0.7).eminDegil, isFalse);
      expect(const IsOnerisi(tur: IsOnerisi.gorev, baslik: 'x').eminDegil, isFalse);
    });
  });

  group('ApiService voice calls', () {
    late FakeAdapter adapter;
    late ApiService api;

    ApiService kur(ResponseBody Function(RequestOptions) yanit) {
      adapter = FakeAdapter(yanit);
      return ApiService(Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adapter);
    }

    test('isCikar sends the text and reads the preview with the skipped ones', () async {
      api = kur((_) => jsonYanit(200, {
            'bugun': '2026-11-07',
            'haftaninGunu': 'Cumartesi',
            'oneriler': [
              {'tur': 'plan-ekle', 'baslik': 'Raporu bitir', 'gun': '2026-11-13', 'tahminDk': 60, 'guven': 0.9, 'kaynakParca': 'Cuma raporu bitir'},
            ],
            'atlananlar': [
              {'tur': 'gorev-ekle', 'baslik': 'X', 'neden': 'Proje yok'},
            ],
          }));
      final yanit = await api.isCikar('Cuma raporu bitir');
      expect(adapter.istekler.single.path, '/api/is-cikar');
      expect(adapter.istekler.single.data, {'metin': 'Cuma raporu bitir'});
      expect(yanit.oneriler.single.tahminDk, 60);
      expect(yanit.atlananlar.single.neden, 'Proje yok');
    });

    test('isCikarUygula takes 207 as an answer and keeps each result', () async {
      api = kur((_) => jsonYanit(207, {
            'uygulanan': 1,
            'basarisiz': 1,
            'sonuclar': [
              {'sira': 0, 'durum': 'uygulandi', 'eylem': {'id': 'e1'}},
              {'sira': 1, 'durum': 'hata', 'mesaj': 'Olmadı'},
            ],
          }));
      final yanit = await api.isCikarUygula(const [
        IsOnerisi(tur: IsOnerisi.plan, baslik: 'A', gun: '2026-11-13'),
        IsOnerisi(tur: IsOnerisi.gorev, baslik: 'B', proje: 'kitap-kulubu'),
      ]);
      expect(adapter.istekler.single.path, '/api/is-cikar/uygula');
      expect((adapter.istekler.single.data as Map)['secilenler'], [
        {'tur': 'plan-ekle', 'baslik': 'A', 'gun': '2026-11-13'},
        {'tur': 'gorev-ekle', 'baslik': 'B', 'proje': 'kitap-kulubu'},
      ]);
      expect(yanit.uygulanan, 1);
      expect(yanit.basarisiz, 1);
      expect(yanit.sonuclar.first.uygulandi, isTrue);
      expect(yanit.sonuclar.last.mesaj, 'Olmadı');
    });

    test('metniYenidenYaz sends the kind by name and returns the plain text', () async {
      api = kur((_) => jsonYanit(200, {'metin': '- bir\n- iki'}));
      final metin = await api.metniYenidenYaz('bir ve iki', YenidenYazKipi.madde);
      expect(adapter.istekler.single.path, '/api/metin/yeniden-yaz');
      expect(adapter.istekler.single.data, {'metin': 'bir ve iki', 'kip': 'madde'});
      expect(metin, '- bir\n- iki');
    });
  });
}
