import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/eylem.dart';
import '../../data/models/yonetim.dart';
import '../../data/services/api_service.dart';
import '../core/hata_metni.dart';
import 'izin_gruplari.dart';

/// The Sahip's management screen: the Asistan's permissions, the brain status
/// and the queue of captures going to the brain. Everything is read from the
/// server (nothing is kept on the phone) and needs the network.
class YonetimViewModel extends ChangeNotifier {
  YonetimViewModel({required this._api});

  final ApiService _api;

  List<Izin> _izinler = const [];
  List<Izin> get izinler => _izinler;

  List<EylemKipDurumu> _eylemKipleri = const [];

  /// The mode of every kind of action the Asistan may suggest.
  List<EylemKipDurumu> get eylemKipleri => _eylemKipleri;

  /// Kinds whose mode is being changed right now (their buttons wait for the answer).
  final Set<String> _kipMesgul = {};
  bool kipMesgulMu(String tur) => _kipMesgul.contains(tur);

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

  /// Open permissions, by key.
  Set<String> get acikIzinler => {for (final i in _izinler) if (i.acik) i.izin};

  IzinSeviyesi seviye(IzinGrubu grup) => grup.seviye(acikIzinler);

  /// A group waits while any of its permissions is being changed.
  bool grupMesgulMu(IzinGrubu grup) => grup.tumu.any(_mesgul.contains);

  /// Null when the server could not be asked (the card then says so).
  GoogleDurum? _google;
  GoogleDurum? get google => _google;

  bool _googleOkunamadi = false;
  bool get googleOkunamadi => _googleOkunamadi;

  bool _esitleniyor = false;
  bool get esitleniyor => _esitleniyor;

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
      final kipler = await _api.eylemKipleriniGetir();
      final beyin = await _api.yonetimBeyinDurumu();
      final kuyruk = await _api.gonderimKuyrugu();
      if (tur != _tur || _atildi) return;
      _izinler = izinler;
      _eylemKipleri = kipler;
      _beyin = beyin;
      _kuyruk = kuyruk;
      await _googleOku(tur);
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

  // The Google card must not take the rest of the screen down with it.
  Future<void> _googleOku(int tur) async {
    try {
      final google = await _api.googleDurumu();
      if (tur != _tur || _atildi) return;
      _google = google;
      _googleOkunamadi = false;
    } on Object {
      if (tur != _tur || _atildi) return;
      _googleOkunamadi = true;
    }
  }

  /// Syncs the calendar now. Returns the message to show (success or failure).
  Future<String> simdiEsitle() async {
    if (_esitleniyor) return 'Zaten eşitleniyor.';
    _esitleniyor = true;
    notifyListeners();
    try {
      final ozet = await _api.googleEsitle();
      await _googleOku(_tur);
      final parcalar = [
        if (ozet.eklenen > 0) '${ozet.eklenen} yeni',
        if (ozet.guncellenen > 0) '${ozet.guncellenen} güncellenen',
        if (ozet.silinen > 0) '${ozet.silinen} silinen',
      ];
      final sonuc = parcalar.isEmpty ? 'Takvim eşitlendi, yeni bir şey yok.' : 'Takvim eşitlendi: ${parcalar.join(', ')}.';
      return ozet.basarisiz > 0 ? '$sonuc ${ozet.basarisiz} etkinlik eşitlenemedi.' : sonuc;
    } on DioException catch (e) {
      return switch (e.response?.statusCode) {
        503 => 'Google Takvim bu sunucuda ayarlanmamış.',
        409 => 'Google erişimi çalışmıyor. Web\'deki Yönetim sayfasından takvimi yeniden bağlamayı dene.',
        _ => hataMetni(e, islem: 'Takvim eşitlenemedi'),
      };
    } on Object catch (e) {
      return hataMetni(e, islem: 'Takvim eşitlenemedi');
    } finally {
      _esitleniyor = false;
      if (!_atildi) notifyListeners();
    }
  }

  /// Sets a whole group to [seviye] with one permission call each, the closing ones first. If a call fails the rest
  /// are not sent and the group shows what the server really holds (possibly "Özel"). Returns a message when it failed.
  Future<String?> grupAyarla(IzinGrubu grup, IzinSeviyesi seviye) async {
    if (seviye == IzinSeviyesi.ozel || grupMesgulMu(grup)) return null;
    final hedef = grup.hedef(seviye);
    final acik = acikIzinler;
    final kapanacak = [for (final i in grup.yazar.reversed.followedBy(grup.okur.reversed)) if (hedef[i] == false && acik.contains(i)) i];
    final acilacak = [for (final i in grup.tumu) if (hedef[i] == true && !acik.contains(i)) i];
    final sirali = [...kapanacak.map((i) => (i, false)), ...acilacak.map((i) => (i, true))];
    if (sirali.isEmpty) return null;
    _mesgul.addAll(grup.tumu);
    notifyListeners();
    try {
      for (final (izin, yeniDurum) in sirali) {
        final yeni = await _api.izinAyarla(izin, acik: yeniDurum);
        _izinler = [for (final i in _izinler) i.izin == yeni.izin ? yeni : i];
        if (!_atildi) notifyListeners();
      }
      return null;
    } on Object catch (e) {
      return hataMetni(e, islem: 'İzinler değiştirilemedi');
    } finally {
      _mesgul.removeAll(grup.tumu);
      if (!_atildi) notifyListeners();
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

  /// Sets the mode of a kind of action. Returns a message for the user when it failed, null when it worked.
  Future<String?> kipDegistir(EylemKipDurumu kayit, EylemKipi kip) async {
    if (kayit.kip == kip || !_kipMesgul.add(kayit.tur)) return null;
    notifyListeners();
    try {
      final yeni = await _api.eylemKipiAyarla(kayit.tur, kip);
      _eylemKipleri = [for (final k in _eylemKipleri) k.tur == yeni.tur ? yeni : k];
      return null;
    } on Object catch (e) {
      return hataMetni(e, islem: 'Kip değiştirilemedi');
    } finally {
      _kipMesgul.remove(kayit.tur);
      if (!_atildi) notifyListeners();
    }
  }

  bool _sifreGonderiliyor = false;

  /// Sets a new password for the Asistan; the server closes its sessions too.
  /// Returns a message for the user when it failed, null when it worked.
  Future<String?> asistanSifresiniYenile(String yeniSifre) async {
    if (_sifreGonderiliyor) return 'Zaten gönderiliyor.';
    _sifreGonderiliyor = true;
    try {
      await _api.asistaninSifresiniYenile(yeniSifre);
      return null;
    } on Object catch (e) {
      return sifreHataMetni(e);
    } finally {
      _sifreGonderiliyor = false;
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
