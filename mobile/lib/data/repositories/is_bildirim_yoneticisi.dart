import '../../utils/bildirim_plani.dart';
import '../services/bildirim_servisi.dart';
import 'is_repository.dart';

/// Answers the buttons of a work card's notification: a button calls the server (answer a question, approve the code gate, send
/// the card back to the plan). Unlike the reminders' buttons it does not wait in the offline queue: a decision on a card is
/// taken on the card as it is now, so without the server it fails. When it worked the notification is taken down; when it did
/// not (offline, the card moved on, the brain refused) the notification is replaced by one that says so, and opening it shows
/// the card.
///
/// It does not start the plugin: the responses reach `HatirlaticiBildirimYoneticisi`, which owns the one callback and hands the
/// card ones over to [yanitla].
class IsBildirimYoneticisi {
  IsBildirimYoneticisi({required this._repo, required this._servis, required this._yazabilir});

  final IsRepository _repo;
  final BildirimServisi _servis;

  /// Whether the user may write to the cards (the Sahip); the buttons are answered only then.
  final bool Function() _yazabilir;

  static const hataBasligi = 'Asistan işi';

  /// A button on a card's notification. Returns true when the card should open instead (the user may not write, or the button is
  /// not one a notification may carry).
  Future<bool> yanitla(BildirimYaniti yanit) async {
    final eylem = yanit.isEylemi;
    if (eylem == null || !eylem.guvenli || !_yazabilir()) return true;
    final no = yanit.bildirimNo ?? bildirimKimligi('sunucu:${eylem.kimlik}');

    var tamam = false;
    try {
      final sonuc = eylem.asama != null
          ? await _repo.asamaDegistir(eylem.kimlik, eylem.asama!)
          : await _repo.cevapla(eylem.kimlik, eylem.soruNo!, eylem.cevap!);
      // An unclear answer (202) is not "done": the write may have happened, but the person should look.
      tamam = sonuc.kart != null;
    } on Object {
      tamam = false;
    }

    if (tamam) {
      await _servis.bildirimiKapat(no);
    } else {
      await _servis.isHatasiBildir(id: no, baslik: hataBasligi, kimlik: eylem.kimlik);
    }
    return false;
  }
}
