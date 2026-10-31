import 'package:json_annotation/json_annotation.dart';

// Wire values follow the API contract (docs/planlar/aliskanlik-takibi.md).

enum AliskanlikTuru {
  @JsonValue('sayac')
  sayac,
  @JsonValue('raf')
  raf,
}

enum Olcu {
  @JsonValue('evetHayir')
  evetHayir,
  @JsonValue('sayili')
  sayili,
}

enum HedefYonu {
  @JsonValue('enAz')
  enAz,
  @JsonValue('enCok')
  enCok,
}

enum Siklik {
  @JsonValue('herGun')
  herGun,
  @JsonValue('haftadaN')
  haftadaN,
  @JsonValue('belirliGunler')
  belirliGunler,
}

enum HaftaGunu {
  @JsonValue('pzt')
  pzt,
  @JsonValue('sal')
  sal,
  @JsonValue('car')
  car,
  @JsonValue('per')
  per,
  @JsonValue('cum')
  cum,
  @JsonValue('cmt')
  cmt,
  @JsonValue('paz')
  paz,
}

enum OgeDurumu {
  @JsonValue('siradaki')
  siradaki,
  @JsonValue('devam')
  devam,
  @JsonValue('bitti')
  bitti,
  @JsonValue('birakildi')
  birakildi,
}
