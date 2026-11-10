import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/bildirim_ogesi.dart';
import '../../data/models/hatirlatici.dart';
import '../../data/repositories/bildirim_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/hatirlatici_repository.dart';
import '../../utils/hatirlatici_hesap.dart';

/// The day heading a notification sits under.
enum BildirimGunu { bugun, dun, once, zamansiz }

/// Which heading a notification made at [zaman] belongs to; the day turns at midnight Istanbul time here (a list of messages, not
/// the 05:00 plan day). [simdi] is the clock.
BildirimGunu bildirimGunu(DateTime? zaman, DateTime simdi) {
  if (zaman == null) return BildirimGunu.zamansiz;
  final fark = istanbulGunu(simdi).difference(istanbulGunu(zaman)).inDays;
  if (fark <= 0) return BildirimGunu.bugun;
  if (fark == 1) return BildirimGunu.dun;
  return BildirimGunu.once;
}

/// The notification list (K-0024, sözleşme §6): newest first in pages, read marks, and "Yaptım" / "Ertele" on a reminder.
class BildirimlerViewModel extends ChangeNotifier {
  BildirimlerViewModel({
    required this._repo,
    required this._hatirlaticilar,
    required this._esitleyici,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now {
    _repo.addListener(_yerelYenile);
  }

  final BildirimRepository _repo;
  final HatirlaticiRepository _hatirlaticilar;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;
  var _kapandi = false;

  DateTime get simdi => _simdi();

  List<BildirimOgesi>? _liste;
  List<BildirimOgesi>? get liste => _liste;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  String? _hata;
  String? get hata => _hata;

  /// A page older than the list was asked for and is on its way.
  bool _dahaYukleniyor = false;
  bool get dahaYukleniyor => _dahaYukleniyor;

  /// The last page was full, so there may be older ones.
  bool _dahaVar = false;
  bool get dahaVar => _dahaVar;

  int get okunmamis => (_liste ?? const []).where((b) => !b.okundu).length;

  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _esitleyici.gonder();
      final sonuc = await _repo.ilkSayfa();
      _liste = sonuc.liste;
      _cevrimdisi = sonuc.cevrimdisi;
      _dahaVar = !sonuc.cevrimdisi && sonuc.liste.length >= BildirimRepository.sayfaBoyu;
    } on DioException catch (e) {
      _hata = e.response != null
          ? 'Bildirimler alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
          : 'Bildirimler alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _yukleniyor = false;
      if (!_kapandi) notifyListeners();
    }
  }

  /// The page older than the oldest row on screen.
  Future<void> dahaYukle() async {
    final liste = _liste;
    if (liste == null || liste.isEmpty || _dahaYukleniyor || !_dahaVar) return;
    final once = liste.last.zaman;
    if (once == null) return;
    _dahaYukleniyor = true;
    notifyListeners();
    try {
      final sayfa = await _repo.dahaEski(once);
      final bilinen = {for (final b in liste) b.id};
      _liste = [...liste, for (final b in sayfa) if (!bilinen.contains(b.id)) b];
      _dahaVar = sayfa.length >= BildirimRepository.sayfaBoyu;
    } on DioException {
      _hata = 'Daha eski bildirimler alınamadı.';
    } finally {
      _dahaYukleniyor = false;
      if (!_kapandi) notifyListeners();
    }
  }

  /// A mark made here or elsewhere on the phone: the list is laid out again from what it has, marks included.
  void _yerelYenile() {
    final liste = _liste;
    if (liste == null) return;
    unawaited(_repo.ilkSayfa().then((s) {
      if (_kapandi) return;
      // Keep the older pages already loaded; only the rows of the newest page are replaced.
      final yeni = {for (final b in s.liste) b.id: b};
      _liste = [for (final b in liste) yeni[b.id] ?? b];
      notifyListeners();
    }).catchError((Object _) {}));
  }

  Future<void> okundu(BildirimOgesi b) async {
    if (b.okundu) return;
    _degistir(b.id, (x) => x.okunmus());
    await _repo.okundu(b.id);
    unawaited(_esitleyici.gonder());
  }

  Future<void> hepsiOkundu() async {
    final liste = _liste;
    if (liste == null || okunmamis == 0) return;
    _liste = [for (final b in liste) b.okunmus()];
    notifyListeners();
    await _repo.hepsiOkundu();
    unawaited(_esitleyici.gonder());
  }

  /// "Yaptım" on a reminder's notification: the reminder is done and the notification is read.
  Future<void> yaptim(BildirimOgesi b) async {
    if (!b.hatirlaticiMi) return;
    await _hatirlaticilar.yaptim(b.hedefKimligi!);
    await okundu(b);
    unawaited(_esitleyici.gonder());
  }

  /// "1 saat ertele".
  Future<void> ertele(BildirimOgesi b) async {
    if (!b.hatirlaticiMi) return;
    await _hatirlaticilar.ertele(b.hedefKimligi!, ErteleSuresi.birSaat);
    await okundu(b);
    unawaited(_esitleyici.gonder());
  }

  void _degistir(String id, BildirimOgesi Function(BildirimOgesi) f) {
    final liste = _liste;
    if (liste == null) return;
    _liste = [for (final b in liste) b.id == id ? f(b) : b];
    notifyListeners();
  }

  @override
  void dispose() {
    _kapandi = true;
    _repo.removeListener(_yerelYenile);
    super.dispose();
  }
}
