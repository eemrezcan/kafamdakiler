import 'package:json_annotation/json_annotation.dart';

part 'ben.g.dart';

/// Response of `GET /api/ben`: who is signed in.
@JsonSerializable()
class Ben {
  const Ben({
    required this.id,
    required this.email,
    this.roller = const [],
    this.izinler = const [],
  });

  static const sahipRolu = 'Sahip';

  final String id;
  final String email;
  final List<String> roller;
  final List<String> izinler;

  bool get sahip => roller.contains(sahipRolu);

  factory Ben.fromJson(Map<String, dynamic> json) => _$BenFromJson(json);
  Map<String, dynamic> toJson() => _$BenToJson(this);
}
