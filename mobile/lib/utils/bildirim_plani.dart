import 'package:intl/intl.dart';

import '../data/models/hatirlatici.dart';
import 'hatirlatici_gorunum.dart';

// Which notifications to set up for the reminders: pure logic, independent of the plugin (see
// data/services/bildirim_servisi.dart for the thin wrapper that talks to Android). The whole plan is recomputed and
// set up again after every sync and at every app start.

/// Ids of the notification action buttons.
abstract final class BildirimEylemi {
  static const yaptim = 'yaptim';
  static const birSaatErtele = 'ertele1s';
  static const yarinErtele = 'erteleYarin';
}

/// One notification to schedule.
class PlanliBildirim {
  const PlanliBildirim({
    required this.id,
    required this.an,
    required this.baslik,
    required this.govde,
    required this.hatirlaticiId,
    required this.onceUyarisi,
    required this.eylemler,
  });

  final int id;

  /// When it shows (UTC).
  final DateTime an;
  final String baslik;
  final String govde;

  /// The reminder it belongs to; the notification carries it as its payload.
  final String hatirlaticiId;

  /// The heads-up ("3 gün sonra: ...") rather than the notification of the moment itself.
  final bool onceUyarisi;

  /// Whether the Yaptım / 1 saat ertele / Yarın buttons are offered.
  final bool eylemler;
}

/// A stable notification id for a reminder: the same reminder always gets the same id (FNV-1a of its id), so a
/// plan set up again replaces the old one and the heads-up has an id of its own. Fits Android's positive 31 bits.
int bildirimKimligi(String hatirlaticiId, {bool onceUyarisi = false}) {
  var h = 0x811c9dc5;
  for (final c in hatirlaticiId.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return ((h & 0x3FFFFFFF) << 1) | (onceUyarisi ? 1 : 0);
}

/// The notifications for [liste]. Only open reminders get any (done and archived ones are left out), and moments
/// that are not after [simdi] are skipped: a past moment would show at once or never. A snooze replaces the rule's
/// next moment; the heads-up stays tied to the rule. [eylemler] is false for users who cannot write (the Asistan).
List<PlanliBildirim> bildirimleriPlanla(List<Hatirlatici> liste, DateTime simdi, {bool eylemler = true}) {
  final plan = <int, PlanliBildirim>{};
  for (final h in liste) {
    if (h.durum != HatirlaticiDurumu.acik) continue;

    if (h.etkinAn.isAfter(simdi)) {
      final id = bildirimKimligi(h.id);
      plan[id] = PlanliBildirim(
        id: id,
        an: h.etkinAn,
        baslik: h.baslik,
        govde: _kimle('bugün', h),
        hatirlaticiId: h.id,
        onceUyarisi: false,
        eylemler: eylemler,
      );
    }

    final once = h.onceAn;
    if (once != null && once.isAfter(simdi)) {
      final id = bildirimKimligi(h.id, onceUyarisi: true);
      plan[id] = PlanliBildirim(
        id: id,
        an: once,
        baslik: '${kalanGunMetni(h.onceGun)}: ${h.baslik}',
        govde: _kimle(_zamanMetni(h.sonrakiAn), h),
        hatirlaticiId: h.id,
        onceUyarisi: true,
        eylemler: false,
      );
    }
  }
  return plan.values.toList()..sort((a, b) => a.an.compareTo(b.an));
}

/// A promise says who it was made to.
String _kimle(String metin, Hatirlatici h) =>
    h.tur == HatirlaticiTuru.soz && h.kime != null ? '$metin · Kime: ${h.kime}' : metin;

/// "15 Aralık Salı, 09:00" in Istanbul time.
String _zamanMetni(DateTime an) =>
    DateFormat('d MMMM EEEE, HH:mm', 'tr').format(an.toUtc().add(const Duration(hours: 3)));
