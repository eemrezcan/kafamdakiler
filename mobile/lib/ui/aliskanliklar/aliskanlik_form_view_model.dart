import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../core/hata_metni.dart';

/// Create / edit form of a habit. Creating and editing are online only.
class AliskanlikFormViewModel extends ChangeNotifier {
  AliskanlikFormViewModel({required this._repo, this.duzenlenenId});

  final AliskanlikRepository _repo;

  /// Null when creating.
  final String? duzenlenenId;
  bool get duzenleme => duzenlenenId != null;

  Aliskanlik? _mevcut;
  Aliskanlik? get mevcut => _mevcut;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _kaydediliyor = false;
  bool get kaydediliyor => _kaydediliyor;

  String? _hata;
  String? get hata => _hata;

  Future<void> yukle() async {
    if (!duzenleme) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      _mevcut = await _repo.aliskanlikGetir(duzenlenenId!);
    } on DioException catch (e) {
      _hata = cevrimdisiHata(e)
          ? 'Düzenlemek için internet bağlantısı gerekir. Bağlanıp tekrar dene.'
          : hataMetni(e, islem: 'Alışkanlık yüklenemedi');
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Returns true when saved; otherwise [hata] says what to do.
  Future<bool> kaydet(AliskanlikYaz yaz) async {
    _kaydediliyor = true;
    _hata = null;
    notifyListeners();
    try {
      if (duzenleme) {
        await _repo.aliskanlikGuncelle(duzenlenenId!, yaz);
      } else {
        await _repo.aliskanlikOlustur(yaz);
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
