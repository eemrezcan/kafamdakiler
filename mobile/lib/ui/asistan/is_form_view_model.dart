import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/beyin.dart';
import '../../data/models/is_karti.dart';
import '../../data/repositories/beyin_repository.dart';
import '../../data/repositories/is_repository.dart';
import '../../utils/dogrulama.dart';
import 'is_hata.dart';

/// The "Yeni kart" form: a title, a request, where the card lives (a project of the brain, or an area) and its type
/// (`kod` has the three gates, `genel` skips them). The checks repeat the server's, so the person sees the message before a
/// request is made; the server's own sentence is shown when it still refuses.
class IsFormViewModel extends ChangeNotifier {
  IsFormViewModel({required this._repo, required this._beyin}) : _anahtar = const Uuid().v4();

  final IsRepository _repo;
  final BeyinRepository _beyin;

  /// The `Idempotency-Key` of the card being made: a send repeated after a timeout does not open it twice.
  final String _anahtar;

  static const enUzunBaslik = 200;
  static const enUzunTalep = 4000;

  /// Areas the server puts nothing in (finance and personal notes stay in the brain).
  static const kapaliAlanlar = ['finans', 'kisisel', 'projects', 'sistem'];

  String baslik = '';
  String talep = '';

  /// Where the card lives: a project (picked from the brain's list) or an area (typed).
  bool projeModu = true;
  String? proje;
  String alan = '';

  /// `kod` or `genel`.
  String tip = 'kod';

  List<ProjeOzet> projeler = const [];

  Map<String, String> hatalar = const {};
  String? genelHata;
  bool gonderiliyor = false;
  bool _atildi = false;

  /// The project list kept on the phone first, then fresh from the server when it can be reached.
  Future<void> projeleriYukle() async {
    projeler = await _beyin.yerelProjeler();
    _bildir();
    if (await _beyin.projeleriYenile()) {
      projeler = await _beyin.yerelProjeler();
      _bildir();
    }
  }

  void modSec(bool projeMi) {
    projeModu = projeMi;
    hatalar = const {};
    _bildir();
  }

  void projeSec(String? kimlik) {
    proje = kimlik;
    _bildir();
  }

  void tipSec(String yeni) {
    tip = yeni;
    _bildir();
  }

  /// The messages of the fields that are wrong, by field name; empty when the form is fine.
  static Map<String, String> dogrula({
    required String baslik,
    required String talep,
    required bool projeModu,
    String? proje,
    String alan = '',
  }) {
    final hatalar = <String, String>{};
    if (zorunluMetin(baslik, 'Başlık', max: enUzunBaslik) case final h?) hatalar['baslik'] = h;
    if (baslik.contains('\n') || baslik.contains('\r')) hatalar['baslik'] = 'Başlık tek satır olmalı.';
    if (talep.trim().length > enUzunTalep) hatalar['talep'] = 'Talep en çok $enUzunTalep karakter olabilir.';
    if (projeModu) {
      if (proje == null || proje.isEmpty) hatalar['proje'] = 'Bir proje seç.';
    } else {
      final a = alan.trim();
      if (a.isEmpty) {
        hatalar['alan'] = 'Alan gerekli.';
      } else if (a.length > 100 || !RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(a)) {
        hatalar['alan'] = 'Alan küçük harf, rakam ve tire olmalı.';
      } else if (kapaliAlanlar.contains(a)) {
        hatalar['alan'] = 'Bu alana kart açılamaz.';
      }
    }
    return hatalar;
  }

  /// Sends the form. Returns the new card's id when the brain took it, else null with [hatalar] or [genelHata] saying why.
  Future<String?> gonder() async {
    if (gonderiliyor) return null;
    hatalar = dogrula(baslik: baslik, talep: talep, projeModu: projeModu, proje: proje, alan: alan);
    genelHata = null;
    if (hatalar.isNotEmpty) {
      _bildir();
      return null;
    }

    gonderiliyor = true;
    _bildir();
    try {
      final sonuc = await _repo.ac(
        IsAcGirdi(
          baslik: baslik.trim(),
          talep: talep.trim(),
          proje: projeModu ? proje : null,
          alan: projeModu ? null : alan.trim(),
          tip: tip,
        ),
        anahtar: _anahtar,
      );
      if (sonuc.kart == null) {
        // The brain's answer was unclear: the card may exist. Not sent again by itself.
        genelHata = sonuc.uyari ?? 'Sonuç belli değil; kartı açmış olabilir. Panoya bak.';
        return null;
      }
      return sonuc.kart!.kimlik;
    } on DioException catch (e) {
      genelHata = isHataMetni(e);
      return null;
    } finally {
      gonderiliyor = false;
      _bildir();
    }
  }

  void _bildir() {
    if (!_atildi) notifyListeners();
  }

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}
