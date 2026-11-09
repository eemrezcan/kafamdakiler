import 'dart:async';

import '../../data/models/is_karti.dart';
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

/// The "Asistan" card of the Bugün tab: how many cards wait on the person, how many the VPS has, how many finished this week,
/// and the titles of the first two that wait. A failed read with nothing kept on the phone hides the card; it never blocks the tab.
class AsistanOzetViewModel extends BeyinYukleyici<({IsPanosu pano, bool cevrimdisi})> {
  AsistanOzetViewModel({required this._repo}) {
    _repo.addListener(_yazildi);
  }

  final IsRepository _repo;

  @override
  Future<({IsPanosu pano, bool cevrimdisi})> getir() async {
    final sonuc = await _repo.panoyuGetir();
    return (pano: IsPanosu.grupla(sonuc.liste), cevrimdisi: sonuc.cevrimdisi);
  }

  int? get sende => veri?.pano.sendeBekleyen.length;

  int? get vpste => veri?.pano.vpstekiSayi;

  int? get buHaftaBiten => veri?.pano.biten.length;

  /// The titles of the first two cards that wait on the person.
  List<String> get ilkBasliklar => [for (final k in (veri?.pano.sendeBekleyen ?? <IsKarti>[]).take(2)) k.baslik];

  void _yazildi() => unawaited(yukle());

  @override
  void dispose() {
    _repo.removeListener(_yazildi);
    super.dispose();
  }
}
