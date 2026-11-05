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

BeyinGun _$BeyinGunFromJson(Map<String, dynamic> json) => BeyinGun(
  tarih: const TarihDonusturucu().fromJson(json['tarih'] as String),
  gunAdi: json['gunAdi'] as String?,
  haftaGunu: json['haftaGunu'] as String?,
  bugun: json['bugun'] as bool? ?? false,
  planVar: json['planVar'] as bool? ?? false,
  kapandi: json['kapandi'] as bool? ?? false,
  bolumler:
      (json['bolumler'] as List<dynamic>?)
          ?.map((e) => BeyinGunBolumu.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  geciken:
      (json['geciken'] as List<dynamic>?)
          ?.map((e) => GecikenGorev.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  toplam: json['toplam'] == null
      ? null
      : BeyinGunToplami.fromJson(json['toplam'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BeyinGunToJson(BeyinGun instance) => <String, dynamic>{
  'tarih': const TarihDonusturucu().toJson(instance.tarih),
  'gunAdi': instance.gunAdi,
  'haftaGunu': instance.haftaGunu,
  'bugun': instance.bugun,
  'planVar': instance.planVar,
  'kapandi': instance.kapandi,
  'bolumler': instance.bolumler.map((e) => e.toJson()).toList(),
  'geciken': instance.geciken.map((e) => e.toJson()).toList(),
  'toplam': instance.toplam?.toJson(),
};

BeyinGunBolumu _$BeyinGunBolumuFromJson(Map<String, dynamic> json) =>
    BeyinGunBolumu(
      ad: json['ad'] as String,
      maddeler:
          (json['maddeler'] as List<dynamic>?)
              ?.map((e) => BeyinGunMaddesi.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$BeyinGunBolumuToJson(BeyinGunBolumu instance) =>
    <String, dynamic>{
      'ad': instance.ad,
      'maddeler': instance.maddeler.map((e) => e.toJson()).toList(),
    };

BeyinGunMaddesi _$BeyinGunMaddesiFromJson(Map<String, dynamic> json) =>
    BeyinGunMaddesi(
      id: json['id'] as String,
      baslik: json['baslik'] as String,
      durum: json['durum'] as String?,
      tahminDk: (json['tahminDk'] as num?)?.toInt(),
      sureDk: (json['sureDk'] as num?)?.toInt(),
      proje: json['proje'] as String?,
      gorev: json['gorev'] as String?,
    );

Map<String, dynamic> _$BeyinGunMaddesiToJson(BeyinGunMaddesi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baslik': instance.baslik,
      'durum': instance.durum,
      'tahminDk': instance.tahminDk,
      'sureDk': instance.sureDk,
      'proje': instance.proje,
      'gorev': instance.gorev,
    };

GecikenGorev _$GecikenGorevFromJson(Map<String, dynamic> json) => GecikenGorev(
  kimlik: json['kimlik'] as String,
  baslik: json['baslik'] as String,
  bitis: const NullableTarihDonusturucu().fromJson(json['bitis'] as String?),
  gun: (json['gun'] as num?)?.toInt(),
  proje: json['proje'] as String?,
  oncelik: json['oncelik'] as String?,
);

Map<String, dynamic> _$GecikenGorevToJson(GecikenGorev instance) =>
    <String, dynamic>{
      'kimlik': instance.kimlik,
      'baslik': instance.baslik,
      'bitis': const NullableTarihDonusturucu().toJson(instance.bitis),
      'gun': instance.gun,
      'proje': instance.proje,
      'oncelik': instance.oncelik,
    };

BeyinGunToplami _$BeyinGunToplamiFromJson(Map<String, dynamic> json) =>
    BeyinGunToplami(
      madde: (json['madde'] as num?)?.toInt() ?? 0,
      yapildi: (json['yapildi'] as num?)?.toInt() ?? 0,
      acik: (json['acik'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$BeyinGunToplamiToJson(BeyinGunToplami instance) =>
    <String, dynamic>{
      'madde': instance.madde,
      'yapildi': instance.yapildi,
      'acik': instance.acik,
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
