import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/repositories/aliskanlik_repository.dart';

/// The "Alışkanlıklar" tab: all habits (or the archived ones).
class AliskanlikListeViewModel extends ChangeNotifier {
  AliskanlikListeViewModel({required this._repo}) {
    _repo.addListener(yukle);
  }

  final AliskanlikRepository _repo;

  List<Aliskanlik>? _liste;
  List<Aliskanlik>? get liste => _liste;

  bool _arsiv = false;
  bool get arsiv => _arsiv;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  Future<void> arsivGoster(bool deger) {
    _arsiv = deger;
    _liste = null;
    return yukle();
  }

  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      _liste = (await _repo.listele(arsiv: _arsiv)).liste;
    } on DioException catch (e) {
      _hata = e.response != null
          ? 'Liste alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
          : 'Liste alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _repo.removeListener(yukle);
    super.dispose();
  }
}
