/// Response of `GET /api/bildirimler/{id}`: the text of a notification the server woke the phone for. FCM carries only
/// the id; the phone reads the rest from here over the tailnet.
class SunucuBildirimi {
  const SunucuBildirimi({
    required this.id,
    required this.baslik,
    required this.metin,
    this.rota,
    this.hedefKimligi,
  });

  final String id;
  final String baslik;
  final String metin;

  /// Where a tap goes inside the app (null: the Bugün screen). May hold `{id}`, replaced by [hedefKimligi].
  final String? rota;
  final String? hedefKimligi;

  factory SunucuBildirimi.fromJson(Map<String, dynamic> json) => SunucuBildirimi(
        id: json['id'] as String,
        baslik: json['baslik'] as String,
        metin: json['metin'] as String,
        rota: json['rota'] as String?,
        hedefKimligi: json['hedefKimligi'] as String?,
      );
}
