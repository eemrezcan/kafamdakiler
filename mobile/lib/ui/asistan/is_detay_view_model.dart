import 'package:dio/dio.dart';

import '../../data/models/is_karti.dart';
import '../../data/repositories/is_repository.dart';
import '../core/beyin_yukleyici.dart';
import '../core/hata_metni.dart';
import 'is_hata.dart';

/// One work card: its request, plan, questions and history, and the writes on it (answer a question, move it to another stage,
/// cancel it). Every write needs the server; one that cannot reach it says so and shuts the write buttons until the card is
/// read again. After a write (or a refusal that means the card has changed) the card is read again, so the screen always shows
/// the stage the brain holds.
class IsDetayViewModel extends BeyinYukleyici<IsAyrinti> {
  IsDetayViewModel({required this._repo, required this.kimlik, this.yazabilir = true});

  final IsRepository _repo;
  final String kimlik;

  /// Whether the person may write to the cards (the Sahip).
  final bool yazabilir;

  bool _islemde = false;
  bool get islemde => _islemde;

  /// What the last write said when it did not simply work: the server's own sentence, or the offline text.
  String? _mesaj;
  String? get mesaj => _mesaj;

  bool _cevrimdisi = false;

  /// The last write found no connection.
  bool get cevrimdisi => _cevrimdisi;

  bool _atildi = false;

  /// The write buttons work: the person may write, a write is not running, the connection is there and the card is open.
  bool get yazmaAcik => yazabilir && !_islemde && !_cevrimdisi && (veri?.kart.acik ?? false);

  @override
  Future<IsAyrinti> getir() => _repo.ayrinti(kimlik);

  Future<bool> cevapla(IsSorusu soru, String cevap) {
    if (cevap.trim().isEmpty) {
      _mesaj = 'Cevap boş olamaz.';
      notifyListeners();
      return Future.value(false);
    }
    return _yaz(() => _repo.cevapla(kimlik, soru.no, cevap.trim()));
  }

  Future<bool> asamaDegistir(String asama, {String? gerekce}) => _yaz(() => _repo.asamaDegistir(kimlik, asama, gerekce: gerekce));

  Future<bool> notYaz(String metin) => _yaz(() => _repo.notYaz(kimlik, metin.trim()));

  void mesajiTemizle() {
    _mesaj = null;
    notifyListeners();
  }

  /// True when the brain took the write. A false answer leaves [mesaj] saying why.
  Future<bool> _yaz(Future<IsYazmaSonucu> Function() yaz) async {
    if (_islemde) return false;
    _islemde = true;
    _mesaj = null;
    notifyListeners();
    var tamam = false;
    try {
      final sonuc = await yaz();
      _cevrimdisi = false;
      // An unclear answer (the write may have happened): told, never counted as done.
      _mesaj = sonuc.uyari;
      tamam = sonuc.kart != null;
      await yukle();
    } on DioException catch (e) {
      _mesaj = isHataMetni(e);
      _cevrimdisi = cevrimdisiHata(e);
      // A refusal means the card is not as the screen showed it (moved on, closed): read it again.
      if (!_cevrimdisi) await yukle();
    } finally {
      _islemde = false;
      if (!_atildi) notifyListeners();
    }
    return tamam;
  }

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}
