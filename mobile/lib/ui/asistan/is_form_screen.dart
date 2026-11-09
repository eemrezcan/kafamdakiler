import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/is_bildirimi.dart';
import '../core/widgets.dart';
import 'is_form_view_model.dart';

/// "Yeni kart": title, request, project or area, and the type. The card opens at the VPS (stage "talep"); the screen then
/// shows it.
class IsFormScreen extends StatefulWidget {
  const IsFormScreen({super.key, required this.viewModel});

  final IsFormViewModel viewModel;

  @override
  State<IsFormScreen> createState() => _IsFormScreenState();
}

class _IsFormScreenState extends State<IsFormScreen> {
  IsFormViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.projeleriYukle();
  }

  Future<void> _gonder() async {
    final kimlik = await _vm.gonder();
    if (kimlik != null && mounted) context.pushReplacement(isRotasi(kimlik));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni kart')),
      body: OrtaGenislik(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final tema = Theme.of(context);
            final soluk = TextStyle(color: tema.colorScheme.onSurfaceVariant);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                TextField(
                  key: const Key('is-baslik'),
                  maxLength: IsFormViewModel.enUzunBaslik,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Başlık', errorText: _vm.hatalar['baslik']),
                  onChanged: (v) => _vm.baslik = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('is-talep'),
                  minLines: 4,
                  maxLines: 8,
                  maxLength: IsFormViewModel.enUzunTalep,
                  decoration: InputDecoration(
                    labelText: 'Talep (isteğe bağlı)',
                    alignLabelWithHint: true,
                    helperText: 'Ne istediğini yaz; planı VPS çıkarır.',
                    errorText: _vm.hatalar['talep'],
                  ),
                  onChanged: (v) => _vm.talep = v,
                ),
                const SizedBox(height: 16),
                Text('Nerede', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Proje')),
                    ButtonSegment(value: false, label: Text('Alan')),
                  ],
                  selected: {_vm.projeModu},
                  onSelectionChanged: (s) => _vm.modSec(s.first),
                ),
                const SizedBox(height: 12),
                if (_vm.projeModu)
                  DropdownButtonFormField<String>(
                    key: const Key('is-proje'),
                    initialValue: _vm.proje,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Proje',
                      errorText: _vm.hatalar['proje'],
                      helperText: _vm.projeler.isEmpty ? 'Telefonda proje listesi yok. İnternet varken ekranı yeniden aç.' : null,
                    ),
                    items: [
                      for (final p in _vm.projeler) DropdownMenuItem(value: p.kimlik, child: Text(p.baslik, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _vm.projeSec,
                  )
                else
                  TextField(
                    key: const Key('is-alan'),
                    decoration: InputDecoration(
                      labelText: 'Alan',
                      helperText: 'ör. ogrenme (küçük harf, rakam, tire)',
                      errorText: _vm.hatalar['alan'],
                    ),
                    onChanged: (v) => _vm.alan = v,
                  ),
                const SizedBox(height: 16),
                Text('Tip', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kod', label: Text('Kod')),
                    ButtonSegment(value: 'genel', label: Text('Genel')),
                  ],
                  selected: {_vm.tip},
                  onSelectionChanged: (s) => _vm.tipSec(s.first),
                ),
                const SizedBox(height: 4),
                Text(
                  _vm.tip == 'kod' ? 'Kod: kod, push ve deploy onayı ister.' : 'Genel: kapı yok; plan, karar, yapım, bitti.',
                  style: soluk,
                ),
                if (_vm.genelHata != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_vm.genelHata!, style: TextStyle(color: tema.colorScheme.error)),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _vm.gonderiliyor ? null : _gonder,
                  child: Text(_vm.gonderiliyor ? 'Açılıyor…' : 'Kartı aç'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
