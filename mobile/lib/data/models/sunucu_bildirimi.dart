import 'is_karti.dart';

/// Response of `GET /api/bildirimler/{id}`: the text of a notification the server woke the phone for. FCM carries only
/// the id; the phone reads the rest from here over the tailnet.
class SunucuBildirimi {
  const SunucuBildirimi({
    required this.id,
    required this.baslik,
    required this.metin,
    this.rota,
    this.hedefKimligi,
    this.kaynakTuru,
    this.secenekler = const [],
  });

  final String id;
  final String baslik;
  final String metin;

  /// Where a tap goes inside the app (null: the Bugün screen). May hold `{id}`, replaced by [hedefKimligi].
  final String? rota;
  final String? hedefKimligi;

  /// What made it: `hatirlatici` is a reminder's moment (its [hedefKimligi] is the reminder), `gorev` and `dogrulama` come from the
  /// brain's tasks, `is` from a work card, `test` is the Yönetim test send.
  final String? kaynakTuru;

  /// The buttons the server offers (work cards: the answers of a decision, "Onayla" at the code gate). Empty for any other
  /// notification, and for a person who may not write the cards.
  final List<BildirimSecenegi> secenekler;

  /// A work card fell to the person (`hedefKimligi` is the card).
  bool get isKartiMi => kaynakTuru == 'is' && hedefKimligi != null && hedefKimligi!.isNotEmpty;

  /// A reminder's moment, sent by the server as the backup of the phone's own schedule.
  bool get hatirlaticiZamaniMi => kaynakTuru == 'hatirlatici' && hedefKimligi != null && hedefKimligi!.isNotEmpty;

  factory SunucuBildirimi.fromJson(Map<String, dynamic> json) => SunucuBildirimi(
        id: json['id'] as String,
        baslik: json['baslik'] as String,
        metin: json['metin'] as String,
        rota: json['rota'] as String?,
        hedefKimligi: json['hedefKimligi'] as String?,
        kaynakTuru: json['kaynakTuru'] as String?,
        secenekler: [
          for (final s in (json['secenekler'] as List?) ?? const []) BildirimSecenegi.fromJson(s as Map<String, dynamic>),
        ],
      );
}
