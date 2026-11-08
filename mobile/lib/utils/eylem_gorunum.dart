import 'dart:convert';

import '../data/models/eylem.dart';

// Display texts of the approval queue screens, in one place (the web has the same words in EylemGorunum.cs).

String eylemKaynakAdi(String kaynak) => switch (kaynak) {
      'kullanici' => 'Sen',
      'ses' => 'Ses',
      'gelen' => 'Gelen kutusu',
      'brifing' => 'Brifing',
      'mail' => 'Mail',
      'gmail' => 'Gmail',
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

/// A Gmail suggestion ends its reason with a link to the mail on the last line (after a one-line quote). The screens show the quote and
/// a "Mailde aç" button instead of the raw address; only a link of exactly that shape is taken.
({String metin, Uri? mail}) eylemGerekcesi(String gerekce) {
  final son = gerekce.lastIndexOf('\n');
  final sonSatir = (son >= 0 ? gerekce.substring(son + 1) : gerekce).trim();
  if (!_mailBaglantisi.hasMatch(sonSatir)) return (metin: gerekce, mail: null);
  return (metin: son >= 0 ? gerekce.substring(0, son).trimRight() : '', mail: Uri.parse(sonSatir));
}

final _mailBaglantisi = RegExp(r'^https://mail\.google\.com/mail/u/0/#inbox/[A-Za-z0-9]{1,64}$');
