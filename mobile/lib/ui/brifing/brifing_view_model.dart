import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/brifing.dart';
import '../../data/repositories/brifing_repository.dart';
import '../core/hata_metni.dart';

/// A Turkish message for a failed briefing call.
String brifingHataMetni(Object hata, {String islem = 'Brifing alınamadı'}) {
  if (hata is DioException) {
    switch (hata.response?.statusCode) {
      case 404:
        return 'Brifing henüz hazır değil. Ayarlanan saatten sonra tekrar dene.';
      case 429:
        return 'Bugünlük yenileme sınırı doldu.';
      case 503:
        return 'Brifing şu an hazırlanamıyor. Biraz sonra tekrar dene.';
      case 403:
        return 'Brifingi okuma iznin yok.';
    }
  }
  return hataMetni(hata, islem: islem);
}

/// The briefing screen: today's cards, a thumb on each, a new briefing on request (the Sahip). Without a connection the
/// last briefing the phone kept is shown, and the screen says so.
class BrifingViewModel extends ChangeNotifier {
  BrifingViewModel({required this._repo, required this._yenileyebilir});

  final BrifingRepository _repo;

  /// Whether the user may ask for a new briefing (the Sahip).
  final bool Function() _yenileyebilir;
  bool _atildi = false;

  bool _yukleniyor = true;
  bool get yukleniyor => _yukleniyor;

  Brifing? _brifing;
  Brifing? get brifing => _brifing;

  /// False: the briefing on screen is the last one the phone kept, not today's.
  bool _guncel = true;
  bool get guncel => _guncel;

  /// Why nothing could be shown (no briefing on the phone either); null when there is one.
  String? _hata;
  String? get hata => _hata;

  /// A one-off message for the person (a vote that did not go through...); the screen shows it and clears it.
  String? _mesaj;
  String? get mesaj => _mesaj;

  bool _mesgul = false;

  /// A vote or a new briefing is on its way.
  bool get mesgul => _mesgul;

  bool get yenileyebilir => _yenileyebilir();

  Future<void> yukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      final okuma = await _repo.bugun();
      _brifing = okuma.brifing;
      _guncel = okuma.guncel;
    } on Object catch (e) {
      // Nothing on the phone to fall back on: what is already on screen (an older read) stays.
      _hata = _brifing == null ? brifingHataMetni(e) : null;
      if (_brifing != null) _mesaj = brifingHataMetni(e);
    }
    _yukleniyor = false;
    if (!_atildi) notifyListeners();
  }

  /// A thumb on card [sira]; the same thumb again takes it back.
  Future<void> oyVer(int sira, int oy) async {
    final brifing = _brifing;
    if (brifing == null || _mesgul) return;
    // Votes are only for today's briefing; an old one is shown for reading.
    if (!_guncel) {
      _mesaj = 'Çevrimdışısın: oy gönderilmedi. Bağlantı gelince tekrar dene.';
      notifyListeners();
      return;
    }
    final mevcut = brifing.kartlar.where((k) => k.sira == sira).firstOrNull?.oy ?? 0;
    final yeni = mevcut == oy ? 0 : oy;
    _mesgul = true;
    notifyListeners();
    try {
      _brifing = await _repo.oyVer(brifing, sira, yeni);
    } on Object catch (e) {
      _mesaj = cevrimdisiHata(e) ? 'Çevrimdışısın: oy gönderilmedi. Bağlantı gelince tekrar dene.' : brifingHataMetni(e, islem: 'Oy verilemedi');
    }
    _mesgul = false;
    if (!_atildi) notifyListeners();
  }

  /// Asks the server for a new briefing (the Sahip; three a day).
  Future<void> yenile() async {
    if (_mesgul || !_yenileyebilir()) return;
    _mesgul = true;
    notifyListeners();
    try {
      _brifing = await _repo.yenile();
      _guncel = true;
      _hata = null;
    } on Object catch (e) {
      _mesaj = brifingHataMetni(e, islem: 'Brifing yenilenemedi');
    }
    _mesgul = false;
    if (!_atildi) notifyListeners();
  }

  /// The screen showed [mesaj]; clears it.
  String? mesajiAl() {
    final m = _mesaj;
    _mesaj = null;
    return m;
  }

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}
