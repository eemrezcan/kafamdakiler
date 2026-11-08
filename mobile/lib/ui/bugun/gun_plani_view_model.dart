import 'dart:async';

import '../../data/models/beyin.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/gun_plani_repository.dart';
import '../core/beyin_yukleyici.dart';

/// The brain's plan for one day on the "Bugün" tab. Starts on today and moves a day forward or back; the habit cards
/// below it always stay on today.
///
/// Writes (K2.3a) are optimistic like the habit ones: they go to the phone's queue, the plan is rebuilt from the cached
/// day plus the queue at once, and the sender runs in the background. What the server refuses is taken back off the
/// screen by the next rebuild and told in [bildirimler].
class GunPlaniViewModel extends BeyinYukleyici<BeyinGun> {
  GunPlaniViewModel({required this._repo, required this._esitleyici}) : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _tarih = bugun;
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final GunPlaniRepository _repo;
  final Esitleyici _esitleyici;
  int _gorulenGonderim;
  bool _kapandi = false;

  late DateTime _tarih;

  /// The day shown (date-only, UTC midnight).
  DateTime get tarih => _tarih;

  /// Today by the same rule as the habits (the day starts at 05:00).
  DateTime get bugun => _repo.bugun;

  bool get bugunMu => _tarih == bugun;

  /// The plan on screen is the phone's copy (no answer from the server).
  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  /// Yesterday's open items; only offered on today's plan.
  List<SabahMaddesi> _sabah = const [];
  List<SabahMaddesi> get sabah => bugunMu ? _sabah : const [];

  /// Project titles by id, so a task line can say "Staj Hazırlığı" instead of "staj-hazirligi".
  Map<String, String> _projeAdlari = const {};

  /// The project's title, or its id when the phone does not know it (yet).
  String projeAdi(String kimlik) => _projeAdlari[kimlik] ?? kimlik;

  /// Overdue tasks, minus the ones "Dünden kalanlar" already offers (yesterday's line for the same task): one job, one place.
  List<GecikenGorev> geciken(BeyinGun gun) => [
        for (final g in gun.geciken)
          if (!sabah.any((s) => _ayniIs(s, g))) g,
      ];

  /// The overdue task a leftover line stands for, if any (shown under the line instead of in the task list).
  GecikenGorev? sabahGorevi(SabahMaddesi s) {
    for (final g in veri?.geciken ?? const <GecikenGorev>[]) {
      if (_ayniIs(s, g)) return g;
    }
    return null;
  }

  // The line is linked to the task (`gorev`, or the brain's `g:<task>` id), or it simply carries the task's title.
  static bool _ayniIs(SabahMaddesi s, GecikenGorev g) {
    final gorev = s.madde.gorev;
    if (gorev != null && (gorev == g.kimlik || gorev.endsWith('/${g.kimlik}') || g.kimlik.endsWith('/$gorev'))) return true;
    if (s.madde.id == 'g:${g.kimlik}') return true;
    return s.madde.baslik.trim().toLowerCase() == g.baslik.trim().toLowerCase();
  }

  /// Refused writes and accepted ones that need a look.
  List<YazmaBildirimi> _bildirimler = const [];
  List<YazmaBildirimi> get bildirimler => _bildirimler;

  /// The day can take writes: it has been read, and the brain has not closed it.
  bool get yazilabilir => veri != null && !veri!.kapandi;

  @override
  Future<BeyinGun> getir() async {
    final sonuc = await _repo.oku(_tarih);
    _cevrimdisi = sonuc.cevrimdisi;
    unawaited(_yanlariYukle(oku: true));
    return sonuc.gun;
  }

  Future<void> gunDegistir(int fark) {
    _tarih = _tarih.add(Duration(days: fark));
    temizle();
    return yukle();
  }

  Future<void> bugune() {
    _tarih = bugun;
    temizle();
    return yukle();
  }

  /// The morning card and the messages; they never block the plan.
  Future<void> _yanlariYukle({required bool oku}) async {
    try {
      final sabah = bugunMu ? await _repo.sabah(oku: oku) : const <SabahMaddesi>[];
      final bildirimler = await _repo.bildirimler();
      final projeler = await _repo.projeler();
      if (_kapandi) return;
      _sabah = sabah;
      _bildirimler = bildirimler;
      _projeAdlari = {for (final p in projeler) p.kimlik: p.baslik};
      notifyListeners();
    } on Object {
      // The extras are best effort: the plan itself stays as it is.
    }
  }

  // Writes: queue, show at once, send in the background.

  Future<void> maddeEkle(String metin, {String? bolum}) => _yaz(() => _repo.maddeEkle(_tarih, metin, bolum: bolum));

  /// Ticks the item, or takes the tick away when it is done. Only an item with the brain's permanent id can be written to:
  /// one that is on the phone only so far has none yet.
  Future<void> isaretle(BeyinGunMaddesi madde) {
    if (!madde.kalici) return Future.value();
    return _yaz(() => _repo.isaretle(_tarih, madde));
  }

  Future<void> devret(BeyinGunMaddesi madde, String bolum) {
    if (!madde.kalici) return Future.value();
    return _yaz(() => _repo.devret(_tarih, madde, bolum: bolum));
  }

  Future<void> notEkle(BeyinGunMaddesi madde, String metin) {
    if (!madde.kalici) return Future.value();
    return _yaz(() => _repo.notEkle(_tarih, madde, metin));
  }

  Future<void> gorevBitir(String kimlik) => _yaz(() => _repo.gorevBitir(kimlik));

  Future<void> gorevEkle({required String baslik, required String proje, DateTime? bitis}) =>
      _yaz(() => _repo.gorevEkle(baslik: baslik, proje: proje, bitis: bitis));

  /// Splits the task over [gunSayisi] days from the day on screen.
  Future<void> bol(String kimlik, int gunSayisi) => _yaz(() => _repo.gunlereBol(kimlik, gunSayisi: gunSayisi, baslangic: _tarih));

  Future<List<ProjeOzet>> projeler() => _repo.projeler();

  Future<void> sabahTasi(SabahMaddesi s) => _yaz(() => _repo.sabahTasi(s));

  Future<void> sabahBirak(SabahMaddesi s) => _repo.sabahBirak(s);

  Future<void> bildirimiKapat(YazmaBildirimi b) => _repo.bildirimiKapat(b.id);

  Future<void> _yaz(Future<void> Function() yaz) async {
    await yaz();
    unawaited(_esitleyici.gonder());
  }

  /// The plan from the cache and the queue; no network, no loading flash.
  Future<void> _yerelYenile() async {
    if (_kapandi) return;
    final gun = await _repo.yerel(_tarih);
    if (_kapandi) return;
    if (gun != null) veriyiDegistir(gun);
    await _yanlariYukle(oku: false);
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi != _gorulenGonderim) {
      _gorulenGonderim = _esitleyici.gonderimSayisi;
      unawaited(yukle());
    } else {
      unawaited(_yerelYenile());
    }
  }

  @override
  void dispose() {
    _kapandi = true;
    _repo.removeListener(_yerelYenile);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
