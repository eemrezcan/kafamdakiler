import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/oge.dart';
import '../../data/models/oturum.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../core/hata_metni.dart';

class OgeDetayViewModel extends ChangeNotifier {
  OgeDetayViewModel({required this._repo, required this._esitleyici, required this.id})
      : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _repo.addListener(yukle);
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final AliskanlikRepository _repo;
  final Esitleyici _esitleyici;
  final String id;
  int _gorulenGonderim;

  Oge? _oge;
  Oge? get oge => _oge;

  /// Unit ("sayfa") and colour key of the habit, from the cached habit list.
  String _birim = '';
  String get birim => _birim;
  String _renk = 'violet';
  String get renk => _renk;

  /// Newest first; null when offline (history is not cached).
  List<Oturum>? _oturumlar;
  List<Oturum>? get oturumlar => _oturumlar;

  bool _yukleniyor = true;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  Future<void> yukle() async {
    _hata = null;
    try {
      _oge = await _repo.oge(id);
      final aliskanlik = (await _repo.yerelListe()).where((a) => a.id == _oge!.aliskanlikId).firstOrNull;
      _birim = aliskanlik?.birim ?? '';
      _renk = aliskanlik?.renk ?? 'violet';
      try {
        _oturumlar = await _repo.oturumlar(id);
      } on DioException {
        _oturumlar = null;
      }
    } on DioException catch (e) {
      _hata = hataMetni(e, islem: 'Öğe yüklenemedi');
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Each returns an error message, or null on success.
  Future<String?> oturumGuncelle(Oturum o, double bitisKonum, int? dakika) =>
      _calistir('Oturum güncellenemedi', () => _repo.oturumGuncelle(o.id, OturumGuncelle(bitisKonum: bitisKonum, dakika: dakika)));

  Future<String?> oturumSil(Oturum o) => _calistir('Oturum silinemedi', () => _repo.oturumSil(o.id));

  Future<String?> ogeSil() => _calistir('Silinemedi', () => _repo.ogeSil(id));

  Future<String?> _calistir(String islem, Future<void> Function() cagri) async {
    try {
      await cagri();
      return null;
    } on DioException catch (e) {
      return hataMetni(e, islem: islem);
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
