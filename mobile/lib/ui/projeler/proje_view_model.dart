import 'dart:async';

import '../../data/models/beyin.dart';
import '../../data/models/proje_repo.dart';
import '../../data/repositories/beyin_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/gun_plani_repository.dart';
import '../core/beyin_yukleyici.dart';

/// The "Projeler" tab: the brain's projects. Offline, the list kept on the phone is shown.
class ProjeListeViewModel extends BeyinYukleyici<({List<ProjeOzet> liste, bool cevrimdisi})> {
  ProjeListeViewModel({required this._repo});

  final BeyinRepository _repo;

  @override
  Future<({List<ProjeOzet> liste, bool cevrimdisi})> getir() => _repo.projeleriGetir();
}

/// One project: status, next step, open tasks, last journal lines.
///
/// Task writes (add, finish, split over days) go through the same phone queue as the ones on the "Bugün" plan card, so they
/// work offline and are sent in the background. The project is read again once something has been sent.
class ProjeDetayViewModel extends BeyinYukleyici<ProjeDetay> {
  ProjeDetayViewModel({
    required this._repo,
    required this._gunPlani,
    required this._esitleyici,
    required this.kimlik,
  }) : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final BeyinRepository _repo;
  final GunPlaniRepository _gunPlani;
  final Esitleyici _esitleyici;
  final String kimlik;
  int _gorulenGonderim;

  /// Tasks finished on the phone and not seen as finished by the server yet; they are left off the open list at once.
  final Set<String> _bitirilen = {};
  Set<String> get bitirilen => _bitirilen;

  /// The projects the phone knows, with this one first (the new-task form starts on the first project).
  Future<List<ProjeOzet>> projeler() async {
    final liste = await _gunPlani.projeler();
    final bu = veri;
    return [
      ProjeOzet(kimlik: kimlik, baslik: bu?.baslik ?? kimlik),
      ...liste.where((p) => p.kimlik != kimlik),
    ];
  }

  Future<void> gorevEkle({required String baslik, required String proje, DateTime? bitis}) =>
      _yaz(() => _gunPlani.gorevEkle(baslik: baslik, proje: proje, bitis: bitis));

  Future<void> gorevBitir(String gorevKimlik) async {
    _bitirilen.add(gorevKimlik);
    notifyListeners();
    await _yaz(() => _gunPlani.gorevBitir(gorevKimlik));
  }

  /// Splits the task over [gunSayisi] days starting today.
  Future<void> bol(String gorevKimlik, int gunSayisi) =>
      _yaz(() => _gunPlani.gunlereBol(gorevKimlik, gunSayisi: gunSayisi, baslangic: _gunPlani.bugun));

  Future<void> _yaz(Future<void> Function() yaz) async {
    await yaz();
    unawaited(_esitleyici.gonder());
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi == _gorulenGonderim) return;
    _gorulenGonderim = _esitleyici.gonderimSayisi;
    _bitirilen.clear();
    unawaited(yukle());
  }

  @override
  Future<ProjeDetay> getir() => _repo.proje(kimlik);

  /// The repository card, read apart from the project so a slow or failing GitHub never holds the page back.
  /// Null while loading and when no repository is linked ([repoYuklendi] tells the two apart).
  ProjeRepoOzeti? _repoOzeti;
  ProjeRepoOzeti? get repoOzeti => _repoOzeti;

  bool _repoYuklendi = false;
  bool get repoYuklendi => _repoYuklendi;

  /// The card could not be read (offline, no permission, server error).
  bool _repoHatasi = false;
  bool get repoHatasi => _repoHatasi;

  bool _atildi = false;

  @override
  Future<void> yukle() async {
    await Future.wait([super.yukle(), _repoYukle()]);
  }

  Future<void> _repoYukle() async {
    try {
      final ozet = await _repo.projeRepo(kimlik);
      if (_atildi) return;
      _repoOzeti = ozet;
      _repoHatasi = false;
    } on Object {
      if (_atildi) return;
      _repoOzeti = null;
      _repoHatasi = true;
    }
    _repoYuklendi = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _atildi = true;
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
