/// Upper case with Turkish rules: Dart's [String.toUpperCase] turns "i" into
/// "I" ("BITTI"); Turkish needs "İ" ("BİTTİ"), and "ı" stays "I".
String trBuyuk(String metin) => metin.replaceAll('i', 'İ').toUpperCase();

/// A file name (without ".md") made from a title: lower case, Turkish letters turned to plain ones, everything else
/// that is not a letter or digit becomes a single "-". Empty when the title has nothing to keep.
String dosyaAdiUret(String baslik) {
  const harita = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u'};
  final kucuk = baslik.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final duz = kucuk.split('').map((h) => harita[h] ?? h).join();
  final ad = duz.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return ad.length > 80 ? ad.substring(0, 80).replaceAll(RegExp(r'-+$'), '') : ad;
}
