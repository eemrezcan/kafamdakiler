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

/// What the brain writes for a task's state / priority, in words.
String gorevDurumuMetni(String? durum) => switch (durum) {
      'aktif' => 'Aktif',
      'bekliyor' => 'Bekliyor',
      'bitti' => 'Bitti',
      null => '',
      final d => d,
    };

String oncelikMetni(String? oncelik) => switch (oncelik) {
      'yuksek' => 'Yüksek öncelik',
      'orta' => 'Orta öncelik',
      'dusuk' => 'Düşük öncelik',
      null => '',
      final o => o,
    };
