// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oturum.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Oturum _$OturumFromJson(Map<String, dynamic> json) => Oturum(
  id: json['id'] as String,
  ogeId: json['ogeId'] as String,
  tarih: const TarihDonusturucu().fromJson(json['tarih'] as String),
  baslangicKonum: (json['baslangicKonum'] as num).toDouble(),
  bitisKonum: (json['bitisKonum'] as num).toDouble(),
  miktar: (json['miktar'] as num).toDouble(),
  dakika: (json['dakika'] as num?)?.toInt(),
  olusturulma: DateTime.parse(json['olusturulma'] as String),
  son: json['son'] as bool,
);

Map<String, dynamic> _$OturumToJson(Oturum instance) => <String, dynamic>{
  'id': instance.id,
  'ogeId': instance.ogeId,
  'tarih': const TarihDonusturucu().toJson(instance.tarih),
  'baslangicKonum': instance.baslangicKonum,
  'bitisKonum': instance.bitisKonum,
  'miktar': instance.miktar,
  'dakika': instance.dakika,
  'olusturulma': instance.olusturulma.toIso8601String(),
  'son': instance.son,
};

OturumEkle _$OturumEkleFromJson(Map<String, dynamic> json) => OturumEkle(
  id: json['id'] as String?,
  bitisKonum: (json['bitisKonum'] as num).toDouble(),
  dakika: (json['dakika'] as num?)?.toInt(),
  baslangicKonum: (json['baslangicKonum'] as num?)?.toDouble(),
  baslangicAni: _anCoz(json['baslangicAni'] as String?),
);

Map<String, dynamic> _$OturumEkleToJson(OturumEkle instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'bitisKonum': instance.bitisKonum,
      'dakika': ?instance.dakika,
      'baslangicKonum': ?instance.baslangicKonum,
      'baslangicAni': ?_anYaz(instance.baslangicAni),
    };

OturumGuncelle _$OturumGuncelleFromJson(Map<String, dynamic> json) =>
    OturumGuncelle(
      bitisKonum: (json['bitisKonum'] as num).toDouble(),
      dakika: (json['dakika'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OturumGuncelleToJson(OturumGuncelle instance) =>
    <String, dynamic>{
      'bitisKonum': instance.bitisKonum,
      'dakika': ?instance.dakika,
    };
