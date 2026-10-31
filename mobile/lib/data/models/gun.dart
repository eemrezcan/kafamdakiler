import 'package:json_annotation/json_annotation.dart';

import 'tarih_donusturucu.dart';

part 'gun.g.dart';

/// `GunDto`: one habit day.
@JsonSerializable()
@TarihDonusturucu()
class Gun {
  const Gun({
    required this.tarih,
    required this.miktar,
    this.dakika,
    required this.deger,
    required this.planli,
    required this.guc,
  });

  final DateTime tarih;
  final double miktar;
  final int? dakika;
  final double deger;
  final bool planli;
  final double guc;

  factory Gun.fromJson(Map<String, dynamic> json) => _$GunFromJson(json);
  Map<String, dynamic> toJson() => _$GunToJson(this);
}

/// Body of `PUT /api/aliskanliklar/{id}/kayitlar/{tarih}`: the day's total.
@JsonSerializable(includeIfNull: false)
class GunYaz {
  const GunYaz({required this.miktar, this.dakika});

  final double miktar;
  final int? dakika;

  factory GunYaz.fromJson(Map<String, dynamic> json) => _$GunYazFromJson(json);
  Map<String, dynamic> toJson() => _$GunYazToJson(this);
}
