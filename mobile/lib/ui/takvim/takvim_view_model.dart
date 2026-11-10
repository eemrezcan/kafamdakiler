import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/gun_gorunum.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/gun_repository.dart';
import '../gun/gun_view_model.dart';

enum TakvimGorunumu { hafta, ay }

/// The Monday of the week [gun] is in (date-only UTC values).
DateTime haftaBasi(DateTime gun) => DateTime.utc(gun.year, gun.month, gun.day - (gun.weekday - 1));

/// The days a calendar view asks the server for: the week of [secili], or the month grid of 42 days (six weeks from the Monday
/// on or before the 1st), which is the most the range endpoint takes.
({DateTime baslangic, DateTime bitis}) takvimAraligiHesapla(TakvimGorunumu gorunum, DateTime secili) {
  if (gorunum == TakvimGorunumu.hafta) {
    final b = haftaBasi(secili);
    return (baslangic: b, bitis: DateTime.utc(b.year, b.month, b.day + 6));
  }
  final b = haftaBasi(DateTime.utc(secili.year, secili.month, 1));
  return (baslangic: b, bitis: DateTime.utc(b.year, b.month, b.day + 41));
}

/// The Takvim tab (K-0024): a week strip or a month grid with a dot per kind of thing on each day, the list of the chosen
/// day (the same day view as Bugün, [gun]) and what comes up in the next days.
class TakvimViewModel extends ChangeNotifier {
  TakvimViewModel({required this._repo, required Esitleyici esitleyici})
      : gun = GunViewModel(repo: _repo, esitleyici: esitleyici),
        _secili = _repo.bugun {
    _repo.addListener(_araligiTazele);
  }

  final GunRepository _repo;

  /// The day list under the strip; follows [secili]. Made and disposed here, so one `yukle` loads both.
  final GunViewModel gun;

  var _kapandi = false;
  var _istekNo = 0;

  TakvimGorunumu _gorunum = TakvimGorunumu.hafta;
  TakvimGorunumu get gorunum => _gorunum;

  DateTime _secili;
  DateTime get secili => _secili;

  TakvimAraligi? _aralik;
  TakvimAraligi? get aralik => _aralik;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  String? _hata;
  String? get hata => _hata;

  DateTime get bugun => _repo.bugun;

  ({DateTime baslangic, DateTime bitis}) get gorunenAralik => takvimAraligiHesapla(_gorunum, _secili);

  /// The range and the chosen day.
  Future<void> yukle() => Future.wait([_araligiYukle(), gun.yukle()]);

  Future<void> _araligiYukle() async {
    final no = ++_istekNo;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    final r = gorunenAralik;
    try {
      final sonuc = await _repo.takvim(r.baslangic, r.bitis);
      if (no == _istekNo) {
        _aralik = sonuc.aralik;
        _cevrimdisi = sonuc.cevrimdisi;
      }
    } on DioException catch (e) {
      if (no == _istekNo) {
        _hata = e.response != null
            ? 'Takvim alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
            : 'Takvim alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
      }
    } finally {
      if (no == _istekNo) _yukleniyor = false;
      if (!_kapandi) notifyListeners();
    }
  }

  /// A write elsewhere moved something: the dots are read again, quietly.
  void _araligiTazele() => unawaited(_araligiYukle());

  Future<void> sec(DateTime gunu) async {
    if (gunu == _secili) return;
    final eski = gorunenAralik;
    _secili = gunu;
    notifyListeners();
    final yeni = gorunenAralik;
    await Future.wait([
      gun.tarihDegistir(gunu),
      if (yeni.baslangic != eski.baslangic) _araligiYukle(),
    ]);
  }

  Future<void> gorunumDegistir(TakvimGorunumu g) async {
    if (g == _gorunum) return;
    _gorunum = g;
    notifyListeners();
    await _araligiYukle();
  }

  /// One week or one month back ([yon] -1) or forward (1); the chosen day moves with it.
  Future<void> kaydir(int yon) {
    final s = _secili;
    final hedef = _gorunum == TakvimGorunumu.hafta
        ? DateTime.utc(s.year, s.month, s.day + 7 * yon)
        : _ayKaydir(s, yon);
    return sec(hedef);
  }

  Future<void> bugunGit() => sec(bugun);

  static DateTime _ayKaydir(DateTime s, int yon) {
    final ay = DateTime.utc(s.year, s.month + yon, 1);
    final sonGun = DateTime.utc(ay.year, ay.month + 1, 0).day;
    return DateTime.utc(ay.year, ay.month, s.day > sonGun ? sonGun : s.day);
  }

  @override
  void dispose() {
    _kapandi = true;
    _repo.removeListener(_araligiTazele);
    gun.dispose();
    super.dispose();
  }
}
