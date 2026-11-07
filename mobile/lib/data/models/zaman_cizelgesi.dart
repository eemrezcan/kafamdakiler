// The one timeline of a day (K2.3c, `GET /api/zaman-cizelgesi?gun=`). Plain hand-written JSON (camelCase, like the API). The
// same shape is kept on the phone, so the last timeline can be shown offline.

/// The kinds of item (`tur`).
abstract final class ZamanCizelgesiTuru {
  static const etkinlik = 'etkinlik';
  static const hatirlatici = 'hatirlatici';
  static const plan = 'plan';
}

/// The state of the Google link (`google`).
abstract final class GoogleDurumu {
  static const kapali = 'kapali';
  static const bagliDegil = 'bagliDegil';
  static const bagli = 'bagli';
  static const yenidenBaglan = 'yenidenBaglan';
}

/// `ZamanCizelgesiOgesi`: one item. Timed items have [saat] ("HH:mm", Istanbul time); an event also has [bitisSaati], [sureDk]
/// and [yer]; a plan item has [durum], [bolum] and [tahminDk]. [kimlik] is what the item links to.
class ZamanCizelgesiOgesi {
  const ZamanCizelgesiOgesi({
    required this.tur,
    required this.kimlik,
    required this.baslik,
    this.tumGun = false,
    this.baslangic,
    this.saat,
    this.bitis,
    this.bitisSaati,
    this.sureDk,
    this.yer,
    this.durum,
    this.bolum,
    this.tahminDk,
  });

  final String tur;
  final String kimlik;
  final String baslik;
  final bool tumGun;
  final DateTime? baslangic;
  final String? saat;
  final DateTime? bitis;
  final String? bitisSaati;
  final int? sureDk;
  final String? yer;
  final String? durum;
  final String? bolum;
  final int? tahminDk;

  bool get etkinlikMi => tur == ZamanCizelgesiTuru.etkinlik;

  /// "09:00 - 10:30", "09:00" for an item with no end, null for an item with no hour.
  String? get saatAraligi {
    if (saat == null) return null;
    return bitisSaati == null ? saat : '$saat - $bitisSaati';
  }

  factory ZamanCizelgesiOgesi.fromJson(Map<String, dynamic> json) => ZamanCizelgesiOgesi(
        tur: json['tur'] as String,
        kimlik: json['kimlik'] as String,
        baslik: json['baslik'] as String,
        tumGun: json['tumGun'] as bool? ?? false,
        baslangic: _an(json['baslangic']),
        saat: json['saat'] as String?,
        bitis: _an(json['bitis']),
        bitisSaati: json['bitisSaati'] as String?,
        sureDk: (json['sureDk'] as num?)?.toInt(),
        yer: json['yer'] as String?,
        durum: json['durum'] as String?,
        bolum: json['bolum'] as String?,
        tahminDk: (json['tahminDk'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'tur': tur,
        'kimlik': kimlik,
        'baslik': baslik,
        'tumGun': tumGun,
        'baslangic': baslangic?.toIso8601String(),
        'saat': saat,
        'bitis': bitis?.toIso8601String(),
        'bitisSaati': bitisSaati,
        'sureDk': sureDk,
        'yer': yer,
        'durum': durum,
        'bolum': bolum,
        'tahminDk': tahminDk,
      };

  static DateTime? _an(Object? deger) => deger == null ? null : DateTime.parse(deger as String).toUtc();
}

/// `ZamanCizelgesiKapasitesi`: "Bugün sığmıyor", counting the day's timed events too.
class ZamanCizelgesiKapasitesi {
  const ZamanCizelgesiKapasitesi({
    required this.planDk,
    required this.etkinlikDk,
    required this.toplamDk,
    required this.kapasiteDk,
    required this.asimDk,
  });

  final int planDk;
  final int etkinlikDk;
  final int toplamDk;
  final int kapasiteDk;
  final int asimDk;

  factory ZamanCizelgesiKapasitesi.fromJson(Map<String, dynamic> json) => ZamanCizelgesiKapasitesi(
        planDk: (json['planDk'] as num).toInt(),
        etkinlikDk: (json['etkinlikDk'] as num).toInt(),
        toplamDk: (json['toplamDk'] as num).toInt(),
        kapasiteDk: (json['kapasiteDk'] as num).toInt(),
        asimDk: (json['asimDk'] as num).toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'planDk': planDk, 'etkinlikDk': etkinlikDk, 'toplamDk': toplamDk, 'kapasiteDk': kapasiteDk, 'asimDk': asimDk};
}

/// `ZamanCizelgesiDto`: one day. [saatli] is in the order of the clock; [saatsiz] holds the plan items, the all-day events and
/// the reminders without an hour. [plan] is `yok`, `tamam` or `okunamadi` (the plan part is then empty).
class ZamanCizelgesi {
  const ZamanCizelgesi({
    required this.gun,
    required this.google,
    required this.plan,
    required this.saatli,
    required this.saatsiz,
    this.kapasite,
    this.sonEsitleme,
  });

  /// `yyyy-MM-dd`.
  final String gun;
  final String google;
  final String plan;
  final List<ZamanCizelgesiOgesi> saatli;
  final List<ZamanCizelgesiOgesi> saatsiz;
  final ZamanCizelgesiKapasitesi? kapasite;
  final DateTime? sonEsitleme;

  bool get bos => saatli.isEmpty && saatsiz.isEmpty;

  factory ZamanCizelgesi.fromJson(Map<String, dynamic> json) {
    List<ZamanCizelgesiOgesi> ogeler(Object? ham) =>
        [for (final o in (ham as List<dynamic>? ?? const [])) ZamanCizelgesiOgesi.fromJson(o as Map<String, dynamic>)];
    return ZamanCizelgesi(
      gun: json['gun'] as String,
      google: json['google'] as String? ?? GoogleDurumu.kapali,
      plan: json['plan'] as String? ?? 'yok',
      saatli: ogeler(json['saatli']),
      saatsiz: ogeler(json['saatsiz']),
      kapasite: json['kapasite'] == null ? null : ZamanCizelgesiKapasitesi.fromJson(json['kapasite'] as Map<String, dynamic>),
      sonEsitleme: json['sonEsitleme'] == null ? null : DateTime.parse(json['sonEsitleme'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'gun': gun,
        'google': google,
        'plan': plan,
        'saatli': [for (final o in saatli) o.toJson()],
        'saatsiz': [for (final o in saatsiz) o.toJson()],
        'kapasite': kapasite?.toJson(),
        'sonEsitleme': sonEsitleme?.toIso8601String(),
      };
}
