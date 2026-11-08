import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/utils/eylem_gorunum.dart';

void main() {
  test('a Gmail reason splits into the quote and the mail link', () {
    final g = eylemGerekcesi("Gmail'den: «Sınav 17 Kasım 09:00»\nhttps://mail.google.com/mail/u/0/#inbox/18c2f0a9b7d4e1f3");
    expect(g.metin, "Gmail'den: «Sınav 17 Kasım 09:00»");
    expect(g.mail, Uri.parse('https://mail.google.com/mail/u/0/#inbox/18c2f0a9b7d4e1f3'));
  });

  test('anything else stays plain text, with no link', () {
    for (final gerekce in [
      'Sadece bir gerekçe',
      "Gmail'den: «x»\nhttps://kotu.example/mail/u/0/#inbox/abc",
      'https://mail.google.com/mail/u/0/#inbox/abc\nson satır başka',
    ]) {
      final g = eylemGerekcesi(gerekce);
      expect(g.mail, isNull, reason: gerekce);
      expect(g.metin, gerekce);
    }
  });

  test('a Gmail suggestion names its source', () => expect(eylemKaynakAdi('gmail'), 'Gmail'));
}
