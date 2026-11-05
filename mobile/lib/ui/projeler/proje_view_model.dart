import '../../data/models/beyin.dart';
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
}
