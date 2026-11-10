import 'package:flutter/material.dart';

import '../../data/models/gun_gorunum.dart';
import '../gun/gun_view_model.dart';

/// "Bir kısmını devret" (K-0024): the day's open plan items and tasks with their estimates; what is ticked goes to tomorrow. The first
/// choice is a guess that clears the overflow: items from the end of the list until it fits.
Future<void> devretAc(BuildContext context, {required GunViewModel viewModel}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DevretSayfasi(viewModel: viewModel),
  );
}

/// The rows that count towards the load (plan items and tasks): the one carry-over takes both (sözleşme E2). A row not sent
/// yet has no id to carry.
List<Yapilacak> devredilecekler(GunGorunum gun) => gun.devredilebilir;

/// The kimlik set the sheet starts with.
Set<String> devretOnerisi(List<Yapilacak> adaylar, int asimDk) {
  final secili = <String>{};
  var toplam = 0;
  for (final o in adaylar.reversed) {
    if (toplam >= asimDk) break;
    secili.add(o.kimlik);
    toplam += o.tahminDk ?? 0;
  }
  return secili;
}

class DevretSayfasi extends StatefulWidget {
  const DevretSayfasi({super.key, required this.viewModel});

  final GunViewModel viewModel;

  @override
  State<DevretSayfasi> createState() => _DevretSayfasiState();
}

class _DevretSayfasiState extends State<DevretSayfasi> {
  late final List<Yapilacak> _adaylar = devredilecekler(widget.viewModel.gun!);
  late final Set<String> _secili = devretOnerisi(_adaylar, widget.viewModel.gun!.yuk.asimDk);

  int get _devredilenDk => _adaylar.where((o) => _secili.contains(o.kimlik)).fold<int>(0, (t, o) => t + (o.tahminDk ?? 0));

  Future<void> _devret() async {
    final nav = Navigator.of(context);
    await widget.viewModel.yarinaDevret([for (final o in _adaylar) if (_secili.contains(o.kimlik)) o]);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final asim = widget.viewModel.gun!.yuk.asimDk;
    final kalan = asim - _devredilenDk;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bir kısmını devret', style: tema.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            asim > 0
                ? '${sureMetni(asim)} fazla. Seçtiklerin yarına geçer.'
                : 'Seçtiklerin yarına geçer.',
            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          if (asim > 0 && _secili.isNotEmpty)
            Text(
              kalan > 0 ? 'Seçilenlerle de ${sureMetni(kalan)} fazla kalır.' : 'Seçilenlerle gün sığar.',
              key: const ValueKey('devret-durum'),
              style: tema.textTheme.bodySmall?.copyWith(color: kalan > 0 ? tema.colorScheme.error : tema.colorScheme.primary),
            ),
          const SizedBox(height: 8),
          if (_adaylar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Devredilecek iş yok.', textAlign: TextAlign.center, style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
            ),
          for (final o in _adaylar)
            CheckboxListTile(
              key: ValueKey('devret-${o.kimlik}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(o.baslik),
              subtitle: Text(o.tahminDk == null ? 'tahmin yok' : sureMetni(o.tahminDk!)),
              value: _secili.contains(o.kimlik),
              onChanged: (v) => setState(() => v == true ? _secili.add(o.kimlik) : _secili.remove(o.kimlik)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('devret-tamam'),
            onPressed: _secili.isEmpty ? null : _devret,
            child: Text(_secili.isEmpty ? 'Yarına devret' : 'Yarına devret (${_secili.length})'),
          ),
        ],
      ),
    );
  }
}
