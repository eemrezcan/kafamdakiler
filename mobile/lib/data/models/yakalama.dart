import 'package:json_annotation/json_annotation.dart';

part 'yakalama.g.dart';

/// Server-side state of a capture (`YakalamaDurumu`, camelCase on the wire).
enum YakalamaDurumu {
  @JsonValue('bekliyor')
  bekliyor,
  @JsonValue('beyneGitti')
  beyneGitti,
  @JsonValue('islendi')
  islendi,
}

/// `YakalamaDto`: a capture as the server stores it.
@JsonSerializable()
class Yakalama {
  const Yakalama({
    required this.id,
    this.metin,
    this.fotografId,
    this.fotografUrl,
    this.hedef,
    required this.durum,
    required this.yakalandiAt,
    required this.olusturulma,
  });

  final String id;
  final String? metin;
  final String? fotografId;
  final String? fotografUrl;
  final String? hedef;
  final YakalamaDurumu durum;
  final DateTime yakalandiAt;
  final DateTime olusturulma;

  factory Yakalama.fromJson(Map<String, dynamic> json) => _$YakalamaFromJson(json);
  Map<String, dynamic> toJson() => _$YakalamaToJson(this);
}

/// `YakalamaYazDto`: body of `POST /api/yakalamalar` and `PUT /api/yakalamalar/{id}`.
/// [id] is the client Guid v7; [yakalandiAt] is the phone's clock.
@JsonSerializable(includeIfNull: false)
class YakalamaYaz {
  const YakalamaYaz({this.id, this.metin, this.fotografId, this.hedef, required this.yakalandiAt});

  final String? id;
  final String? metin;
  final String? fotografId;
  final String? hedef;
  @JsonKey(toJson: _anYaz)
  final DateTime yakalandiAt;

  factory YakalamaYaz.fromJson(Map<String, dynamic> json) => _$YakalamaYazFromJson(json);
  Map<String, dynamic> toJson() => _$YakalamaYazToJson(this);
}

String _anYaz(DateTime an) => an.toUtc().toIso8601String();

/// A queued capture write: the [yaz] body plus the photo copy kept in the
/// app's own folder. [yaz] gets its `fotografId` once the photo is uploaded,
/// so a retry sends the capture without uploading the photo again.
class YakalamaGovde {
  const YakalamaGovde({required this.yaz, this.fotografYolu});

  final YakalamaYaz yaz;

  /// Local copy of the photo; null when there is none, or when the photo is
  /// already on the server (an edit that kept it).
  final String? fotografYolu;

  factory YakalamaGovde.fromJson(Map<String, dynamic> json) =>
      YakalamaGovde(yaz: YakalamaYaz.fromJson(json), fotografYolu: json['fotografYolu'] as String?);

  Map<String, dynamic> toJson() => {...yaz.toJson(), if (fotografYolu != null) 'fotografYolu': fotografYolu};

  /// The photo still has to be uploaded.
  bool get yuklenecekFotografVar => fotografYolu != null && yaz.fotografId == null;
}

/// Where a capture is now, shown as a mark on the list.
enum YakalamaKonumu {
  /// Queued on the phone, not on the server yet.
  telefonda,

  /// On the server, waiting (`bekliyor`).
  sunucuda,

  /// Went to the brain (`beyneGitti`, `islendi`).
  beyinde,
}

/// One row of the captures list: server data with the queued writes laid on top.
class YakalamaSatiri {
  const YakalamaSatiri({
    required this.id,
    this.metin,
    this.fotografId,
    this.fotografYolu,
    this.hedef,
    required this.konum,
    required this.islendi,
    required this.yakalandiAt,
    this.hata,
  });

  final String id;
  final String? metin;

  /// Photo on the server.
  final String? fotografId;

  /// Photo copy on the phone (kept until the capture is sent).
  final String? fotografYolu;
  final String? hedef;
  final YakalamaKonumu konum;

  /// Only meaningful for [YakalamaKonumu.beyinde]: `islendi` rather than `beyneGitti`.
  final bool islendi;
  final DateTime yakalandiAt;

  /// Why the server refused a queued write of this capture (4xx).
  final String? hata;

  /// Only a capture that waits is changed or deleted (a queued one waits too).
  bool get degistirilebilir => konum != YakalamaKonumu.beyinde;

  YakalamaSatiri copyWith({String? hata}) => YakalamaSatiri(
        id: id,
        metin: metin,
        fotografId: fotografId,
        fotografYolu: fotografYolu,
        hedef: hedef,
        konum: konum,
        islendi: islendi,
        yakalandiAt: yakalandiAt,
        hata: hata ?? this.hata,
      );
}
