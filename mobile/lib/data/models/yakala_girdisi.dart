/// What the capture screen starts with when it is opened from outside the app
/// (the Android share menu or the app shortcut). All fields empty = a plain
/// "open Yakala" request (the shortcut).
class YakalaGirdisi {
  const YakalaGirdisi({this.metin, this.fotografYolu, this.cokluGorsel = false});

  /// Shared text or link, to be edited in the text field.
  final String? metin;

  /// Local path of the shared image, to be shown in the photo area.
  final String? fotografYolu;

  /// More than one image was shared; only the first is used.
  final bool cokluGorsel;

  /// A plain "open Yakala" request (shortcut or home screen widget): nothing to fill in.
  bool get bos => metin == null && fotografYolu == null;
}

enum PaylasimTuru { metin, gorsel, diger }

/// One shared item, free of the sharing plugin's types so the conversion can be tested.
class PaylasimOgesi {
  const PaylasimOgesi(this.tur, this.deger);

  final PaylasimTuru tur;

  /// The text, or the file path of the image.
  final String deger;
}

/// Turns what was shared into the capture screen's starting state, or null
/// when nothing usable was shared (a video or another file type, empty text).
YakalaGirdisi? paylasimdanGirdi(List<PaylasimOgesi> ogeler) {
  final metinler = [
    for (final o in ogeler)
      if (o.tur == PaylasimTuru.metin && o.deger.trim().isNotEmpty) o.deger.trim(),
  ];
  final gorseller = [
    for (final o in ogeler)
      if (o.tur == PaylasimTuru.gorsel && o.deger.isNotEmpty) o.deger,
  ];
  if (metinler.isEmpty && gorseller.isEmpty) return null;
  return YakalaGirdisi(
    metin: metinler.isEmpty ? null : metinler.join('\n'),
    fotografYolu: gorseller.isEmpty ? null : gorseller.first,
    cokluGorsel: gorseller.length > 1,
  );
}

/// The `type` of the "Yakala" app shortcut; the home screen widget sends the same one.
const yakalaKisayoluTuru = 'yakala';

/// The starting state for a tapped shortcut, or null for an unknown type.
YakalaGirdisi? kisayolGirdisi(String tur) => tur == yakalaKisayoluTuru ? const YakalaGirdisi() : null;
