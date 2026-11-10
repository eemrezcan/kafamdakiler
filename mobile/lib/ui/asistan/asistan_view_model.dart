import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/asistan.dart';
import '../../data/models/brifing.dart';
import '../../data/models/eylem.dart';
import '../../data/repositories/asistan_repository.dart';
import '../../data/repositories/brifing_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../brifing/brifing_gorunum.dart';

/// The Asistan tab (K-0024): the single feed, its filters, the one input and what can be done on an item (answer a question,
/// approve or refuse an action, undo a result, a thumb on a briefing card).
///
/// Writes go to the phone's queue first and show on the feed at once; the sender runs in the background and the feed is read
/// again when something reached the server. Without a connection the last page the phone kept is shown.
class AsistanViewModel extends ChangeNotifier {
  AsistanViewModel({
    required this._repo,
    required this._brifing,
    required this._esitleyici,
  }) : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final AsistanRepository _repo;
  final BrifingRepository _brifing;
  final Esitleyici _esitleyici;
  int _gorulenGonderim;
  var _kapandi = false;

  String _suzgec = AkisSuzgeci.hepsi;
  String get suzgec => _suzgec;

  /// The feed on screen, newest first, for the chosen filter.
  List<AkisOgesi>? _liste;
  List<AkisOgesi>? get liste => _liste;

  /// The unfiltered newest page: the chips count from it.
  List<AkisOgesi> _tum = const [];

  int get bekleyenSayisi => _tum.where((o) => o.bekleyenMi).length;
  int get islerSayisi => _tum.where((o) => o.tur == AkisTuru.isKarti).length;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  String? _hata;
  String? get hata => _hata;

  bool _dahaVar = false;
  bool get dahaVar => _dahaVar;

  bool _dahaYukleniyor = false;
  bool get dahaYukleniyor => _dahaYukleniyor;

  String? _mesaj;

  /// A one-off message for the person (a vote that did not go through...); taking it clears it.
  String? mesajiAl() {
    final m = _mesaj;
    _mesaj = null;
    return m;
  }

  var _istekNo = 0;

  Future<void> yukle() async {
    final no = ++_istekNo;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _esitleyici.gonder();
      final sonuc = await _repo.ilkSayfa(suzgec: _suzgec);
      if (no != _istekNo) return;
      _liste = sonuc.liste;
      _cevrimdisi = sonuc.cevrimdisi;
      _dahaVar = !sonuc.cevrimdisi && _sunucuOgesi(sonuc.liste) >= AsistanRepository.sayfaBoyu;
      if (_suzgec == AkisSuzgeci.hepsi) {
        _tum = sonuc.liste;
      } else {
        // The chips count from the unfiltered page; it is read quietly beside the filtered one.
        try {
          _tum = (await _repo.ilkSayfa()).liste;
        } on DioException {
          // The counts keep their last values.
        }
      }
    } on DioException catch (e) {
      if (no == _istekNo) {
        _hata = e.response != null
            ? 'Asistan akışı alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
            : 'Asistan akışı alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
      }
    } finally {
      if (no == _istekNo) _yukleniyor = false;
      if (!_kapandi) notifyListeners();
    }
  }

  static int _sunucuOgesi(List<AkisOgesi> liste) => liste.where((o) => !o.id.startsWith('yerel:')).length;

  Future<void> suzgecDegistir(String suzgec) async {
    if (suzgec == _suzgec) return;
    _suzgec = suzgec;
    _liste = null;
    notifyListeners();
    await _yerelYenile();
    await yukle();
  }

  /// The older page: the one before the oldest item the server sent.
  Future<void> dahaYukle() async {
    final liste = _liste;
    if (liste == null || _dahaYukleniyor || !_dahaVar) return;
    final sunucudan = liste.where((o) => !o.id.startsWith('yerel:'));
    if (sunucudan.isEmpty) return;
    _dahaYukleniyor = true;
    notifyListeners();
    try {
      final sayfa = await _repo.dahaEski(sunucudan.last.zaman, suzgec: _suzgec);
      final bilinen = {for (final o in liste) o.id};
      _liste = [...liste, for (final o in sayfa) if (!bilinen.contains(o.id)) o];
      _dahaVar = sayfa.length >= AsistanRepository.sayfaBoyu;
    } on DioException {
      _mesaj = 'Daha eski kayıtlar alınamadı.';
    } finally {
      _dahaYukleniyor = false;
      if (!_kapandi) notifyListeners();
    }
  }

  /// A write on the phone: the feed is laid out again from the kept page with the queue on top (no network).
  Future<void> _yerelYenile() async {
    final yerel = await _repo.yerel(suzgec: _suzgec);
    if (_kapandi || yerel == null) return;
    _liste = yerel;
    notifyListeners();
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi == _gorulenGonderim) return;
    _gorulenGonderim = _esitleyici.gonderimSayisi;
    yukle();
  }

  // Writes.

  /// The one input: text, a photo, or both.
  Future<void> gonder({String? metin, String? fotografKaynagi, String kaynak = AsistanKaynagi.yazi}) async {
    await _repo.girdiGonder(metin: metin, fotografKaynagi: fotografKaynagi, kaynak: kaynak);
    unawaited(_esitleyici.gonder());
  }

  Future<void> cevapla(AsistanSorusu soru, String cevap) async {
    await _repo.cevapla(soru.id, cevap);
    unawaited(_esitleyici.gonder());
  }

  Future<void> onayla(Eylem eylem) async {
    await _repo.onayla(eylem);
    unawaited(_esitleyici.gonder());
  }

  Future<void> reddet(Eylem eylem) async {
    await _repo.reddet(eylem);
    unawaited(_esitleyici.gonder());
  }

  Future<void> sonucuOnayla(AsistanSonucu sonuc) async {
    await _repo.sonucuOnayla(sonuc);
    unawaited(_esitleyici.gonder());
  }

  Future<void> sonucuGec(AsistanSonucu sonuc) async {
    await _repo.sonucuGec(sonuc);
    unawaited(_esitleyici.gonder());
  }

  Future<void> geriAl(AsistanSonucu sonuc) async {
    await _repo.geriAl(sonuc);
    unawaited(_esitleyici.gonder());
  }

  /// An input the server refused: taken off the feed.
  Future<void> girdiyiSil(AkisOgesi o) => _repo.girdiyiSil(o.id.replaceFirst('yerel:', ''));

  /// A thumb on a card of the briefing in the feed; the same thumb again takes it back. A vote needs the server.
  Future<void> oyVer(AkisOgesi o, BrifingKarti kart, int oy) async {
    final brifing = o.brifing;
    if (brifing == null) return;
    try {
      final yeni = await _brifing.oyVer(brifing, kart.sira, kart.oy == oy ? 0 : oy);
      final liste = _liste;
      if (liste != null) {
        _liste = [for (final x in liste) x.id == o.id ? x.kopya(brifing: yeni) : x];
        notifyListeners();
      }
    } on Object catch (e) {
      _mesaj = brifingHataMetni(e, islem: 'Oy verilemedi');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _kapandi = true;
    _repo.removeListener(_yerelYenile);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
