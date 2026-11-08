// Voice and text (K2.4, `/api/is-cikar`, `/api/metin/yeniden-yaz`). The phone turns speech into text; the server only gets
// the text. Plain hand-written JSON (camelCase, like the API); nothing here needs code generation.

/// The `kaynak` of `/api/is-cikar/uygula`: where the text was written. It only labels the actions in the queue.
abstract final class IsCikarKaynagi {
  /// The box in the morning briefing (K2.7). Without a source the server takes `ses`.
  static const brifing = 'brifing';
}

/// `IsOnerisi`: one suggestion, in the shape of the preview and of the apply request alike (the person may correct a field
/// in between). [tur] is `hatirlatici-kur`, `plan-ekle` or `gorev-ekle`; [baslik] is the reminder's title, the plan item's
/// text or the task's title. Dates are `yyyy-MM-dd`, [saat] is `HH:mm`.
///   hatirlatici-kur: gun (required), saat, tekrar
///   plan-ekle:       gun (required), bolum, tahminDk
///   gorev-ekle:      proje or alan, bitis
/// [kaynakParca] (the sentence it came from) and [guven] (0 to 1) only travel along.
class IsOnerisi {
  const IsOnerisi({
    required this.tur,
    required this.baslik,
    this.gun,
    this.saat,
    this.tekrar,
    this.bolum,
    this.tahminDk,
    this.proje,
    this.alan,
    this.bitis,
    this.kaynakParca,
    this.guven,
  });

  static const hatirlatici = 'hatirlatici-kur';
  static const plan = 'plan-ekle';
  static const gorev = 'gorev-ekle';
  static const takvim = 'takvim-ekle';

  /// Below this a suggestion is marked "not sure" (the same threshold as the approval queue).
  static const guvenEsigi = 0.7;

  final String tur;
  final String baslik;
  final String? gun;
  final String? saat;
  final String? tekrar;
  final String? bolum;
  final int? tahminDk;
  final String? proje;
  final String? alan;
  final String? bitis;
  final String? kaynakParca;
  final double? guven;

  bool get eminDegil => guven != null && guven! < guvenEsigi;

  /// The fields a person may correct in the preview; everything else stays. A null clears the optional ones.
  IsOnerisi duzelt({required String baslik, String? gun, String? saat, String? bitis}) => IsOnerisi(
        tur: tur,
        baslik: baslik,
        gun: gun,
        saat: saat,
        tekrar: tekrar,
        bolum: bolum,
        tahminDk: tahminDk,
        proje: proje,
        alan: alan,
        bitis: bitis,
        kaynakParca: kaynakParca,
        guven: guven,
      );

  factory IsOnerisi.fromJson(Map<String, dynamic> json) => IsOnerisi(
        tur: json['tur'] as String,
        baslik: json['baslik'] as String,
        gun: json['gun'] as String?,
        saat: json['saat'] as String?,
        tekrar: json['tekrar'] as String?,
        bolum: json['bolum'] as String?,
        tahminDk: (json['tahminDk'] as num?)?.toInt(),
        proje: json['proje'] as String?,
        alan: json['alan'] as String?,
        bitis: json['bitis'] as String?,
        kaynakParca: json['kaynakParca'] as String?,
        guven: (json['guven'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'tur': tur,
        'baslik': baslik,
        'gun': ?gun,
        'saat': ?saat,
        'tekrar': ?tekrar,
        'bolum': ?bolum,
        'tahminDk': ?tahminDk,
        'proje': ?proje,
        'alan': ?alan,
        'bitis': ?bitis,
        'kaynakParca': ?kaynakParca,
        'guven': ?guven,
      };
}

/// `AtlananOneri`: a suggestion Claude made that broke a rule (a date in the past, a project that does not exist...),
/// with the reason, so a missing suggestion is never silent.
class AtlananOneri {
  const AtlananOneri({this.tur, this.baslik, this.kaynakParca, required this.neden});

  final String? tur;
  final String? baslik;
  final String? kaynakParca;
  final String neden;

  factory AtlananOneri.fromJson(Map<String, dynamic> json) => AtlananOneri(
        tur: json['tur'] as String?,
        baslik: json['baslik'] as String?,
        kaynakParca: json['kaynakParca'] as String?,
        neden: json['neden'] as String? ?? '',
      );
}

/// `IsCikarYaniti`: the preview. Nothing was saved.
class IsCikarYaniti {
  const IsCikarYaniti({required this.bugun, required this.haftaninGunu, required this.oneriler, required this.atlananlar});

  final String bugun;
  final String haftaninGunu;
  final List<IsOnerisi> oneriler;
  final List<AtlananOneri> atlananlar;

  factory IsCikarYaniti.fromJson(Map<String, dynamic> json) => IsCikarYaniti(
        bugun: json['bugun'] as String? ?? '',
        haftaninGunu: json['haftaninGunu'] as String? ?? '',
        oneriler: [for (final e in (json['oneriler'] as List<dynamic>? ?? const [])) IsOnerisi.fromJson(e as Map<String, dynamic>)],
        atlananlar: [for (final e in (json['atlananlar'] as List<dynamic>? ?? const [])) AtlananOneri.fromJson(e as Map<String, dynamic>)],
      );
}

/// `IsUygulaSonucu`: what happened to one chosen suggestion. [durum] is `uygulandi`, `hata` (tried and failed),
/// `gecersiz` (broke a rule, nothing was tried) or `izinYok` (the person may not do what this kind does). [sira] is the
/// position in the request.
class IsUygulaSonucu {
  const IsUygulaSonucu({required this.sira, required this.durum, this.alan, this.mesaj});

  static const uygulandiDurumu = 'uygulandi';

  final int sira;
  final String durum;
  final String? alan;
  final String? mesaj;

  bool get uygulandi => durum == uygulandiDurumu;

  factory IsUygulaSonucu.fromJson(Map<String, dynamic> json) => IsUygulaSonucu(
        sira: (json['sira'] as num).toInt(),
        durum: json['durum'] as String,
        alan: json['alan'] as String?,
        mesaj: json['mesaj'] as String?,
      );
}

/// `IsCikarUygulaYaniti`: 200 when every suggestion went through, 207 when some did not; the applied ones stay applied.
class IsCikarUygulaYaniti {
  const IsCikarUygulaYaniti({required this.uygulanan, required this.basarisiz, required this.sonuclar});

  final int uygulanan;
  final int basarisiz;
  final List<IsUygulaSonucu> sonuclar;

  factory IsCikarUygulaYaniti.fromJson(Map<String, dynamic> json) => IsCikarUygulaYaniti(
        uygulanan: (json['uygulanan'] as num).toInt(),
        basarisiz: (json['basarisiz'] as num).toInt(),
        sonuclar: [for (final e in (json['sonuclar'] as List<dynamic>? ?? const [])) IsUygulaSonucu.fromJson(e as Map<String, dynamic>)],
      );
}

/// How the rewrite shapes the text: a short summary or a bullet list.
enum YenidenYazKipi {
  ozet,
  madde;

  String get ad => this == ozet ? 'Özet' : 'Maddeler';
}
