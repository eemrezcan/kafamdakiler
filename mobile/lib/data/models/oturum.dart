import 'package:json_annotation/json_annotation.dart';

import 'tarih_donusturucu.dart';

part 'oturum.g.dart';

/// `OturumDto`: one reading/watching session of a shelf item.
@JsonSerializable()
class Oturum {
  const Oturum({
    required this.id,
    required this.ogeId,
    required this.tarih,
    required this.baslangicKonum,
    required this.bitisKonum,
    required this.miktar,
    this.dakika,
    required this.olusturulma,
    required this.son,
  });

  final String id;
  final String ogeId;
  @TarihDonusturucu()
  final DateTime tarih;
  final double baslangicKonum;
  final double bitisKonum;
  final double miktar;
  final int? dakika;
  final DateTime olusturulma;
  final bool son;

  factory Oturum.fromJson(Map<String, dynamic> json) => _$OturumFromJson(json);
  Map<String, dynamic> toJson() => _$OturumToJson(this);
}

/// `OturumEkleDto`. Offline entries carry the client Guid v7 [id], the
/// [baslangicKonum] they computed and the [baslangicAni] (with offset).
@JsonSerializable(includeIfNull: false)
class OturumEkle {
  const OturumEkle({
    this.id,
    required this.bitisKonum,
    this.dakika,
    this.baslangicKonum,
    this.baslangicAni,
  });

  final String? id;
  final double bitisKonum;
  final int? dakika;
  final double? baslangicKonum;
  @JsonKey(fromJson: _anCoz, toJson: _anYaz)
  final DateTime? baslangicAni;

  factory OturumEkle.fromJson(Map<String, dynamic> json) => _$OturumEkleFromJson(json);
  Map<String, dynamic> toJson() => _$OturumEkleToJson(this);
}

DateTime? _anCoz(String? metin) => metin == null ? null : DateTime.parse(metin);

/// The contract example is `2026-10-31T21:10:00+03:00`; a UTC instant with
/// `Z` is the same moment and what `DateTimeOffset` accepts as well.
String? _anYaz(DateTime? an) => an?.toUtc().toIso8601String();

/// Body of `PUT /api/oturumlar/{id}`.
@JsonSerializable(includeIfNull: false)
class OturumGuncelle {
  const OturumGuncelle({required this.bitisKonum, this.dakika});

  final double bitisKonum;
  final int? dakika;

  factory OturumGuncelle.fromJson(Map<String, dynamic> json) => _$OturumGuncelleFromJson(json);
  Map<String, dynamic> toJson() => _$OturumGuncelleToJson(this);
}
