import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/metin.dart';

/// Small upper-case section label, like the date headings of the captures list.
class BolumBasligi extends StatelessWidget {
  const BolumBasligi(this.metin, {super.key, this.ustBosluk = 20});

  final String metin;
  final double ustBosluk;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, ustBosluk, 4, 8),
      child: Text(
        trBuyuk(metin),
        style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8),
      ),
    );
  }
}

/// "45 dk", "2 sa", "1 sa 30 dk".
String dakikaMetni(int dakika) {
  if (dakika < 60) return '$dakika dk';
  final saat = dakika ~/ 60;
  final kalan = dakika % 60;
  return kalan == 0 ? '$saat sa' : '$saat sa $kalan dk';
}

/// "10 Kas" for a due date.
String kisaTarih(DateTime tarih) => DateFormat('d MMM', 'tr').format(tarih);

/// "10 Kasım Salı" for a day the user picks or reads in full.
String uzunTarih(DateTime tarih) => DateFormat('d MMMM EEEE', 'tr').format(tarih);

/// A time the brain or the API writes as text ("2026-11-03 09:15", "2026-11-03T09:15", "2026-11-03") in words:
/// "3 Kas 09:15", with the year only when it is not this year. Anything it cannot read comes back as it is.
String zamanMetni(String ham, {DateTime? simdi}) {
  final eslesme = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?').firstMatch(ham.trim());
  if (eslesme == null) return ham;
  final yil = int.parse(eslesme[1]!);
  final tarih = DateTime(yil, int.parse(eslesme[2]!), int.parse(eslesme[3]!));
  final gun = DateFormat(yil == (simdi ?? DateTime.now()).year ? 'd MMM' : 'd MMM y', 'tr').format(tarih);
  return eslesme[4] == null ? gun : '$gun ${eslesme[4]}:${eslesme[5]}';
}

/// A brain path or project id ("projects/kitap-kulubu", "kitap-kulubu") as the project's title when [adlar] knows it,
/// otherwise as readable words ("Kitap kulubu").
String projeMetni(String yolYaDaKimlik, Map<String, String> adlar) {
  final parcalar = yolYaDaKimlik.split('/').where((p) => p.isNotEmpty).toList();
  final kimlik = parcalar.length >= 2 && parcalar.first == 'projects' ? parcalar[1] : (parcalar.isEmpty ? '' : parcalar.last);
  if (adlar[kimlik] case final ad?) return ad;
  final duz = kimlik.replaceAll('-', ' ');
  return duz.isEmpty ? yolYaDaKimlik : duz.replaceFirst(duz[0], duz[0].toUpperCase());
}

/// What the brain writes for a task's state / priority, in words.
String gorevDurumuMetni(String? durum) => switch (durum) {
      'aktif' => 'Aktif',
      'bekliyor' => 'Bekliyor',
      'engelli' => 'Engelli',
      'bitti' => 'Bitti',
      null || '' => '',
      final d => d.replaceFirst(d[0], d[0].toUpperCase()),
    };

String oncelikMetni(String? oncelik) => switch (oncelik) {
      'yuksek' => 'Yüksek öncelik',
      'orta' => 'Orta öncelik',
      'dusuk' => 'Düşük öncelik',
      null => '',
      final o => o,
    };
