import '../../data/models/beyin.dart';
import '../../data/models/proje_repo.dart';
import '../../data/repositories/beyin_repository.dart';
import '../core/beyin_yukleyici.dart';

/// The "Projeler" tab: the brain's projects. Offline, the list kept on the phone is shown.
class ProjeListeViewModel extends BeyinYukleyici<({List<ProjeOzet> liste, bool cevrimdisi})> {
  ProjeListeViewModel({required this._repo});

  final BeyinRepository _repo;

  @override
  Future<({List<ProjeOzet> liste, bool cevrimdisi})> getir() => _repo.projeleriGetir();
}

/// One project: status, next step, open tasks, last journal lines.
class ProjeDetayViewModel extends BeyinYukleyici<ProjeDetay> {
  ProjeDetayViewModel({required this._repo, required this.kimlik});

  final BeyinRepository _repo;
  final String kimlik;

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
    super.dispose();
  }
}
