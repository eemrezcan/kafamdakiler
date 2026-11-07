import 'package:flutter/material.dart';

import '../../data/models/beyin.dart';
import '../../data/models/gelen.dart';

/// The hand-made placement of a card: a folder from the pick list, a file name, a title and the tags. The server checks
/// the path and the tags again; a refusal shows up as a refused entry in the sending queue.
/// Returns the placement, or null when cancelled.
Future<GelenIsleGirdi?> gelenIsleDialogGoster(BuildContext context, {required GelenKarti kart, required List<ProjeOzet> projeler}) {
  return showDialog<GelenIsleGirdi>(
    context: context,
    builder: (_) => _GelenIsleDialog(kart: kart, projeler: projeler),
  );
}

class _GelenIsleDialog extends StatefulWidget {
  const _GelenIsleDialog({required this.kart, required this.projeler});

  final GelenKarti kart;
  final List<ProjeOzet> projeler;

  @override
  State<_GelenIsleDialog> createState() => _GelenIsleDialogState();
}

class _GelenIsleDialogState extends State<_GelenIsleDialog> {
  static const _kokler = ['ogrenme/', 'spor/', 'aliskanliklar/'];

  late final TextEditingController _dosya = TextEditingController();
  late final TextEditingController _baslik = TextEditingController(text: widget.kart.ozet);
  late final TextEditingController _etiketler = TextEditingController();
  late String _klasor = widget.projeler.isNotEmpty ? 'projects/${widget.projeler.first.kimlik}/notlar/' : _kokler.first;
  String? _hata;

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
    final etiketler = [
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
    final secenekler = <(String, String)>[
      for (final p in widget.projeler) ('projects/${p.kimlik}/notlar/', '${p.baslik} (notlar)'),
      for (final k in _kokler) (k, k),
    ];
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
              items: [for (final (deger, ad) in secenekler) DropdownMenuItem(value: deger, child: Text(ad, overflow: TextOverflow.ellipsis))],
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
