import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/beyin.dart';
import '../../data/models/gelen.dart';
import '../../data/repositories/beyin_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/eylem_repository.dart';
import '../../data/repositories/gelen_repository.dart';
import '../core/hata_metni.dart';

/// The inbox: the cards with their suggestions. Every decision (approve, reject, place, delete) writes to the phone's
/// queue first, like every other write, so it works offline. "Suggest again" needs the network.
class GelenListeViewModel extends ChangeNotifier {
  GelenListeViewModel({
    required this._repo,
    required this._eylemler,
    required this._esitleyici,
    this._beyin,
  }) {
    _repo.addListener(_yerelYenile);
    _eylemler.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
    _gorulenGonderim = _esitleyici.gonderimSayisi;
  }

  final GelenRepository _repo;
  final EylemRepository _eylemler;
  final Esitleyici _esitleyici;
  final BeyinRepository? _beyin;
  late int _gorulenGonderim;
  bool _atildi = false;

  List<GelenKarti>? _liste;
  List<GelenKarti>? get liste => _liste;

  /// Cards put aside with "Sonra" (a swipe to the left). They go to the end of the list until the screen is left.
  final Set<String> _sonra = {};

  /// Cards with a suggestion first (the oldest first, the brain's order), then the others; the ones put aside last.
  List<GelenKarti> get kartlar {
    final liste = _liste ?? const <GelenKarti>[];
    return [
      ...liste.where((k) => !_sonra.contains(k.kimlik) && k.oneri != null),
      ...liste.where((k) => !_sonra.contains(k.kimlik) && k.oneri == null),
      ...liste.where((k) => _sonra.contains(k.kimlik)),
    ];
  }

  bool sonraMi(String kimlik) => _sonra.contains(kimlik);

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  /// Claude is set up on the server; "Yeniden öner" is hidden while it is not. False until the server says so.
  bool _asistanBagli = false;
  bool get asistanBagli => _asistanBagli;

  Future<void> _asistanDurumunuAl() async {
    final bagli = await _repo.asistanBagliMi();
    if (_atildi || bagli == _asistanBagli) return;
    _asistanBagli = bagli;
    notifyListeners();
  }

  /// Fetches the server's list; offline, the cached list is shown.
  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    if (!_asistanBagli) unawaited(_asistanDurumunuAl());
    try {
      final sonuc = await _repo.listele();
      _liste = sonuc.liste;
      _cevrimdisi = sonuc.cevrimdisi;
    } on DioException catch (e) {
      _hata = e.response?.statusCode == 503
          ? 'Beyin bu sunucuda bağlı değil; gelen kutusu boş görünüyor.'
          : hataMetni(e, islem: 'Gelen kutusu alınamadı');
      _liste ??= await _repo.yerelListe();
    } finally {
      _yukleniyor = false;
      if (!_atildi) notifyListeners();
    }
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi != _gorulenGonderim) {
      _gorulenGonderim = _esitleyici.gonderimSayisi;
      unawaited(yukle());
    } else {
      unawaited(_yerelYenile());
    }
  }

  Future<void> _yerelYenile() async {
    final liste = await _repo.yerelListe();
    if (_atildi) return;
    _liste = liste;
    notifyListeners();
  }

  /// Approve the card's suggestion: the approval queue's own decision, sent by the same sender.
  Future<void> uygula(GelenKarti kart) async {
    final oneri = kart.oneri;
    if (oneri == null) return;
    await _eylemler.uygula(oneri.eylemId);
    unawaited(_esitleyici.gonder());
  }

  Future<void> reddet(GelenKarti kart, {bool birDahaOnerme = false}) async {
    final oneri = kart.oneri;
    if (oneri == null) return;
    await _eylemler.reddet(oneri.eylemId, birDahaOnerme: birDahaOnerme);
    unawaited(_esitleyici.gonder());
  }

  /// "Sonra": the card moves to the end of the list, nothing is decided.
  void sonraBak(String kimlik) {
    _sonra.add(kimlik);
    notifyListeners();
  }

  Future<void> isle(String kimlik, GelenIsleGirdi girdi) async {
    await _repo.isle(kimlik, girdi);
    unawaited(_esitleyici.gonder());
  }

  Future<void> sil(String kimlik) async {
    await _repo.sil(kimlik);
    unawaited(_esitleyici.gonder());
  }

  /// Asks Claude again. Returns the message to show.
  Future<String> oneriIste(String kimlik) async {
    try {
      final yanit = await _repo.oneriIste(kimlik);
      await yukle();
      return switch (yanit.durum) {
        'olustu' => 'Öneri hazır.',
        'laptoptaIslenecek' => 'Yeni etiket gerekiyor: kart laptopta işlenecek olarak işaretlendi.',
        _ => yanit.mesaj ?? 'Öneri kaydedilmedi.',
      };
    } on DioException catch (e) {
      return switch (e.response?.statusCode) {
        null => 'Çevrimdışısın: öneri istemek için bağlantı gerekiyor.',
        409 => 'Bu kart için bekleyen bir öneri var; önce onu uygula ya da reddet.',
        422 => _problemDetayi(e) ?? 'Bu karta öneri istenemez.',
        429 => 'Claude için bugünlük sınır doldu. Yarın tekrar dene ya da kartı elle yerleştir.',
        502 => 'Claude öneri üretemedi ya da önerisi kurallara uymadı. Kart yerinde duruyor.',
        503 => 'Claude ya da beyin bu sunucuda bağlı değil.',
        _ => hataMetni(e, islem: 'Öneri istenemedi'),
      };
    }
  }

  /// The projects offered for a hand-made placement (the cached list works offline).
  Future<List<ProjeOzet>> projeler() async => (await _beyin?.yerelProjeler()) ?? const [];

  /// The tag and folder pick lists from the server; null when it cannot be asked (the dialog then falls back).
  Future<GelenSecenekleri?> secenekler() => _repo.secenekler();

  static String? _problemDetayi(DioException e) {
    final veri = e.response?.data;
    return veri is Map && veri['detail'] is String ? veri['detail'] as String : null;
  }

  @override
  void dispose() {
    _atildi = true;
    _repo.removeListener(_yerelYenile);
    _eylemler.removeListener(_yerelYenile);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
