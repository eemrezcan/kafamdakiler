import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/eylem.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/eylem_repository.dart';
import '../core/hata_metni.dart';

/// The approval queue: the waiting actions (newest first), the recently applied ones (to undo) and the failed ones.
/// Every decision writes to the phone's queue first, like every other write, so it works offline.
class EylemListeViewModel extends ChangeNotifier {
  EylemListeViewModel({required this._repo, required this._esitleyici}) {
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
    _gorulenGonderim = _esitleyici.gonderimSayisi;
  }

  /// How many applied actions are listed.
  static const sonUygulananSayisi = 10;

  final EylemRepository _repo;
  final Esitleyici _esitleyici;
  late int _gorulenGonderim;
  bool _atildi = false;

  List<Eylem>? _liste;
  List<Eylem>? get liste => _liste;

  /// Waiting, newest first.
  List<Eylem> get bekleyenler =>
      ((_liste ?? const <Eylem>[]).where((e) => e.durum == EylemDurumu.bekliyor).toList())
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Applied, the latest first.
  List<Eylem> get sonUygulananlar {
    final uygulananlar = (_liste ?? const <Eylem>[]).where((e) => e.durum == EylemDurumu.uygulandi).toList()
      ..sort((a, b) => _karar(b).compareTo(_karar(a)));
    return uygulananlar.take(sonUygulananSayisi).toList();
  }

  List<Eylem> get hatalilar => (_liste ?? const <Eylem>[]).where((e) => e.durum == EylemDurumu.hatali).toList();

  static DateTime _karar(Eylem e) => e.uygulamaAni ?? e.kararAni ?? e.createdAt;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  /// Fetches the server's list; offline, the cached list is shown.
  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      final sonuc = await _repo.listele();
      _liste = sonuc.liste;
      _cevrimdisi = sonuc.cevrimdisi;
    } on DioException catch (e) {
      _hata = hataMetni(e, islem: 'Liste alınamadı');
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

  Future<void> uygula(String id) async {
    await _repo.uygula(id);
    unawaited(_esitleyici.gonder());
  }

  Future<void> reddet(String id, {bool birDahaOnerme = false}) async {
    await _repo.reddet(id, birDahaOnerme: birDahaOnerme);
    unawaited(_esitleyici.gonder());
  }

  Future<void> geriAl(String id) async {
    await _repo.geriAl(id);
    unawaited(_esitleyici.gonder());
  }

  @override
  void dispose() {
    _atildi = true;
    _repo.removeListener(_yerelYenile);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
