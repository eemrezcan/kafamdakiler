// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OgeOzet _$OgeOzetFromJson(Map<String, dynamic> json) => OgeOzet(
  id: json['id'] as String,
  ad: json['ad'] as String,
  altBaslik: json['altBaslik'] as String?,
  fotografUrl: json['fotografUrl'] as String?,
  guncelKonum: (json['guncelKonum'] as num).toDouble(),
  toplam: (json['toplam'] as num?)?.toDouble(),
  ilerleme: (json['ilerleme'] as num?)?.toDouble(),
);

Map<String, dynamic> _$OgeOzetToJson(OgeOzet instance) => <String, dynamic>{
  'id': instance.id,
  'ad': instance.ad,
  'altBaslik': instance.altBaslik,
  'fotografUrl': instance.fotografUrl,
  'guncelKonum': instance.guncelKonum,
  'toplam': instance.toplam,
  'ilerleme': instance.ilerleme,
};

Oge _$OgeFromJson(Map<String, dynamic> json) => Oge(
  id: json['id'] as String,
  aliskanlikId: json['aliskanlikId'] as String,
  ad: json['ad'] as String,
  altBaslik: json['altBaslik'] as String?,
  toplam: (json['toplam'] as num?)?.toDouble(),
  baslangicKonumu: (json['baslangicKonumu'] as num).toDouble(),
  guncelKonum: (json['guncelKonum'] as num).toDouble(),
  ilerleme: (json['ilerleme'] as num?)?.toDouble(),
  fotografId: json['fotografId'] as String?,
  fotografUrl: json['fotografUrl'] as String?,
  durum: $enumDecode(_$OgeDurumuEnumMap, json['durum']),
  baslamaTarihi: const NullableTarihDonusturucu().fromJson(
    json['baslamaTarihi'] as String?,
  ),
  bitisTarihi: const NullableTarihDonusturucu().fromJson(
    json['bitisTarihi'] as String?,
  ),
  puan: (json['puan'] as num?)?.toInt(),
  not: json['not'] as String?,
  hiz: (json['hiz'] as num?)?.toDouble(),
  tahminiBitis: const NullableTarihDonusturucu().fromJson(
    json['tahminiBitis'] as String?,
  ),
  toplamDakika: (json['toplamDakika'] as num?)?.toInt(),
  olusturulma: DateTime.parse(json['olusturulma'] as String),
);

Map<String, dynamic> _$OgeToJson(Oge instance) => <String, dynamic>{
  'id': instance.id,
  'aliskanlikId': instance.aliskanlikId,
  'ad': instance.ad,
  'altBaslik': instance.altBaslik,
  'toplam': instance.toplam,
  'baslangicKonumu': instance.baslangicKonumu,
  'guncelKonum': instance.guncelKonum,
  'ilerleme': instance.ilerleme,
  'fotografId': instance.fotografId,
  'fotografUrl': instance.fotografUrl,
  'durum': _$OgeDurumuEnumMap[instance.durum]!,
  'baslamaTarihi': const NullableTarihDonusturucu().toJson(
    instance.baslamaTarihi,
  ),
  'bitisTarihi': const NullableTarihDonusturucu().toJson(instance.bitisTarihi),
  'puan': instance.puan,
  'not': instance.not,
  'hiz': instance.hiz,
  'tahminiBitis': const NullableTarihDonusturucu().toJson(
    instance.tahminiBitis,
  ),
  'toplamDakika': instance.toplamDakika,
  'olusturulma': instance.olusturulma.toIso8601String(),
};

const _$OgeDurumuEnumMap = {
  OgeDurumu.siradaki: 'siradaki',
  OgeDurumu.devam: 'devam',
  OgeDurumu.bitti: 'bitti',
  OgeDurumu.birakildi: 'birakildi',
};

OgeYaz _$OgeYazFromJson(Map<String, dynamic> json) => OgeYaz(
  id: json['id'] as String?,
  ad: json['ad'] as String,
  altBaslik: json['altBaslik'] as String?,
  toplam: (json['toplam'] as num?)?.toDouble(),
  baslangicKonumu: (json['baslangicKonumu'] as num?)?.toDouble() ?? 0,
  fotografId: json['fotografId'] as String?,
  durum: $enumDecode(_$OgeDurumuEnumMap, json['durum']),
  puan: (json['puan'] as num?)?.toInt(),
  not: json['not'] as String?,
);

Map<String, dynamic> _$OgeYazToJson(OgeYaz instance) => <String, dynamic>{
  'id': ?instance.id,
  'ad': instance.ad,
  'altBaslik': ?instance.altBaslik,
  'toplam': ?instance.toplam,
  'baslangicKonumu': instance.baslangicKonumu,
  'fotografId': ?instance.fotografId,
  'durum': _$OgeDurumuEnumMap[instance.durum]!,
  'puan': ?instance.puan,
  'not': ?instance.not,
};
