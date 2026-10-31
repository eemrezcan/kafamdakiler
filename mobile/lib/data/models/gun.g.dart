// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gun.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Gun _$GunFromJson(Map<String, dynamic> json) => Gun(
  tarih: const TarihDonusturucu().fromJson(json['tarih'] as String),
  miktar: (json['miktar'] as num).toDouble(),
  dakika: (json['dakika'] as num?)?.toInt(),
  deger: (json['deger'] as num).toDouble(),
  planli: json['planli'] as bool,
  guc: (json['guc'] as num).toDouble(),
);

Map<String, dynamic> _$GunToJson(Gun instance) => <String, dynamic>{
  'tarih': const TarihDonusturucu().toJson(instance.tarih),
  'miktar': instance.miktar,
  'dakika': instance.dakika,
  'deger': instance.deger,
  'planli': instance.planli,
  'guc': instance.guc,
};

GunYaz _$GunYazFromJson(Map<String, dynamic> json) => GunYaz(
  miktar: (json['miktar'] as num).toDouble(),
  dakika: (json['dakika'] as num?)?.toInt(),
);

Map<String, dynamic> _$GunYazToJson(GunYaz instance) => <String, dynamic>{
  'miktar': instance.miktar,
  'dakika': ?instance.dakika,
};
