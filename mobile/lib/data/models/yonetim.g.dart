// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yonetim.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Izin _$IzinFromJson(Map<String, dynamic> json) => Izin(
  izin: json['izin'] as String,
  aciklama: json['aciklama'] as String,
  acik: json['acik'] as bool,
);

Map<String, dynamic> _$IzinToJson(Izin instance) => <String, dynamic>{
  'izin': instance.izin,
  'aciklama': instance.aciklama,
  'acik': instance.acik,
};

YonetimBeyinDurumu _$YonetimBeyinDurumuFromJson(Map<String, dynamic> json) =>
    YonetimBeyinDurumu(
      bagli: json['bagli'] as bool,
      vault: json['vault'] as String?,
      bekleyenYakalama: (json['bekleyenYakalama'] as num?)?.toInt() ?? 0,
      hataliYakalama: (json['hataliYakalama'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$YonetimBeyinDurumuToJson(YonetimBeyinDurumu instance) =>
    <String, dynamic>{
      'bagli': instance.bagli,
      'vault': instance.vault,
      'bekleyenYakalama': instance.bekleyenYakalama,
      'hataliYakalama': instance.hataliYakalama,
    };

Gonderim _$GonderimFromJson(Map<String, dynamic> json) => Gonderim(
  id: json['id'] as String,
  metin: json['metin'] as String?,
  fotografVar: json['fotografVar'] as bool? ?? false,
  hedef: json['hedef'] as String?,
  durum: $enumDecode(_$YakalamaDurumuEnumMap, json['durum']),
  gonderim: $enumDecode(_$GonderimDurumuEnumMap, json['gonderim']),
  yakalandiAt: DateTime.parse(json['yakalandiAt'] as String),
  denemeSayisi: (json['denemeSayisi'] as num?)?.toInt() ?? 0,
  sonDenemeAt: json['sonDenemeAt'] == null
      ? null
      : DateTime.parse(json['sonDenemeAt'] as String),
  sonHata: json['sonHata'] as String?,
);

Map<String, dynamic> _$GonderimToJson(Gonderim instance) => <String, dynamic>{
  'id': instance.id,
  'metin': instance.metin,
  'fotografVar': instance.fotografVar,
  'hedef': instance.hedef,
  'durum': _$YakalamaDurumuEnumMap[instance.durum]!,
  'gonderim': _$GonderimDurumuEnumMap[instance.gonderim]!,
  'yakalandiAt': instance.yakalandiAt.toIso8601String(),
  'denemeSayisi': instance.denemeSayisi,
  'sonDenemeAt': instance.sonDenemeAt?.toIso8601String(),
  'sonHata': instance.sonHata,
};

const _$YakalamaDurumuEnumMap = {
  YakalamaDurumu.bekliyor: 'bekliyor',
  YakalamaDurumu.beyneGitti: 'beyneGitti',
  YakalamaDurumu.islendi: 'islendi',
};

const _$GonderimDurumuEnumMap = {
  GonderimDurumu.bekliyor: 'bekliyor',
  GonderimDurumu.gonderiliyor: 'gonderiliyor',
  GonderimDurumu.hatali: 'hatali',
  GonderimDurumu.takili: 'takili',
  GonderimDurumu.tamam: 'tamam',
};
