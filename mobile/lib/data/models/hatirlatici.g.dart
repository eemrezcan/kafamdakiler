// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hatirlatici.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Hatirlatici _$HatirlaticiFromJson(Map<String, dynamic> json) => Hatirlatici(
  id: json['id'] as String,
  baslik: json['baslik'] as String,
  not: json['not'] as String?,
  tur: $enumDecode(_$HatirlaticiTuruEnumMap, json['tur']),
  kime: json['kime'] as String?,
  gun: const TarihDonusturucu().fromJson(json['gun'] as String),
  saat: const SaatDonusturucu().fromJson(json['saat'] as String?),
  tekrar: $enumDecode(_$TekrarEnumMap, json['tekrar']),
  onceGun: (json['onceGun'] as num).toInt(),
  durum: $enumDecode(_$HatirlaticiDurumuEnumMap, json['durum']),
  sonrakiAn: DateTime.parse(json['sonrakiAn'] as String),
  erteleAn: json['erteleAn'] == null
      ? null
      : DateTime.parse(json['erteleAn'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  israrli: json['israrli'] as bool? ?? false,
  israrAraligiDakika: (json['israrAraligiDakika'] as num?)?.toInt() ?? 15,
  israrEnCok: (json['israrEnCok'] as num?)?.toInt() ?? 3,
  acil: json['acil'] as bool? ?? false,
);

Map<String, dynamic> _$HatirlaticiToJson(Hatirlatici instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baslik': instance.baslik,
      'not': instance.not,
      'tur': _$HatirlaticiTuruEnumMap[instance.tur]!,
      'kime': instance.kime,
      'gun': const TarihDonusturucu().toJson(instance.gun),
      'saat': const SaatDonusturucu().toJson(instance.saat),
      'tekrar': _$TekrarEnumMap[instance.tekrar]!,
      'onceGun': instance.onceGun,
      'durum': _$HatirlaticiDurumuEnumMap[instance.durum]!,
      'sonrakiAn': instance.sonrakiAn.toIso8601String(),
      'erteleAn': instance.erteleAn?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'israrli': instance.israrli,
      'israrAraligiDakika': instance.israrAraligiDakika,
      'israrEnCok': instance.israrEnCok,
      'acil': instance.acil,
    };

const _$HatirlaticiTuruEnumMap = {
  HatirlaticiTuru.gorev: 'gorev',
  HatirlaticiTuru.soz: 'soz',
  HatirlaticiTuru.ozelTarih: 'ozelTarih',
};

const _$TekrarEnumMap = {
  Tekrar.yok: 'yok',
  Tekrar.gunluk: 'gunluk',
  Tekrar.haftalik: 'haftalik',
  Tekrar.aylik: 'aylik',
  Tekrar.yillik: 'yillik',
};

const _$HatirlaticiDurumuEnumMap = {
  HatirlaticiDurumu.acik: 'acik',
  HatirlaticiDurumu.tamam: 'tamam',
  HatirlaticiDurumu.arsiv: 'arsiv',
};

HatirlaticiYaz _$HatirlaticiYazFromJson(Map<String, dynamic> json) =>
    HatirlaticiYaz(
      id: json['id'] as String?,
      baslik: json['baslik'] as String,
      not: json['not'] as String?,
      tur:
          $enumDecodeNullable(_$HatirlaticiTuruEnumMap, json['tur']) ??
          HatirlaticiTuru.gorev,
      kime: json['kime'] as String?,
      gun: const TarihDonusturucu().fromJson(json['gun'] as String),
      saat: const SaatDonusturucu().fromJson(json['saat'] as String?),
      tekrar:
          $enumDecodeNullable(_$TekrarEnumMap, json['tekrar']) ?? Tekrar.yok,
      onceGun: (json['onceGun'] as num?)?.toInt() ?? 0,
      durum:
          $enumDecodeNullable(_$HatirlaticiDurumuEnumMap, json['durum']) ??
          HatirlaticiDurumu.acik,
      israrli: json['israrli'] as bool? ?? false,
      israrAraligiDakika: (json['israrAraligiDakika'] as num?)?.toInt() ?? 15,
      israrEnCok: (json['israrEnCok'] as num?)?.toInt() ?? 3,
      acil: json['acil'] as bool? ?? false,
    );

Map<String, dynamic> _$HatirlaticiYazToJson(HatirlaticiYaz instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'baslik': instance.baslik,
      'not': ?instance.not,
      'tur': _$HatirlaticiTuruEnumMap[instance.tur]!,
      'kime': ?instance.kime,
      'gun': const TarihDonusturucu().toJson(instance.gun),
      'saat': ?const SaatDonusturucu().toJson(instance.saat),
      'tekrar': _$TekrarEnumMap[instance.tekrar]!,
      'onceGun': instance.onceGun,
      'durum': _$HatirlaticiDurumuEnumMap[instance.durum]!,
      'israrli': instance.israrli,
      'israrAraligiDakika': instance.israrAraligiDakika,
      'israrEnCok': instance.israrEnCok,
      'acil': instance.acil,
    };
