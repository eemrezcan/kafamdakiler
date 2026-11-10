import 'package:flutter/material.dart';

import '../../data/models/beyin.dart';
import '../core/beyin_gorunum.dart';

/// The new-task form: a title, a project and an optional due day.
typedef YeniGorev = ({String baslik, String proje, DateTime? bitis});

Future<YeniGorev?> gorevEkleDialogu(BuildContext context, List<ProjeOzet> projeler) {
  return showDialog<YeniGorev>(
    context: context,
    builder: (context) => _GorevEkleDialogu(projeler: projeler),
  );
}

class _GorevEkleDialogu extends StatefulWidget {
  const _GorevEkleDialogu({required this.projeler});

  final List<ProjeOzet> projeler;

  @override
  State<_GorevEkleDialogu> createState() => _GorevEkleDialoguState();
}

class _GorevEkleDialoguState extends State<_GorevEkleDialogu> {
  final _baslik = TextEditingController();
  String? _proje;
  DateTime? _bitis;

  @override
  void initState() {
    super.initState();
    _proje = widget.projeler.isEmpty ? null : widget.projeler.first.kimlik;
  }

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  Future<void> _gunSec() async {
    final simdi = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: _bitis ?? simdi,
      firstDate: simdi.subtract(const Duration(days: 365)),
      lastDate: simdi.add(const Duration(days: 365 * 3)),
    );
    if (secilen != null) setState(() => _bitis = DateTime.utc(secilen.year, secilen.month, secilen.day));
  }

  @override
  Widget build(BuildContext context) {
    final gonderilebilir = _baslik.text.trim().isNotEmpty && _proje != null;
    return AlertDialog(
      title: const Text('Görev ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _baslik,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Görev'),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          if (widget.projeler.isEmpty)
            const Text('Proje listesi telefonda yok; bağlantı gelince bir kez açılıp yenilenir.')
          else
            DropdownButtonFormField<String>(
              initialValue: _proje,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Proje'),
              items: [for (final p in widget.projeler) DropdownMenuItem(value: p.kimlik, child: Text(p.baslik))],
              onChanged: (v) => setState(() => _proje = v),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(onPressed: _gunSec, child: Text(_bitis == null ? 'Bitiş günü seç' : 'Bitiş: ${uzunTarih(_bitis!)}')),
              if (_bitis != null) IconButton(tooltip: 'Bitişi kaldır', onPressed: () => setState(() => _bitis = null), icon: const Icon(Icons.close)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: gonderilebilir ? () => Navigator.pop(context, (baslik: _baslik.text.trim(), proje: _proje!, bitis: _bitis)) : null,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

/// "How many days?" for splitting a task over days; null when cancelled.
Future<int?> gunlereBolDialogu(BuildContext context, String gorev, {int enCok = 14}) {
  return showDialog<int>(
    context: context,
    builder: (context) {
      var gun = 2;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Günlere böl'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gorev),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kaç güne'),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Azalt',
                        onPressed: gun > 1 ? () => setState(() => gun--) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$gun'),
                      IconButton(
                        tooltip: 'Artır',
                        onPressed: gun < enCok ? () => setState(() => gun++) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              const Text(
                'Görünen günden başlar; her güne bir madde yazılır. Görev yalnız son günün maddesine bağlanır, o madde yapılınca görev biter.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, gun), child: const Text('Böl')),
          ],
        ),
      );
    },
  );
}
