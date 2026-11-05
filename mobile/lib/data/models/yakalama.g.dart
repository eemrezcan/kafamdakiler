// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yakalama.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Yakalama _$YakalamaFromJson(Map<String, dynamic> json) => Yakalama(
  id: json['id'] as String,
  metin: json['metin'] as String?,
  fotografId: json['fotografId'] as String?,
  fotografUrl: json['fotografUrl'] as String?,
  hedef: json['hedef'] as String?,
  durum: $enumDecode(_$YakalamaDurumuEnumMap, json['durum']),
  yakalandiAt: DateTime.parse(json['yakalandiAt'] as String),
  olusturulma: DateTime.parse(json['olusturulma'] as String),
);

Map<String, dynamic> _$YakalamaToJson(Yakalama instance) => <String, dynamic>{
  'id': instance.id,
  'metin': instance.metin,
  'fotografId': instance.fotografId,
  'fotografUrl': instance.fotografUrl,
  'hedef': instance.hedef,
  'durum': _$YakalamaDurumuEnumMap[instance.durum]!,
  'yakalandiAt': instance.yakalandiAt.toIso8601String(),
  'olusturulma': instance.olusturulma.toIso8601String(),
};

const _$YakalamaDurumuEnumMap = {
  YakalamaDurumu.bekliyor: 'bekliyor',
  YakalamaDurumu.beyneGitti: 'beyneGitti',
  YakalamaDurumu.islendi: 'islendi',
};

YakalamaYaz _$YakalamaYazFromJson(Map<String, dynamic> json) => YakalamaYaz(
  id: json['id'] as String?,
  metin: json['metin'] as String?,
  fotografId: json['fotografId'] as String?,
  hedef: json['hedef'] as String?,
  yakalandiAt: DateTime.parse(json['yakalandiAt'] as String),
);

Map<String, dynamic> _$YakalamaYazToJson(YakalamaYaz instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'metin': ?instance.metin,
      'fotografId': ?instance.fotografId,
      'hedef': ?instance.hedef,
      'yakalandiAt': _anYaz(instance.yakalandiAt),
    };
