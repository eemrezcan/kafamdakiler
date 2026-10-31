import 'package:flutter/foundation.dart';

import '../../data/repositories/kronometre_repository.dart';

/// A stopwatch that only remembers when it started. The elapsed time is
/// `now - start`, so it is right after the app was in the background (timers
/// pause there) or even killed (the start instant is persisted).
class KronometreViewModel extends ChangeNotifier {
  KronometreViewModel({
    required this._repo,
    required this.hedefId,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now;

  final KronometreRepository _repo;
  final String hedefId;
  final DateTime Function() _simdi;

  DateTime? _baslangic;
  DateTime? get baslangic => _baslangic;
  bool get calisiyor => _baslangic != null;

  /// Picks up a stopwatch that was started before (app restart).
  Future<void> yukle() async {
    _baslangic = await _repo.baslangic(hedefId);
    notifyListeners();
  }

  Future<void> baslat() async {
    _baslangic = _simdi();
    await _repo.baslat(hedefId, _baslangic!);
    notifyListeners();
  }

  /// Time since the start; zero when not running.
  Duration get gecen {
    final b = _baslangic;
    if (b == null) return Duration.zero;
    final fark = _simdi().difference(b);
    return fark.isNegative ? Duration.zero : fark;
  }

  /// Whole minutes for the record: rounded, and at least 1 once started.
  int get dakika {
    if (!calisiyor) return 0;
    final d = (gecen.inSeconds / 60).round();
    return d < 1 ? 1 : d;
  }

  /// Forgets the stopwatch (after the record was saved, or on cancel).
  Future<void> sifirla() async {
    _baslangic = null;
    await _repo.temizle(hedefId);
    notifyListeners();
  }
}

/// "01:05:09" / "05:09".
String sureMetni(Duration d) {
  String iki(int n) => n.toString().padLeft(2, '0');
  final s = d.inSeconds;
  final saat = s ~/ 3600;
  final dk = (s % 3600) ~/ 60;
  final sn = s % 60;
  return saat > 0 ? '${iki(saat)}:${iki(dk)}:${iki(sn)}' : '${iki(dk)}:${iki(sn)}';
}
