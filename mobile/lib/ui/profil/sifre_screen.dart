import 'package:flutter/material.dart';

import '../../utils/dogrulama.dart';
import '../core/widgets.dart';
import 'sifre_view_model.dart';

/// "Şifremi değiştir": the current password, the new one and the new one again.
class SifreScreen extends StatefulWidget {
  const SifreScreen({super.key, required this.viewModel});

  final SifreViewModel viewModel;

  @override
  State<SifreScreen> createState() => _SifreScreenState();
}

class _SifreScreenState extends State<SifreScreen> {
  final _form = GlobalKey<FormState>();
  final _mevcut = TextEditingController();
  final _yeni = TextEditingController();
  final _tekrar = TextEditingController();

  @override
  void dispose() {
    _mevcut.dispose();
    _yeni.dispose();
    _tekrar.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    // Taken before the wait, so no BuildContext crosses it.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final basarili = await widget.viewModel.degistir(mevcut: _mevcut.text, yeni: _yeni.text);
    if (!basarili || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Şifren değişti.')));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi değiştir')),
      body: OrtaGenislik(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final vm = widget.viewModel;
            return Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _mevcut,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Mevcut şifre'),
                    validator: mevcutSifreDogrula,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _yeni,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Yeni şifre'),
                    validator: yeniSifreDogrula,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tekrar,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _gonder(),
                    decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)'),
                    validator: (v) => sifreTekrarDogrula(v, _yeni.text),
                  ),
                  if (vm.hata != null) ...[
                    const SizedBox(height: 16),
                    Text(vm.hata!, style: TextStyle(color: tema.colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: vm.gonderiliyor ? null : _gonder,
                    child: vm.gonderiliyor
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Şifreyi değiştir'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
