import 'package:json_annotation/json_annotation.dart';

part 'eylem.g.dart';

// The approval queue (K2.6, `/api/eylemler` and `/api/yonetim/eylem-izinleri`). Wire values follow the API
// (camelCase enum names).

enum EylemDurumu {
  @JsonValue('bekliyor')
  bekliyor,
  @JsonValue('uygulandi')
  uygulandi,
  @JsonValue('reddedildi')
  reddedildi,
  @JsonValue('geriAlindi')
  geriAlindi,
  @JsonValue('hatali')
  hatali,
}

/// What the Asistan may do for a kind of action without asking.
enum EylemKipi {
  @JsonValue('sor')
  sor,
  @JsonValue('kendinYap')
  kendinYap,
  @JsonValue('yasak')
  yasak,
}

/// `EylemDto`: one suggested action. [yuk] is the payload in the shape its kind expects; the phone shows it as JSON
/// and sends a corrected copy back when the user changes it.
@JsonSerializable()
class Eylem {
  const Eylem({
    required this.id,
    required this.tur,
    required this.turAdi,
    this.yuk = const {},
    required this.ozet,
    required this.kaynak,
    this.disKaynak = false,
    this.gerekce,
    this.guven,
    required this.durum,
    this.geriAlmaBilgisi,
    this.hataMesaji,
    required this.createdAt,
    this.kararAni,
    this.uygulamaAni,
    this.geriAlmaAni,
    this.kararVerenId,
    this.geriAlinabilir = true,
  });

  /// Below this a suggestion is marked "not sure" (the same threshold as the web page).
  static const guvenEsigi = 0.7;

  final String id;
  final String tur;
  final String turAdi;
  final Map<String, dynamic> yuk;
  final String ozet;
  final String kaynak;

  /// Drawn from text someone else wrote: never applied by itself.
  final bool disKaynak;
  final String? gerekce;

  /// 0 to 1, when the source can tell.
  final double? guven;
  final EylemDurumu durum;
  final Map<String, dynamic>? geriAlmaBilgisi;
  final String? hataMesaji;
  final DateTime createdAt;
  final DateTime? kararAni;
  final DateTime? uygulamaAni;
  final DateTime? geriAlmaAni;
  final String? kararVerenId;

  /// False for a kind whose effect cannot be taken back (placing an inbox card): the screens show no "Geri al".
  final bool geriAlinabilir;

  bool get eminDegil => guven != null && guven! < guvenEsigi;

  Eylem copyWith({EylemDurumu? durum, Map<String, dynamic>? yuk, DateTime? kararAni, DateTime? uygulamaAni, DateTime? geriAlmaAni}) => Eylem(
        id: id,
        tur: tur,
        turAdi: turAdi,
        yuk: yuk ?? this.yuk,
        ozet: ozet,
        kaynak: kaynak,
        disKaynak: disKaynak,
        gerekce: gerekce,
        guven: guven,
        durum: durum ?? this.durum,
        geriAlmaBilgisi: geriAlmaBilgisi,
        hataMesaji: hataMesaji,
        createdAt: createdAt,
        kararAni: kararAni ?? this.kararAni,
        uygulamaAni: uygulamaAni ?? this.uygulamaAni,
        geriAlmaAni: geriAlmaAni ?? this.geriAlmaAni,
        kararVerenId: kararVerenId,
        geriAlinabilir: geriAlinabilir,
      );

  factory Eylem.fromJson(Map<String, dynamic> json) => _$EylemFromJson(json);
  Map<String, dynamic> toJson() => _$EylemToJson(this);
}

/// `EylemKipiDto`: the mode of one kind of action (Yönetim, Sahip only).
@JsonSerializable()
class EylemKipDurumu {
  const EylemKipDurumu({required this.tur, required this.turAdi, required this.kip, this.ardArdaRed = 0});

  final String tur;
  final String turAdi;
  final EylemKipi kip;
  final int ardArdaRed;

  factory EylemKipDurumu.fromJson(Map<String, dynamic> json) => _$EylemKipDurumuFromJson(json);
  Map<String, dynamic> toJson() => _$EylemKipDurumuToJson(this);
}
