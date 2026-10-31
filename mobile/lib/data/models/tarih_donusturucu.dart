import 'package:json_annotation/json_annotation.dart';

import '../../utils/aliskanlik_gunu.dart';

/// `DateOnly` on the wire ("2026-10-31") <-> date-only UTC [DateTime].
class TarihDonusturucu implements JsonConverter<DateTime, String> {
  const TarihDonusturucu();

  @override
  DateTime fromJson(String json) => tarihCoz(json);

  @override
  String toJson(DateTime object) => tarihMetni(object);
}

class NullableTarihDonusturucu implements JsonConverter<DateTime?, String?> {
  const NullableTarihDonusturucu();

  @override
  DateTime? fromJson(String? json) => json == null ? null : tarihCoz(json);

  @override
  String? toJson(DateTime? object) => object == null ? null : tarihMetni(object);
}
