import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/ses.dart';
import '../../data/services/api_service.dart';
import '../../data/services/baglanti_servisi.dart';
import '../../data/services/dikte_servisi.dart';
import '../core/hata_metni.dart';

/// Where the "turn into work" flow is. [yok]: not started (or closed); [yukleniyor]: Claude is working out the preview;
/// [onizleme]: the list is shown; [uygulaniyor]: the chosen ones are being sent; [sonuc]: each result is shown.
enum IsAkisi { yok, yukleniyor, onizleme, uygulaniyor, sonuc }

/// A Turkish message for a failed voice call (K2.4): the statuses the server uses for Claude being off, capped or wrong.
String sesHataMetni(Object hata, {String islem = 'İşlem tamamlanamadı'}) {
  if (hata is DioException) {
    switch (hata.response?.statusCode) {
      case 429:
        return 'Asistanın bugünkü çağrı sınırı doldu. Yarın tekrar dene.';
      case 502:
        return 'Asistan yanıt veremedi. Biraz sonra tekrar dene.';
      case 503:
        return 'Asistan şu an kullanılamıyor.';
      case 403:
        return 'Asistanı kullanma iznin yok.';
    }
  }
  return hataMetni(hata, islem: islem);
}

/// Dictation, "İşe çevir" and "Özetle / Maddele" of the capture screen (K2.4). The text itself stays in the screen's field;
/// this holds what surrounds it. Dictation works on the phone. The rest needs the server, so it is off without a connection.
class SesViewModel extends ChangeNotifier {
  SesViewModel({required this._api, required this._dikte, required this._baglanti, this.kaynak}) {
    _baglanti.varMi().then(_baglantiDegisti, onError: (Object _) {});
    _abonelik = _baglanti.degisim.listen(_baglantiDegisti, onError: (Object _) {});
    _asistanDurumunuAl();
  }

  /// The server's limit for the text of "İşe çevir" (the field itself takes more).
  static const isCikarSiniri = 4000;

  /// Where the text was written, sent along when the chosen ones are applied (`brifing` for the briefing box); null is the
  /// capture screen's default.
  final String? kaynak;

  final ApiService _api;
  final DikteServisi _dikte;
  final BaglantiServisi _baglanti;
  StreamSubscription<bool>? _abonelik;
  bool _atildi = false;

  // ---- Connection ----

  bool _cevrimici = true;
  bool get cevrimici => _cevrimici;

  void _baglantiDegisti(bool baglanti) {
    if (_atildi || baglanti == _cevrimici) return;
    _cevrimici = baglanti;
    notifyListeners();
    if (baglanti) _asistanDurumunuAl();
  }

  // ---- The assistant ----

  /// Claude is set up on the server. False until the server says so: the buttons that call Claude stay hidden while it is
  /// off, instead of failing when pressed.
  bool _asistanBagli = false;
  bool get asistanBagli => _asistanBagli;

  Future<void> _asistanDurumunuAl() async {
    if (_asistanBagli) return;
    final bagli = await _api.asistanBagliMi();
    if (_atildi || bagli == _asistanBagli) return;
    _asistanBagli = bagli;
    notifyListeners();
  }

  // ---- Dictation ----

  bool _hazirlaniyor = false;
  bool _dinliyor = false;
  bool get dinliyor => _dinliyor;

  /// Something to tell the person about the microphone (refused, no Turkish...); null when all is well.
  String? _dikteMesaji;
  String? get dikteMesaji => _dikteMesaji;

  /// The microphone permission was refused: the screen offers the phone's settings instead of a retry.
  bool _izinReddedildi = false;
  bool get izinReddedildi => _izinReddedildi;

  String _temel = '';
  String _gecerli = '';
  void Function(String)? _metinDegisti;

  static String _birlestir(String temel, String yeni) {
    if (yeni.isEmpty) return temel;
    if (temel.trim().isEmpty) return yeni;
    return '${temel.trimRight()} $yeni';
  }

  /// Starts dictation after [temel], the text already in the field. [metinDegisti] gets the whole field text each time
  /// the words so far change, so the text streams into the field while the person speaks.
  Future<void> dikteBaslat({required String temel, required void Function(String) metinDegisti}) async {
    if (_dinliyor || _hazirlaniyor) return;
    _hazirlaniyor = true;
    _dikteMesaji = null;
    _izinReddedildi = false;
    notifyListeners();
    try {
      final hazirlik = await _dikte.hazirla();
      if (_atildi) return;
      switch (hazirlik) {
        case DikteHazirlik.izinYok:
          _izinReddedildi = true;
          _dikteMesaji = 'Mikrofon izni verilmedi. Dikte için telefonun ayarlarından Kafamdakiler\'e mikrofon izni ver.';
          return;
        case DikteHazirlik.turkceYok:
          _dikteMesaji = 'Telefondaki ses tanıma Türkçe bilmiyor. Telefon ayarlarından Türkçe ses tanımayı ekle.';
          return;
        case DikteHazirlik.kullanilamaz:
          _dikteMesaji = 'Bu telefonda ses tanıma kullanılamıyor.';
          return;
        case DikteHazirlik.hazir:
          break;
      }
      _temel = temel;
      _gecerli = temel;
      _metinDegisti = metinDegisti;
      _dinliyor = true;
      notifyListeners();
      await _dikte.dinle(onSonuc: _sonucGeldi, onDurdu: _durdu, onHata: _hataGeldi);
    } on Object {
      _dinliyor = false;
      _dikteMesaji = 'Ses tanıma başlatılamadı. Tekrar dene.';
    } finally {
      _hazirlaniyor = false;
      if (!_atildi) notifyListeners();
    }
  }

  void _sonucGeldi(String metin, bool son) {
    if (_atildi || !_dinliyor) return;
    _gecerli = _birlestir(_temel, metin);
    _metinDegisti?.call(_gecerli);
    // A settled sentence becomes part of the text; a following one is added after it.
    if (son) _temel = _gecerli;
  }

  void _durdu() {
    if (_atildi || !_dinliyor) return;
    _dinliyor = false;
    _temel = _gecerli;
    notifyListeners();
  }

  void _hataGeldi(String kod) {
    if (_atildi) return;
    // Nothing was said: the listening just ends, nothing to report.
    if (kod == 'error_no_match' || kod == 'error_speech_timeout') return;
    if (kod == 'error_permission') {
      _izinReddedildi = true;
      _dikteMesaji = 'Mikrofon izni verilmedi. Dikte için telefonun ayarlarından Kafamdakiler\'e mikrofon izni ver.';
    } else {
      _dikteMesaji = 'Ses tanıma durdu ($kod). Tekrar dene.';
    }
    _dinliyor = false;
    notifyListeners();
  }

  Future<void> dikteDurdur() async {
    if (!_dinliyor) return;
    try {
      await _dikte.durdur();
    } on Object {
      // The recognizer is gone already; the state below is what matters.
    }
    _durdu();
  }

  // ---- Turn into work ("İşe çevir") ----

  IsAkisi _akis = IsAkisi.yok;
  IsAkisi get akis => _akis;

  String? _hata;
  String? get hata => _hata;

  List<IsOnerisi> _oneriler = const [];
  List<IsOnerisi> get oneriler => _oneriler;

  List<AtlananOneri> _atlananlar = const [];
  List<AtlananOneri> get atlananlar => _atlananlar;

  final Set<int> _secili = {};
  bool seciliMi(int i) => _secili.contains(i);
  int get seciliSayisi => _secili.length;

  /// The suggestions that were sent, in the order of the request, to match with the results.
  List<IsOnerisi> _gonderilen = const [];
  List<IsUygulaSonucu> _sonuclar = const [];

  /// Each sent suggestion with what happened to it.
  List<({IsOnerisi oneri, IsUygulaSonucu? sonuc})> get sonucSatirlari => [
        for (var i = 0; i < _gonderilen.length; i++)
          (oneri: _gonderilen[i], sonuc: _sonuclar.where((s) => s.sira == i).firstOrNull),
      ];

  /// The last flow added something (or may have: no answer came). Stays after [akisiKapat]; the next [isCikar] resets it.
  bool _eklendi = false;
  bool get eklendi => _eklendi;

  /// The server could not be reached while applying: nothing says whether it went through.
  bool _sonucBilinmiyor = false;
  bool get sonucBilinmiyor => _sonucBilinmiyor;

  /// Asks the server what could be done with [metin]. Nothing is saved. Starts the flow; [hata] says why it did not open.
  Future<void> isCikar(String metin) async {
    if (_akis == IsAkisi.yukleniyor || _akis == IsAkisi.uygulaniyor) return;
    final temiz = metin.trim();
    if (temiz.isEmpty) return;
    _hata = null;
    _eklendi = false;
    if (temiz.length > isCikarSiniri) {
      _hata = 'İşe çevirmek için metin en çok $isCikarSiniri karakter olabilir. Metni kısalt ya da parçala.';
      notifyListeners();
      return;
    }
    _akis = IsAkisi.yukleniyor;
    notifyListeners();
    try {
      final yanit = await _api.isCikar(temiz);
      if (_atildi) return;
      _oneriler = yanit.oneriler;
      _atlananlar = yanit.atlananlar;
      // A suggestion Claude is not sure of is not ticked: it is added only if the person chooses it.
      _secili
        ..clear()
        ..addAll([for (var i = 0; i < _oneriler.length; i++) if (!_oneriler[i].eminDegil) i]);
      _akis = IsAkisi.onizleme;
    } on Object catch (e) {
      if (_atildi) return;
      _hata = sesHataMetni(e, islem: 'Metinden iş çıkarılamadı');
      _akis = IsAkisi.yok;
    }
    notifyListeners();
  }

  void secimiDegistir(int i) {
    if (_akis != IsAkisi.onizleme) return;
    if (!_secili.remove(i)) _secili.add(i);
    notifyListeners();
  }

  /// The person corrected suggestion [i] in the preview.
  void duzelt(int i, IsOnerisi yeni) {
    if (_akis != IsAkisi.onizleme || i < 0 || i >= _oneriler.length) return;
    _oneriler = [for (var k = 0; k < _oneriler.length; k++) k == i ? yeni : _oneriler[k]];
    notifyListeners();
  }

  /// Sends the ticked suggestions. The server answers each one on its own: some may fail while the others stay applied.
  Future<void> uygula() async {
    if (_akis != IsAkisi.onizleme || _secili.isEmpty) return;
    final sirali = _secili.toList()..sort();
    _gonderilen = [for (final i in sirali) _oneriler[i]];
    _sonuclar = const [];
    _sonucBilinmiyor = false;
    _hata = null;
    _akis = IsAkisi.uygulaniyor;
    notifyListeners();
    try {
      final yanit = await _api.isCikarUygula(_gonderilen, kaynak: kaynak);
      _sonuclar = yanit.sonuclar;
    } on Object catch (e) {
      if (_atildi) return;
      // A refusal of the whole request (no permission, Claude off...) applied nothing: back to the preview. With no answer
      // at all it is not known, so the result list says so.
      if (cevrimdisiHata(e)) {
        _sonucBilinmiyor = true;
      } else {
        _hata = sesHataMetni(e, islem: 'Seçilenler eklenemedi');
        _akis = IsAkisi.onizleme;
        notifyListeners();
        return;
      }
    }
    if (_atildi) return;
    _eklendi = _sonucBilinmiyor || _sonuclar.any((s) => s.uygulandi);
    _akis = IsAkisi.sonuc;
    notifyListeners();
  }

  /// Closes the flow (the sheet was dismissed or "Kapat" was pressed).
  void akisiKapat() {
    if (_akis == IsAkisi.yukleniyor || _akis == IsAkisi.uygulaniyor) return;
    _akis = IsAkisi.yok;
    _oneriler = const [];
    _atlananlar = const [];
    _secili.clear();
    _gonderilen = const [];
    _sonuclar = const [];
    _sonucBilinmiyor = false;
    _hata = null;
    notifyListeners();
  }

  void hatayiTemizle() {
    if (_hata == null) return;
    _hata = null;
    notifyListeners();
  }

  // ---- Rewrite ("Özetle" / "Maddele") ----

  bool _yeniden = false;
  bool get yenidenYaziliyor => _yeniden;

  /// The text rewritten as [kip], or null when it failed ([hata] says why). Saves nothing: the screen decides.
  Future<String?> yenidenYaz(String metin, YenidenYazKipi kip) async {
    if (_yeniden || metin.trim().isEmpty) return null;
    _hata = null;
    if (metin.trim().length > isCikarSiniri) {
      _hata = '${kip.ad} için metin en çok $isCikarSiniri karakter olabilir. Metni kısalt.';
      notifyListeners();
      return null;
    }
    _yeniden = true;
    notifyListeners();
    try {
      return await _api.metniYenidenYaz(metin.trim(), kip);
    } on Object catch (e) {
      _hata = sesHataMetni(e, islem: 'Metin yeniden yazılamadı');
      return null;
    } finally {
      _yeniden = false;
      if (!_atildi) notifyListeners();
    }
  }

  @override
  void dispose() {
    _atildi = true;
    _abonelik?.cancel();
    if (_dinliyor) unawaited(_dikte.durdur().catchError((Object _) {}));
    super.dispose();
  }
}
