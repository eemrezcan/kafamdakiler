import 'dart:convert';

import '../../utils/aliskanlik_gunu.dart';
import '../../utils/gun_degeri.dart';
import '../models/aliskanlik.dart';
import '../models/beyin.dart';
import '../models/oge.dart';
import '../models/oturum.dart';
import '../models/eylem.dart';
import '../models/gelen.dart';
import '../models/gun_gorunum.dart';
import '../models/gun.dart';
import '../models/hatirlatici.dart';
import '../../utils/hatirlatici_islemleri.dart';
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

/// Lays the queued approval decisions over the server's (or cached) actions, in queue order, so an action approved,
/// rejected or undone offline moves at once. A decision only counts when the action is in the state it needs
/// (a waiting one can be approved or rejected, an applied one undone); the server would answer 409 otherwise.
/// Each decision is applied at the moment it was queued ([BekleyenIslemlerData.olusturulma]).
/// [bekleyenler] holds the unsent entries without the refused ones.
List<Eylem> eylemlereBekleyenleriUygula(List<Eylem> sunucu, List<BekleyenIslemlerData> bekleyenler) {
  final harita = <String, Eylem>{for (final e in sunucu) e.id: e};
  for (final b in bekleyenler) {
    final mevcut = harita[b.hedefId];
    if (mevcut == null) continue;
    switch (b.tur) {
      case BekleyenTur.eylemUygula when mevcut.durum == EylemDurumu.bekliyor:
        final yuk = (jsonDecode(b.govde) as Map<String, dynamic>)['yuk'] as Map<String, dynamic>?;
        harita[b.hedefId] = mevcut.copyWith(
          durum: EylemDurumu.uygulandi,
          yuk: yuk,
          kararAni: b.olusturulma,
          uygulamaAni: b.olusturulma,
        );
      case BekleyenTur.eylemReddet when mevcut.durum == EylemDurumu.bekliyor:
        harita[b.hedefId] = mevcut.copyWith(durum: EylemDurumu.reddedildi, kararAni: b.olusturulma);
      case BekleyenTur.eylemGeriAl when mevcut.durum == EylemDurumu.uygulandi:
        harita[b.hedefId] = mevcut.copyWith(durum: EylemDurumu.geriAlindi, geriAlmaAni: b.olusturulma);
      default:
        break;
    }
  }
  return harita.values.toList();
}

/// Lays the queued inbox decisions over the server's (or cached) cards, in queue order, so a card placed, deleted or
/// decided on offline moves at once. [bekleyenler] holds the unsent entries without the refused ones.
///
/// - A queued placement or deletion of a card takes the card off the list.
/// - A queued approval of the card's suggestion places the card, so the card goes too; a queued rejection leaves the
///   card without its suggestion.
List<GelenKarti> gelenKartlarinaBekleyenleriUygula(List<GelenKarti> sunucu, List<BekleyenIslemlerData> bekleyenler) {
  final kartlar = <String, GelenKarti>{for (final k in sunucu) k.kimlik: k};
  for (final b in bekleyenler) {
    switch (b.tur) {
      case BekleyenTur.gelenIsle || BekleyenTur.gelenSil:
        kartlar.remove(b.hedefId);
      case BekleyenTur.eylemUygula || BekleyenTur.eylemReddet:
        final kart = kartlar.values.where((k) => k.oneri?.eylemId == b.hedefId).firstOrNull;
        if (kart == null) break;
        if (b.tur == BekleyenTur.eylemUygula) {
          kartlar.remove(kart.kimlik);
        } else {
          kartlar[kart.kimlik] = kart.oneriz();
        }
      default:
        break;
    }
  }
  return kartlar.values.toList();
}

/// Lays the queued reminder writes over the server's (or cached) reminders, in queue order, so a reminder made,
/// changed, done or snoozed offline shows at once. Each write is applied at the moment it was queued
/// ([BekleyenIslemlerData.olusturulma]). [bekleyenler] holds the unsent entries without the refused ones.
List<Hatirlatici> hatirlaticilaraBekleyenleriUygula(List<Hatirlatici> sunucu, List<BekleyenIslemlerData> bekleyenler) {
  final harita = <String, Hatirlatici>{for (final h in sunucu) h.id: h};
  for (final b in bekleyenler) {
    final govde = jsonDecode(b.govde) as Map<String, dynamic>;
    final mevcut = harita[b.hedefId];
    switch (b.tur) {
      case BekleyenTur.hatirlaticiEkle:
        harita[b.hedefId] = hatirlaticiYazdan(HatirlaticiYaz.fromJson(govde), b.olusturulma);
      case BekleyenTur.hatirlaticiGuncelle when mevcut != null:
        harita[b.hedefId] = hatirlaticiYazdan(HatirlaticiYaz.fromJson(govde), b.olusturulma, mevcut: mevcut);
      case BekleyenTur.hatirlaticiSil:
        harita.remove(b.hedefId);
      case BekleyenTur.hatirlaticiYaptim when mevcut != null:
        harita[b.hedefId] = hatirlaticiYaptim(mevcut, b.olusturulma);
      case BekleyenTur.hatirlaticiErtele when mevcut != null:
        harita[b.hedefId] = hatirlaticiErtele(mevcut, govde['sure'] as String, b.olusturulma);
      default:
        break;
    }
  }
  return harita.values.toList();
}

/// Lays the queued plan and task writes over the brain's plan of one day (optimistic update), in queue order, so a tick,
/// a carry-over or a new item shows at once, offline too. [bekleyenler] holds the unsent entries without the refused
/// ones: a write the server refused is no longer applied, so the screen goes back to what the brain has.
///
/// - A new item is shown with the id `yerel:<queue id>`: it cannot be ticked or carried until it is sent.
/// - A tick on an item linked to a task also takes the task off the overdue list (the brain closes it too).
/// - A carry-over marks the item `devredildi` on its day and adds it to the next day's plan.
/// - The tally and the "does not fit" warning are worked out again from the items. The warning is only kept or dropped,
///   never started: the day's capacity is a server setting the phone only learns from the warning itself.
BeyinGun gunPlaninaBekleyenleriUygula(BeyinGun gun, List<BekleyenIslemlerData> bekleyenler) {
  final bugun = tarihMetni(gun.tarih);
  final dun = tarihMetni(gun.tarih.subtract(const Duration(days: 1)));
  final bolumler = <String, List<BeyinGunMaddesi>>{
    for (final b in gun.bolumler) b.ad: [...b.maddeler],
  };
  final geciken = [...gun.geciken];
  final varsayilanBolum = gun.bolumler.isEmpty ? 'Yapılacaklar' : gun.bolumler.first.ad;
  var degisti = false;

  void maddeDegistir(String id, BeyinGunMaddesi Function(BeyinGunMaddesi) f) {
    for (final liste in bolumler.values) {
      for (var i = 0; i < liste.length; i++) {
        if (liste[i].id == id) {
          liste[i] = f(liste[i]);
          degisti = true;
        }
      }
    }
  }

  BeyinGunMaddesi kopya(BeyinGunMaddesi m, {String? durum}) => BeyinGunMaddesi(
        id: m.id,
        baslik: m.baslik,
        durum: durum ?? m.durum,
        tahminDk: m.tahminDk,
        sureDk: m.sureDk,
        proje: m.proje,
        gorev: m.gorev,
      );

  for (final b in bekleyenler) {
    final govde = jsonDecode(b.govde) as Map<String, dynamic>;
    switch (b.tur) {
      case BekleyenTur.beyinMaddeEkle when b.tarih == bugun:
        final (baslik, dk) = tahminAyir(govde['baslik'] as String);
        (bolumler[govde['bolum'] as String? ?? varsayilanBolum] ??= []).add(
          BeyinGunMaddesi(id: '${BeyinGunMaddesi.yerelOnek}${b.id}', baslik: baslik, durum: 'acik', tahminDk: dk),
        );
        degisti = true;
      case BekleyenTur.beyinMaddeIsaretle when b.tarih == bugun:
        final geri = (govde['istek'] as Map)['geri'] == true;
        String? gorev;
        maddeDegistir(b.hedefId, (m) {
          gorev = m.gorev;
          return kopya(m, durum: geri ? 'acik' : 'yapildi');
        });
        if (!geri && gorev != null) geciken.removeWhere((g) => g.kimlik == gorev);
      case BekleyenTur.beyinMaddeDevret when b.tarih == bugun:
        maddeDegistir(b.hedefId, (m) => kopya(m, durum: 'devredildi'));
      case BekleyenTur.beyinMaddeDevret when b.tarih == dun:
        // Carried here from the day before: the brain skips it when an open item with the same text is already there.
        final baslik = govde['baslik'] as String;
        if (bolumler.values.any((l) => l.any((m) => m.baslik == baslik && m.acik))) break;
        (bolumler[govde['bolum'] as String? ?? varsayilanBolum] ??= []).add(
          BeyinGunMaddesi(id: '${BeyinGunMaddesi.yerelOnek}${b.id}', baslik: baslik, durum: 'acik', tahminDk: govde['tahminDk'] as int?),
        );
        degisti = true;
      case BekleyenTur.beyinGorevBitir:
        final once = geciken.length;
        geciken.removeWhere((g) => g.kimlik == b.hedefId);
        degisti |= geciken.length != once;
        maddeDegistirGorev(bolumler, b.hedefId, kopya, () => degisti = true);
      default:
        break;
    }
  }
  if (!degisti) return gun;

  final maddeler = [for (final l in bolumler.values) ...l];
  final acikDk = maddeler.where((m) => m.acik).fold<int>(0, (t, m) => t + (m.tahminDk ?? 0));
  final uyari = gun.kapasiteUyarisi;
  return BeyinGun(
    tarih: gun.tarih,
    gunAdi: gun.gunAdi,
    haftaGunu: gun.haftaGunu,
    bugun: gun.bugun,
    planVar: gun.planVar || maddeler.isNotEmpty,
    kapandi: gun.kapandi,
    bolumler: [
      for (final e in bolumler.entries)
        if (e.value.isNotEmpty || gun.bolumler.any((b) => b.ad == e.key)) BeyinGunBolumu(ad: e.key, maddeler: e.value),
    ],
    geciken: geciken,
    toplam: BeyinGunToplami(
      madde: maddeler.length,
      yapildi: maddeler.where((m) => m.yapildi).length,
      acik: maddeler.where((m) => m.acik).length,
    ),
    kapasiteUyarisi: uyari != null && acikDk > uyari.kapasiteDk
        ? GunKapasiteUyarisi(acikTahminDk: acikDk, kapasiteDk: uyari.kapasiteDk, asimDk: acikDk - uyari.kapasiteDk)
        : null,
  );
}

/// A finished task also finishes the plan items linked to it (the brain does the same).
void maddeDegistirGorev(
  Map<String, List<BeyinGunMaddesi>> bolumler,
  String gorev,
  BeyinGunMaddesi Function(BeyinGunMaddesi, {String? durum}) kopya,
  void Function() degisti,
) {
  for (final liste in bolumler.values) {
    for (var i = 0; i < liste.length; i++) {
      if (liste[i].gorev == gorev && liste[i].acik) {
        liste[i] = kopya(liste[i], durum: 'yapildi');
        degisti();
      }
    }
  }
}

final _saatDakika = RegExp(r'~(\d+(?:[.,]\d+)?)\s*(?:saat|sa|s)(?:\s*(\d+)\s*(?:dk|d))?(?![\wçğıöşüÇĞİÖŞÜ])');
final _dakika = RegExp(r'~(\d+)\s*(?:dk|d)(?![\wçğıöşüÇĞİÖŞÜ])');

/// "Teklif hazırla ~1s30dk" -> ("Teklif hazırla", 90): the estimate tag is taken out of the text and read, as the brain does
/// when it writes the line. No tag: the text as it is and null.
(String, int?) tahminAyir(String metin) {
  String temiz(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final sa = _saatDakika.firstMatch(metin);
  if (sa != null) {
    final dk = (double.parse(sa.group(1)!.replaceAll(',', '.')) * 60).round() + (int.tryParse(sa.group(2) ?? '') ?? 0);
    return (temiz(metin.replaceRange(sa.start, sa.end, '')), dk);
  }
  final d = _dakika.firstMatch(metin);
  if (d != null) return (temiz(metin.replaceRange(d.start, d.end, '')), int.parse(d.group(1)!));
  return (temiz(metin), null);
}

/// Lays the queued day-view writes over one day of the day view (optimistic update), in queue order, so a tick, a new row,
/// a reminder, a carry-over or a "Bırak" shows at once, offline too. [bekleyenler] holds the unsent entries without the
/// refused ones: a write the server refused is no longer applied.
///
/// - A new row is shown as `yerel:<queue id>`: it cannot be ticked or edited until it is sent.
/// - Carrying yesterday's item to today (the plan write dated yesterday) takes it off "Dünden kalanlar" and adds it here;
///   carrying an item of this day away takes it off the list.
/// - The load is worked out again from the open rows. The capacity is the server's, kept as it came.
GunGorunum gunGorunumuneBekleyenleriUygula(GunGorunum gun, List<BekleyenIslemlerData> bekleyenler) {
  final tarih = tarihMetni(gun.tarih);
  final dun = tarihMetni(gun.tarih.subtract(const Duration(days: 1)));
  var ogeler = [...gun.ogeler];
  var dunden = [...gun.dundenKalanlar];
  var degisti = false;

  void degistir(String kimlik, Yapilacak Function(Yapilacak) f) {
    for (var i = 0; i < ogeler.length; i++) {
      if (ogeler[i].kimlik == kimlik) {
        ogeler[i] = f(ogeler[i]);
        degisti = true;
      }
    }
  }

  HatirlaticiOzet ozet(String id, Map<String, dynamic> istek) {
    final g = HatirlaticiGovde.fromJson(istek);
    return HatirlaticiOzet(id: id, saat: g.saat, tekrar: g.tekrar, gunler: g.gunler, acil: g.acil, israrli: g.israrli, onceGun: g.onceGun);
  }

  for (final b in bekleyenler) {
    final govde = jsonDecode(b.govde) as Map<String, dynamic>;
    switch (b.tur) {
      case BekleyenTur.gunYaptim when b.tarih == tarih:
        final geri = govde['geri'] == true;
        degistir(b.hedefId, (o) => o.copyWith(durum: geri ? 'acik' : 'yapildi'));
      case BekleyenTur.beyinGorevBitir:
        degistir('g:${b.hedefId}', (o) => o.copyWith(durum: 'yapildi'));
      case BekleyenTur.gunOgeEkle when b.tarih == tarih:
        final y = YeniOgeYaz.fromJson(govde);
        ogeler.add(Yapilacak(
          kimlik: '${Yapilacak.yerelOnek}${b.id}',
          tur: YapilacakTuru.plan,
          baslik: y.baslik,
          saat: y.saat ?? y.hatirlatici?.saat,
          tahminDk: y.tahminDk,
          proje: y.proje,
          bolum: y.bolum,
          hatirlatici: y.hatirlatici == null ? null : ozet('yerel', y.hatirlatici!.toJson()),
        ));
        degisti = true;
      case BekleyenTur.ogeHatirlaticiYaz when b.tarih == tarih:
        final istek = Map<String, dynamic>.from(govde['istek'] as Map);
        degistir(b.hedefId, (o) {
          final h = ozet(o.hatirlatici?.id ?? 'yerel', istek);
          return o.copyWith(hatirlatici: h, saat: o.saat == null ? h.saat : null);
        });
      case BekleyenTur.ogeHatirlaticiSil when b.tarih == tarih:
        degistir(b.hedefId, (o) => o.copyWith(hatirlaticiTemizle: true));
      case BekleyenTur.dundenBirak when b.tarih == tarih:
        final once = dunden.length;
        dunden.removeWhere((d) => d.maddeId == b.hedefId);
        degisti |= dunden.length != once;
      case BekleyenTur.gunDevret when b.tarih == dun:
        // Carried here from yesterday: off the "left over" list, onto this day (the brain skips a twin that is open already).
        final baslik = govde['baslik'] as String;
        final once = dunden.length;
        dunden.removeWhere((d) => 'm:${d.maddeId}' == b.hedefId);
        degisti |= dunden.length != once;
        if (ogeler.any((o) => o.baslik == baslik && !o.yapildi)) break;
        ogeler.add(Yapilacak(
          kimlik: '${Yapilacak.yerelOnek}${b.id}',
          tur: YapilacakTuru.plan,
          baslik: baslik,
          bolum: govde['bolum'] as String?,
          tahminDk: govde['tahminDk'] as int?,
        ));
        degisti = true;
      case BekleyenTur.gunDevret when b.tarih == tarih:
        final once = ogeler.length;
        ogeler.removeWhere((o) => o.kimlik == b.hedefId);
        degisti |= ogeler.length != once;
      case BekleyenTur.beyinMaddeDevret when b.tarih == dun:
        // The older plan write (an entry queued before the single carry-over): same effect on the lists.
        final baslik = govde['baslik'] as String;
        final once = dunden.length;
        dunden.removeWhere((d) => d.maddeId == b.hedefId);
        degisti |= dunden.length != once;
        if (ogeler.any((o) => o.baslik == baslik && !o.yapildi)) break;
        ogeler.add(Yapilacak(
          kimlik: '${Yapilacak.yerelOnek}${b.id}',
          tur: YapilacakTuru.plan,
          baslik: baslik,
          bolum: govde['bolum'] as String?,
          tahminDk: govde['tahminDk'] as int?,
        ));
        degisti = true;
      case BekleyenTur.beyinMaddeDevret when b.tarih == tarih:
        final once = ogeler.length;
        ogeler.removeWhere((o) => o.kimlik == 'm:${b.hedefId}');
        degisti |= ogeler.length != once;
      default:
        break;
    }
  }
  if (!degisti) return gun;

  // Timed rows by their hour first, then the ones without (the server's order; the sort is stable).
  ogeler = [
    ...ogeler.where((o) => o.saat != null).toList()..sort((a, b) => a.saat!.compareTo(b.saat!)),
    ...ogeler.where((o) => o.saat == null),
  ];
  final yukluler = ogeler.where((o) => o.yuke).toList();
  return gun.copyWith(
    ogeler: ogeler,
    dundenKalanlar: dunden,
    yuk: gun.yuk.yenidenHesapla(
      acikTahminDk: yukluler.fold<int>(0, (t, o) => t + (o.tahminDk ?? 0)),
      tahminsizSayi: yukluler.where((o) => o.tahminDk == null).length,
    ),
  );
}
