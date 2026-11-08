import 'package:json_annotation/json_annotation.dart';

import 'yakalama.dart';
import 'zaman_cizelgesi.dart';

part 'yonetim.g.dart';

// The Sahip's management screens (`/api/yonetim`, backend/Yonetim): the Asistan's
// permissions, the brain status and the queue of captures going to the brain.

/// `IzinDto`: one permission the Asistan can hold. [izin] is the key (`beyin.oku`).
@JsonSerializable()
class Izin {
  const Izin({required this.izin, required this.aciklama, required this.acik});

  final String izin;
  final String aciklama;
  final bool acik;

  factory Izin.fromJson(Map<String, dynamic> json) => _$IzinFromJson(json);
  Map<String, dynamic> toJson() => _$IzinToJson(this);
}

/// `BeyinDurumDto`: is the brain set up, and how many captures wait for it.
@JsonSerializable()
class YonetimBeyinDurumu {
  const YonetimBeyinDurumu({
    required this.bagli,
    this.vault,
    this.bekleyenYakalama = 0,
    this.hataliYakalama = 0,
  });

  final bool bagli;
  final String? vault;
  final int bekleyenYakalama;

  /// Captures that need a look: a failed send, or one stuck after a crash or a timeout.
  final int hataliYakalama;

  factory YonetimBeyinDurumu.fromJson(Map<String, dynamic> json) => _$YonetimBeyinDurumuFromJson(json);
  Map<String, dynamic> toJson() => _$YonetimBeyinDurumuToJson(this);
}

/// `GonderimDurumu`: where a capture is on its way to the brain.
enum GonderimDurumu {
  /// Waits for its turn.
  @JsonValue('bekliyor')
  bekliyor,

  /// Taken by the sender a moment ago.
  @JsonValue('gonderiliyor')
  gonderiliyor,

  /// The last try failed and wrote nothing; the server tries again by itself.
  @JsonValue('hatali')
  hatali,

  /// Taken long ago and never finished: the card may already be in the brain.
  @JsonValue('takili')
  takili,

  /// Went to the brain.
  @JsonValue('tamam')
  tamam,
}

/// `GonderimDto`: a capture as the sending queue sees it.
@JsonSerializable()
class Gonderim {
  const Gonderim({
    required this.id,
    this.metin,
    this.fotografVar = false,
    this.hedef,
    required this.durum,
    required this.gonderim,
    required this.yakalandiAt,
    this.denemeSayisi = 0,
    this.sonDenemeAt,
    this.sonHata,
  });

  final String id;
  final String? metin;
  final bool fotografVar;
  final String? hedef;

  /// The capture's own state (`bekliyor`, `beyneGitti`, `islendi`).
  final YakalamaDurumu durum;

  /// Where it is on its way to the brain.
  final GonderimDurumu gonderim;
  final DateTime yakalandiAt;
  final int denemeSayisi;
  final DateTime? sonDenemeAt;
  final String? sonHata;

  /// Only these two can be sent again by hand.
  bool get yenidenDenenebilir => gonderim == GonderimDurumu.hatali || gonderim == GonderimDurumu.takili;

  factory Gonderim.fromJson(Map<String, dynamic> json) => _$GonderimFromJson(json);
  Map<String, dynamic> toJson() => _$GonderimToJson(this);
}

/// `GoogleDurumDto` (`GET /api/google/durum`): is Google Calendar set up and connected, and when it was last synced.
/// Hand-written JSON (camelCase, like the API); [durum] is one of [GoogleDurumu].
class GoogleDurum {
  const GoogleDurum({required this.durum, this.sonEsitleme, this.etkinlikSayisi = 0});

  final String durum;
  final DateTime? sonEsitleme;
  final int etkinlikSayisi;

  bool get bagli => durum == GoogleDurumu.bagli;

  factory GoogleDurum.fromJson(Map<String, dynamic> json) => GoogleDurum(
        durum: json['durum'] as String? ?? GoogleDurumu.kapali,
        sonEsitleme: json['sonEsitleme'] == null ? null : DateTime.parse(json['sonEsitleme'] as String),
        etkinlikSayisi: json['etkinlikSayisi'] as int? ?? 0,
      );
}

/// `EsitlemeOzeti` (`POST /api/google/esitle`): what one sync round did.
class GoogleEsitlemeOzeti {
  const GoogleEsitlemeOzeti({this.eklenen = 0, this.guncellenen = 0, this.silinen = 0, this.basarisiz = 0});

  final int eklenen;
  final int guncellenen;
  final int silinen;
  final int basarisiz;

  factory GoogleEsitlemeOzeti.fromJson(Map<String, dynamic> json) => GoogleEsitlemeOzeti(
        eklenen: json['eklenen'] as int? ?? 0,
        guncellenen: json['guncellenen'] as int? ?? 0,
        silinen: json['silinen'] as int? ?? 0,
        basarisiz: json['basarisiz'] as int? ?? 0,
      );
}
