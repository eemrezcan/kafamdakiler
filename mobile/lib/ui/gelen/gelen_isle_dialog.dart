import 'package:flutter/material.dart';

import '../../data/models/beyin.dart';
import '../../data/models/gelen.dart';

/// The hand-made placement of a card: a folder from the pick list, a file name, a title and the tags. The server checks
/// the path and the tags again; a refusal shows up as a refused entry in the sending queue.
/// With [secenekler] (from the server) the folder and the tags are picked from lists; without them (offline, no
/// permission) the cached projects and a typed tag field stand in.
/// Returns the placement, or null when cancelled.
Future<GelenIsleGirdi?> gelenIsleDialogGoster(
  BuildContext context, {
  required GelenKarti kart,
  required List<ProjeOzet> projeler,
  GelenSecenekleri? secenekler,
}) {
  return showDialog<GelenIsleGirdi>(
    context: context,
    builder: (_) => _GelenIsleDialog(kart: kart, projeler: projeler, secenekler: secenekler),
  );
}

class _GelenIsleDialog extends StatefulWidget {
  const _GelenIsleDialog({required this.kart, required this.projeler, this.secenekler});

  final GelenKarti kart;
  final List<ProjeOzet> projeler;
  final GelenSecenekleri? secenekler;

  @override
  State<_GelenIsleDialog> createState() => _GelenIsleDialogState();
}

class _GelenIsleDialogState extends State<_GelenIsleDialog> {
  static const _kokler = ['ogrenme/', 'spor/', 'aliskanliklar/'];

  late final TextEditingController _dosya = TextEditingController();
  late final TextEditingController _baslik = TextEditingController(text: widget.kart.ozet);
  late final TextEditingController _etiketler = TextEditingController();
  final Set<String> _secilenEtiketler = {};
  String? _hata;

  /// The folder choices as (path, label): the server's list, or the cached projects plus the fixed roots.
  late final List<(String, String)> _klasorler = widget.secenekler != null && widget.secenekler!.klasorler.isNotEmpty
      ? [for (final k in widget.secenekler!.klasorler) (k.yol, k.tur == 'proje' ? '${k.ad} (notlar)' : k.ad)]
      : [
          for (final p in widget.projeler) ('projects/${p.kimlik}/notlar/', '${p.baslik} (notlar)'),
          for (final k in _kokler) (k, k),
        ];
  late String _klasor = _klasorler.first.$1;

  bool get _etiketSecici => widget.secenekler != null && widget.secenekler!.etiketler.isNotEmpty;

  @override
  void dispose() {
    _dosya.dispose();
    _baslik.dispose();
    _etiketler.dispose();
    super.dispose();
  }

  void _yerlestir() {
    final ad = _dosya.text.trim();
    final baslik = _baslik.text.trim();
    final etiketler = _etiketSecici
        ? _secilenEtiketler.toList()
        : [
            for (final e in _etiketler.text.split(RegExp(r'[,\s]+')))
              if (e.trim().isNotEmpty) e.trim().replaceFirst(RegExp(r'^#'), ''),
          ];
    if (ad.isEmpty || baslik.isEmpty || etiketler.isEmpty) {
      setState(() => _hata = 'Dosya adı, başlık ve en az bir etiket gerekli.');
      return;
    }
    Navigator.pop(context, GelenIsleGirdi(yol: '$_klasor${ad.endsWith('.md') ? ad : '$ad.md'}', baslik: baslik, etiketler: etiketler));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elle yerleştir'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _klasor,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Klasör'),
              items: [for (final (deger, ad) in _klasorler) DropdownMenuItem(value: deger, child: Text(ad, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _klasor = v ?? _klasor),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dosya,
              decoration: const InputDecoration(labelText: 'Dosya adı', hintText: 'ornek-not'),
              autocorrect: false,
              maxLength: 100,
            ),
            TextField(
              controller: _baslik,
              decoration: const InputDecoration(labelText: 'Başlık'),
              maxLength: 200,
            ),
            if (_etiketSecici) ...[
              const SizedBox(height: 8),
              const Text('Etiketler'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in widget.secenekler!.etiketler)
                    FilterChip(
                      label: Text(e.ad),
                      tooltip: e.esler.isEmpty ? null : 'Eş: ${e.esler.join(', ')}',
                      selected: _secilenEtiketler.contains(e.ad),
                      onSelected: (secili) => setState(() => secili ? _secilenEtiketler.add(e.ad) : _secilenEtiketler.remove(e.ad)),
                    ),
                ],
              ),
            ] else
              TextField(
                controller: _etiketler,
                decoration: const InputDecoration(labelText: 'Etiketler', hintText: 'kaynak, okul', helperText: 'Virgülle ayır; etiket sözlükte olmalı.'),
                autocorrect: false,
              ),
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _yerlestir, child: const Text('Yerleştir')),
      ],
    );
  }
}
