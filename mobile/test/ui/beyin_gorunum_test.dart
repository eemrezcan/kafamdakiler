import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/ui/core/beyin_gorunum.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  group('zamanMetni', () {
    final simdi = DateTime(2026, 11, 8);

    test('a time the brain writes reads as words', () {
      expect(zamanMetni('2026-11-03 09:15', simdi: simdi), '3 Kas 09:15');
      expect(zamanMetni('2026-11-03T18:40:00', simdi: simdi), '3 Kas 18:40');
      expect(zamanMetni('2026-11-03', simdi: simdi), '3 Kas');
    });

    test('another year is named; anything else comes back as it is', () {
      expect(zamanMetni('2025-12-31 23:00', simdi: simdi), '31 Ara 2025 23:00');
      expect(zamanMetni('dün akşam', simdi: simdi), 'dün akşam');
    });
  });

  group('projeMetni', () {
    const adlar = {'kitap-kulubu': 'Kitap Kulübü Sitesi'};

    test('a path or an id becomes the project title when it is known', () {
      expect(projeMetni('projects/kitap-kulubu', adlar), 'Kitap Kulübü Sitesi');
      expect(projeMetni('projects/kitap-kulubu/notlar', adlar), 'Kitap Kulübü Sitesi');
      expect(projeMetni('kitap-kulubu', adlar), 'Kitap Kulübü Sitesi');
    });

    test('an unknown one still reads as words', () {
      expect(projeMetni('projects/balkon-bahcesi', adlar), 'Balkon bahcesi');
    });
  });

  test('task states read as words, an unknown one starts with a capital', () {
    expect(gorevDurumuMetni('engelli'), 'Engelli');
    expect(gorevDurumuMetni('askida'), 'Askida');
    expect(gorevDurumuMetni(null), '');
  });
}
