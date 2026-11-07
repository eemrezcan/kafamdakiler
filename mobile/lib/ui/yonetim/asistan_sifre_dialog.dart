import 'package:flutter/material.dart';

import '../../utils/dogrulama.dart';

/// Asks the Sahip for the Asistan's new password. [gonder] sends it and returns
/// a message when it failed (shown in the dialog, which stays open) or null when
/// it worked (the dialog closes with `true`).
class AsistanSifreDialog extends StatefulWidget {
  const AsistanSifreDialog({super.key, required this.gonder});

  final Future<String?> Function(String yeniSifre) gonder;

  @override
  State<AsistanSifreDialog> createState() => _AsistanSifreDialogState();
}

class _AsistanSifreDialogState extends State<AsistanSifreDialog> {
  final _form = GlobalKey<FormState>();
  final _yeni = TextEditingController();
  final _tekrar = TextEditingController();
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void dispose() {
    _yeni.dispose();
    _tekrar.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (_gonderiliyor || !_form.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    final hata = await widget.gonder(_yeni.text);
    if (!mounted) return;
    if (hata == null) {
      navigator.pop(true);
      return;
    }
    setState(() {
      _gonderiliyor = false;
      _hata = hata;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: const Text('Asistan\'ın şifresini yenile'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Eski şifreyi bilmen gerekmez. Asistan\'ın oturumları kapanır; yeni şifreyle yeniden giriş yapması gerekir.',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yeni,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Yeni şifre'),
                validator: yeniSifreDogrula,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tekrar,
                obscureText: true,
                onFieldSubmitted: (_) => _gonder(),
                decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)'),
                validator: (v) => sifreTekrarDogrula(v, _yeni.text),
              ),
              if (_hata != null) ...[
                const SizedBox(height: 16),
                Text(_hata!, style: TextStyle(color: tema.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _gonderiliyor ? null : () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _gonderiliyor ? null : _gonder,
          child: _gonderiliyor
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Yenile'),
        ),
      ],
    );
  }
}
