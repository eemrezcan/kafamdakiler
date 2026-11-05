import 'package:json_annotation/json_annotation.dart';

import 'tarih_donusturucu.dart';

part 'beyin.g.dart';

// The read side of the second brain (`/api/beyin`, backend/Beyin/BeyinDtos.cs):
// only the fields the screens need.

/// `ProjeOzetDto`: one row of the project list (also the capture's project picker).
@JsonSerializable()
class ProjeOzet {
  const ProjeOzet({required this.kimlik, required this.baslik});

  final String kimlik;
  final String baslik;

  /// The `Hedef` a capture gets when this project is picked.
  String get hedef => 'projects/$kimlik';

  factory ProjeOzet.fromJson(Map<String, dynamic> json) => _$ProjeOzetFromJson(json);
  Map<String, dynamic> toJson() => _$ProjeOzetToJson(this);
}

/// `ProjeDto`: a project's status, next step, open tasks and last journal lines.
@JsonSerializable()
class ProjeDetay {
  const ProjeDetay({
    required this.kimlik,
    required this.baslik,
    this.durum,
    this.siradakiAdim,
    this.acikGorevler = const [],
    this.sonGunluk = const [],
  });

  final String kimlik;
  final String baslik;
  final String? durum;
  final String? siradakiAdim;
  final List<ProjeGorev> acikGorevler;
  final List<GunlukSatiri> sonGunluk;

  factory ProjeDetay.fromJson(Map<String, dynamic> json) => _$ProjeDetayFromJson(json);
  Map<String, dynamic> toJson() => _$ProjeDetayToJson(this);
}

@JsonSerializable()
@NullableTarihDonusturucu()
class ProjeGorev {
  const ProjeGorev({
    required this.kimlik,
    required this.baslik,
    this.durum,
    this.bitis,
    this.oncelik,
    this.sonrakiAdim,
  });

  final String kimlik;
  final String baslik;
  final String? durum;
  final DateTime? bitis;
  final String? oncelik;
  final String? sonrakiAdim;

  factory ProjeGorev.fromJson(Map<String, dynamic> json) => _$ProjeGorevFromJson(json);
  Map<String, dynamic> toJson() => _$ProjeGorevToJson(this);
}

@JsonSerializable()
class GunlukSatiri {
  const GunlukSatiri({this.zaman, this.baslik, this.metin});

  /// "2026-11-03 18:42", as the brain wrote it.
  final String? zaman;
  final String? baslik;
  final String? metin;

  factory GunlukSatiri.fromJson(Map<String, dynamic> json) => _$GunlukSatiriFromJson(json);
  Map<String, dynamic> toJson() => _$GunlukSatiriToJson(this);
}

/// `BeyinGunDto`: the brain's plan for one day (read only).
@JsonSerializable()
@TarihDonusturucu()
class BeyinGun {
  const BeyinGun({
    required this.tarih,
    this.gunAdi,
    this.haftaGunu,
    this.bugun = false,
    this.planVar = false,
    this.kapandi = false,
    this.bolumler = const [],
    this.geciken = const [],
    this.toplam,
  });

  final DateTime tarih;
  final String? gunAdi;
  final String? haftaGunu;
  final bool bugun;
  final bool planVar;
  final bool kapandi;
  final List<BeyinGunBolumu> bolumler;
  final List<GecikenGorev> geciken;
  final BeyinGunToplami? toplam;

  /// Nothing to show for the day: no plan lines and no overdue tasks.
  bool get bos => bolumler.every((b) => b.maddeler.isEmpty) && geciken.isEmpty;

  factory BeyinGun.fromJson(Map<String, dynamic> json) => _$BeyinGunFromJson(json);
  Map<String, dynamic> toJson() => _$BeyinGunToJson(this);
}

@JsonSerializable()
class BeyinGunBolumu {
  const BeyinGunBolumu({required this.ad, this.maddeler = const []});

  final String ad;
  final List<BeyinGunMaddesi> maddeler;

  factory BeyinGunBolumu.fromJson(Map<String, dynamic> json) => _$BeyinGunBolumuFromJson(json);
  Map<String, dynamic> toJson() => _$BeyinGunBolumuToJson(this);
}

@JsonSerializable()
class BeyinGunMaddesi {
  const BeyinGunMaddesi({
    required this.id,
    required this.baslik,
    this.durum,
    this.tahminDk,
    this.sureDk,
    this.proje,
    this.gorev,
  });

  final String id;
  final String baslik;

  /// "acik" or "yapildi" (what the brain writes; anything else counts as open).
  final String? durum;
  final int? tahminDk;
  final int? sureDk;
  final String? proje;
  final String? gorev;

  bool get yapildi => durum == 'yapildi';

  factory BeyinGunMaddesi.fromJson(Map<String, dynamic> json) => _$BeyinGunMaddesiFromJson(json);
  Map<String, dynamic> toJson() => _$BeyinGunMaddesiToJson(this);
}

@JsonSerializable()
@NullableTarihDonusturucu()
class GecikenGorev {
  const GecikenGorev({required this.kimlik, required this.baslik, this.bitis, this.gun, this.proje, this.oncelik});

  final String kimlik;
  final String baslik;
  final DateTime? bitis;

  /// How many days late.
  final int? gun;
  final String? proje;
  final String? oncelik;

  factory GecikenGorev.fromJson(Map<String, dynamic> json) => _$GecikenGorevFromJson(json);
  Map<String, dynamic> toJson() => _$GecikenGorevToJson(this);
}

@JsonSerializable()
class BeyinGunToplami {
  const BeyinGunToplami({this.madde = 0, this.yapildi = 0, this.acik = 0});

  final int madde;
  final int yapildi;
  final int acik;

  factory BeyinGunToplami.fromJson(Map<String, dynamic> json) => _$BeyinGunToplamiFromJson(json);
  Map<String, dynamic> toJson() => _$BeyinGunToplamiToJson(this);
}

/// `AramaSonucuDto`: one search hit.
@JsonSerializable()
class AramaSonucu {
  const AramaSonucu({required this.yol, required this.baslik, this.proje, this.alan, this.alinti});

  /// Vault-relative note path; opens the note screen.
  final String yol;
  final String baslik;
  final String? proje;
  final String? alan;
  final String? alinti;

  factory AramaSonucu.fromJson(Map<String, dynamic> json) => _$AramaSonucuFromJson(json);
  Map<String, dynamic> toJson() => _$AramaSonucuToJson(this);
}

/// `NotDto`: a note to read (Markdown body).
@JsonSerializable()
class BeyinNotu {
  const BeyinNotu({required this.yol, required this.baslik, this.etiketler = const [], this.govde = ''});

  final String yol;
  final String baslik;
  final List<String> etiketler;
  final String govde;

  factory BeyinNotu.fromJson(Map<String, dynamic> json) => _$BeyinNotuFromJson(json);
  Map<String, dynamic> toJson() => _$BeyinNotuToJson(this);
}
