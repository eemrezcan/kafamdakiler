import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/yonetim.dart';
import '../../data/services/api_service.dart';
import '../core/hata_metni.dart';

/// The Sahip's management screen: the Asistan's permissions, the brain status
/// and the queue of captures going to the brain. Everything is read from the
/// server (nothing is kept on the phone) and needs the network.
class YonetimViewModel extends ChangeNotifier {
  YonetimViewModel({required this._api});

  final ApiService _api;

  List<Izin> _izinler = const [];
  List<Izin> get izinler => _izinler;

  YonetimBeyinDurumu? _beyin;
  YonetimBeyinDurumu? get beyin => _beyin;

  List<Gonderim> _kuyruk = const [];
  List<Gonderim> get kuyruk => _kuyruk;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  /// Why the first load failed (null when it worked).
  String? _hata;
  String? get hata => _hata;

  /// Permissions being changed right now (their switch waits for the answer).
  final Set<String> _mesgul = {};
  bool izinMesgulMu(String izin) => _mesgul.contains(izin);

  /// Captures being sent again right now.
  final Set<String> _yenidenGonderiliyor = {};
  bool yenidenGonderiliyorMu(String id) => _yenidenGonderiliyor.contains(id);

  int _tur = 0;
  bool _atildi = false;

  /// Reads the three lists; a later call wins over one still on its way.
  Future<void> yukle() async {
    final tur = ++_tur;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      final izinler = await _api.izinleriGetir();
      final beyin = await _api.yonetimBeyinDurumu();
      final kuyruk = await _api.gonderimKuyrugu();
      if (tur != _tur || _atildi) return;
      _izinler = izinler;
      _beyin = beyin;
      _kuyruk = kuyruk;
    } on Object catch (e) {
      if (tur != _tur || _atildi) return;
      _hata = hataMetni(e, islem: 'Yönetim bilgileri okunamadı');
    } finally {
      if (tur == _tur && !_atildi) {
        _yukleniyor = false;
        notifyListeners();
      }
    }
  }

  /// Opens or closes [izin] for the Asistan. Returns a message for the user
  /// when it failed, null when it worked.
  Future<String?> izinDegistir(Izin izin, bool acik) async {
    if (!_mesgul.add(izin.izin)) return null;
    notifyListeners();
    try {
      final yeni = await _api.izinAyarla(izin.izin, acik: acik);
      _izinler = [for (final i in _izinler) i.izin == yeni.izin ? yeni : i];
      return null;
    } on Object catch (e) {
      return hataMetni(e, islem: 'İzin değiştirilemedi');
    } finally {
      _mesgul.remove(izin.izin);
      if (!_atildi) notifyListeners();
    }
  }

  /// Gives a failed or stuck capture back to the server's sender. Returns the
  /// message to show (success or failure).
  Future<String> yenidenDene(Gonderim g) async {
    if (!_yenidenGonderiliyor.add(g.id)) return 'Zaten deneniyor.';
    notifyListeners();
    try {
      final yeni = await _api.gonderimiYenidenDene(g.id);
      _kuyruk = [for (final k in _kuyruk) k.id == yeni.id ? yeni : k];
      // The counts and the order change too.
      await _kuyruguYenile();
      return 'Yeniden gönderilecek.';
    } on DioException catch (e) {
      // 409 is not a failure to keep: the server is sending it right now.
      if (e.response?.statusCode == 409) {
        await _kuyruguYenile();
        return 'Yakalama şu an gönderiliyor ya da artık beklemiyor. Biraz sonra bakıp gerekirse tekrar dene.';
      }
      return hataMetni(e, islem: 'Yeniden denenemedi');
    } on Object catch (e) {
      return hataMetni(e, islem: 'Yeniden denenemedi');
    } finally {
      _yenidenGonderiliyor.remove(g.id);
      if (!_atildi) notifyListeners();
    }
  }

  Future<void> _kuyruguYenile() async {
    try {
      final beyin = await _api.yonetimBeyinDurumu();
      final kuyruk = await _api.gonderimKuyrugu();
      if (_atildi) return;
      _beyin = beyin;
      _kuyruk = kuyruk;
    } on Object {
      // The answer to the retry itself is what matters; the lists refresh with a pull.
    }
  }

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}
