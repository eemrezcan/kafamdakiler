import 'package:json_annotation/json_annotation.dart';

import '../../utils/hatirlatici_hesap.dart';
import 'enums.dart';
import 'tarih_donusturucu.dart';

part 'hatirlatici.g.dart';

// Wire values follow the API (camelCase enum names).

enum HatirlaticiTuru {
  @JsonValue('gorev')
  gorev,
  @JsonValue('soz')
  soz,
  @JsonValue('ozelTarih')
  ozelTarih,
}

enum Tekrar {
  @JsonValue('yok')
  yok,
  @JsonValue('gunluk')
  gunluk,
  @JsonValue('haftalik')
  haftalik,
  @JsonValue('aylik')
  aylik,
  @JsonValue('yillik')
  yillik,
}

enum HatirlaticiDurumu {
  @JsonValue('acik')
  acik,
  @JsonValue('tamam')
  tamam,
  @JsonValue('arsiv')
  arsiv,
}

/// The nag intervals the server accepts (minutes), and the defaults it stores (`Hatirlatici.VarsayilanIsrar*`; the
/// constructors and `@JsonKey` below repeat the two numbers as literals because the generator wants it).
const israrAraliklari = [5, 15, 60];
const varsayilanIsrarAraligi = 15;
const varsayilanIsrarEnCok = 3;
const enCokIsrarSayisi = 4;

/// An hour of the day ("09:00"); `TimeOnly` on the wire ("09:00:00").
class Saat {
  const Saat(this.saat, this.dakika);

  final int saat;
  final int dakika;

  factory Saat.coz(String metin) {
    final p = metin.split(':');
    return Saat(int.parse(p[0]), int.parse(p[1]));
  }

  /// "09:00", for display.
  String get kisa => '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}';

  String toJson() => '$kisa:00';

  @override
  bool operator ==(Object other) => other is Saat && other.saat == saat && other.dakika == dakika;

  @override
  int get hashCode => Object.hash(saat, dakika);
}

class SaatDonusturucu implements JsonConverter<Saat?, String?> {
  const SaatDonusturucu();

  @override
  Saat? fromJson(String? json) => json == null ? null : Saat.coz(json);

  @override
  String? toJson(Saat? object) => object?.toJson();
}

/// `HatirlaticiDto`: a reminder as the server stores it. The server's derived fields (`etkinAn`, `onceAn`,
/// `kalanGun`) are not read: the phone computes them again ([etkinAn], [onceAn], [kalanGun]), so they stay right
/// offline and across midnight.
@JsonSerializable()
class Hatirlatici {
  const Hatirlatici({
    required this.id,
    required this.baslik,
    this.not,
    required this.tur,
    this.kime,
    required this.gun,
    this.saat,
    required this.tekrar,
    required this.onceGun,
    required this.durum,
    required this.sonrakiAn,
    this.erteleAn,
    required this.createdAt,
    this.israrli = false,
    this.israrAraligiDakika = 15,
    this.israrEnCok = 3,
    this.acil = false,
    this.gunler,
  });

  final String id;
  final String baslik;
  final String? not;
  final HatirlaticiTuru tur;
  final String? kime;
  @TarihDonusturucu()
  final DateTime gun;
  @SaatDonusturucu()
  final Saat? saat;
  final Tekrar tekrar;
  final int onceGun;
  final HatirlaticiDurumu durum;
  final DateTime sonrakiAn;
  final DateTime? erteleAn;
  final DateTime createdAt;

  /// Nags: after the first notification up to [israrEnCok] more come, [israrAraligiDakika] minutes apart, until the
  /// reminder is done or snoozed. [acil] also breaks through silent mode. Rows cached before these fields existed read
  /// as a plain reminder.
  @JsonKey(defaultValue: false)
  final bool israrli;
  @JsonKey(defaultValue: 15)
  final int israrAraligiDakika;
  @JsonKey(defaultValue: 3)
  final int israrEnCok;
  @JsonKey(defaultValue: false)
  final bool acil;

  /// The weekdays of a weekly repeat (UI revision, sözleşme §2); empty or null means the weekday of [gun].
  final List<HaftaGunu>? gunler;

  /// The hour the rule fires at: its own, or the default morning hour.
  Saat get kuralSaati => saat ?? varsayilanHatirlaticiSaati;

  /// The moment that counts: a snooze comes before the rule's next moment.
  DateTime get etkinAn => erteleAn ?? sonrakiAn;

  /// The heads-up moment (relative to the rule's next moment), or null.
  DateTime? get onceAn => hatirlaticiOnceAni(sonrakiAn, onceGun);

  /// Days from today (Istanbul) to [etkinAn]; negative when it is past.
  int kalanGun(DateTime simdi) => hatirlaticiKalanGun(etkinAn, simdi);

  Hatirlatici copyWith({
    String? baslik,
    String? not,
    HatirlaticiTuru? tur,
    String? kime,
    DateTime? gun,
    Saat? saat,
    Tekrar? tekrar,
    int? onceGun,
    HatirlaticiDurumu? durum,
    DateTime? sonrakiAn,
    DateTime? erteleAn,
    bool erteleAnTemizle = false,
    bool? israrli,
    int? israrAraligiDakika,
    int? israrEnCok,
    bool? acil,
  }) =>
      Hatirlatici(
        id: id,
        baslik: baslik ?? this.baslik,
        not: not ?? this.not,
        tur: tur ?? this.tur,
        kime: kime ?? this.kime,
        gun: gun ?? this.gun,
        saat: saat ?? this.saat,
        tekrar: tekrar ?? this.tekrar,
        onceGun: onceGun ?? this.onceGun,
        durum: durum ?? this.durum,
        sonrakiAn: sonrakiAn ?? this.sonrakiAn,
        erteleAn: erteleAnTemizle ? null : (erteleAn ?? this.erteleAn),
        createdAt: createdAt,
        israrli: israrli ?? this.israrli,
        israrAraligiDakika: israrAraligiDakika ?? this.israrAraligiDakika,
        israrEnCok: israrEnCok ?? this.israrEnCok,
        acil: acil ?? this.acil,
        gunler: gunler,
      );

  factory Hatirlatici.fromJson(Map<String, dynamic> json) => _$HatirlaticiFromJson(json);
  Map<String, dynamic> toJson() => _$HatirlaticiToJson(this);
}

/// `HatirlaticiYazDto`: body of `POST /api/hatirlaticilar` and `PUT /api/hatirlaticilar/{id}`.
/// [id] is the client Guid v7 (a repeated send finds the same record).
@JsonSerializable(includeIfNull: false)
class HatirlaticiYaz {
  const HatirlaticiYaz({
    this.id,
    required this.baslik,
    this.not,
    this.tur = HatirlaticiTuru.gorev,
    this.kime,
    required this.gun,
    this.saat,
    this.tekrar = Tekrar.yok,
    this.onceGun = 0,
    this.durum = HatirlaticiDurumu.acik,
    this.israrli = false,
    this.israrAraligiDakika = 15,
    this.israrEnCok = 3,
    this.acil = false,
    this.gunler,
  });

  final String? id;
  final String baslik;
  final String? not;
  final HatirlaticiTuru tur;
  final String? kime;
  @TarihDonusturucu()
  final DateTime gun;
  @SaatDonusturucu()
  final Saat? saat;
  final Tekrar tekrar;
  final int onceGun;
  final HatirlaticiDurumu durum;

  /// See [Hatirlatici.israrli]; a queued write from before these fields existed reads as a plain reminder.
  @JsonKey(defaultValue: false)
  final bool israrli;
  @JsonKey(defaultValue: 15)
  final int israrAraligiDakika;
  @JsonKey(defaultValue: 3)
  final int israrEnCok;
  @JsonKey(defaultValue: false)
  final bool acil;

  /// See [Hatirlatici.gunler].
  final List<HaftaGunu>? gunler;

  factory HatirlaticiYaz.fromJson(Map<String, dynamic> json) => _$HatirlaticiYazFromJson(json);
  Map<String, dynamic> toJson() => _$HatirlaticiYazToJson(this);
}

/// Body of `POST /api/hatirlaticilar/{id}/ertele`: `1s` or `yarin`.
class ErteleSuresi {
  static const birSaat = '1s';
  static const yarin = 'yarin';
}
