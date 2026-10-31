// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'giris.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GirisIstegi _$GirisIstegiFromJson(Map<String, dynamic> json) => GirisIstegi(
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$GirisIstegiToJson(GirisIstegi instance) =>
    <String, dynamic>{'email': instance.email, 'password': instance.password};

GirisYaniti _$GirisYanitiFromJson(Map<String, dynamic> json) => GirisYaniti(
  tokenType: json['tokenType'] as String,
  accessToken: json['accessToken'] as String,
  expiresIn: (json['expiresIn'] as num).toInt(),
  refreshToken: json['refreshToken'] as String,
);

Map<String, dynamic> _$GirisYanitiToJson(GirisYaniti instance) =>
    <String, dynamic>{
      'tokenType': instance.tokenType,
      'accessToken': instance.accessToken,
      'expiresIn': instance.expiresIn,
      'refreshToken': instance.refreshToken,
    };

DosyaYaniti _$DosyaYanitiFromJson(Map<String, dynamic> json) =>
    DosyaYaniti(id: json['id'] as String, url: json['url'] as String);

Map<String, dynamic> _$DosyaYanitiToJson(DosyaYaniti instance) =>
    <String, dynamic>{'id': instance.id, 'url': instance.url};
