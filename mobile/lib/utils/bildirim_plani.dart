import 'dart:math';

import 'package:intl/intl.dart';

import '../data/models/brifing.dart';
import '../data/models/eylem.dart';
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

  /// The buttons of an approval queue notification.
  static const eylemOnayla = 'eylemOnayla';
  static const eylemReddet = 'eylemReddet';
}

/// The payload of an approval queue notification starts with this; the rest is the action id (empty for the summary).
const eylemBildirimOneki = 'eylem:';

/// One approval queue notification, shown at once (not scheduled).
class EylemBildirimi {
  const EylemBildirimi({required this.id, required this.eylemId, required this.baslik, required this.govde, required this.eylemler});

  final int id;

  /// The action it announces; null for the summary of many.
  final String? eylemId;
  final String baslik;
  final String govde;

  /// Whether the Onayla / Reddet buttons are offered.
  final bool eylemler;
}

/// Up to this many new actions get a notification each; more than that are announced by one summary.
const enCokTekEylemBildirimi = 3;

/// A stable notification id for an action, so it can be taken down when it is decided.
int eylemBildirimKimligi(String eylemId) => bildirimKimligi('$eylemBildirimOneki$eylemId');

/// The id of the summary notification (a stable small number, apart from the reminders' ids).
const eylemOzetBildirimKimligi = 7;

/// The notifications for waiting actions that were not announced yet. A suggestion drawn from outside text, or one
/// the source is unsure about, never gets the Onayla button: approving it takes a look at the screen first.
/// [eylemler] is false for users who cannot decide (the buttons are left out).
List<EylemBildirimi> eylemBildirimleriPlanla(List<Eylem> yeniler, {bool eylemler = true}) {
  if (yeniler.isEmpty) return const [];
  if (yeniler.length > enCokTekEylemBildirimi) {
    return [
      EylemBildirimi(
        id: eylemOzetBildirimKimligi,
        eylemId: null,
        baslik: '${yeniler.length} eylem onay bekliyor',
        govde: 'Onay kuyruğunu açıp tek tek bak.',
        eylemler: false,
      ),
    ];
  }
  return [
    for (final e in yeniler)
      EylemBildirimi(
        id: eylemBildirimKimligi(e.id),
        eylemId: e.id,
        baslik: e.ozet,
        govde: [e.turAdi, if (e.disKaynak) 'dış kaynak', if (e.eminDegil) 'emin değil', 'onayını bekliyor'].join(' · '),
        eylemler: eylemler && !e.disKaynak && !e.eminDegil,
      ),
  ];
}

/// The payload of the morning briefing notification (a reminder id is a Guid, so the two never meet).
const brifingBildirimYuku = 'brifing';

/// The id of the briefing notification (a stable small number, apart from the summary's and the hashed ones).
const brifingBildirimKimligi = 8;

/// The morning briefing's notification (K2.7): the next [ayar] hour in Istanbul time (UTC+3, no daylight saving), repeating
/// every day at that hour so it keeps coming even if the app is not opened. Null when the person turned it off or may not read
/// the briefing ([okuyabilir] false). Planned again with the rest after every sync and at every app start.
PlanliBildirim? brifingBildirimiPlanla(BrifingAyari ayar, DateTime simdi, {required bool okuyabilir}) {
  if (!okuyabilir || !ayar.acik) return null;
  final an = simdi.toUtc();
  // The hour of the day in UTC, then the first such moment after [simdi].
  var sonraki = DateTime.utc(an.year, an.month, an.day, ayar.saat - 3, ayar.dakika);
  if (!sonraki.isAfter(an)) sonraki = sonraki.add(const Duration(days: 1));
  return PlanliBildirim(
    id: brifingBildirimKimligi,
    an: sonraki,
    baslik: 'Sabah brifingi',
    govde: 'Bugünün özeti hazır. Dokun, göz at.',
    hatirlaticiId: brifingBildirimYuku,
    onceUyarisi: false,
    eylemler: false,
    gunlukTekrar: true,
  );
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
    this.gunlukTekrar = false,
    this.acil = false,
    this.israrNo = 0,
  });

  /// Repeats every day at the same hour (the briefing).
  final bool gunlukTekrar;

  /// Breaks through silent mode: its own high importance channel and a full-screen intent.
  final bool acil;

  /// 0 for the notification of the moment itself (and the heads-up); 1.. for the n-th nag after it.
  final int israrNo;

  bool get brifingMi => hatirlaticiId == brifingBildirimYuku;

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
/// The n-th nag ([israrNo] 1..) hashes `<id>#<n>`, so each nag has an id of its own too.
int bildirimKimligi(String hatirlaticiId, {bool onceUyarisi = false, int israrNo = 0}) {
  var h = 0x811c9dc5;
  for (final c in (israrNo == 0 ? hatirlaticiId : '$hatirlaticiId#$israrNo').codeUnits) {
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
        acil: h.acil,
      );
    }

    // The nags count from the moment that counts, and a snooze moves them with it: snoozing (or marking done) is what
    // cancels the rest, because the whole plan is made again. A nag whose time passed is skipped like any past moment,
    // so after the first notification fired the later ones stay planned.
    if (h.israrli) {
      final enCok = min(h.israrEnCok, enCokIsrarSayisi);
      for (var n = 1; n <= enCok; n++) {
        final an = h.etkinAn.add(Duration(minutes: n * h.israrAraligiDakika));
        if (!an.isAfter(simdi)) continue;
        final id = bildirimKimligi(h.id, israrNo: n);
        plan[id] = PlanliBildirim(
          id: id,
          an: an,
          baslik: h.baslik,
          govde: _kimle('hâlâ yapılmadı ($n/$enCok)', h),
          hatirlaticiId: h.id,
          onceUyarisi: false,
          eylemler: eylemler,
          acil: h.acil,
          israrNo: n,
        );
      }
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
