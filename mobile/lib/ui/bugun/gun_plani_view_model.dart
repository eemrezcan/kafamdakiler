import '../../data/models/beyin.dart';
import '../../data/repositories/beyin_repository.dart';
import '../../utils/aliskanlik_gunu.dart';
import '../core/beyin_yukleyici.dart';

/// The brain's plan for one day on the "Bugün" tab, read only. Starts on today and
/// moves a day forward or back; the habit cards below it always stay on today.
class GunPlaniViewModel extends BeyinYukleyici<BeyinGun> {
  GunPlaniViewModel({required this._repo, DateTime Function()? simdi}) : _simdi = simdi ?? DateTime.now {
    _tarih = bugun;
  }

  final BeyinRepository _repo;
  final DateTime Function() _simdi;

  late DateTime _tarih;

  /// The day shown (date-only, UTC midnight).
  DateTime get tarih => _tarih;

  /// Today by the same rule as the habits (the day starts at 05:00).
  DateTime get bugun => aliskanlikGunu(_simdi());

  bool get bugunMu => _tarih == bugun;

  @override
  Future<BeyinGun> getir() => _repo.gun(_tarih);

  Future<void> gunDegistir(int fark) {
    _tarih = _tarih.add(Duration(days: fark));
    temizle();
    return yukle();
  }

  Future<void> bugune() {
    _tarih = bugun;
    temizle();
    return yukle();
  }
}
