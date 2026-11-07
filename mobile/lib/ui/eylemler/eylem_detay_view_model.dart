import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/eylem.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/eylem_repository.dart';
import '../../utils/eylem_gorunum.dart';

/// One action in full, with its payload as editable JSON. Approving writes to the phone's queue (offline works); a
/// corrected payload is sent only when the text was changed, and the server checks it again.
class EylemDetayViewModel extends ChangeNotifier {
  EylemDetayViewModel({required this._repo, required this._esitleyici, required this.id});

  final EylemRepository _repo;
  final Esitleyici _esitleyici;
  final String id;

  Eylem? _eylem;
  Eylem? get eylem => _eylem;

  bool _yuklendi = false;

  /// True once the read finished, with or without a result (null [eylem] then means "not found").
  bool get yuklendi => _yuklendi;

  /// The payload as first shown, to tell whether the person changed it.
  String _ilkYuk = '';

  Future<void> yukle() async {
    _eylem = await _repo.getir(id);
    _ilkYuk = _eylem == null ? '' : eylemYukMetni(_eylem!.yuk);
    _yuklendi = true;
    notifyListeners();
  }

  String get ilkYuk => _ilkYuk;

  /// Approves. Returns a message when the typed payload is not a JSON object, null when the decision was queued.
  Future<String?> uygula(String yukMetni) async {
    Map<String, dynamic>? duzeltilmis;
    if (yukMetni.trim() != _ilkYuk.trim()) {
      duzeltilmis = eylemYukCoz(yukMetni);
      if (duzeltilmis == null) return 'Yük geçerli bir JSON nesnesi değil.';
    }
    await _repo.uygula(id, yuk: duzeltilmis);
    unawaited(_esitleyici.gonder());
    return null;
  }

  Future<void> reddet({required bool birDahaOnerme}) async {
    await _repo.reddet(id, birDahaOnerme: birDahaOnerme);
    unawaited(_esitleyici.gonder());
  }
}
