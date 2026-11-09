// Work cards of the brain (`/api/isler`, backend/Isler/IsDtos.cs): the board, a card's detail and the notification buttons.
// Written by hand like the other small read models: the shapes are flat and the server never sends the card's file path.

/// `IsKartiDto`: one card of the board.
class IsKarti {
  const IsKarti({
    required this.kimlik,
    required this.baslik,
    required this.tip,
    required this.asama,
    required this.sahip,
    this.kilit,
    this.proje,
    this.alan,
    this.kaynak = '',
    this.olusma,
    this.guncelleme,
    this.bekleyenSoru = 0,
    this.gecisler = const [],
    this.acik = true,
  });

  final String kimlik;
  final String baslik;

  /// `kod` | `genel` | `yeni-proje`.
  final String tip;

  /// `talep` `plan` `karar` `kod-onayi` `yapim` `push-onayi` `deploy-onayi` `bitti` `iptal`.
  final String asama;

  /// Who the card waits on: `kullanici` | `vps` | `laptop`.
  final String sahip;
  final String? kilit;
  final String? proje;
  final String? alan;
  final String kaynak;

  /// Times as the brain writes them ("2026-11-10T14:30", Istanbul, no zone).
  final String? olusma;
  final String? guncelleme;
  final int bekleyenSoru;

  /// The stages this card can go to from here (back to `plan` and `iptal` included).
  final List<String> gecisler;
  final bool acik;

  /// The project or the area the card lives in.
  String get yer => proje ?? alan ?? '';

  factory IsKarti.fromJson(Map<String, dynamic> j) => IsKarti(
        kimlik: j['kimlik'] as String,
        baslik: j['baslik'] as String,
        tip: (j['tip'] as String?) ?? 'kod',
        asama: j['asama'] as String,
        sahip: j['sahip'] as String,
        kilit: j['kilit'] as String?,
        proje: j['proje'] as String?,
        alan: j['alan'] as String?,
        kaynak: (j['kaynak'] as String?) ?? '',
        olusma: j['olusma'] as String?,
        guncelleme: j['guncelleme'] as String?,
        bekleyenSoru: (j['bekleyenSoru'] as num?)?.toInt() ?? 0,
        gecisler: [for (final g in (j['gecisler'] as List?) ?? const []) g as String],
        acik: (j['acik'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'kimlik': kimlik,
        'baslik': baslik,
        'tip': tip,
        'asama': asama,
        'sahip': sahip,
        'kilit': kilit,
        'proje': proje,
        'alan': alan,
        'kaynak': kaynak,
        'olusma': olusma,
        'guncelleme': guncelleme,
        'bekleyenSoru': bekleyenSoru,
        'gecisler': gecisler,
        'acik': acik,
      };
}

/// `IsSorusuDto`: a question the plan session put to the person. [cevap] null means unanswered; an answered one is locked.
class IsSorusu {
  const IsSorusu({required this.no, required this.soru, this.secenekler = const [], this.onerilen, this.neden, this.cevap});

  final int no;
  final String soru;
  final List<String> secenekler;
  final String? onerilen;
  final String? neden;
  final String? cevap;

  bool get cevaplandi => cevap != null;

  factory IsSorusu.fromJson(Map<String, dynamic> j) => IsSorusu(
        no: (j['no'] as num).toInt(),
        soru: j['soru'] as String,
        secenekler: [for (final s in (j['secenekler'] as List?) ?? const []) s as String],
        onerilen: j['onerilen'] as String?,
        neden: j['neden'] as String?,
        cevap: j['cevap'] as String?,
      );
}

/// `IsGecmisiDto`: one line of the card's history.
class IsGecmisi {
  const IsGecmisi({required this.zaman, required this.olay, required this.kim});

  final String zaman;
  final String olay;
  final String kim;

  factory IsGecmisi.fromJson(Map<String, dynamic> j) => IsGecmisi(
        zaman: (j['zaman'] as String?) ?? '',
        olay: j['olay'] as String,
        kim: (j['kim'] as String?) ?? '',
      );
}

/// `IsAyrintiDto`: a card with its request, plan (Markdown), questions and history.
class IsAyrinti {
  const IsAyrinti({
    required this.kart,
    this.talep = '',
    this.plan = '',
    this.sorular = const [],
    this.gecmis = const [],
  });

  final IsKarti kart;
  final String talep;
  final String plan;
  final List<IsSorusu> sorular;
  final List<IsGecmisi> gecmis;

  factory IsAyrinti.fromJson(Map<String, dynamic> j) => IsAyrinti(
        kart: IsKarti.fromJson(j),
        talep: (j['talep'] as String?) ?? '',
        plan: (j['plan'] as String?) ?? '',
        sorular: [for (final s in (j['sorular'] as List?) ?? const []) IsSorusu.fromJson(s as Map<String, dynamic>)],
        gecmis: [for (final g in (j['gecmis'] as List?) ?? const []) IsGecmisi.fromJson(g as Map<String, dynamic>)],
      );
}

/// A new card as the form collects it. Exactly one of [proje] and [alan].
class IsAcGirdi {
  const IsAcGirdi({required this.baslik, this.talep = '', this.proje, this.alan, this.tip = 'kod'});

  final String baslik;
  final String talep;
  final String? proje;
  final String? alan;

  /// `kod` or `genel`.
  final String tip;

  Map<String, dynamic> toJson() => {
        'baslik': baslik,
        if (talep.isNotEmpty) 'talep': talep,
        'proje': ?proje,
        'alan': ?alan,
        'tip': tip,
      };
}

/// `BildirimSecenegiDto`: a button the server offers on a card's notification. [eylem] `cevap` answers question [soruNo]
/// with [cevap]; `asama` moves the card to [asama].
class BildirimSecenegi {
  const BildirimSecenegi({required this.etiket, required this.eylem, this.soruNo, this.cevap, this.asama});

  final String etiket;
  final String eylem;
  final int? soruNo;
  final String? cevap;
  final String? asama;

  factory BildirimSecenegi.fromJson(Map<String, dynamic> j) => BildirimSecenegi(
        etiket: j['etiket'] as String,
        eylem: j['eylem'] as String,
        soruNo: (j['soruNo'] as num?)?.toInt(),
        cevap: j['cevap'] as String?,
        asama: j['asama'] as String?,
      );
}
