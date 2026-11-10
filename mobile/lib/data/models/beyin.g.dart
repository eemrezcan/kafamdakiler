// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'beyin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjeOzet _$ProjeOzetFromJson(Map<String, dynamic> json) => ProjeOzet(
  kimlik: json['kimlik'] as String,
  baslik: json['baslik'] as String,
);

Map<String, dynamic> _$ProjeOzetToJson(ProjeOzet instance) => <String, dynamic>{
  'kimlik': instance.kimlik,
  'baslik': instance.baslik,
};

ProjeDetay _$ProjeDetayFromJson(Map<String, dynamic> json) => ProjeDetay(
  kimlik: json['kimlik'] as String,
  baslik: json['baslik'] as String,
  durum: json['durum'] as String?,
  siradakiAdim: json['siradakiAdim'] as String?,
  acikGorevler:
      (json['acikGorevler'] as List<dynamic>?)
          ?.map((e) => ProjeGorev.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  sonGunluk:
      (json['sonGunluk'] as List<dynamic>?)
          ?.map((e) => GunlukSatiri.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProjeDetayToJson(ProjeDetay instance) =>
    <String, dynamic>{
      'kimlik': instance.kimlik,
      'baslik': instance.baslik,
      'durum': instance.durum,
      'siradakiAdim': instance.siradakiAdim,
      'acikGorevler': instance.acikGorevler.map((e) => e.toJson()).toList(),
      'sonGunluk': instance.sonGunluk.map((e) => e.toJson()).toList(),
    };

ProjeGorev _$ProjeGorevFromJson(Map<String, dynamic> json) => ProjeGorev(
  kimlik: json['kimlik'] as String,
  baslik: json['baslik'] as String,
  durum: json['durum'] as String?,
  bitis: const NullableTarihDonusturucu().fromJson(json['bitis'] as String?),
  oncelik: json['oncelik'] as String?,
  sonrakiAdim: json['sonrakiAdim'] as String?,
);

Map<String, dynamic> _$ProjeGorevToJson(ProjeGorev instance) =>
    <String, dynamic>{
      'kimlik': instance.kimlik,
      'baslik': instance.baslik,
      'durum': instance.durum,
      'bitis': const NullableTarihDonusturucu().toJson(instance.bitis),
      'oncelik': instance.oncelik,
      'sonrakiAdim': instance.sonrakiAdim,
    };

GunlukSatiri _$GunlukSatiriFromJson(Map<String, dynamic> json) => GunlukSatiri(
  zaman: json['zaman'] as String?,
  baslik: json['baslik'] as String?,
  metin: json['metin'] as String?,
);

Map<String, dynamic> _$GunlukSatiriToJson(GunlukSatiri instance) =>
    <String, dynamic>{
      'zaman': instance.zaman,
      'baslik': instance.baslik,
      'metin': instance.metin,
    };

AramaSonucu _$AramaSonucuFromJson(Map<String, dynamic> json) => AramaSonucu(
  yol: json['yol'] as String,
  baslik: json['baslik'] as String,
  proje: json['proje'] as String?,
  alan: json['alan'] as String?,
  alinti: json['alinti'] as String?,
);

Map<String, dynamic> _$AramaSonucuToJson(AramaSonucu instance) =>
    <String, dynamic>{
      'yol': instance.yol,
      'baslik': instance.baslik,
      'proje': instance.proje,
      'alan': instance.alan,
      'alinti': instance.alinti,
    };

BeyinNotu _$BeyinNotuFromJson(Map<String, dynamic> json) => BeyinNotu(
  yol: json['yol'] as String,
  baslik: json['baslik'] as String,
  etiketler:
      (json['etiketler'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  govde: json['govde'] as String? ?? '',
);

Map<String, dynamic> _$BeyinNotuToJson(BeyinNotu instance) => <String, dynamic>{
  'yol': instance.yol,
  'baslik': instance.baslik,
  'etiketler': instance.etiketler,
  'govde': instance.govde,
};
