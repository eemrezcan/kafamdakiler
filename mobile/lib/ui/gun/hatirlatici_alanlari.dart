import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/enums.dart';
import '../../data/models/gun_gorunum.dart';
import '../../data/models/hatirlatici.dart';

/// The reminder as the forms edit it: hour, repeat, weekdays of a weekly repeat, "days before", urgent and nagging. The same
/// fields serve the "yeni yapılacak" form and the reminder of a row (K-0024).
@immutable
class HatirlaticiTaslagi {
  const HatirlaticiTaslagi({
    this.saat,
    this.tekrar = Tekrar.yok,
    this.gunler = const {},
    this.acil = false,
    this.israrli = false,
    this.onceGun = 0,
  });

  /// The draft of an existing reminder summary (editing a row's reminder).
  factory HatirlaticiTaslagi.ozetten(HatirlaticiOzet? o) {
    if (o == null) return const HatirlaticiTaslagi();
    final saat = o.saat == null ? null : Saat.coz(o.saat!);
    return HatirlaticiTaslagi(
      saat: saat == null ? null : TimeOfDay(hour: saat.saat, minute: saat.dakika),
      tekrar: o.tekrar,
      gunler: {...?o.gunler},
      acil: o.acil,
      israrli: o.israrli,
      onceGun: o.onceGun,
    );
  }

  final TimeOfDay? saat;
  final Tekrar tekrar;
  final Set<HaftaGunu> gunler;
  final bool acil;
  final bool israrli;
  final int onceGun;

  HatirlaticiTaslagi kopya({
    TimeOfDay? saat,
    bool saatTemizle = false,
    Tekrar? tekrar,
    Set<HaftaGunu>? gunler,
    bool? acil,
    bool? israrli,
    int? onceGun,
  }) =>
      HatirlaticiTaslagi(
        saat: saatTemizle ? null : (saat ?? this.saat),
        tekrar: tekrar ?? this.tekrar,
        gunler: gunler ?? this.gunler,
        acil: acil ?? this.acil,
        israrli: israrli ?? this.israrli,
        onceGun: onceGun ?? this.onceGun,
      );

  /// The wire form. The weekdays go only with a weekly repeat, in the week's order.
  HatirlaticiGovde govde() => HatirlaticiGovde(
        saat: saat == null ? null : Saat(saat!.hour, saat!.minute).kisa,
        tekrar: tekrar,
        gunler: tekrar == Tekrar.haftalik && gunler.isNotEmpty ? [for (final g in HaftaGunu.values) if (gunler.contains(g)) g] : null,
        acil: acil,
        israrli: israrli,
        onceGun: onceGun,
      );
}

const _gunAdlari = {
  HaftaGunu.pzt: 'Pzt',
  HaftaGunu.sal: 'Sal',
  HaftaGunu.car: 'Çar',
  HaftaGunu.per: 'Per',
  HaftaGunu.cum: 'Cum',
  HaftaGunu.cmt: 'Cmt',
  HaftaGunu.paz: 'Paz',
};

const _tekrarAdlari = {
  Tekrar.yok: 'Tek sefer',
  Tekrar.gunluk: 'Her gün',
  Tekrar.haftalik: 'Haftalık',
  Tekrar.aylik: 'Aylık',
  Tekrar.yillik: 'Yıllık',
};

/// "her gün", "her salı, perşembe", for a row's meta line.
String tekrarMetni(HatirlaticiOzet h) {
  switch (h.tekrar) {
    case Tekrar.yok:
      return '';
    case Tekrar.gunluk:
      return 'her gün';
    case Tekrar.haftalik:
      final g = h.gunler;
      return g == null || g.isEmpty ? 'her hafta' : 'haftalık ${g.map((x) => _gunAdlari[x]).join(', ')}';
    case Tekrar.aylik:
      return 'her ay';
    case Tekrar.yillik:
      return 'her yıl';
  }
}

/// The reminder's fields. [onDegisti] gets the changed draft; the owner keeps it in its state.
class HatirlaticiAlanlari extends StatelessWidget {
  const HatirlaticiAlanlari({super.key, required this.taslak, required this.onDegisti, this.varsayilanSaat});

  final HatirlaticiTaslagi taslak;
  final ValueChanged<HatirlaticiTaslagi> onDegisti;

  /// What "Saat" shows while none is chosen (the row's own hour); without it the server's morning hour applies.
  final String? varsayilanSaat;

  Future<void> _saatSec(BuildContext context) async {
    final simdi = taslak.saat ?? const TimeOfDay(hour: 9, minute: 0);
    final secilen = await showTimePicker(context: context, initialTime: simdi, helpText: 'Hatırlatma saati');
    if (secilen != null) onDegisti(taslak.kopya(saat: secilen));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final saatMetni = taslak.saat == null
        ? (varsayilanSaat ?? 'Sabah 09:00')
        : Saat(taslak.saat!.hour, taslak.saat!.minute).kisa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const ValueKey('hatirlatici-saat'),
          contentPadding: EdgeInsets.zero,
          minTileHeight: 48,
          leading: const Icon(LucideIcons.clock),
          title: const Text('Saat'),
          trailing: Text(saatMetni, style: tema.textTheme.titleMedium),
          onTap: () => _saatSec(context),
        ),
        Text('Ne zaman hatırlatsın?', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (gun, ad) in [(0, 'Saatinde'), (1, '1 gün önce'), (2, '2 gün önce')])
              ChoiceChip(
                key: ValueKey('once-$gun'),
                label: Text(ad),
                selected: taslak.onceGun == gun,
                onSelected: (_) => onDegisti(taslak.kopya(onceGun: gun)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Tekrar', style: tema.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in Tekrar.values)
              ChoiceChip(
                key: ValueKey('tekrar-${t.name}'),
                label: Text(_tekrarAdlari[t]!),
                selected: taslak.tekrar == t,
                onSelected: (_) => onDegisti(taslak.kopya(tekrar: t)),
              ),
          ],
        ),
        if (taslak.tekrar == Tekrar.haftalik) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final g in HaftaGunu.values)
                FilterChip(
                  key: ValueKey('gun-${g.name}'),
                  label: Text(_gunAdlari[g]!),
                  selected: taslak.gunler.contains(g),
                  onSelected: (acik) => onDegisti(taslak.kopya(gunler: acik ? {...taslak.gunler, g} : ({...taslak.gunler}..remove(g)))),
                ),
            ],
          ),
        ],
        SwitchListTile(
          key: const ValueKey('hatirlatici-acil'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Acil'),
          subtitle: const Text('Sessiz kipi deler'),
          value: taslak.acil,
          onChanged: (v) => onDegisti(taslak.kopya(acil: v)),
        ),
        SwitchListTile(
          key: const ValueKey('hatirlatici-israrli'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Israrlı'),
          subtitle: const Text('Yapılana kadar tekrarlar'),
          value: taslak.israrli,
          onChanged: (v) => onDegisti(taslak.kopya(israrli: v)),
        ),
      ],
    );
  }
}
