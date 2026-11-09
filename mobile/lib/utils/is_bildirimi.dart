import '../data/models/is_karti.dart';

// The buttons on a work card's notification. An Android action carries one string (its id), so what the button does is written
// into it: `is|c|<card>|<question no>|<answer>` answers a question, `is|a|<card>|<stage>` moves the card. The parts are URI
// encoded, so a `|` in an answer cannot split it.

const _onek = 'is|';

/// The only stages a notification button may move a card to: approve the code gate, or send the card back to the plan. The
/// server offers no other; this keeps a forged id from approving a push or a deploy from the tray.
const bildirimdenGidilebilenAsamalar = ['yapim', 'plan'];

/// What a pressed button asks for.
class IsBildirimEylemi {
  const IsBildirimEylemi.cevap({required this.kimlik, required int this.soruNo, required String this.cevap}) : asama = null;

  const IsBildirimEylemi.asama({required this.kimlik, required String this.asama})
      : soruNo = null,
        cevap = null;

  final String kimlik;
  final int? soruNo;
  final String? cevap;
  final String? asama;

  /// A button that is allowed from a notification: an answer, or one of [bildirimdenGidilebilenAsamalar].
  bool get guvenli => asama == null ? (soruNo != null && cevap != null) : bildirimdenGidilebilenAsamalar.contains(asama);

  /// The id to put on the Android action.
  String get kod => asama != null
      ? '${_onek}a|${Uri.encodeComponent(kimlik)}|${Uri.encodeComponent(asama!)}'
      : '${_onek}c|${Uri.encodeComponent(kimlik)}|$soruNo|${Uri.encodeComponent(cevap!)}';

  /// The action behind the id of a pressed button; null for any other id (a tap, a reminder button).
  static IsBildirimEylemi? coz(String? kod) {
    if (kod == null || !kod.startsWith(_onek)) return null;
    final p = kod.substring(_onek.length).split('|');
    try {
      if (p.length == 3 && p[0] == 'a') {
        return IsBildirimEylemi.asama(kimlik: Uri.decodeComponent(p[1]), asama: Uri.decodeComponent(p[2]));
      }
      if (p.length == 4 && p[0] == 'c') {
        final no = int.tryParse(p[2]);
        if (no == null) return null;
        return IsBildirimEylemi.cevap(kimlik: Uri.decodeComponent(p[1]), soruNo: no, cevap: Uri.decodeComponent(p[3]));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// The button of a server option on the card [kimlik]; null when the option is not one the notification may carry.
  static IsBildirimEylemi? secenekten(String kimlik, BildirimSecenegi s) {
    final eylem = switch (s.eylem) {
      'cevap' when s.soruNo != null && s.cevap != null => IsBildirimEylemi.cevap(kimlik: kimlik, soruNo: s.soruNo!, cevap: s.cevap!),
      'asama' when s.asama != null => IsBildirimEylemi.asama(kimlik: kimlik, asama: s.asama!),
      _ => null,
    };
    return eylem != null && eylem.guvenli ? eylem : null;
  }
}

/// The in-app route of a card.
String isRotasi(String kimlik) => '/asistan/${Uri.encodeComponent(kimlik)}';
