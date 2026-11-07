// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eylem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Eylem _$EylemFromJson(Map<String, dynamic> json) => Eylem(
  id: json['id'] as String,
  tur: json['tur'] as String,
  turAdi: json['turAdi'] as String,
  yuk: json['yuk'] as Map<String, dynamic>? ?? const {},
  ozet: json['ozet'] as String,
  kaynak: json['kaynak'] as String,
  disKaynak: json['disKaynak'] as bool? ?? false,
  gerekce: json['gerekce'] as String?,
  guven: (json['guven'] as num?)?.toDouble(),
  durum: $enumDecode(_$EylemDurumuEnumMap, json['durum']),
  geriAlmaBilgisi: json['geriAlmaBilgisi'] as Map<String, dynamic>?,
  hataMesaji: json['hataMesaji'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  kararAni: json['kararAni'] == null
      ? null
      : DateTime.parse(json['kararAni'] as String),
  uygulamaAni: json['uygulamaAni'] == null
      ? null
      : DateTime.parse(json['uygulamaAni'] as String),
  geriAlmaAni: json['geriAlmaAni'] == null
      ? null
      : DateTime.parse(json['geriAlmaAni'] as String),
  kararVerenId: json['kararVerenId'] as String?,
);

Map<String, dynamic> _$EylemToJson(Eylem instance) => <String, dynamic>{
  'id': instance.id,
  'tur': instance.tur,
  'turAdi': instance.turAdi,
  'yuk': instance.yuk,
  'ozet': instance.ozet,
  'kaynak': instance.kaynak,
  'disKaynak': instance.disKaynak,
  'gerekce': instance.gerekce,
  'guven': instance.guven,
  'durum': _$EylemDurumuEnumMap[instance.durum]!,
  'geriAlmaBilgisi': instance.geriAlmaBilgisi,
  'hataMesaji': instance.hataMesaji,
  'createdAt': instance.createdAt.toIso8601String(),
  'kararAni': instance.kararAni?.toIso8601String(),
  'uygulamaAni': instance.uygulamaAni?.toIso8601String(),
  'geriAlmaAni': instance.geriAlmaAni?.toIso8601String(),
  'kararVerenId': instance.kararVerenId,
};

const _$EylemDurumuEnumMap = {
  EylemDurumu.bekliyor: 'bekliyor',
  EylemDurumu.uygulandi: 'uygulandi',
  EylemDurumu.reddedildi: 'reddedildi',
  EylemDurumu.geriAlindi: 'geriAlindi',
  EylemDurumu.hatali: 'hatali',
};

EylemKipDurumu _$EylemKipDurumuFromJson(Map<String, dynamic> json) =>
    EylemKipDurumu(
      tur: json['tur'] as String,
      turAdi: json['turAdi'] as String,
      kip: $enumDecode(_$EylemKipiEnumMap, json['kip']),
      ardArdaRed: (json['ardArdaRed'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$EylemKipDurumuToJson(EylemKipDurumu instance) =>
    <String, dynamic>{
      'tur': instance.tur,
      'turAdi': instance.turAdi,
      'kip': _$EylemKipiEnumMap[instance.kip]!,
      'ardArdaRed': instance.ardArdaRed,
    };

const _$EylemKipiEnumMap = {
  EylemKipi.sor: 'sor',
  EylemKipi.kendinYap: 'kendinYap',
  EylemKipi.yasak: 'yasak',
};
