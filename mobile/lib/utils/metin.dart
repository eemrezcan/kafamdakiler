/// Upper case with Turkish rules: Dart's [String.toUpperCase] turns "i" into
/// "I" ("BITTI"); Turkish needs "İ" ("BİTTİ"), and "ı" stays "I".
String trBuyuk(String metin) => metin.replaceAll('i', 'İ').toUpperCase();
