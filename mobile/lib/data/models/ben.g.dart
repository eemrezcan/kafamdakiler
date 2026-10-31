// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ben.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ben _$BenFromJson(Map<String, dynamic> json) => Ben(
  id: json['id'] as String,
  email: json['email'] as String,
  roller:
      (json['roller'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  izinler:
      (json['izinler'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$BenToJson(Ben instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'roller': instance.roller,
  'izinler': instance.izinler,
};
