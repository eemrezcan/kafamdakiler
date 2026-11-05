import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/oturum.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/services/database/app_database.dart';
import '../../utils/dogrulama.dart';

/// A queued write the server refused for good.
class GonderilemeyenKayit {
  const GonderilemeyenKayit({required this.id, required this.baslik, required this.hata});

  final String id;
  final String baslik;
  final String hata;
}

/// Offline queue state for the profile screen.
class ProfilViewModel extends ChangeNotifier {
  ProfilViewModel({required this._repo, required this._esitleyici}) {
    _esitleyici.addListener(yukle);
  }

  final AliskanlikRepository _repo;
  final Esitleyici _esitleyici;

  /// Entries still waiting for a connection (not refused).
  int _bekleyen = 0;
  int get bekleyen => _bekleyen;

  List<GonderilemeyenKayit> _gonderilemeyenler = const [];
  List<GonderilemeyenKayit> get gonderilemeyenler => _gonderilemeyenler;

  Future<void> yukle() async {
    final adlar = {for (final a in await _repo.yerelListe()) a.id: a.ad};
    _bekleyen = (await _esitleyici.bekleyenler()).length;
    _gonderilemeyenler = [
      for (final b in await _esitleyici.reddedilenler())
        GonderilemeyenKayit(id: b.id, baslik: _baslik(b, adlar), hata: b.hata ?? ''),
    ];
    notifyListeners();
  }

  String _baslik(BekleyenIslemlerData b, Map<String, String> adlar) {
    return switch (b.tur) {
      BekleyenTur.gunYaz => '${adlar[b.hedefId] ?? 'Alışkanlık'}: ${b.tarih} günü kaydı',
      BekleyenTur.gunSil => '${adlar[b.hedefId] ?? 'Alışkanlık'}: ${b.tarih} günü silme',
      BekleyenTur.oturumEkle =>
        'Oturum: ${sayiMetni(OturumEkle.fromJson(jsonDecode(b.govde) as Map<String, dynamic>).bitisKonum)} konumuna kadar',
      BekleyenTur.yakalamaEkle => 'Yakalama: yeni kayıt',
      BekleyenTur.yakalamaGuncelle => 'Yakalama: değişiklik',
      BekleyenTur.yakalamaSil => 'Yakalama: silme',
    };
  }

  Future<void> kaydiSil(String id) => _esitleyici.sil(id);

  Future<void> simdiGonder() => _esitleyici.gonder();

  /// Entries that would be lost on sign-out: everything not sent yet,
  /// refused ones included.
  Future<int> cikistaKaybolacak() async => (await _esitleyici.bekleyenler(reddedilenler: true)).length;

  @override
  void dispose() {
    _esitleyici.removeListener(yukle);
    super.dispose();
  }
}
