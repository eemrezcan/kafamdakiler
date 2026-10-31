import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/dogrulama.dart';

/// Asks for a number (a day's total). Returns null when cancelled.
Future<double?> sayiGirisDialogu(
  BuildContext context, {
  required String baslik,
  required double mevcut,
  String? birim,
}) {
  return showDialog<double>(
    context: context,
    builder: (context) => _SayiGirisDialogu(baslik: baslik, mevcut: mevcut, birim: birim),
  );
}

class _SayiGirisDialogu extends StatefulWidget {
  const _SayiGirisDialogu({required this.baslik, required this.mevcut, this.birim});

  final String baslik;
  final double mevcut;
  final String? birim;

  @override
  State<_SayiGirisDialogu> createState() => _SayiGirisDialoguState();
}

class _SayiGirisDialoguState extends State<_SayiGirisDialogu> {
  final _form = GlobalKey<FormState>();
  late final _denetleyici = TextEditingController(text: sayiMetni(widget.mevcut));

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  void _tamam() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, sayiCoz(_denetleyici.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.baslik),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _denetleyici,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(labelText: 'Bugünkü toplam', suffixText: widget.birim),
          validator: (v) {
            final s = sayiCoz(v);
            if (s == null) return 'Bir sayı yaz.';
            if (s < 0) return '0 ya da daha büyük olmalı.';
            return null;
          },
          onFieldSubmitted: (_) => _tamam(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _tamam, child: const Text('Kaydet')),
      ],
    );
  }
}
