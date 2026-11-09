// The inbox (K2.2, `/api/gelen`): the cards waiting in the brain and the suggestion Claude made for each. Plain
// hand-written JSON (camelCase, like the API); nothing here needs code generation.

/// `YeniEtiket`: a tag the dictionary of the brain does not have yet. Approving the suggestion adds it to the dictionary
/// ([bolum] is the `##` section of etiketler.md, [esler] its synonyms) before the card is placed.
class GelenYeniEtiket {
  const GelenYeniEtiket({required this.ad, this.esler = const [], required this.bolum});

  final String ad;
  final List<String> esler;
  final String bolum;

  factory GelenYeniEtiket.fromJson(Map<String, dynamic> json) => GelenYeniEtiket(
        ad: json['ad'] as String,
        esler: [for (final e in (json['esler'] as List<dynamic>? ?? const [])) e as String],
        bolum: json['bolum'] as String,
      );

  Map<String, dynamic> toJson() => {'ad': ad, 'esler': esler, 'bolum': bolum};
}

/// `GelenOneriDto`: the placement suggestion waiting in the approval queue for a card. [eylemId] is the id of the
/// action in that queue: approving or rejecting goes through the approval queue's own calls. When [yeniEtiket] is set,
/// [etiketler] holds its name too.
class GelenOneri {
  const GelenOneri({
    required this.eylemId,
    required this.yol,
    required this.baslik,
    this.etiketler = const [],
    this.gerekce,
    this.guven,
    this.disKaynak = false,
    this.yeniEtiket,
  });

  /// Below this a suggestion is marked "not sure" (the same threshold as the approval queue).
  static const guvenEsigi = 0.7;

  final String eylemId;
  final String yol;
  final String baslik;
  final List<String> etiketler;
  final String? gerekce;
  final double? guven;

  /// The card's text holds an address: never applied by itself.
  final bool disKaynak;

  final GelenYeniEtiket? yeniEtiket;

  bool get eminDegil => guven != null && guven! < guvenEsigi;

  /// The tags that are in the dictionary already (the new one left out).
  List<String> get varOlanEtiketler => [for (final e in etiketler) if (e != yeniEtiket?.ad) e];

  /// The payload of "place the card with the existing tags alone" for the approval queue; null when there is no new tag
  /// or no other tag would be left (then the tags are picked by hand).
  Map<String, dynamic>? yeniEtiketsizYuk(String kart) => yeniEtiket == null || varOlanEtiketler.isEmpty
      ? null
      : {'kart': kart, 'yol': yol, 'baslik': baslik, 'etiketler': varOlanEtiketler};

  factory GelenOneri.fromJson(Map<String, dynamic> json) => GelenOneri(
        eylemId: json['eylemId'] as String,
        yol: json['yol'] as String,
        baslik: json['baslik'] as String,
        etiketler: [for (final e in (json['etiketler'] as List<dynamic>? ?? const [])) e as String],
        gerekce: json['gerekce'] as String?,
        guven: (json['guven'] as num?)?.toDouble(),
        disKaynak: json['disKaynak'] as bool? ?? false,
        yeniEtiket: json['yeniEtiket'] == null ? null : GelenYeniEtiket.fromJson(json['yeniEtiket'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'eylemId': eylemId,
        'yol': yol,
        'baslik': baslik,
        'etiketler': etiketler,
        'gerekce': gerekce,
        'guven': guven,
        'disKaynak': disKaynak,
        'yeniEtiket': yeniEtiket?.toJson(),
      };
}

/// `GelenKartDto`: one inbox card. [kimlik] is the file name in the brain without ".md". [ozet] is the card's title
/// (its first line); the full text is not sent. [yakalandi] is the brain's local time as written ("2026-11-03T18:40").
class GelenKarti {
  const GelenKarti({
    required this.kimlik,
    required this.ozet,
    this.gorselVar = false,
    this.hedef,
    this.yakalandi,
    this.laptoptaIslenecek = false,
    this.laptopNotu,
    this.oneri,
  });

  final String kimlik;
  final String ozet;
  final bool gorselVar;
  final String? hedef;
  final String? yakalandi;

  /// Only on cards marked before a new tag could be suggested (K-0023): asking again replaces the mark with a suggestion.
  final bool laptoptaIslenecek;
  final String? laptopNotu;
  final GelenOneri? oneri;

  /// The same card without its suggestion (decided on the phone but not sent yet).
  GelenKarti oneriz() => GelenKarti(
        kimlik: kimlik,
        ozet: ozet,
        gorselVar: gorselVar,
        hedef: hedef,
        yakalandi: yakalandi,
        laptoptaIslenecek: laptoptaIslenecek,
        laptopNotu: laptopNotu,
      );

  factory GelenKarti.fromJson(Map<String, dynamic> json) => GelenKarti(
        kimlik: json['kimlik'] as String,
        ozet: json['ozet'] as String,
        gorselVar: json['gorselVar'] as bool? ?? false,
        hedef: json['hedef'] as String?,
        yakalandi: json['yakalandi'] as String?,
        laptoptaIslenecek: json['laptoptaIslenecek'] as bool? ?? false,
        laptopNotu: json['laptopNotu'] as String?,
        oneri: json['oneri'] == null ? null : GelenOneri.fromJson(json['oneri'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'kimlik': kimlik,
        'ozet': ozet,
        'gorselVar': gorselVar,
        'hedef': hedef,
        'yakalandi': yakalandi,
        'laptoptaIslenecek': laptoptaIslenecek,
        'laptopNotu': laptopNotu,
        'oneri': oneri?.toJson(),
      };
}

/// `GelenIsleGirdi`: a placement the user makes by hand (`POST /api/gelen/{kart}/isle`). The server checks the path and
/// the tags again (400).
class GelenIsleGirdi {
  const GelenIsleGirdi({required this.yol, required this.baslik, required this.etiketler});

  final String yol;
  final String baslik;
  final List<String> etiketler;

  factory GelenIsleGirdi.fromJson(Map<String, dynamic> json) => GelenIsleGirdi(
        yol: json['yol'] as String,
        baslik: json['baslik'] as String,
        etiketler: [for (final e in json['etiketler'] as List<dynamic>) e as String],
      );

  Map<String, dynamic> toJson() => {'yol': yol, 'baslik': baslik, 'etiketler': etiketler};
}

/// `GelenEtiketDto` (`GET /api/gelen/etiketler`): a tag of the dictionary by its main name, with its synonyms.
class GelenEtiket {
  const GelenEtiket({required this.ad, this.esler = const []});

  final String ad;
  final List<String> esler;

  factory GelenEtiket.fromJson(Map<String, dynamic> json) => GelenEtiket(
        ad: json['ad'] as String,
        esler: [for (final e in (json['esler'] as List<dynamic>? ?? const [])) e as String],
      );
}

/// `GelenKlasorDto` (`GET /api/gelen/klasorler`): a folder a card may be placed in. [yol] ends with a slash; [tur] is
/// `proje` (the notes folder of project [proje]) or `kok` (a top-level folder).
class GelenKlasoru {
  const GelenKlasoru({required this.yol, required this.ad, required this.tur, this.proje});

  final String yol;
  final String ad;
  final String tur;
  final String? proje;

  factory GelenKlasoru.fromJson(Map<String, dynamic> json) => GelenKlasoru(
        yol: json['yol'] as String,
        ad: json['ad'] as String,
        tur: json['tur'] as String,
        proje: json['proje'] as String?,
      );
}

/// The pick lists of the hand-made placement: null means the server could not be asked (the dialog falls back to a
/// typed tag list and the cached projects).
typedef GelenSecenekleri = ({List<GelenEtiket> etiketler, List<GelenKlasoru> klasorler});

/// The answer of "suggest again" (`GelenOneriYaniti`): `olustu` (a suggestion is waiting now) or `atlandi`.
class GelenOneriYaniti {
  const GelenOneriYaniti({required this.durum, this.mesaj});

  final String durum;
  final String? mesaj;

  factory GelenOneriYaniti.fromJson(Map<String, dynamic> json) =>
      GelenOneriYaniti(durum: json['durum'] as String, mesaj: json['mesaj'] as String?);
}
