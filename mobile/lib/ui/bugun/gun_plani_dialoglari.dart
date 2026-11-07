import 'package:flutter/material.dart';

import '../../data/models/beyin.dart';
import '../../utils/aliskanlik_gunu.dart';

/// One-line text questions of the plan card (new item, note). Returns the trimmed text, or null when cancelled or empty.
Future<String?> gunPlaniMetinDialogu(
  BuildContext context, {
  required String baslik,
  required String ipucu,
  String onay = 'Ekle',
  int enCok = 300,
}) async {
  final metin = await showDialog<String>(
    context: context,
    builder: (context) => _MetinDialogu(baslik: baslik, ipucu: ipucu, onay: onay, enCok: enCok),
  );
  final temiz = metin?.trim();
  return temiz == null || temiz.isEmpty ? null : temiz;
}

/// Owns its text controller, so it is disposed only after the dialog has finished closing.
class _MetinDialogu extends StatefulWidget {
  const _MetinDialogu({required this.baslik, required this.ipucu, required this.onay, required this.enCok});

  final String baslik;
  final String ipucu;
  final String onay;
  final int enCok;

  @override
  State<_MetinDialogu> createState() => _MetinDialoguState();
}

class _MetinDialoguState extends State<_MetinDialogu> {
  final _denetleyici = TextEditingController();

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.baslik),
      content: TextField(
        controller: _denetleyici,
        autofocus: true,
        maxLength: widget.enCok,
        decoration: InputDecoration(hintText: widget.ipucu),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, _denetleyici.text), child: Text(widget.onay)),
      ],
    );
  }
}

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
              TextButton(onPressed: _gunSec, child: Text(_bitis == null ? 'Bitiş günü seç' : 'Bitiş: ${tarihMetni(_bitis!)}')),
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
