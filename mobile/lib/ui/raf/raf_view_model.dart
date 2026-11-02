import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/models/oge.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';

/// The shelf page of one Raf habit (opened from the habit, as on the web):
/// its items split into the four shelves.
class RafViewModel extends ChangeNotifier {
  RafViewModel({required this._repo, required this._esitleyici, required this.aliskanlikId})
      : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _repo.addListener(yukle);
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final AliskanlikRepository _repo;
  final Esitleyici _esitleyici;
  int _gorulenGonderim;

  final String aliskanlikId;

  Aliskanlik? _secili;
  Aliskanlik? get secili => _secili;

  List<Oge> _ogeler = const [];
  List<Oge> ogeleri(OgeDurumu durum) => [for (final o in _ogeler) if (o.durum == durum) o];

  bool _ilkYukleme = true;
  bool get ilkYukleme => _ilkYukleme;

  String? _hata;
  String? get hata => _hata;

  bool _yukleniyor = false;

  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    try {
      final liste = (await _repo.listele()).liste;
      _secili = liste.where((a) => a.id == aliskanlikId && a.tur == AliskanlikTuru.raf).firstOrNull;
      _ogeler = _secili == null ? const [] : await _repo.ogeleriListele(_secili!.id);
    } on DioException catch (e) {
      _hata = e.response != null
          ? 'Raf alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
          : 'Raf alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _yukleniyor = false;
      _ilkYukleme = false;
      notifyListeners();
    }
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi == _gorulenGonderim) return;
    _gorulenGonderim = _esitleyici.gonderimSayisi;
    yukle();
  }

  @override
  void dispose() {
    _repo.removeListener(yukle);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
