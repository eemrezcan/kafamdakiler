import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/hatirlatici.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/hatirlatici_repository.dart';
import '../core/hata_metni.dart';

/// The reminders list: Açık / Tamam / Arşiv tabs. The open ones come soonest first (overdue on top), the others
/// newest first. Yaptım and Ertele write to the phone's queue first, like every other write.
class HatirlaticiListeViewModel extends ChangeNotifier {
  HatirlaticiListeViewModel({required this._repo, required this._esitleyici, DateTime Function()? simdi})
      : _simdi = simdi ?? DateTime.now {
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
    _gorulenGonderim = _esitleyici.gonderimSayisi;
  }

  final HatirlaticiRepository _repo;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;
  late int _gorulenGonderim;
  bool _atildi = false;

  DateTime get simdi => _simdi();

  List<Hatirlatici>? _liste;
  List<Hatirlatici>? get liste => _liste;

  HatirlaticiDurumu _durum = HatirlaticiDurumu.acik;
  HatirlaticiDurumu get durum => _durum;

  void durumSec(HatirlaticiDurumu durum) {
    _durum = durum;
    notifyListeners();
  }

  int sayi(HatirlaticiDurumu durum) => (_liste ?? const []).where((h) => h.durum == durum).length;

  /// The rows of the selected tab.
  List<Hatirlatici> get gosterilen {
    final satirlar = (_liste ?? const <Hatirlatici>[]).where((h) => h.durum == _durum).toList();
    // The repository sorts soonest first; closed ones are shown newest first.
    return _durum == HatirlaticiDurumu.acik ? satirlar : satirlar.reversed.toList();
  }

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

  Future<void> yaptim(String id) async {
    await _repo.yaptim(id);
    unawaited(_esitleyici.gonder());
  }

  Future<void> ertele(String id, String sure) async {
    await _repo.ertele(id, sure);
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
