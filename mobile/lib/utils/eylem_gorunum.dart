import 'dart:convert';

import '../data/models/eylem.dart';

// Display texts of the approval queue screens, in one place (the web has the same words in EylemGorunum.cs).

String eylemKaynakAdi(String kaynak) => switch (kaynak) {
      'kullanici' => 'Sen',
      'ses' => 'Ses',
      'gelen' => 'Gelen kutusu',
      'brifing' => 'Brifing',
      'mail' => 'Mail',
      _ => kaynak,
    };

String eylemKipAdi(EylemKipi kip) => switch (kip) {
      EylemKipi.sor => 'Sor',
      EylemKipi.kendinYap => 'Kendin yap',
      EylemKipi.yasak => 'Yasak',
    };

String eylemKipAciklamasi(EylemKipi kip) => switch (kip) {
      EylemKipi.sor => 'Önce onayını bekler.',
      EylemKipi.kendinYap => 'Hemen uygular, geri alınabilir. Dış kaynaklı öneriler yine onay bekler.',
      EylemKipi.yasak => 'Bu türde öneri hiç kaydedilmez.',
    };

/// "%30"
String eylemGuvenMetni(double guven) => '%${(guven * 100).round()}';

/// The payload as a person edits it: indented JSON.
String eylemYukMetni(Map<String, dynamic> yuk) => const JsonEncoder.withIndent('  ').convert(yuk);

/// Reads a payload the person typed. Null when it is not a JSON object.
Map<String, dynamic>? eylemYukCoz(String metin) {
  try {
    final cozulen = jsonDecode(metin);
    return cozulen is Map<String, dynamic> ? cozulen : null;
  } on FormatException {
    return null;
  }
}
