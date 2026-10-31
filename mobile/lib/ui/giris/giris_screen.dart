import 'package:flutter/material.dart';

import 'giris_view_model.dart';

class GirisScreen extends StatefulWidget {
  const GirisScreen({super.key, required this.viewModel});

  final GirisViewModel viewModel;

  @override
  State<GirisScreen> createState() => _GirisScreenState();
}

class _GirisScreenState extends State<GirisScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _sifre = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    await widget.viewModel.girisYap(_email.text, _sifre.text);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  final vm = widget.viewModel;
                  return Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Kafamdakiler', style: tema.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Devam etmek için giriş yap.',
                          style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'E-posta'),
                          validator: (v) {
                            final metin = v?.trim() ?? '';
                            if (metin.isEmpty) return 'E-posta gerekli.';
                            if (!metin.contains('@')) return 'Geçerli bir e-posta yaz.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _sifre,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _gonder(),
                          decoration: const InputDecoration(labelText: 'Şifre'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Şifre gerekli.' : null,
                        ),
                        if (vm.hata != null) ...[
                          const SizedBox(height: 16),
                          Text(vm.hata!, style: TextStyle(color: tema.colorScheme.error)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: vm.yukleniyor ? null : _gonder,
                          child: vm.yukleniyor
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Giriş yap'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
