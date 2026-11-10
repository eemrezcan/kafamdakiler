// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gun_gorunum.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GunYuku _$GunYukuFromJson(Map<String, dynamic> json) => GunYuku(
  acikTahminDk: (json['acikTahminDk'] as num?)?.toInt() ?? 0,
  etkinlikDk: (json['etkinlikDk'] as num?)?.toInt() ?? 0,
  kapasiteDk: (json['kapasiteDk'] as num?)?.toInt() ?? 0,
  asimDk: (json['asimDk'] as num?)?.toInt() ?? 0,
  bosDk: (json['bosDk'] as num?)?.toInt() ?? 0,
  tahminsizSayi: (json['tahminsizSayi'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$GunYukuToJson(GunYuku instance) => <String, dynamic>{
  'acikTahminDk': instance.acikTahminDk,
  'etkinlikDk': instance.etkinlikDk,
  'kapasiteDk': instance.kapasiteDk,
  'asimDk': instance.asimDk,
  'bosDk': instance.bosDk,
  'tahminsizSayi': instance.tahminsizSayi,
};

DundenKalan _$DundenKalanFromJson(Map<String, dynamic> json) => DundenKalan(
  maddeId: json['maddeId'] as String,
  baslik: json['baslik'] as String,
  tahminDk: (json['tahminDk'] as num?)?.toInt(),
  proje: json['proje'] as String?,
);

Map<String, dynamic> _$DundenKalanToJson(DundenKalan instance) =>
    <String, dynamic>{
      'maddeId': instance.maddeId,
      'baslik': instance.baslik,
      'tahminDk': instance.tahminDk,
      'proje': instance.proje,
    };

HatirlaticiOzet _$HatirlaticiOzetFromJson(Map<String, dynamic> json) =>
    HatirlaticiOzet(
      id: json['id'] as String,
      saat: json['saat'] as String?,
      tekrar:
          $enumDecodeNullable(_$TekrarEnumMap, json['tekrar']) ?? Tekrar.yok,
      gunler: (json['gunler'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$HaftaGunuEnumMap, e))
          .toList(),
      acil: json['acil'] as bool? ?? false,
      israrli: json['israrli'] as bool? ?? false,
      onceGun: (json['onceGun'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$HatirlaticiOzetToJson(HatirlaticiOzet instance) =>
    <String, dynamic>{
      'id': instance.id,
      'saat': instance.saat,
      'tekrar': _$TekrarEnumMap[instance.tekrar]!,
      'gunler': instance.gunler?.map((e) => _$HaftaGunuEnumMap[e]!).toList(),
      'acil': instance.acil,
      'israrli': instance.israrli,
      'onceGun': instance.onceGun,
    };

const _$TekrarEnumMap = {
  Tekrar.yok: 'yok',
  Tekrar.gunluk: 'gunluk',
  Tekrar.haftalik: 'haftalik',
  Tekrar.aylik: 'aylik',
  Tekrar.yillik: 'yillik',
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

BolunmusBilgi _$BolunmusBilgiFromJson(Map<String, dynamic> json) =>
    BolunmusBilgi(
      sira: (json['sira'] as num).toInt(),
      toplam: (json['toplam'] as num).toInt(),
    );

Map<String, dynamic> _$BolunmusBilgiToJson(BolunmusBilgi instance) =>
    <String, dynamic>{'sira': instance.sira, 'toplam': instance.toplam};

Yapilacak _$YapilacakFromJson(Map<String, dynamic> json) => Yapilacak(
  kimlik: json['kimlik'] as String,
  tur: $enumDecode(_$YapilacakTuruEnumMap, json['tur']),
  baslik: json['baslik'] as String,
  saat: json['saat'] as String?,
  bitisSaati: json['bitisSaati'] as String?,
  tumGun: json['tumGun'] as bool? ?? false,
  tahminDk: (json['tahminDk'] as num?)?.toInt(),
  sureDk: (json['sureDk'] as num?)?.toInt(),
  durum: json['durum'] as String? ?? 'acik',
  proje: json['proje'] as String?,
  bolum: json['bolum'] as String?,
  gecikmeGun: (json['gecikmeGun'] as num?)?.toInt(),
  bolunmus: json['bolunmus'] == null
      ? null
      : BolunmusBilgi.fromJson(json['bolunmus'] as Map<String, dynamic>),
  hatirlatici: json['hatirlatici'] == null
      ? null
      : HatirlaticiOzet.fromJson(json['hatirlatici'] as Map<String, dynamic>),
  maddeId: json['maddeId'] as String?,
  gorevKimligi: json['gorevKimligi'] as String?,
  hatirlaticiId: json['hatirlaticiId'] as String?,
  etkinlikId: json['etkinlikId'] as String?,
  yer: json['yer'] as String?,
  tarih: const NullableTarihDonusturucu().fromJson(json['tarih'] as String?),
);

Map<String, dynamic> _$YapilacakToJson(Yapilacak instance) => <String, dynamic>{
  'kimlik': instance.kimlik,
  'tur': _$YapilacakTuruEnumMap[instance.tur]!,
  'baslik': instance.baslik,
  'saat': instance.saat,
  'bitisSaati': instance.bitisSaati,
  'tumGun': instance.tumGun,
  'tahminDk': instance.tahminDk,
  'sureDk': instance.sureDk,
  'durum': instance.durum,
  'proje': instance.proje,
  'bolum': instance.bolum,
  'gecikmeGun': instance.gecikmeGun,
  'bolunmus': instance.bolunmus?.toJson(),
  'hatirlatici': instance.hatirlatici?.toJson(),
  'maddeId': instance.maddeId,
  'gorevKimligi': instance.gorevKimligi,
  'hatirlaticiId': instance.hatirlaticiId,
  'etkinlikId': instance.etkinlikId,
  'yer': instance.yer,
  'tarih': const NullableTarihDonusturucu().toJson(instance.tarih),
};

const _$YapilacakTuruEnumMap = {
  YapilacakTuru.plan: 'plan',
  YapilacakTuru.gorev: 'gorev',
  YapilacakTuru.hatirlatici: 'hatirlatici',
  YapilacakTuru.etkinlik: 'etkinlik',
};

GunKaynaklari _$GunKaynaklariFromJson(Map<String, dynamic> json) =>
    GunKaynaklari(
      plan: json['plan'] as String? ?? 'tamam',
      google: json['google'] as String? ?? 'kapali',
      sonEsitleme: json['sonEsitleme'] == null
          ? null
          : DateTime.parse(json['sonEsitleme'] as String),
    );

Map<String, dynamic> _$GunKaynaklariToJson(GunKaynaklari instance) =>
    <String, dynamic>{
      'plan': instance.plan,
      'google': instance.google,
      'sonEsitleme': instance.sonEsitleme?.toIso8601String(),
    };

GunGorunum _$GunGorunumFromJson(Map<String, dynamic> json) => GunGorunum(
  tarih: const TarihDonusturucu().fromJson(json['tarih'] as String),
  bugun: json['bugun'] as bool? ?? false,
  kapandi: json['kapandi'] as bool? ?? false,
  ozet: json['ozet'] as String?,
  yuk: json['yuk'] == null
      ? const GunYuku()
      : GunYuku.fromJson(json['yuk'] as Map<String, dynamic>),
  dundenKalanlar:
      (json['dundenKalanlar'] as List<dynamic>?)
          ?.map((e) => DundenKalan.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  ogeler:
      (json['ogeler'] as List<dynamic>?)
          ?.map((e) => Yapilacak.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  kaynaklar: json['kaynaklar'] == null
      ? const GunKaynaklari()
      : GunKaynaklari.fromJson(json['kaynaklar'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GunGorunumToJson(GunGorunum instance) =>
    <String, dynamic>{
      'tarih': const TarihDonusturucu().toJson(instance.tarih),
      'bugun': instance.bugun,
      'kapandi': instance.kapandi,
      'ozet': instance.ozet,
      'yuk': instance.yuk.toJson(),
      'dundenKalanlar': instance.dundenKalanlar.map((e) => e.toJson()).toList(),
      'ogeler': instance.ogeler.map((e) => e.toJson()).toList(),
      'kaynaklar': instance.kaynaklar.toJson(),
    };

YaptimYaniti _$YaptimYanitiFromJson(Map<String, dynamic> json) => YaptimYaniti(
  oge: Yapilacak.fromJson(json['oge'] as Map<String, dynamic>),
  zincir:
      (json['zincir'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$YaptimYanitiToJson(YaptimYaniti instance) =>
    <String, dynamic>{'oge': instance.oge.toJson(), 'zincir': instance.zincir};

TakvimSayilari _$TakvimSayilariFromJson(Map<String, dynamic> json) =>
    TakvimSayilari(
      plan: (json['plan'] as num?)?.toInt() ?? 0,
      gorev: (json['gorev'] as num?)?.toInt() ?? 0,
      hatirlatici: (json['hatirlatici'] as num?)?.toInt() ?? 0,
      etkinlik: (json['etkinlik'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TakvimSayilariToJson(TakvimSayilari instance) =>
    <String, dynamic>{
      'plan': instance.plan,
      'gorev': instance.gorev,
      'hatirlatici': instance.hatirlatici,
      'etkinlik': instance.etkinlik,
    };

TakvimGunu _$TakvimGunuFromJson(Map<String, dynamic> json) => TakvimGunu(
  tarih: const TarihDonusturucu().fromJson(json['tarih'] as String),
  sayilar: json['sayilar'] == null
      ? const TakvimSayilari()
      : TakvimSayilari.fromJson(json['sayilar'] as Map<String, dynamic>),
  yukAsimi: json['yukAsimi'] as bool? ?? false,
);

Map<String, dynamic> _$TakvimGunuToJson(TakvimGunu instance) =>
    <String, dynamic>{
      'tarih': const TarihDonusturucu().toJson(instance.tarih),
      'sayilar': instance.sayilar.toJson(),
      'yukAsimi': instance.yukAsimi,
    };

TakvimAraligi _$TakvimAraligiFromJson(Map<String, dynamic> json) =>
    TakvimAraligi(
      gunler:
          (json['gunler'] as List<dynamic>?)
              ?.map((e) => TakvimGunu.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      yaklasan:
          (json['yaklasan'] as List<dynamic>?)
              ?.map((e) => Yapilacak.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TakvimAraligiToJson(TakvimAraligi instance) =>
    <String, dynamic>{
      'gunler': instance.gunler.map((e) => e.toJson()).toList(),
      'yaklasan': instance.yaklasan.map((e) => e.toJson()).toList(),
    };

HatirlaticiGovde _$HatirlaticiGovdeFromJson(Map<String, dynamic> json) =>
    HatirlaticiGovde(
      saat: json['saat'] as String?,
      tekrar:
          $enumDecodeNullable(_$TekrarEnumMap, json['tekrar']) ?? Tekrar.yok,
      gunler: (json['gunler'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$HaftaGunuEnumMap, e))
          .toList(),
      acil: json['acil'] as bool? ?? false,
      israrli: json['israrli'] as bool? ?? false,
      onceGun: (json['onceGun'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$HatirlaticiGovdeToJson(HatirlaticiGovde instance) =>
    <String, dynamic>{
      'saat': ?instance.saat,
      'tekrar': _$TekrarEnumMap[instance.tekrar]!,
      'gunler': ?instance.gunler?.map((e) => _$HaftaGunuEnumMap[e]!).toList(),
      'acil': instance.acil,
      'israrli': instance.israrli,
      'onceGun': instance.onceGun,
    };

YeniOgeYaz _$YeniOgeYazFromJson(Map<String, dynamic> json) => YeniOgeYaz(
  baslik: json['baslik'] as String,
  saat: json['saat'] as String?,
  tahminDk: (json['tahminDk'] as num?)?.toInt(),
  proje: json['proje'] as String?,
  bolum: json['bolum'] as String?,
  hatirlatici: json['hatirlatici'] == null
      ? null
      : HatirlaticiGovde.fromJson(json['hatirlatici'] as Map<String, dynamic>),
);

Map<String, dynamic> _$YeniOgeYazToJson(YeniOgeYaz instance) =>
    <String, dynamic>{
      'baslik': instance.baslik,
      'saat': ?instance.saat,
      'tahminDk': ?instance.tahminDk,
      'proje': ?instance.proje,
      'bolum': ?instance.bolum,
      'hatirlatici': ?instance.hatirlatici?.toJson(),
    };

GunAyari _$GunAyariFromJson(Map<String, dynamic> json) => GunAyari(
  haftaIciDk: (json['haftaIciDk'] as num?)?.toInt() ?? 360,
  haftaSonuDk: (json['haftaSonuDk'] as num?)?.toInt() ?? 180,
);

Map<String, dynamic> _$GunAyariToJson(GunAyari instance) => <String, dynamic>{
  'haftaIciDk': instance.haftaIciDk,
  'haftaSonuDk': instance.haftaSonuDk,
};
