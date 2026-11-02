import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/oge.dart';
import '../../utils/dogrulama.dart';
import '../core/widgets.dart';
import 'kronometre_gosterge.dart';
import 'oturum_view_model.dart';

enum _Faz { kronometre, form }

/// Stopwatch ("Başla" / "Bitir") followed by "Nereye kadar geldin?", or the
/// manual form without a stopwatch.
class OturumScreen extends StatefulWidget {
  const OturumScreen({super.key, required this.viewModel});

  final OturumViewModel viewModel;

  @override
  State<OturumScreen> createState() => _OturumScreenState();
}

class _OturumScreenState extends State<OturumScreen> {
  final _form = GlobalKey<FormState>();
  final _konum = TextEditingController();
  final _dakika = TextEditingController();
  _Faz _faz = _Faz.kronometre;
  bool _kaydediliyor = false;

  OturumViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _konum.dispose();
    _dakika.dispose();
    super.dispose();
  }

  void _bitir() {
    _dakika.text = _vm.kronometre.dakika.toString();
    setState(() => _faz = _Faz.form);
  }

  void _elleGir() => setState(() => _faz = _Faz.form);

  /// Throws the running stopwatch away; no session is written.
  Future<void> _vazgec() async {
    await _vm.kronometre.sifirla();
    if (mounted) context.pop();
  }

  Future<void> _kaydet() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _kaydediliyor = true);
    await _vm.kaydet(sayiCoz(_konum.text)!, dakika: int.tryParse(_dakika.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final oge = _vm.oge;
        return Scaffold(
          appBar: AppBar(title: Text(oge?.ad ?? 'Oturum')),
          body: OrtaGenislik(
            maxGenislik: 480,
            child: _govde(context, oge),
          ),
        );
      },
    );
  }

  Widget _govde(BuildContext context, Oge? oge) {
    if (_vm.yukleniyor && oge == null) return const Center(child: CircularProgressIndicator());
    if (oge == null) {
      return BosDurum(metin: _vm.hata ?? 'Öğe bulunamadı.', dugme: 'Tekrar dene', onPressed: _vm.yukle);
    }
    // A stopwatch that was already running when the screen opened keeps going
    // (the view model reloaded its start instant).
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _faz == _Faz.kronometre ? _kronometre(oge) : _formu(context, oge),
    );
  }

  Widget _kronometre(Oge oge) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(oge.ad, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        if (oge.altBaslik != null) Text(oge.altBaslik!, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        KronometreGosterge(viewModel: _vm.kronometre, onBitir: _bitir, onVazgec: _vazgec),
        const SizedBox(height: 24),
        if (!_vm.kronometre.calisiyor)
          TextButton(onPressed: _elleGir, child: const Text('Kronometresiz, elle gir')),
      ],
    );
  }

  Widget _formu(BuildContext context, Oge oge) {
    final tema = Theme.of(context);
    final toplam = oge.toplam;
    return Form(
      key: _form,
      child: ListView(
        children: [
          Text('Nereye kadar geldin?', style: tema.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Başlangıç: ${sayiMetni(oge.guncelKonum)}'
            '${toplam != null ? ' · Toplam: ${sayiMetni(toplam)}' : ''}',
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _konum,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(labelText: 'Bitiş konumu'),
            validator: (v) => konumDogrula(v, baslangic: oge.guncelKonum, toplam: toplam),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _dakika,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Süre (dakika, isteğe bağlı)'),
            validator: dakikaDogrula,
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _kaydediliyor ? null : _kaydet,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
