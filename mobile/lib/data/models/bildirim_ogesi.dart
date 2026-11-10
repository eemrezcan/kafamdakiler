import 'is_karti.dart';

/// One row of `GET /api/bildirimler` (K-0024, sözleşme §6): the notification as `GET /api/bildirimler/{id}` tells it, plus
/// whether it was read. Hand-written JSON; the same shape is kept on the phone, so the list shows offline.
class BildirimOgesi {
  const BildirimOgesi({
    required this.id,
    required this.baslik,
    required this.metin,
    this.zaman,
    this.rota,
    this.hedefKimligi,
    this.kaynakTuru,
    this.secenekler = const [],
    this.okundu = false,
  });

  final String id;
  final String baslik;
  final String metin;

  /// When it was made: the server's `olusmaAni`. Null only for a row kept by an older version of the phone.
  final DateTime? zaman;
  final String? rota;
  final String? hedefKimligi;

  /// `hatirlatici`, `gorev`, `dogrulama`, `is`, `asistan`, `eylem`...
  final String? kaynakTuru;
  final List<BildirimSecenegi> secenekler;
  final bool okundu;

  /// A reminder's moment: "Yaptım" and "Ertele" belong on it ([hedefKimligi] is the reminder).
  bool get hatirlaticiMi => kaynakTuru == 'hatirlatici' && hedefKimligi != null && hedefKimligi!.isNotEmpty;

  BildirimOgesi okunmus() => BildirimOgesi(
        id: id,
        baslik: baslik,
        metin: metin,
        zaman: zaman,
        rota: rota,
        hedefKimligi: hedefKimligi,
        kaynakTuru: kaynakTuru,
        secenekler: secenekler,
        okundu: true,
      );

  factory BildirimOgesi.fromJson(Map<String, dynamic> j) {
    // The contract does not name the time field; the usual names are read.
    final an = j['olusmaAni'] as String?;
    return BildirimOgesi(
      id: j['id'] as String,
      baslik: (j['baslik'] as String?) ?? '',
      metin: (j['metin'] as String?) ?? '',
      zaman: an == null ? null : DateTime.tryParse(an)?.toUtc(),
      rota: j['rota'] as String?,
      hedefKimligi: j['hedefKimligi'] as String?,
      kaynakTuru: j['kaynakTuru'] as String?,
      secenekler: [
        for (final s in (j['secenekler'] as List?) ?? const []) BildirimSecenegi.fromJson(s as Map<String, dynamic>),
      ],
      okundu: (j['okundu'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'metin': metin,
        'olusmaAni': zaman?.toIso8601String(),
        'rota': rota,
        'hedefKimligi': hedefKimligi,
        'kaynakTuru': kaynakTuru,
        'okundu': okundu,
      };
}
