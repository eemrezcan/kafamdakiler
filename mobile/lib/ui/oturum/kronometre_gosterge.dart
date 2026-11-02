import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_theme.dart';
import 'kronometre_view_model.dart';

/// The big counter with its Start / Finish button, and "Vazgeç" to throw away
/// a started stopwatch. Ticks once a second, but the value always comes from
/// the start instant, never from counting ticks.
class KronometreGosterge extends StatefulWidget {
  const KronometreGosterge({super.key, required this.viewModel, required this.onBitir, this.onVazgec});

  final KronometreViewModel viewModel;
  final VoidCallback onBitir;

  /// Discards the running stopwatch without saving; hidden when null.
  final VoidCallback? onVazgec;

  @override
  State<KronometreGosterge> createState() => _KronometreGostergeState();
}

class _KronometreGostergeState extends State<KronometreGosterge> with WidgetsBindingObserver {
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.viewModel.calisiyor) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zamanlayici?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final rakam = KdYazi.of(context).sayi.copyWith(fontSize: 56, fontWeight: FontWeight.w500);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Geçen süre',
              child: Text(sureMetni(vm.gecen), style: rakam),
            ),
            const SizedBox(height: 24),
            if (!vm.calisiyor)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 56)),
                onPressed: vm.baslat,
                icon: const Icon(LucideIcons.play),
                label: const Text('Başla'),
              )
            else ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 56)),
                onPressed: widget.onBitir,
                icon: const Icon(LucideIcons.square),
                label: const Text('Bitir'),
              ),
              if (widget.onVazgec != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: widget.onVazgec, child: const Text('Vazgeç')),
              ],
            ],
          ],
        );
      },
    );
  }
}
