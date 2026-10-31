import 'package:json_annotation/json_annotation.dart';

part 'giris.g.dart';

/// Body of `POST /api/hesap/login` (ASP.NET Core Identity API).
@JsonSerializable()
class GirisIstegi {
  const GirisIstegi({required this.email, required this.password});

  final String email;
  final String password;

  factory GirisIstegi.fromJson(Map<String, dynamic> json) => _$GirisIstegiFromJson(json);
  Map<String, dynamic> toJson() => _$GirisIstegiToJson(this);
}

/// Response of `/login` and `/refresh` (Identity `AccessTokenResponse`).
@JsonSerializable()
class GirisYaniti {
  const GirisYaniti({
    required this.tokenType,
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
  });

  final String tokenType;
  final String accessToken;
  final int expiresIn;
  final String refreshToken;

  factory GirisYaniti.fromJson(Map<String, dynamic> json) => _$GirisYanitiFromJson(json);
  Map<String, dynamic> toJson() => _$GirisYanitiToJson(this);
}

/// Response of `POST /api/dosyalar`.
@JsonSerializable()
class DosyaYaniti {
  const DosyaYaniti({required this.id, required this.url});

  final String id;
  final String url;

  factory DosyaYaniti.fromJson(Map<String, dynamic> json) => _$DosyaYanitiFromJson(json);
  Map<String, dynamic> toJson() => _$DosyaYanitiToJson(this);
}
