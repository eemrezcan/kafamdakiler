// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aliskanlik.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BugunDurumu _$BugunDurumuFromJson(Map<String, dynamic> json) => BugunDurumu(
  tarih: const TarihDonusturucu().fromJson(json['tarih'] as String),
  miktar: (json['miktar'] as num).toDouble(),
  dakika: (json['dakika'] as num?)?.toInt(),
  deger: (json['deger'] as num).toDouble(),
  planli: json['planli'] as bool,
);

Map<String, dynamic> _$BugunDurumuToJson(BugunDurumu instance) =>
    <String, dynamic>{
      'tarih': const TarihDonusturucu().toJson(instance.tarih),
      'miktar': instance.miktar,
      'dakika': instance.dakika,
      'deger': instance.deger,
      'planli': instance.planli,
    };

Aliskanlik _$AliskanlikFromJson(Map<String, dynamic> json) => Aliskanlik(
  id: json['id'] as String,
  ad: json['ad'] as String,
  tur: $enumDecode(_$AliskanlikTuruEnumMap, json['tur']),
  ikon: json['ikon'] as String,
  renk: json['renk'] as String,
  olcu: $enumDecode(_$OlcuEnumMap, json['olcu']),
  hedefYonu: $enumDecode(_$HedefYonuEnumMap, json['hedefYonu']),
  gunlukHedef: (json['gunlukHedef'] as num?)?.toDouble(),
  birim: json['birim'] as String?,
  ogeEtiketi: json['ogeEtiketi'] as String?,
  altBaslikEtiketi: json['altBaslikEtiketi'] as String?,
  siklik: $enumDecode(_$SiklikEnumMap, json['siklik']),
  haftalikSayi: (json['haftalikSayi'] as num?)?.toInt(),
  gunler: (json['gunler'] as List<dynamic>?)
      ?.map((e) => $enumDecode(_$HaftaGunuEnumMap, e))
      .toList(),
  sira: (json['sira'] as num).toInt(),
  arsivlendi: json['arsivlendi'] as bool,
  olusturulma: DateTime.parse(json['olusturulma'] as String),
  bugun: json['bugun'] == null
      ? null
      : BugunDurumu.fromJson(json['bugun'] as Map<String, dynamic>),
  guc: (json['guc'] as num?)?.toDouble() ?? 0,
  seri: (json['seri'] as num?)?.toInt() ?? 0,
  enUzunSeri: (json['enUzunSeri'] as num?)?.toInt() ?? 0,
  devamEdenler:
      (json['devamEdenler'] as List<dynamic>?)
          ?.map((e) => OgeOzet.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$AliskanlikToJson(Aliskanlik instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ad': instance.ad,
      'tur': _$AliskanlikTuruEnumMap[instance.tur]!,
      'ikon': instance.ikon,
      'renk': instance.renk,
      'olcu': _$OlcuEnumMap[instance.olcu]!,
      'hedefYonu': _$HedefYonuEnumMap[instance.hedefYonu]!,
      'gunlukHedef': instance.gunlukHedef,
      'birim': instance.birim,
      'ogeEtiketi': instance.ogeEtiketi,
      'altBaslikEtiketi': instance.altBaslikEtiketi,
      'siklik': _$SiklikEnumMap[instance.siklik]!,
      'haftalikSayi': instance.haftalikSayi,
      'gunler': instance.gunler?.map((e) => _$HaftaGunuEnumMap[e]!).toList(),
      'sira': instance.sira,
      'arsivlendi': instance.arsivlendi,
      'olusturulma': instance.olusturulma.toIso8601String(),
      'bugun': instance.bugun?.toJson(),
      'guc': instance.guc,
      'seri': instance.seri,
      'enUzunSeri': instance.enUzunSeri,
      'devamEdenler': instance.devamEdenler.map((e) => e.toJson()).toList(),
    };

const _$AliskanlikTuruEnumMap = {
  AliskanlikTuru.sayac: 'sayac',
  AliskanlikTuru.raf: 'raf',
};

const _$OlcuEnumMap = {Olcu.evetHayir: 'evetHayir', Olcu.sayili: 'sayili'};

const _$HedefYonuEnumMap = {HedefYonu.enAz: 'enAz', HedefYonu.enCok: 'enCok'};

const _$SiklikEnumMap = {
  Siklik.herGun: 'herGun',
  Siklik.haftadaN: 'haftadaN',
  Siklik.belirliGunler: 'belirliGunler',
};

const _$HaftaGunuEnumMap = {
  HaftaGunu.pzt: 'pzt',
  HaftaGunu.sal: 'sal',
  HaftaGunu.car: 'car',
  HaftaGunu.per: 'per',
  HaftaGunu.cum: 'cum',
  HaftaGunu.cmt: 'cmt',
  HaftaGunu.paz: 'paz',
};

AliskanlikYaz _$AliskanlikYazFromJson(Map<String, dynamic> json) =>
    AliskanlikYaz(
      id: json['id'] as String?,
      ad: json['ad'] as String,
      tur: $enumDecode(_$AliskanlikTuruEnumMap, json['tur']),
      ikon: json['ikon'] as String,
      renk: json['renk'] as String,
      olcu: $enumDecode(_$OlcuEnumMap, json['olcu']),
      hedefYonu: $enumDecode(_$HedefYonuEnumMap, json['hedefYonu']),
      gunlukHedef: (json['gunlukHedef'] as num?)?.toDouble(),
      birim: json['birim'] as String?,
      ogeEtiketi: json['ogeEtiketi'] as String?,
      altBaslikEtiketi: json['altBaslikEtiketi'] as String?,
      siklik: $enumDecode(_$SiklikEnumMap, json['siklik']),
      haftalikSayi: (json['haftalikSayi'] as num?)?.toInt(),
      gunler: (json['gunler'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$HaftaGunuEnumMap, e))
          .toList(),
      sira: (json['sira'] as num?)?.toInt() ?? 0,
      arsivlendi: json['arsivlendi'] as bool? ?? false,
    );

Map<String, dynamic> _$AliskanlikYazToJson(AliskanlikYaz instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'ad': instance.ad,
      'tur': _$AliskanlikTuruEnumMap[instance.tur]!,
      'ikon': instance.ikon,
      'renk': instance.renk,
      'olcu': _$OlcuEnumMap[instance.olcu]!,
      'hedefYonu': _$HedefYonuEnumMap[instance.hedefYonu]!,
      'gunlukHedef': ?instance.gunlukHedef,
      'birim': ?instance.birim,
      'ogeEtiketi': ?instance.ogeEtiketi,
      'altBaslikEtiketi': ?instance.altBaslikEtiketi,
      'siklik': _$SiklikEnumMap[instance.siklik]!,
      'haftalikSayi': ?instance.haftalikSayi,
      'gunler': ?instance.gunler?.map((e) => _$HaftaGunuEnumMap[e]!).toList(),
      'sira': instance.sira,
      'arsivlendi': instance.arsivlendi,
    };
