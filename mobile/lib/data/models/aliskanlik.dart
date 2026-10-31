import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'oge.dart';
import 'tarih_donusturucu.dart';

part 'aliskanlik.g.dart';

/// Today's state of a habit inside [Aliskanlik].
@JsonSerializable()
@TarihDonusturucu()
class BugunDurumu {
  const BugunDurumu({
    required this.tarih,
    required this.miktar,
    this.dakika,
    required this.deger,
    required this.planli,
  });

  final DateTime tarih;
  final double miktar;
  final int? dakika;
  final double deger;
  final bool planli;

  factory BugunDurumu.fromJson(Map<String, dynamic> json) => _$BugunDurumuFromJson(json);
  Map<String, dynamic> toJson() => _$BugunDurumuToJson(this);
}

/// `AliskanlikDto`.
@JsonSerializable()
class Aliskanlik {
  const Aliskanlik({
    required this.id,
    required this.ad,
    required this.tur,
    required this.ikon,
    required this.renk,
    required this.olcu,
    required this.hedefYonu,
    this.gunlukHedef,
    this.birim,
    this.ogeEtiketi,
    this.altBaslikEtiketi,
    required this.siklik,
    this.haftalikSayi,
    this.gunler,
    required this.sira,
    required this.arsivlendi,
    required this.olusturulma,
    this.bugun,
    this.guc = 0,
    this.seri = 0,
    this.enUzunSeri = 0,
    this.devamEdenler = const [],
  });

  final String id;
  final String ad;
  final AliskanlikTuru tur;
  final String ikon;
  final String renk;
  final Olcu olcu;
  final HedefYonu hedefYonu;
  final double? gunlukHedef;
  final String? birim;
  final String? ogeEtiketi;
  final String? altBaslikEtiketi;
  final Siklik siklik;
  final int? haftalikSayi;
  final List<HaftaGunu>? gunler;
  final int sira;
  final bool arsivlendi;
  final DateTime olusturulma;
  final BugunDurumu? bugun;
  final double guc;
  final int seri;
  final int enUzunSeri;
  final List<OgeOzet> devamEdenler;

  /// A habit counts as planned today unless the server said otherwise.
  bool get bugunPlanli => bugun?.planli ?? true;

  /// Dakikalı Sayaç: a counter whose unit is minutes gets a stopwatch.
  bool get dakikaliSayac =>
      tur == AliskanlikTuru.sayac &&
      olcu == Olcu.sayili &&
      const {'dakika', 'dk'}.contains(birim?.toLowerCase().trim());

  /// The writable view of this habit, the starting point of the edit form.
  AliskanlikYaz yazDto({bool? arsivlendi}) => AliskanlikYaz(
        id: id,
        ad: ad,
        tur: tur,
        ikon: ikon,
        renk: renk,
        olcu: olcu,
        hedefYonu: hedefYonu,
        gunlukHedef: gunlukHedef,
        birim: birim,
        ogeEtiketi: ogeEtiketi,
        altBaslikEtiketi: altBaslikEtiketi,
        siklik: siklik,
        haftalikSayi: haftalikSayi,
        gunler: gunler,
        sira: sira,
        arsivlendi: arsivlendi ?? this.arsivlendi,
      );

  Aliskanlik copyWith({BugunDurumu? bugun, List<OgeOzet>? devamEdenler}) => Aliskanlik(
        id: id,
        ad: ad,
        tur: tur,
        ikon: ikon,
        renk: renk,
        olcu: olcu,
        hedefYonu: hedefYonu,
        gunlukHedef: gunlukHedef,
        birim: birim,
        ogeEtiketi: ogeEtiketi,
        altBaslikEtiketi: altBaslikEtiketi,
        siklik: siklik,
        haftalikSayi: haftalikSayi,
        gunler: gunler,
        sira: sira,
        arsivlendi: arsivlendi,
        olusturulma: olusturulma,
        bugun: bugun ?? this.bugun,
        guc: guc,
        seri: seri,
        enUzunSeri: enUzunSeri,
        devamEdenler: devamEdenler ?? this.devamEdenler,
      );

  factory Aliskanlik.fromJson(Map<String, dynamic> json) => _$AliskanlikFromJson(json);
  Map<String, dynamic> toJson() => _$AliskanlikToJson(this);
}

/// `AliskanlikYazDto`: the writable fields of a habit.
@JsonSerializable(includeIfNull: false)
class AliskanlikYaz {
  const AliskanlikYaz({
    this.id,
    required this.ad,
    required this.tur,
    required this.ikon,
    required this.renk,
    required this.olcu,
    required this.hedefYonu,
    this.gunlukHedef,
    this.birim,
    this.ogeEtiketi,
    this.altBaslikEtiketi,
    required this.siklik,
    this.haftalikSayi,
    this.gunler,
    this.sira = 0,
    this.arsivlendi = false,
  });

  final String? id;
  final String ad;
  final AliskanlikTuru tur;
  final String ikon;
  final String renk;
  final Olcu olcu;
  final HedefYonu hedefYonu;
  final double? gunlukHedef;
  final String? birim;
  final String? ogeEtiketi;
  final String? altBaslikEtiketi;
  final Siklik siklik;
  final int? haftalikSayi;
  final List<HaftaGunu>? gunler;
  final int sira;
  final bool arsivlendi;

  factory AliskanlikYaz.fromJson(Map<String, dynamic> json) => _$AliskanlikYazFromJson(json);
  Map<String, dynamic> toJson() => _$AliskanlikYazToJson(this);
}
