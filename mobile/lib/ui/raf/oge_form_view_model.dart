import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/oge.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../core/hata_metni.dart';

/// Create / edit form of a shelf item. Creating, editing and the photo upload
/// are online only.
class OgeFormViewModel extends ChangeNotifier {
  OgeFormViewModel({required this._repo, this.aliskanlikId, this.duzenlenenId})
      : assert(aliskanlikId != null || duzenlenenId != null);

  final AliskanlikRepository _repo;

  /// Habit the new item belongs to (create).
  final String? aliskanlikId;

  /// Item being edited (null when creating).
  final String? duzenlenenId;
  bool get duzenleme => duzenlenenId != null;

  Oge? _mevcut;
  Oge? get mevcut => _mevcut;

  /// Labels of the habit ("Kitap", "Yazar") for the field captions.
  String _ogeEtiketi = 'Öğe';
  String get ogeEtiketi => _ogeEtiketi;
  String _altBaslikEtiketi = 'Alt başlık';
  String get altBaslikEtiketi => _altBaslikEtiketi;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _kaydediliyor = false;
  bool get kaydediliyor => _kaydediliyor;

  String? _hata;
  String? get hata => _hata;

  Future<void> yukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      if (duzenleme) _mevcut = await _repo.oge(duzenlenenId!);
      final habitId = aliskanlikId ?? _mevcut?.aliskanlikId;
      final a = (await _repo.yerelListe()).where((x) => x.id == habitId).firstOrNull;
      _ogeEtiketi = a?.ogeEtiketi ?? _ogeEtiketi;
      _altBaslikEtiketi = a?.altBaslikEtiketi ?? _altBaslikEtiketi;
    } on DioException catch (e) {
      _hata = hataMetni(e, islem: 'Öğe yüklenemedi');
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Uploads [fotografYolu] first when a new cover was picked, then saves.
  /// Returns true when saved; otherwise [hata] says what to do.
  Future<bool> kaydet(OgeYaz yaz, {String? fotografYolu}) async {
    _kaydediliyor = true;
    _hata = null;
    notifyListeners();
    try {
      var son = yaz;
      if (fotografYolu != null) {
        final dosya = await _repo.dosyaYukle(fotografYolu);
        son = OgeYaz(
          id: yaz.id,
          ad: yaz.ad,
          altBaslik: yaz.altBaslik,
          toplam: yaz.toplam,
          baslangicKonumu: yaz.baslangicKonumu,
          fotografId: dosya.id,
          durum: yaz.durum,
          puan: yaz.puan,
          not: yaz.not,
        );
      }
      if (duzenleme) {
        await _repo.ogeGuncelle(duzenlenenId!, son);
      } else {
        await _repo.ogeOlustur(aliskanlikId!, son);
      }
      return true;
    } on DioException catch (e) {
      _hata = cevrimdisiHata(e)
          ? 'Kaydetmek için internet bağlantısı gerekir. Bağlanıp tekrar dene.'
          : hataMetni(e, islem: 'Kaydedilemedi');
      return false;
    } finally {
      _kaydediliyor = false;
      notifyListeners();
    }
  }
}
