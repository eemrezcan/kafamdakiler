import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/gun_gorunum.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/gun_repository.dart';

/// "Gün kapasitesi": how long a day holds on weekdays and at the weekend (sözleşme §5). The day load on Bugün and Takvim is
/// measured against it. The change is kept on the phone at once and sent when there is a connection.
Future<void> kapasiteAc(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _KapasiteSayfasi(),
  );
}

class _KapasiteSayfasi extends StatefulWidget {
  const _KapasiteSayfasi();

  @override
  State<_KapasiteSayfasi> createState() => _KapasiteSayfasiState();
}

class _KapasiteSayfasiState extends State<_KapasiteSayfasi> {
  static const _adim = 30;
  static const _enCok = 16 * 60;

  GunAyari? _ayar;

  @override
  void initState() {
    super.initState();
    context.read<GunRepository>().gunAyari().then((a) {
      if (mounted) setState(() => _ayar = a);
    });
  }

  Future<void> _kaydet() async {
    final repo = context.read<GunRepository>();
    final esitleyici = context.read<Esitleyici>();
    final nav = Navigator.of(context);
    await repo.gunAyariYaz(_ayar!);
    esitleyici.gonder();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ayar = _ayar;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gün kapasitesi', style: tema.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Bir günde ne kadar iş yapabileceğini söyle; gün yükü buna göre ölçülür.',
            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (ayar == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else ...[
            _Adimlayici(
              anahtar: 'hafta-ici',
              baslik: 'Hafta içi',
              dakika: ayar.haftaIciDk,
              onDegisti: (d) => setState(() => _ayar = GunAyari(haftaIciDk: d.clamp(0, _enCok), haftaSonuDk: _ayar!.haftaSonuDk)),
              adim: _adim,
            ),
            _Adimlayici(
              anahtar: 'hafta-sonu',
              baslik: 'Hafta sonu',
              dakika: ayar.haftaSonuDk,
              onDegisti: (d) => setState(() => _ayar = GunAyari(haftaIciDk: _ayar!.haftaIciDk, haftaSonuDk: d.clamp(0, _enCok))),
              adim: _adim,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(key: const ValueKey('kapasite-kaydet'), onPressed: _kaydet, child: const Text('Kaydet')),
            ),
          ],
        ],
      ),
    );
  }
}

class _Adimlayici extends StatelessWidget {
  const _Adimlayici({required this.anahtar, required this.baslik, required this.dakika, required this.onDegisti, required this.adim});

  final String anahtar;
  final String baslik;
  final int dakika;
  final ValueChanged<int> onDegisti;
  final int adim;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(baslik, style: tema.textTheme.titleMedium)),
        IconButton(
          key: ValueKey('$anahtar-azalt'),
          tooltip: '$baslik, azalt',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.minus),
          onPressed: dakika <= 0 ? null : () => onDegisti(dakika - adim),
        ),
        SizedBox(
          width: 84,
          child: Text(sureMetni(dakika), textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
        ),
        IconButton(
          key: ValueKey('$anahtar-arttir'),
          tooltip: '$baslik, arttır',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.plus),
          onPressed: () => onDegisti(dakika + adim),
        ),
      ],
    );
  }
}
