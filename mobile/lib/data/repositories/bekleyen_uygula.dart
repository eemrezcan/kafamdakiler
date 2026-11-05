import 'dart:convert';

import '../../utils/aliskanlik_gunu.dart';
import '../../utils/gun_degeri.dart';
import '../models/aliskanlik.dart';
import '../models/oge.dart';
import '../models/oturum.dart';
import '../models/gun.dart';
import '../models/yakalama.dart';
import '../services/database/app_database.dart';

/// Lays the writes that are still queued on the phone over a server (or
/// cached) habit list, so the screen shows them at once (optimistic update).
/// A cached "today" that belongs to an earlier day is shown as zero.
///
/// [bekleyenler] must be in queue order. [bugun] is the habit day of now.
List<Aliskanlik> bekleyenleriUygula(
  List<Aliskanlik> liste,
  List<BekleyenIslemlerData> bekleyenler,
  DateTime bugun,
) {
  return [for (final a in liste) _aliskanligaUygula(a, bekleyenler, bugun)];
}

Aliskanlik _aliskanligaUygula(Aliskanlik a, List<BekleyenIslemlerData> bekleyenler, DateTime bugun) {
  final eskiGun = a.bugun != null && a.bugun!.tarih != bugun;
  var miktar = a.bugun != null && !eskiGun ? a.bugun!.miktar : 0.0;
  var dakika = a.bugun != null && !eskiGun ? a.bugun!.dakika : null;
  var devam = a.devamEdenler;
  var degisti = eskiGun;

  for (final b in bekleyenler) {
    switch (b.tur) {
      case BekleyenTur.gunYaz when b.hedefId == a.id && tarihCoz(b.tarih!) == bugun:
        final g = GunYaz.fromJson(jsonDecode(b.govde) as Map<String, dynamic>);
        miktar = g.miktar;
        dakika = g.dakika;
        degisti = true;
      case BekleyenTur.gunSil when b.hedefId == a.id && tarihCoz(b.tarih!) == bugun:
        miktar = 0;
        dakika = null;
        degisti = true;
      case BekleyenTur.oturumEkle when devam.any((o) => o.id == b.hedefId):
        final o = OturumEkle.fromJson(jsonDecode(b.govde) as Map<String, dynamic>);
        final gun = aliskanlikGunu(o.baslangicAni ?? b.olusturulma);
        devam = [
          for (final x in devam)
            if (x.id == b.hedefId) _ozetiIlerlet(x, o.bitisKonum) else x,
        ];
        if (gun == bugun && o.baslangicKonum != null) {
          miktar += o.bitisKonum - o.baslangicKonum!;
          dakika = (dakika ?? 0) + (o.dakika ?? 0);
        }
        degisti = true;
      default:
        break;
    }
  }
  if (!degisti) return a;

  return a.copyWith(
    devamEdenler: devam,
    bugun: BugunDurumu(
      tarih: bugun,
      miktar: miktar,
      dakika: dakika,
      deger: gunDegeri(olcu: a.olcu, hedefYonu: a.hedefYonu, hedef: a.gunlukHedef, miktar: miktar),
      planli: a.bugunPlanli,
    ),
  );
}

OgeOzet _ozetiIlerlet(OgeOzet o, double bitis) => o.copyWith(
      guncelKonum: bitis,
      ilerleme: o.toplam == null || o.toplam == 0 ? null : (bitis / o.toplam!).clamp(0, 1).toDouble(),
    );

/// Same for one item: the position moves to the last queued session's end.
Oge ogeyeBekleyenleriUygula(Oge oge, List<BekleyenIslemlerData> bekleyenler) {
  var konum = oge.guncelKonum;
  var degisti = false;
  for (final b in bekleyenler) {
    if (b.tur != BekleyenTur.oturumEkle || b.hedefId != oge.id) continue;
    konum = OturumEkle.fromJson(jsonDecode(b.govde) as Map<String, dynamic>).bitisKonum;
    degisti = true;
  }
  if (!degisti) return oge;
  final toplam = oge.toplam;
  return oge.copyWith(
    guncelKonum: konum,
    ilerleme: toplam == null || toplam == 0 ? null : (konum / toplam).clamp(0, 1).toDouble(),
  );
}

/// Lays the queued capture writes over the server's captures, newest first.
///
/// - A queued new capture is a row of its own ([YakalamaKonumu.telefonda]).
/// - A queued edit shows the new content; a queued delete hides the row.
/// - A capture that already went to the brain is never changed on the screen
///   (the server would refuse the write anyway).
/// - A write the server refused ([BekleyenIslemlerData.hata]) is not applied;
///   its reason is attached to the row, so the list can show it.
///
/// [bekleyenler] holds the unsent entries, refused ones included, in queue order.
List<YakalamaSatiri> yakalamalaraBekleyenleriUygula(
  List<Yakalama> sunucu,
  List<BekleyenIslemlerData> bekleyenler,
) {
  final satirlar = <String, YakalamaSatiri>{
    for (final y in sunucu)
      y.id: YakalamaSatiri(
        id: y.id,
        metin: y.metin,
        fotografId: y.fotografId,
        hedef: y.hedef,
        konum: y.durum == YakalamaDurumu.bekliyor ? YakalamaKonumu.sunucuda : YakalamaKonumu.beyinde,
        islendi: y.durum == YakalamaDurumu.islendi,
        yakalandiAt: y.yakalandiAt,
      ),
  };

  YakalamaSatiri telefonda(BekleyenIslemlerData b, {String? hata}) {
    final g = YakalamaGovde.fromJson(jsonDecode(b.govde) as Map<String, dynamic>);
    return YakalamaSatiri(
      id: b.hedefId,
      metin: g.yaz.metin,
      fotografId: g.yaz.fotografId,
      fotografYolu: g.fotografYolu,
      hedef: g.yaz.hedef,
      konum: YakalamaKonumu.telefonda,
      islendi: false,
      yakalandiAt: g.yaz.yakalandiAt,
      hata: hata,
    );
  }

  for (final b in bekleyenler) {
    final hedef = satirlar[b.hedefId];
    switch (b.tur) {
      case BekleyenTur.yakalamaEkle:
        satirlar[b.hedefId] = telefonda(b, hata: b.hata);
      case BekleyenTur.yakalamaGuncelle when hedef != null && hedef.degistirilebilir:
        satirlar[b.hedefId] = b.hata == null ? telefonda(b) : hedef.copyWith(hata: b.hata);
      case BekleyenTur.yakalamaSil when hedef != null && hedef.degistirilebilir:
        if (b.hata == null) {
          satirlar.remove(b.hedefId);
        } else {
          satirlar[b.hedefId] = hedef.copyWith(hata: b.hata);
        }
      default:
        break;
    }
  }

  return satirlar.values.toList()
    ..sort((a, b) {
      final tarih = b.yakalandiAt.compareTo(a.yakalandiAt);
      return tarih != 0 ? tarih : b.id.compareTo(a.id);
    });
}
