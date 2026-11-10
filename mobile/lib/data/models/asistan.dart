import 'brifing.dart';
import 'eylem.dart';
import 'is_karti.dart';
import 'yakalama.dart';

// The assistant feed of the UI revision (K-0024, docs/planlar/ui-revizyon/sozlesme.md §7): what is sent to the one input
// `POST /api/asistan/girdi`, what it answers, and the items of `GET /api/asistan/akis`. Hand-written JSON (camelCase, like
// the API); the same shape is kept on the phone, so the last page of the feed shows offline.

/// Where an input came from (`kaynak`).
abstract final class AsistanKaynagi {
  static const yazi = 'yazi';
  static const ses = 'ses';
  static const paylas = 'paylas';
  static const widget = 'widget';
}

/// `AsistanGirdisiDto`. [id] is made on the phone (a repeated send finds the same answer). Either [metin] or [fotografId].
class AsistanGirdisi {
  const AsistanGirdisi({required this.id, this.metin, this.fotografId, this.kaynak = AsistanKaynagi.yazi, this.bugun});

  static const enUzunMetin = 4000;

  final String id;
  final String? metin;
  final String? fotografId;
  final String kaynak;

  /// The day the phone thinks it is ("2026-11-10"), so "yarın" means the same on both sides.
  final String? bugun;

  factory AsistanGirdisi.fromJson(Map<String, dynamic> j) => AsistanGirdisi(
        id: j['id'] as String,
        metin: j['metin'] as String?,
        fotografId: j['fotografId'] as String?,
        kaynak: (j['kaynak'] as String?) ?? AsistanKaynagi.yazi,
        bugun: j['bugun'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'metin': ?metin,
        'fotografId': ?fotografId,
        'kaynak': kaynak,
        'bugun': ?bugun,
      };
}

/// `AsistanSonucuDto.durum`.
abstract final class SonucDurumu {
  static const uygulandi = 'uygulandi';
  static const izinYok = 'izinYok';
  static const hata = 'hata';
  static const gecersiz = 'gecersiz';
}

/// `AsistanSonucuDto.tur` of a capture; its "Geri al" deletes the capture ([AsistanSonucu.hedefKimlik] is its id).
const sonucTuruNot = 'not';

/// `AsistanSonucuDto`: one thing the assistant did for an input.
class AsistanSonucu {
  const AsistanSonucu({
    required this.tur,
    required this.baslik,
    this.ozet = '',
    this.durum = SonucDurumu.uygulandi,
    this.eylemId,
    this.hedefKimlik,
    this.hedefRota,
    this.geriAlinabilir = false,
    this.mesaj,
  });

  final String tur;
  final String baslik;

  /// "yarın 09:00 · 🔔".
  final String ozet;
  final String durum;
  final String? eylemId;
  final String? hedefKimlik;
  final String? hedefRota;
  final bool geriAlinabilir;
  final String? mesaj;

  bool get uygulandi => durum == SonucDurumu.uygulandi;

  AsistanSonucu geriAlindi() => AsistanSonucu(
        tur: tur,
        baslik: baslik,
        ozet: ozet,
        durum: durum,
        eylemId: eylemId,
        hedefKimlik: hedefKimlik,
        hedefRota: hedefRota,
        geriAlinabilir: false,
        mesaj: 'Geri alınıyor',
      );

  factory AsistanSonucu.fromJson(Map<String, dynamic> j) {
    final hedef = j['hedef'] as Map<String, dynamic>?;
    return AsistanSonucu(
      tur: (j['tur'] as String?) ?? '',
      baslik: (j['baslik'] as String?) ?? '',
      ozet: (j['ozet'] as String?) ?? '',
      durum: (j['durum'] as String?) ?? SonucDurumu.uygulandi,
      eylemId: j['eylemId'] as String?,
      hedefKimlik: hedef?['kimlik'] as String?,
      hedefRota: hedef?['rota'] as String?,
      geriAlinabilir: (j['geriAlinabilir'] as bool?) ?? false,
      mesaj: j['mesaj'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'tur': tur,
        'baslik': baslik,
        'ozet': ozet,
        'durum': durum,
        'eylemId': eylemId,
        'hedef': {'kimlik': hedefKimlik, 'rota': hedefRota},
        'geriAlinabilir': geriAlinabilir,
        'mesaj': mesaj,
      };
}

/// `AsistanSorusuDto`: the one question the assistant asks when it is not sure, with at most three short answers.
class AsistanSorusu {
  const AsistanSorusu({required this.id, required this.metin, this.secenekler = const []});

  final String id;
  final String metin;
  final List<String> secenekler;

  factory AsistanSorusu.fromJson(Map<String, dynamic> j) => AsistanSorusu(
        id: j['id'] as String,
        metin: (j['metin'] as String?) ?? '',
        secenekler: [for (final s in (j['secenekler'] as List?) ?? const []) s as String],
      );

  Map<String, dynamic> toJson() => {'id': id, 'metin': metin, 'secenekler': secenekler};
}

/// `AsistanYanitiDto`: the answer to an input or to an answer.
class AsistanYaniti {
  const AsistanYaniti({required this.girdiId, required this.mesajId, this.sonuclar = const [], this.soru});

  final String girdiId;
  final String mesajId;
  final List<AsistanSonucu> sonuclar;
  final AsistanSorusu? soru;

  factory AsistanYaniti.fromJson(Map<String, dynamic> j) => AsistanYaniti(
        girdiId: (j['girdiId'] as String?) ?? '',
        mesajId: (j['mesajId'] as String?) ?? '',
        sonuclar: [for (final s in (j['sonuclar'] as List?) ?? const []) AsistanSonucu.fromJson(s as Map<String, dynamic>)],
        soru: j['soru'] == null ? null : AsistanSorusu.fromJson(j['soru'] as Map<String, dynamic>),
      );
}

/// The kinds of feed item (`AkisOgesiDto.tur`).
abstract final class AkisTuru {
  static const kullanici = 'kullanici';
  static const sonuc = 'sonuc';
  static const soru = 'soru';
  static const onay = 'onay';
  static const isKarti = 'is';
  static const brifing = 'brifing';
  static const not = 'not';
}

/// The filters of the feed (`suzgec`).
abstract final class AkisSuzgeci {
  static const hepsi = 'hepsi';
  static const bekleyen = 'bekleyen';
  static const isler = 'isler';
  static const notlar = 'notlar';
}

/// `AkisOgesiDto`: one item of the single feed. Which field is set follows [tur]. The server's items come newest first; the
/// phone's own unsent inputs are added by the repository ([bekliyor], [gonderilemedi]).
class AkisOgesi {
  const AkisOgesi({
    required this.id,
    required this.zaman,
    required this.tur,
    this.metin,
    this.fotografUrl,
    this.sonuclar = const [],
    this.soru,
    this.eylem,
    this.isKarti,
    this.brifing,
    this.yakalama,
    this.bekliyor = false,
    this.gonderilemedi,
    this.yerelFotograf,
  });

  final String id;
  final DateTime zaman;
  final String tur;
  final String? metin;
  final String? fotografUrl;
  final List<AsistanSonucu> sonuclar;
  final AsistanSorusu? soru;
  final Eylem? eylem;
  final IsKarti? isKarti;
  final Brifing? brifing;
  final Yakalama? yakalama;

  /// An input made on the phone that has not reached the server yet ("gönderilecek").
  final bool bekliyor;

  /// Why the server refused an input of the phone for good; null otherwise.
  final String? gonderilemedi;

  /// The local copy of the photo of an unsent input.
  final String? yerelFotograf;

  /// Waits on the person: an unanswered question, an action to approve, a work card with a question.
  bool get bekleyenMi => tur == AkisTuru.soru || tur == AkisTuru.onay || (tur == AkisTuru.isKarti && (isKarti?.bekleyenSoru ?? 0) > 0);

  AkisOgesi kopya({List<AsistanSonucu>? sonuclar, AsistanSorusu? soru, bool soruTemizle = false, Brifing? brifing}) => AkisOgesi(
        id: id,
        zaman: zaman,
        tur: tur,
        metin: metin,
        fotografUrl: fotografUrl,
        sonuclar: sonuclar ?? this.sonuclar,
        soru: soruTemizle ? null : (soru ?? this.soru),
        eylem: eylem,
        isKarti: isKarti,
        brifing: brifing ?? this.brifing,
        yakalama: yakalama,
        bekliyor: bekliyor,
        gonderilemedi: gonderilemedi,
        yerelFotograf: yerelFotograf,
      );

  factory AkisOgesi.fromJson(Map<String, dynamic> j) => AkisOgesi(
        id: j['id'] as String,
        zaman: DateTime.parse(j['zaman'] as String).toUtc(),
        tur: j['tur'] as String,
        metin: j['metin'] as String?,
        fotografUrl: j['fotografUrl'] as String?,
        sonuclar: [for (final s in (j['sonuclar'] as List?) ?? const []) AsistanSonucu.fromJson(s as Map<String, dynamic>)],
        soru: j['soru'] == null ? null : AsistanSorusu.fromJson(j['soru'] as Map<String, dynamic>),
        eylem: j['eylem'] == null ? null : Eylem.fromJson(j['eylem'] as Map<String, dynamic>),
        isKarti: j['is'] == null ? null : IsKarti.fromJson(j['is'] as Map<String, dynamic>),
        brifing: j['brifing'] == null ? null : Brifing.fromJson(j['brifing'] as Map<String, dynamic>),
        yakalama: j['yakalama'] == null ? null : Yakalama.fromJson(j['yakalama'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'zaman': zaman.toIso8601String(),
        'tur': tur,
        'metin': metin,
        'fotografUrl': fotografUrl,
        'sonuclar': [for (final s in sonuclar) s.toJson()],
        'soru': soru?.toJson(),
        'eylem': eylem?.toJson(),
        'is': isKarti?.toJson(),
        'brifing': brifing?.toJson(),
        'yakalama': yakalama?.toJson(),
      };
}
