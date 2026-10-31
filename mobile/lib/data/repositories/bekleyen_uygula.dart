import 'dart:convert';

import '../../utils/aliskanlik_gunu.dart';
import '../../utils/gun_degeri.dart';
import '../models/aliskanlik.dart';
import '../models/oge.dart';
import '../models/oturum.dart';
import '../models/gun.dart';
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
