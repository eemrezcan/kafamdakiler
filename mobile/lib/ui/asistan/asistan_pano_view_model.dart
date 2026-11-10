import 'dart:async';

import '../../data/repositories/is_repository.dart';
import '../../utils/is_gorunum.dart';
import '../core/beyin_yukleyici.dart';

/// The board `/asistan`: the work cards in groups. Offline, the board last downloaded is shown ([cevrimdisi]) and the write
/// buttons are shut. A write made anywhere in the app (a card's screen, a notification button) refreshes it.
class AsistanPanoViewModel extends BeyinYukleyici<({IsPanosu pano, bool cevrimdisi})> {
  AsistanPanoViewModel({required this._repo}) {
    _repo.addListener(_yazildi);
  }

  final IsRepository _repo;

  @override
  Future<({IsPanosu pano, bool cevrimdisi})> getir() async {
    final sonuc = await _repo.panoyuGetir();
    return (pano: IsPanosu.grupla(sonuc.liste), cevrimdisi: sonuc.cevrimdisi);
  }

  void _yazildi() => unawaited(yukle());

  @override
  void dispose() {
    _repo.removeListener(_yazildi);
    super.dispose();
  }
}
