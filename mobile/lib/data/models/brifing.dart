// The morning briefing (K2.7, `/api/brifing`). Plain hand-written JSON (camelCase, like the API). The same shape is kept on
// the phone, so the last briefing can be shown offline.

/// The kinds of card (`tur`).
abstract final class BrifingTuru {
  static const plan = 'plan';
  static const kalan = 'kalan';
  static const hatirlatici = 'hatirlatici';
  static const onay = 'onay';
  static const takvim = 'takvim';
  static const kapasite = 'kapasite';
  static const bos = 'bos';
}

/// `BrifingKartDto`: one card. [sira] counts from 0 and is what the vote endpoint takes. [oy] is this person's vote: 1, -1,
/// or 0 for none. [bagliKimlikler] are ids of plan items, reminders or actions.
class BrifingKarti {
  const BrifingKarti({
    required this.sira,
    required this.tur,
    required this.baslik,
    required this.metin,
    this.bagliKimlikler = const [],
    this.oy = 0,
  });

  final int sira;
  final String tur;
  final String baslik;
  final String metin;
  final List<String> bagliKimlikler;
  final int oy;

  BrifingKarti oyla(int yeni) =>
      BrifingKarti(sira: sira, tur: tur, baslik: baslik, metin: metin, bagliKimlikler: bagliKimlikler, oy: yeni);

  factory BrifingKarti.fromJson(Map<String, dynamic> json) => BrifingKarti(
        sira: (json['sira'] as num).toInt(),
        tur: json['tur'] as String,
        baslik: json['baslik'] as String,
        metin: json['metin'] as String,
        bagliKimlikler: [for (final k in (json['bagliKimlikler'] as List<dynamic>? ?? const [])) k as String],
        oy: (json['oy'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'sira': sira, 'tur': tur, 'baslik': baslik, 'metin': metin, 'bagliKimlikler': bagliKimlikler, 'oy': oy};
}

/// `BrifingDto`: one day's briefing. [yontem] is `claude` or `hesap` (made by fixed rules).
class Brifing {
  const Brifing({
    required this.gun,
    required this.uretimAni,
    required this.yontem,
    required this.kartlar,
    this.kalanYenileme = 0,
  });

  static const claudeYontemi = 'claude';
  static const hesapYontemi = 'hesap';

  /// `yyyy-MM-dd`.
  final String gun;
  final DateTime uretimAni;
  final String yontem;
  final List<BrifingKarti> kartlar;

  /// How many times the Sahip may still ask for a new one today.
  final int kalanYenileme;

  Brifing oyla(int sira, int oy) => Brifing(
        gun: gun,
        uretimAni: uretimAni,
        yontem: yontem,
        kartlar: [for (final k in kartlar) k.sira == sira ? k.oyla(oy) : k],
        kalanYenileme: kalanYenileme,
      );

  factory Brifing.fromJson(Map<String, dynamic> json) => Brifing(
        gun: json['gun'] as String,
        uretimAni: DateTime.parse(json['uretimAni'] as String).toUtc(),
        yontem: json['yontem'] as String,
        kartlar: [for (final k in (json['kartlar'] as List<dynamic>? ?? const [])) BrifingKarti.fromJson(k as Map<String, dynamic>)],
        kalanYenileme: (json['kalanYenileme'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'gun': gun,
        'uretimAni': uretimAni.toIso8601String(),
        'yontem': yontem,
        'kartlar': [for (final k in kartlar) k.toJson()],
        'kalanYenileme': kalanYenileme,
      };
}

/// The phone's own briefing setting: whether the notification is on and at what hour (Istanbul time).
class BrifingAyari {
  const BrifingAyari({this.acik = true, this.saat = 6, this.dakika = 30});

  static const varsayilan = BrifingAyari();

  final bool acik;
  final int saat;
  final int dakika;

  /// "06:30".
  String get saatMetni => '${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')}';

  /// How it is stored: "06:30", or "kapali".
  String get depolama => acik ? saatMetni : kapali;

  static const kapali = 'kapali';

  /// Reads the stored text; a missing or unusable value is the default (06:30, on).
  static BrifingAyari oku(String? metin) {
    if (metin == null) return varsayilan;
    if (metin == kapali) return const BrifingAyari(acik: false);
    final parcalar = metin.split(':');
    final s = parcalar.length == 2 ? int.tryParse(parcalar[0]) : null;
    final d = parcalar.length == 2 ? int.tryParse(parcalar[1]) : null;
    if (s == null || d == null || s < 0 || s > 23 || d < 0 || d > 59) return varsayilan;
    return BrifingAyari(saat: s, dakika: d);
  }
}
