import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'hatirlatici.dart';
import 'tarih_donusturucu.dart';

part 'gun_gorunum.g.dart';

// The day view of the UI revision (K-0024, docs/planlar/ui-revizyon/sozlesme.md §1-§5): `GET /api/gun/{tarih}`, the calendar
// range, the new-item body and the day capacity setting. Only the fields the screens use.

/// How long a day is in minutes, shown as "7 sa 20 dk".
String sureMetni(int dakika) {
  if (dakika <= 0) return '0 dk';
  final s = dakika ~/ 60;
  final d = dakika % 60;
  if (s == 0) return '$d dk';
  if (d == 0) return '$s sa';
  return '$s sa $d dk';
}

/// `GunYukuDto`: open work against the capacity of the day.
@JsonSerializable()
class GunYuku {
  const GunYuku({
    this.acikTahminDk = 0,
    this.etkinlikDk = 0,
    this.kapasiteDk = 0,
    this.asimDk = 0,
    this.bosDk = 0,
    this.tahminsizSayi = 0,
  });

  final int acikTahminDk;
  final int etkinlikDk;
  final int kapasiteDk;
  final int asimDk;
  final int bosDk;
  final int tahminsizSayi;

  /// Estimates and events together, as the bar shows them.
  int get toplamDk => acikTahminDk + etkinlikDk;

  /// The same numbers worked out again from the open items, for the screen after a queued write moved something.
  GunYuku yenidenHesapla({required int acikTahminDk, required int tahminsizSayi}) {
    final toplam = acikTahminDk + etkinlikDk;
    return GunYuku(
      acikTahminDk: acikTahminDk,
      etkinlikDk: etkinlikDk,
      kapasiteDk: kapasiteDk,
      asimDk: toplam > kapasiteDk ? toplam - kapasiteDk : 0,
      bosDk: kapasiteDk > toplam ? kapasiteDk - toplam : 0,
      tahminsizSayi: tahminsizSayi,
    );
  }

  factory GunYuku.fromJson(Map<String, dynamic> json) => _$GunYukuFromJson(json);
  Map<String, dynamic> toJson() => _$GunYukuToJson(this);
}

/// `DundenKalanDto`: an item yesterday's plan left open.
@JsonSerializable()
class DundenKalan {
  const DundenKalan({required this.maddeId, required this.baslik, this.tahminDk, this.proje});

  final String maddeId;
  final String baslik;
  final int? tahminDk;
  final String? proje;

  factory DundenKalan.fromJson(Map<String, dynamic> json) => _$DundenKalanFromJson(json);
  Map<String, dynamic> toJson() => _$DundenKalanToJson(this);
}

/// `HatirlaticiOzetDto`: the reminder tied to an item.
@JsonSerializable()
class HatirlaticiOzet {
  const HatirlaticiOzet({
    required this.id,
    this.saat,
    this.tekrar = Tekrar.yok,
    this.gunler,
    this.acil = false,
    this.israrli = false,
    this.onceGun = 0,
  });

  final String id;

  /// "HH:mm".
  final String? saat;
  final Tekrar tekrar;
  final List<HaftaGunu>? gunler;
  final bool acil;
  final bool israrli;
  final int onceGun;

  factory HatirlaticiOzet.fromJson(Map<String, dynamic> json) => _$HatirlaticiOzetFromJson(json);
  Map<String, dynamic> toJson() => _$HatirlaticiOzetToJson(this);
}

/// `YapilacakDto.bolunmus`: "2 günden 1.".
@JsonSerializable()
class BolunmusBilgi {
  const BolunmusBilgi({required this.sira, required this.toplam});

  final int sira;
  final int toplam;

  factory BolunmusBilgi.fromJson(Map<String, dynamic> json) => _$BolunmusBilgiFromJson(json);
  Map<String, dynamic> toJson() => _$BolunmusBilgiToJson(this);
}

/// The four kinds of row in the one list: a plan item, a task, a reminder and a calendar event.
enum YapilacakTuru {
  @JsonValue('plan')
  plan,
  @JsonValue('gorev')
  gorev,
  @JsonValue('hatirlatici')
  hatirlatici,
  @JsonValue('etkinlik')
  etkinlik,
}

/// `YapilacakDto`: one row of the day list. [kimlik] is typed by a prefix: `m:` plan item, `g:` task, `h:` reminder, `e:`
/// event (and, on the phone only, [yerelOnek] for an item added offline that has no id yet).
@JsonSerializable()
class Yapilacak {
  const Yapilacak({
    required this.kimlik,
    required this.tur,
    required this.baslik,
    this.saat,
    this.bitisSaati,
    this.tumGun = false,
    this.tahminDk,
    this.sureDk,
    this.durum = 'acik',
    this.proje,
    this.bolum,
    this.gecikmeGun,
    this.bolunmus,
    this.hatirlatici,
    this.maddeId,
    this.gorevKimligi,
    this.hatirlaticiId,
    this.etkinlikId,
    this.yer,
    this.tarih,
  });

  static const yerelOnek = 'yerel:';

  final String kimlik;
  final YapilacakTuru tur;
  final String baslik;
  final String? saat;
  final String? bitisSaati;
  final bool tumGun;
  final int? tahminDk;
  final int? sureDk;

  /// "acik" or "yapildi".
  final String durum;
  final String? proje;
  final String? bolum;
  final int? gecikmeGun;
  final BolunmusBilgi? bolunmus;
  final HatirlaticiOzet? hatirlatici;
  final String? maddeId;
  final String? gorevKimligi;
  final String? hatirlaticiId;
  final String? etkinlikId;
  final String? yer;

  /// The day of the row (sözleşme E1); the upcoming rows name theirs.
  @NullableTarihDonusturucu()
  final DateTime? tarih;

  bool get yapildi => durum == 'yapildi';

  /// Events have no "yaptım".
  bool get yapilabilir => tur != YapilacakTuru.etkinlik;

  /// An item added on the phone that has not been sent yet: it can only be looked at until it is.
  bool get yerel => kimlik.startsWith(yerelOnek);

  /// A task or a plan item counts towards the load of the day while it is open.
  bool get yuke => !yapildi && (tur == YapilacakTuru.plan || tur == YapilacakTuru.gorev);

  Yapilacak copyWith({
    String? durum,
    String? saat,
    int? tahminDk,
    HatirlaticiOzet? hatirlatici,
    bool hatirlaticiTemizle = false,
  }) =>
      Yapilacak(
        kimlik: kimlik,
        tur: tur,
        baslik: baslik,
        saat: saat ?? this.saat,
        bitisSaati: bitisSaati,
        tumGun: tumGun,
        tahminDk: tahminDk ?? this.tahminDk,
        sureDk: sureDk,
        durum: durum ?? this.durum,
        proje: proje,
        bolum: bolum,
        gecikmeGun: gecikmeGun,
        bolunmus: bolunmus,
        hatirlatici: hatirlaticiTemizle ? null : (hatirlatici ?? this.hatirlatici),
        maddeId: maddeId,
        gorevKimligi: gorevKimligi,
        hatirlaticiId: hatirlaticiId,
        etkinlikId: etkinlikId,
        yer: yer,
        tarih: tarih,
      );

  factory Yapilacak.fromJson(Map<String, dynamic> json) => _$YapilacakFromJson(json);
  Map<String, dynamic> toJson() => _$YapilacakToJson(this);
}

/// `GunGorunumuDto.kaynaklar`: where the day's data came from, for the "okunamadı" notes.
@JsonSerializable()
class GunKaynaklari {
  const GunKaynaklari({this.plan = 'tamam', this.google = 'kapali', this.sonEsitleme});

  /// "yok", "tamam" or "okunamadi".
  final String plan;

  /// "kapali", "bagliDegil", "bagli" or "yenidenBaglan".
  final String google;
  final DateTime? sonEsitleme;

  bool get planOkunamadi => plan == 'okunamadi';

  factory GunKaynaklari.fromJson(Map<String, dynamic> json) => _$GunKaynaklariFromJson(json);
  Map<String, dynamic> toJson() => _$GunKaynaklariToJson(this);
}

/// `GunGorunumDto`: the one read behind Bugün and the day list of Takvim.
@JsonSerializable()
@TarihDonusturucu()
class GunGorunum {
  const GunGorunum({
    required this.tarih,
    this.bugun = false,
    this.kapandi = false,
    this.ozet,
    this.yuk = const GunYuku(),
    this.dundenKalanlar = const [],
    this.ogeler = const [],
    this.kaynaklar = const GunKaynaklari(),
  });

  final DateTime tarih;
  final bool bugun;
  final bool kapandi;

  /// One or two sentences from the assistant; null when it has nothing to say.
  final String? ozet;
  final GunYuku yuk;
  final List<DundenKalan> dundenKalanlar;
  final List<Yapilacak> ogeler;
  final GunKaynaklari kaynaklar;

  /// The open rows that count towards the load, the ones "Bir kısmını devret" offers.
  List<Yapilacak> get devredilebilir => [for (final o in ogeler) if (o.yuke && !o.yerel) o];

  int get acikSayi => ogeler.where((o) => o.yapilabilir && !o.yapildi).length;

  GunGorunum copyWith({
    GunYuku? yuk,
    List<DundenKalan>? dundenKalanlar,
    List<Yapilacak>? ogeler,
  }) =>
      GunGorunum(
        tarih: tarih,
        bugun: bugun,
        kapandi: kapandi,
        ozet: ozet,
        yuk: yuk ?? this.yuk,
        dundenKalanlar: dundenKalanlar ?? this.dundenKalanlar,
        ogeler: ogeler ?? this.ogeler,
        kaynaklar: kaynaklar,
      );

  factory GunGorunum.fromJson(Map<String, dynamic> json) => _$GunGorunumFromJson(json);
  Map<String, dynamic> toJson() => _$GunGorunumToJson(this);
}

/// `POST /api/gun/{tarih}/yaptim` answer: the row as it is now and the ids that closed with it (the chain of §1.2).
@JsonSerializable()
class YaptimYaniti {
  const YaptimYaniti({required this.oge, this.zincir = const []});

  final Yapilacak oge;
  final List<String> zincir;

  factory YaptimYaniti.fromJson(Map<String, dynamic> json) => _$YaptimYanitiFromJson(json);
  Map<String, dynamic> toJson() => _$YaptimYanitiToJson(this);
}

/// `TakvimGunuDto.sayilar`.
@JsonSerializable()
class TakvimSayilari {
  const TakvimSayilari({this.plan = 0, this.gorev = 0, this.hatirlatici = 0, this.etkinlik = 0});

  final int plan;
  final int gorev;
  final int hatirlatici;
  final int etkinlik;

  int get toplam => plan + gorev + hatirlatici + etkinlik;

  factory TakvimSayilari.fromJson(Map<String, dynamic> json) => _$TakvimSayilariFromJson(json);
  Map<String, dynamic> toJson() => _$TakvimSayilariToJson(this);
}

/// `TakvimGunuDto`: a day's dots on the week strip and the month grid.
@JsonSerializable()
@TarihDonusturucu()
class TakvimGunu {
  const TakvimGunu({required this.tarih, this.sayilar = const TakvimSayilari(), this.yukAsimi = false});

  final DateTime tarih;
  final TakvimSayilari sayilar;
  final bool yukAsimi;

  factory TakvimGunu.fromJson(Map<String, dynamic> json) => _$TakvimGunuFromJson(json);
  Map<String, dynamic> toJson() => _$TakvimGunuToJson(this);
}

/// `TakvimAraligiDto`: the days of a range (at most 42) and the upcoming items.
@JsonSerializable()
class TakvimAraligi {
  const TakvimAraligi({this.gunler = const [], this.yaklasan = const []});

  final List<TakvimGunu> gunler;
  final List<Yapilacak> yaklasan;

  TakvimGunu? gun(DateTime tarih) {
    for (final g in gunler) {
      if (g.tarih.year == tarih.year && g.tarih.month == tarih.month && g.tarih.day == tarih.day) return g;
    }
    return null;
  }

  factory TakvimAraligi.fromJson(Map<String, dynamic> json) => _$TakvimAraligiFromJson(json);
  Map<String, dynamic> toJson() => _$TakvimAraligiToJson(this);
}

/// The reminder part of the new-item body and of the shortcut on an item (`HatirlaticiYazDto`'s hour, repeat, days, urgent,
/// nagging and "days before" fields).
@JsonSerializable(includeIfNull: false)
class HatirlaticiGovde {
  const HatirlaticiGovde({
    this.saat,
    this.tekrar = Tekrar.yok,
    this.gunler,
    this.acil = false,
    this.israrli = false,
    this.onceGun = 0,
  });

  /// "HH:mm"; null falls back to the item's hour, then the default morning hour on the server.
  final String? saat;
  final Tekrar tekrar;

  /// The weekdays of a weekly repeat, written like the habit's `gunler`; empty means the day's own weekday.
  final List<HaftaGunu>? gunler;
  final bool acil;
  final bool israrli;
  final int onceGun;

  factory HatirlaticiGovde.fromJson(Map<String, dynamic> json) => _$HatirlaticiGovdeFromJson(json);
  Map<String, dynamic> toJson() => _$HatirlaticiGovdeToJson(this);
}

/// Body of `POST /api/gun/{tarih}/ogeler` (the new "yapılacak" form).
@JsonSerializable(includeIfNull: false)
class YeniOgeYaz {
  const YeniOgeYaz({
    required this.baslik,
    this.saat,
    this.tahminDk,
    this.proje,
    this.bolum,
    this.hatirlatici,
  });

  final String baslik;
  final String? saat;
  final int? tahminDk;
  final String? proje;
  final String? bolum;
  final HatirlaticiGovde? hatirlatici;

  factory YeniOgeYaz.fromJson(Map<String, dynamic> json) => _$YeniOgeYazFromJson(json);
  Map<String, dynamic> toJson() => _$YeniOgeYazToJson(this);
}

/// `GET/PUT /api/ayarlar/gun`: minutes a day holds, on weekdays and at the weekend.
@JsonSerializable()
class GunAyari {
  const GunAyari({this.haftaIciDk = 360, this.haftaSonuDk = 180});

  final int haftaIciDk;
  final int haftaSonuDk;

  factory GunAyari.fromJson(Map<String, dynamic> json) => _$GunAyariFromJson(json);
  Map<String, dynamic> toJson() => _$GunAyariToJson(this);
}
