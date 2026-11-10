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

/// A sent write the server accepted without a clear "done" (202), or a split that stopped half way (207): the note to read.
class UyariKaydi {
  const UyariKaydi({required this.id, required this.baslik, required this.metin});

  final String id;
  final String baslik;
  final String metin;
}

/// Offline queue state for the profile sheet.
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

  /// Writes the server took without a clear answer; each stays until it is read and dismissed.
  List<UyariKaydi> _uyarilar = const [];
  List<UyariKaydi> get uyarilar => _uyarilar;

  Future<void> yukle() async {
    final adlar = {for (final a in await _repo.yerelListe()) a.id: a.ad};
    _bekleyen = (await _esitleyici.bekleyenler()).length;
    _gonderilemeyenler = [
      for (final b in await _esitleyici.reddedilenler())
        GonderilemeyenKayit(id: b.id, baslik: _baslik(b, adlar), hata: b.hata ?? ''),
    ];
    _uyarilar = [
      for (final b in await _esitleyici.uyarilar()) UyariKaydi(id: b.id, baslik: _baslik(b, adlar), metin: b.uyari ?? ''),
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
      BekleyenTur.hatirlaticiEkle => 'Hatırlatıcı: yeni kayıt',
      BekleyenTur.hatirlaticiGuncelle => 'Hatırlatıcı: değişiklik',
      BekleyenTur.hatirlaticiSil => 'Hatırlatıcı: silme',
      BekleyenTur.hatirlaticiYaptim => 'Hatırlatıcı: yaptım',
      BekleyenTur.hatirlaticiErtele => 'Hatırlatıcı: erteleme',
      BekleyenTur.eylemUygula => 'Onay kuyruğu: uygulama',
      BekleyenTur.eylemReddet => 'Onay kuyruğu: reddetme',
      BekleyenTur.eylemGeriAl => 'Onay kuyruğu: geri alma',
      BekleyenTur.beyinMaddeEkle => 'Gün planı: madde ekleme (${b.tarih})',
      BekleyenTur.beyinMaddeIsaretle => 'Gün planı: madde işaretleme (${b.tarih})',
      BekleyenTur.beyinMaddeDevret => 'Gün planı: madde devretme (${b.tarih})',
      BekleyenTur.beyinMaddeNot => 'Gün planı: madde notu (${b.tarih})',
      BekleyenTur.beyinGorevEkle => 'Görev: ekleme',
      BekleyenTur.beyinGorevBitir => 'Görev: bitirme',
      BekleyenTur.beyinGunlereBol => 'Görev: günlere bölme',
      BekleyenTur.gelenIsle => 'Gelen kutusu: yerleştirme',
      BekleyenTur.gelenSil => 'Gelen kutusu: silme',
      BekleyenTur.gunYaptim => 'Yapılacak: yaptım (${b.tarih})',
      BekleyenTur.gunOgeEkle => 'Yapılacak: yeni kayıt (${b.tarih})',
      BekleyenTur.ogeHatirlaticiYaz => 'Yapılacak: hatırlatıcı (${b.tarih})',
      BekleyenTur.ogeHatirlaticiSil => 'Yapılacak: hatırlatıcıyı kaldırma (${b.tarih})',
      BekleyenTur.dundenBirak => 'Dünden kalan: bırakma',
      BekleyenTur.ayarGunYaz => 'Gün kapasitesi ayarı',
      BekleyenTur.gunDevret => 'Yapılacak: devretme (${b.tarih})',
      BekleyenTur.asistanGirdi => 'Asistan: girdi',
      BekleyenTur.asistanCevap => 'Asistan: soruya cevap',
      BekleyenTur.bildirimOkundu => 'Bildirim: okundu işareti',
      BekleyenTur.bildirimHepsiOkundu => 'Bildirimler: hepsi okundu işareti',
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
