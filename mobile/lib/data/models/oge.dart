import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'tarih_donusturucu.dart';

part 'oge.g.dart';

/// Item summary inside `AliskanlikDto.devamEdenler`.
@JsonSerializable()
class OgeOzet {
  const OgeOzet({
    required this.id,
    required this.ad,
    this.altBaslik,
    this.fotografUrl,
    required this.guncelKonum,
    this.toplam,
    this.ilerleme,
  });

  final String id;
  final String ad;
  final String? altBaslik;
  final String? fotografUrl;
  final double guncelKonum;
  final double? toplam;
  final double? ilerleme;

  OgeOzet copyWith({double? guncelKonum, double? ilerleme}) => OgeOzet(
        id: id,
        ad: ad,
        altBaslik: altBaslik,
        fotografUrl: fotografUrl,
        guncelKonum: guncelKonum ?? this.guncelKonum,
        toplam: toplam,
        ilerleme: ilerleme ?? this.ilerleme,
      );

  factory OgeOzet.fromJson(Map<String, dynamic> json) => _$OgeOzetFromJson(json);
  Map<String, dynamic> toJson() => _$OgeOzetToJson(this);
}

/// `OgeDto`.
@JsonSerializable()
@NullableTarihDonusturucu()
class Oge {
  const Oge({
    required this.id,
    required this.aliskanlikId,
    required this.ad,
    this.altBaslik,
    this.toplam,
    required this.baslangicKonumu,
    required this.guncelKonum,
    this.ilerleme,
    this.fotografId,
    this.fotografUrl,
    required this.durum,
    this.baslamaTarihi,
    this.bitisTarihi,
    this.puan,
    this.not,
    this.hiz,
    this.tahminiBitis,
    this.toplamDakika,
    required this.olusturulma,
  });

  final String id;
  final String aliskanlikId;
  final String ad;
  final String? altBaslik;
  final double? toplam;
  final double baslangicKonumu;
  final double guncelKonum;
  final double? ilerleme;
  final String? fotografId;
  final String? fotografUrl;
  final OgeDurumu durum;
  final DateTime? baslamaTarihi;
  final DateTime? bitisTarihi;
  final int? puan;
  final String? not;
  final double? hiz;
  final DateTime? tahminiBitis;
  final int? toplamDakika;
  final DateTime olusturulma;

  Oge copyWith({double? guncelKonum, double? ilerleme, OgeDurumu? durum}) => Oge(
        id: id,
        aliskanlikId: aliskanlikId,
        ad: ad,
        altBaslik: altBaslik,
        toplam: toplam,
        baslangicKonumu: baslangicKonumu,
        guncelKonum: guncelKonum ?? this.guncelKonum,
        ilerleme: ilerleme ?? this.ilerleme,
        fotografId: fotografId,
        fotografUrl: fotografUrl,
        durum: durum ?? this.durum,
        baslamaTarihi: baslamaTarihi,
        bitisTarihi: bitisTarihi,
        puan: puan,
        not: not,
        hiz: hiz,
        tahminiBitis: tahminiBitis,
        toplamDakika: toplamDakika,
        olusturulma: olusturulma,
      );

  /// The writable view of this item, the starting point of the edit form.
  OgeYaz yazDto() => OgeYaz(
        id: id,
        ad: ad,
        altBaslik: altBaslik,
        toplam: toplam,
        baslangicKonumu: baslangicKonumu,
        fotografId: fotografId,
        durum: durum,
        puan: puan,
        not: not,
      );

  factory Oge.fromJson(Map<String, dynamic> json) => _$OgeFromJson(json);
  Map<String, dynamic> toJson() => _$OgeToJson(this);
}

/// `OgeYazDto`.
@JsonSerializable(includeIfNull: false)
class OgeYaz {
  const OgeYaz({
    this.id,
    required this.ad,
    this.altBaslik,
    this.toplam,
    this.baslangicKonumu = 0,
    this.fotografId,
    required this.durum,
    this.puan,
    this.not,
  });

  final String? id;
  final String ad;
  final String? altBaslik;
  final double? toplam;
  final double baslangicKonumu;
  final String? fotografId;
  final OgeDurumu durum;
  final int? puan;
  final String? not;

  factory OgeYaz.fromJson(Map<String, dynamic> json) => _$OgeYazFromJson(json);
  Map<String, dynamic> toJson() => _$OgeYazToJson(this);
}
