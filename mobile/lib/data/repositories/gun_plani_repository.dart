import 'package:flutter/foundation.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/beyin.dart';
import 'beyin_repository.dart';
import 'esitleyici.dart';

/// The writes on the brain's tasks (K2.3a): add, finish and split over days. The day itself is read and written through the day
/// view ([GunRepository]); this is what the project page uses for its tasks.
///
/// Every write is queued on the phone first ([Esitleyici]); the caller then asks [Esitleyici.gonder] to send. Listeners are told
/// after every local write.
class GunPlaniRepository extends ChangeNotifier {
  GunPlaniRepository({
    required this._beyin,
    required this._esitleyici,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now;

  final BeyinRepository _beyin;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;

  /// Today by the rule shared with the brain (the day turns at 05:00).
  DateTime get bugun => aliskanlikGunu(_simdi());

  Future<void> gorevEkle({required String baslik, required String proje, DateTime? bitis}) async {
    await _esitleyici.beyinGorevEkleKuyrugaAl(baslik: baslik.trim(), proje: proje, bitis: bitis);
    notifyListeners();
  }

  Future<void> gorevBitir(String kimlik) async {
    await _esitleyici.beyinGorevBitirKuyrugaAl(kimlik);
    notifyListeners();
  }

  Future<void> gunlereBol(String kimlik, {required int gunSayisi, DateTime? baslangic}) async {
    await _esitleyici.beyinGunlereBolKuyrugaAl(kimlik, gunSayisi: gunSayisi, baslangic: baslangic);
    notifyListeners();
  }

  /// The projects the phone knows (the capture picker's list), for the new-task form.
  Future<List<ProjeOzet>> projeler() => _beyin.yerelProjeler();
}
